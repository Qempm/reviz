import 'server-only'
import { z } from 'zod'
import type { ClientReviz } from '@/lib/supabase/jeton'
import {
  etatAcces,
  peutAjouterMatiere,
  type Subscription,
} from '@/lib/payments/subscriptions'
import { BAREME } from '@/lib/xp/attribution'
import { attribuerXp } from '@/lib/xp/attribuer'

/**
 * Dépôt d'un cours — la logique, sans la porte d'entrée.
 *
 * Elle vivait dans `app/(app)/reviser/ajouter/actions.ts`. Une Server Action
 * n'est pas appelable depuis Flutter : c'est un protocole interne à Next.js,
 * avec des identifiants d'action chiffrés et une charge utile multipart. Le
 * corps descend donc ici, et la Server Action comme la route REST l'appellent
 * — une seule implémentation, deux portes.
 *
 * Le client Supabase est injecté plutôt que construit ici : c'est ce qui
 * permet à la route d'agir au nom du porteur d'un jeton et à l'action au nom
 * d'un cookie, sans que cette fonction ait à le savoir.
 *
 * Le fichier ne passe jamais par nos fonctions : il monte du téléphone
 * directement vers le stockage, par une URL signée. Une charge utile de 25 Mo
 * dépasserait de toute façon la limite d'une fonction serverless.
 */

const MIMES = {
  'application/pdf': 'pdf',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'docx',
  'application/msword': 'doc',
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
} as const

/** 25 Mo, comme le bucket `cours` (20260909180000_stockage.sql). */
export const TAILLE_MAX_COURS = 26_214_400

export const entreeDepot = z.object({
  /** SHA-256 du fichier, calculé par le client : 64 caractères hexa. */
  fileHash: z.string().regex(/^[0-9a-f]{64}$/),
  subjectId: z.string().uuid(),
  title: z.string().trim().min(2).max(200),
  /** `YYYY-MM-DD`, ou rien. */
  examDate: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .nullable()
    .optional(),
  mime: z.enum(
    Object.keys(MIMES) as [keyof typeof MIMES, ...(keyof typeof MIMES)[]],
  ),
  taille: z.number().int().positive().max(TAILLE_MAX_COURS),
})

export type EntreeDepot = z.input<typeof entreeDepot>

export type RefusDepot =
  | 'session'
  | 'aucun-acces'
  | 'acces-expire'
  | 'plafond-matieres'
  | 'deja-depose'
  | 'invalide'
  | 'serveur'

export type PreparationDepot =
  | { ok: true; courseId: string; storagePath: string; uploadUrl: string }
  | {
      ok: false
      error: RefusDepot
      /** Cours déjà déposé pour cette empreinte, pour y renvoyer. */
      courseId?: string
      /** Plafond du pack, pour l'expliquer plutôt que de refuser sèchement. */
      plafond?: number
    }

export async function preparerDepot(
  supabase: ClientReviz,
  userId: string,
  brut: EntreeDepot,
): Promise<PreparationDepot> {
  const parse = entreeDepot.safeParse(brut)
  if (!parse.success) return { ok: false, error: 'invalide' }
  const { fileHash, subjectId, title, examDate, mime } = parse.data

  // Règle métier 1 : hors pack actif, l'application est en lecture seule.
  const { data: lignes } = await supabase
    .from('subscriptions')
    .select('pack_code, starts_at, ends_at, corrections_left, packs(subjects_limit)')

  const abonnements: Subscription[] = (lignes ?? []).map((l) => ({
    packCode: l.pack_code,
    startsAt: new Date(l.starts_at),
    endsAt: new Date(l.ends_at),
    correctionsLeft: l.corrections_left,
    subjectsLimit:
      (l.packs as { subjects_limit: number | null } | null)?.subjects_limit ?? null,
  }))

  const acces = etatAcces(abonnements)
  if (acces.state === 'expired') return { ok: false, error: 'acces-expire' }
  if (acces.state === 'none') return { ok: false, error: 'aucun-acces' }

  // Le plafond porte sur les matières, pas sur les cours : deux cours de la
  // même matière n'en consomment qu'une. Les cours de démonstration ne
  // comptent pas, ils n'appartiennent à personne.
  const { data: miens } = await supabase
    .from('courses')
    .select('subject_id, file_hash, id')
    .eq('owner_id', userId)

  const matieres = new Set(
    (miens ?? []).map((c) => c.subject_id).filter((s): s is string => s !== null),
  )

  const dejaLa = (miens ?? []).find((c) => c.file_hash === fileHash)
  // `unique (owner_id, file_hash)` refuserait de toute façon l'insertion :
  // autant renvoyer l'étudiant vers le cours qu'il a déjà.
  if (dejaLa) return { ok: false, error: 'deja-depose', courseId: dejaLa.id }

  if (
    !matieres.has(subjectId) &&
    !peutAjouterMatiere({ acces, matieresActives: matieres.size })
  ) {
    return {
      ok: false,
      error: 'plafond-matieres',
      plafond: acces.subjectsLimit ?? undefined,
    }
  }

  // L'identifiant est tiré ici et non par la base : le chemin de stockage en
  // dépend, et le client doit le connaître avant d'envoyer le fichier.
  const courseId = crypto.randomUUID()
  const storagePath = `${userId}/${courseId}/source.${MIMES[mime]}`

  const { error } = await supabase.from('courses').insert({
    id: courseId,
    owner_id: userId,
    subject_id: subjectId,
    title,
    file_hash: fileHash,
    storage_path: storagePath,
    exam_date: examDate ?? null,
    status: 'uploaded',
  })

  if (error) {
    console.error('[cours] création impossible', error.message)
    return { ok: false, error: 'serveur' }
  }

  // L'URL est signée sous l'identité de l'étudiant : la politique de stockage
  // s'applique au moment de la signature, et le jeton ne vaut que pour ce
  // chemin-là.
  const { data: signature, error: erreurSignature } = await supabase.storage
    .from('cours')
    .createSignedUploadUrl(storagePath)

  if (erreurSignature || !signature) {
    // La ligne vient d'être créée : sans elle, l'empreinte resterait prise.
    await supabase.from('courses').delete().eq('id', courseId)
    console.error('[cours] signature d’envoi impossible', erreurSignature?.message)
    return { ok: false, error: 'serveur' }
  }

  return { ok: true, courseId, storagePath, uploadUrl: signature.signedUrl }
}

/**
 * Le fichier est arrivé : le cours part en traitement.
 *
 * Le job `ingest_course` est enfin mis en file. Il ne l'était pas, et pour une
 * bonne raison : le traitement n'existait pas, et le runner échoue
 * **définitivement** sur un type sans traitement enregistré — chaque cours
 * déposé serait passé en `failed` au premier passage du cron. Il existe
 * maintenant (`lib/jobs/handlers.ts`).
 *
 * Le traitement part **tout de suite**, dans la même invocation, comme la
 * correction de copie : le cron ne tourne qu'une fois par jour sur l'offre
 * Hobby, et un étudiant qui dépose son cours la veille d'un contrôle ne peut
 * pas attendre demain soir. C'est à l'appelant de le lancer — on rend
 * l'identifiant du job pour cela.
 */
export async function confirmerDepot(
  supabase: ClientReviz,
  userId: string,
  courseId: string,
): Promise<{ ok: boolean; jobId?: string }> {
  const parse = z.string().uuid().safeParse(courseId)
  if (!parse.success) return { ok: false }

  // `eq('status', 'uploaded')` n'est pas décoratif : sans lui, un client qui
  // rappelle l'action — reprise après coupure, double clic — recréditerait
  // les XP du dépôt à chaque fois. Le trigger `courses_protect_status`
  // laisserait passer, la transition étant alors un non-changement.
  const { data: modifie, error } = await supabase
    .from('courses')
    .update({ status: 'processing' })
    .eq('id', parse.data)
    .eq('owner_id', userId)
    .eq('status', 'uploaded')
    .select('id')

  if (error) {
    console.error('[cours] passage en traitement impossible', error.message)
    return { ok: false }
  }

  // La transition n'a lieu qu'une fois : sans cela, un client qui rappelle
  // l'action recréditerait les XP et enfilerait un second traitement.
  if ((modifie ?? []).length === 0) return { ok: true }

  await attribuerXp({
    userId,
    gains: [{ reason: 'course_added', amount: BAREME.course_added }],
    referenceId: parse.data,
  })

  // La file n'a aucune politique RLS : elle s'écrit avec le rôle de service.
  const { createAdminClient } = await import('@/lib/supabase/admin')
  const { data: job, error: erreurJob } = await createAdminClient()
    .from('jobs')
    .insert({ type: 'ingest_course', payload: { course_id: parse.data } })
    .select('id')
    .single()

  if (erreurJob || !job) {
    // Le cours est en `processing` et les XP sont crédités : on ne revient pas
    // en arrière pour une mise en file ratée. Le cours restera en attente, et
    // c'est visible à l'écran.
    console.error('[cours] mise en file du traitement impossible', erreurJob)
    return { ok: true }
  }

  return { ok: true, jobId: job.id }
}

/**
 * Le fichier n'a pas pu monter : la ligne créée par `preparerDepot` est
 * retirée. Sans cela, l'empreinte resterait prise par
 * `unique (owner_id, file_hash)` et le même document ne pourrait plus jamais
 * être redéposé.
 */
export async function annulerDepot(
  supabase: ClientReviz,
  userId: string,
  courseId: string,
): Promise<void> {
  const parse = z.string().uuid().safeParse(courseId)
  if (!parse.success) return

  await supabase
    .from('courses')
    .delete()
    .eq('id', parse.data)
    .eq('owner_id', userId)
    .eq('status', 'uploaded')
}
