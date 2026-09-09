'use server'

import { revalidatePath } from 'next/cache'
import { z } from 'zod'
import { createClient } from '@/lib/supabase/server'
import {
  etatAcces,
  peutAjouterMatiere,
  type Subscription,
} from '@/lib/payments/subscriptions'

/**
 * Dépôt d'un cours (écran D1).
 *
 * En deux temps, et non en un seul envoi de formulaire : le fichier monte
 * directement du téléphone vers Supabase Storage, sans transiter par une
 * fonction serverless. Un polycopié scanné de 25 Mo dépasserait la limite de
 * charge utile d'une Server Action, et le faire passer par Vercel doublerait
 * la consommation de données de l'étudiant.
 *
 *   1. `preparerDepot` vérifie les droits, crée la ligne `courses` et signe
 *      une URL d'envoi pour le chemin attendu par la politique
 *      « Je dépose mes cours » (`<user_id>/…`).
 *   2. Le client y envoie le fichier par un simple `fetch` — pas de client
 *      Supabase dans le navigateur : l'importer coûtait 70 ko sur cette
 *      route, pour un seul appel.
 *   3. `confirmerDepot` fait passer le cours en `processing`.
 *
 * La ligne `courses` est écrite sous l'identité de l'étudiant : la politique
 * d'insertion exige `owner_id = auth.uid()`, elle suffit et le rôle de
 * service n'a rien à faire ici.
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
const TAILLE_MAX = 26_214_400

const entree = z.object({
  /** SHA-256 du fichier, calculé par le navigateur : 64 caractères hexa. */
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
  taille: z.number().int().positive().max(TAILLE_MAX),
})

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
  brut: z.input<typeof entree>,
): Promise<PreparationDepot> {
  const parse = entree.safeParse(brut)
  if (!parse.success) return { ok: false, error: 'invalide' }
  const { fileHash, subjectId, title, examDate, mime } = parse.data

  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) return { ok: false, error: 'session' }

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
    .eq('owner_id', user.id)

  const matieres = new Set(
    (miens ?? []).map((c) => c.subject_id).filter((s): s is string => s !== null),
  )

  const dejaLa = (miens ?? []).find((c) => c.file_hash === fileHash)
  // `unique (owner_id, file_hash)` refuserait de toute façon l'insertion :
  // autant renvoyer l'étudiant vers le cours qu'il a déjà, plutôt que sur une
  // erreur de contrainte.
  if (dejaLa) return { ok: false, error: 'deja-depose', courseId: dejaLa.id }

  // La matière déjà déposée ne consomme pas une place de plus.
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
  const storagePath = `${user.id}/${courseId}/source.${MIMES[mime]}`

  const { error } = await supabase.from('courses').insert({
    id: courseId,
    owner_id: user.id,
    subject_id: subjectId,
    title,
    file_hash: fileHash,
    storage_path: storagePath,
    exam_date: examDate ?? null,
    status: 'uploaded',
  })

  if (error) {
    console.error('Création du cours impossible', error.message)
    return { ok: false, error: 'serveur' }
  }

  // L'URL est signée sous l'identité de l'étudiant : la politique de
  // stockage s'applique au moment de la signature, et le jeton ne vaut que
  // pour ce chemin-là.
  const { data: signature, error: erreurSignature } = await supabase.storage
    .from('cours')
    .createSignedUploadUrl(storagePath)

  if (erreurSignature || !signature) {
    // La ligne vient d'être créée : sans elle, l'empreinte resterait prise.
    await supabase.from('courses').delete().eq('id', courseId)
    console.error('Signature d’envoi impossible', erreurSignature?.message)
    return { ok: false, error: 'serveur' }
  }

  return { ok: true, courseId, storagePath, uploadUrl: signature.signedUrl }
}

/**
 * Le fichier est arrivé : le cours passe en attente de traitement.
 *
 * Aucun job n'est mis en file pour l'instant, et c'est délibéré : le
 * traitement `ingest_course` n'existe pas encore (il attend les clés IA,
 * lot 9), et le runner échoue **définitivement** sur un type sans
 * traitement enregistré (`lib/jobs/runner.ts`). Mettre le job en file
 * maintenant ferait passer chaque cours déposé en `failed` au premier
 * passage du cron. Les cours en `processing` sont donc la file d'attente :
 * le lot 9 les reprendra.
 */
export async function confirmerDepot(courseId: string): Promise<{ ok: boolean }> {
  const parse = z.string().uuid().safeParse(courseId)
  if (!parse.success) return { ok: false }

  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) return { ok: false }

  const { error } = await supabase
    .from('courses')
    .update({ status: 'processing' })
    .eq('id', parse.data)
    .eq('owner_id', user.id)

  if (error) {
    console.error('Passage en traitement impossible', error.message)
    return { ok: false }
  }

  revalidatePath('/reviser')
  revalidatePath(`/cours/${parse.data}`)
  return { ok: true }
}

/**
 * Le fichier n'a pas pu monter : la ligne créée par `preparerDepot` est
 * retirée.
 *
 * Sans cela, l'empreinte resterait prise par `unique (owner_id, file_hash)`
 * et l'étudiant ne pourrait plus jamais redéposer le même document.
 */
export async function annulerDepot(courseId: string): Promise<void> {
  const parse = z.string().uuid().safeParse(courseId)
  if (!parse.success) return

  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) return

  await supabase
    .from('courses')
    .delete()
    .eq('id', parse.data)
    .eq('owner_id', user.id)
    .eq('status', 'uploaded')
}
