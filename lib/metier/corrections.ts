import 'server-only'
import { z } from 'zod'
import type { ClientReviz } from '@/lib/supabase/jeton'
import { TYPES_EPREUVE } from '@/lib/metier/corrections-types'
import {
  etatAcces,
  peutCorriger,
  type PackCode,
  type RefusCorrection,
} from '@/lib/payments/subscriptions'

/**
 * Dépôt d'une copie à corriger — la logique, sans la porte d'entrée.
 *
 * **Le fichier ne passe plus par nos fonctions.** La première version le
 * faisait traverser une fonction serverless, plafonnée à 4,5 Mo de charge
 * utile chez Vercel, alors que le seau `copies` accepte 10 Mo par image : une
 * photo de téléphone récent pèse 3 à 8 Mo, et deux ne passaient jamais.
 * Garder ce chemin aurait imposé une compression agressive, donc sacrifié la
 * lisibilité d'une écriture manuscrite à une limite de plateforme. La copie
 * monte donc du téléphone directement vers le stockage, par une URL signée,
 * exactement comme un cours (`lib/metier/cours.ts`).
 *
 * Deux autres corrections au passage :
 *
 *  * la ligne `corrections` est créée **avant** l'envoi, ce qui fait trancher
 *    le plafond de cinq par jour en 200 ms au lieu d'après quarante secondes
 *    d'envoi sur une 3G ;
 *  * l'URL est signée **sous l'identité de l'étudiant** et non avec le rôle de
 *    service : la politique « Je dépose mes copies » s'applique alors au
 *    moment de la signature. La version précédente téléversait en admin,
 *    donc hors RLS.
 */

const MIMES = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
} as const

/** 10 Mo, comme le seau `copies` (20260909180000_stockage.sql). */
export const TAILLE_MAX_COPIE = 10_485_760

const fichier = z.object({
  mime: z.enum(
    Object.keys(MIMES) as [keyof typeof MIMES, ...(keyof typeof MIMES)[]],
  ),
  taille: z.number().int().positive().max(TAILLE_MAX_COPIE),
})

/** Pages de copie au-delà de la première. */
export const PAGES_SUPPLEMENTAIRES_MAX = 3


export const entreeCorrection = z.object({
  copie: fichier,
  /**
   * Les pages suivantes de la copie. Facultatif : un APK antérieur n'envoie
   * que `copie`, et continue de fonctionner.
   */
  pages: z.array(fichier).max(PAGES_SUPPLEMENTAIRES_MAX).optional(),
  /** Le type d'épreuve, pour exiger ce qu'on attend à ce moment de l'année. */
  typeEpreuve: z.enum(TYPES_EPREUVE).nullable().optional(),
  /** Le barème annoncé par le professeur. 20 par défaut. */
  bareme: z.number().int().min(5).max(100).nullable().optional(),
  /** Le sujet, facultatif : il aide le modèle à noter ce qui était demandé. */
  sujet: fichier.nullable().optional(),
  /** Rattachement à un cours, pour situer la correction. Facultatif. */
  courseId: z.string().uuid().nullable().optional(),
})

export type EntreeCorrection = z.input<typeof entreeCorrection>

/** `page` : une page de copie au-delà de la première, dans l'ordre. */
export type ChampEnvoi = 'copie' | 'page' | 'sujet'

export type RefusPreparation =
  | 'invalide'
  | 'serveur'
  /** Les refus de `peutCorriger()`, transmis tels quels pour être traduits. */
  | RefusCorrection

export type PreparationCorrection =
  | {
      ok: true
      correctionId: string
      /** Une entrée par fichier attendu, dans l'ordre : copie, pages, sujet. */
      envois: Array<{ champ: ChampEnvoi; chemin: string; url: string }>
    }
  | {
      ok: false
      error: RefusPreparation
      /** Corrections restantes, pour l'expliquer plutôt que refuser sèchement. */
      restantes?: number
    }

/** Bornes du jour, en UTC — celles que retient le trigger `corrections_daily_cap`. */
function debutDuJour(maintenant: Date): string {
  const d = new Date(maintenant)
  d.setUTCHours(0, 0, 0, 0)
  return d.toISOString()
}

/**
 * Réserve une correction et signe les URL d'envoi.
 *
 * L'accès est calculé par `etatAcces()` et `peutCorriger()`, qui **somment**
 * les corrections restantes de tous les packs actifs. La version précédente
 * fabriquait un état à la main — `daysLeft: 999`, `packCodes: [… as any]` — à
 * partir d'un seul abonnement (`.limit(1)`) : un étudiant avec deux packs
 * actifs ne voyait que les corrections de l'un.
 */
export async function preparerCorrection(
  supabase: ClientReviz,
  userId: string,
  brut: EntreeCorrection,
  maintenant: Date = new Date(),
): Promise<PreparationCorrection> {
  const parse = entreeCorrection.safeParse(brut)
  if (!parse.success) return { ok: false, error: 'invalide' }
  const { copie, sujet, courseId, pages, typeEpreuve, bareme } = parse.data

  const { data: lignes } = await supabase
    .from('subscriptions')
    .select('pack_code, starts_at, ends_at, corrections_left, packs(subjects_limit)')
    .eq('user_id', userId)

  const acces = etatAcces(
    (lignes ?? []).map((l) => ({
      packCode: l.pack_code as PackCode,
      startsAt: new Date(l.starts_at),
      endsAt: new Date(l.ends_at),
      correctionsLeft: l.corrections_left,
      subjectsLimit:
        (l.packs as { subjects_limit: number | null } | null)?.subjects_limit ??
        null,
    })),
    maintenant,
  )

  // Le plafond journalier est aussi tenu par le trigger
  // `corrections_daily_cap` : on le vérifie ici pour pouvoir le dire avant
  // l'envoi, pas pour le remplacer.
  const { count: duJour } = await supabase
    .from('corrections')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId)
    .gte('created_at', debutDuJour(maintenant))

  const droit = peutCorriger({
    acces,
    correctionsAujourdhui: duJour ?? 0,
  })

  if (!droit.autorise) {
    return {
      ok: false,
      error: droit.reason,
      restantes: acces.state === 'active' ? acces.correctionsLeft : 0,
    }
  }

  // L'identifiant est tiré ici et non par la base : les chemins de stockage
  // en dépendent, et le client doit les connaître avant d'envoyer.
  const correctionId = crypto.randomUUID()

  const attendus: Array<{ champ: ChampEnvoi; chemin: string }> = [
    { champ: 'copie', chemin: `${userId}/${correctionId}/copie.${MIMES[copie.mime]}` },
    // Numérotées à partir de 2 : `copie-2`, `copie-3`… Le gestionnaire les
    // remet dans cet ordre et les étiquette « Page N de la copie ».
    ...(pages ?? []).map((p, i) => ({
      champ: 'page' as const,
      chemin: `${userId}/${correctionId}/copie-${i + 2}.${MIMES[p.mime]}`,
    })),
  ]

  if (sujet) {
    attendus.push({
      champ: 'sujet',
      chemin: `${userId}/${correctionId}/sujet.${MIMES[sujet.mime]}`,
    })
  }

  const { error } = await supabase.from('corrections').insert({
    id: correctionId,
    user_id: userId,
    course_id: courseId ?? null,
    storage_paths: attendus.map((a) => a.chemin),
    status: 'pending',
    // Ce que l'étudiant a précisé, gardé dans `feedback` jusqu'à la
    // correction, qui le remplace : pas de colonne à ajouter, donc rien qui
    // casse tant que la base n'a pas été migrée.
    feedback: {
      demande: { typeEpreuve: typeEpreuve ?? null, bareme: bareme ?? null },
    },
  })

  if (error) {
    // Le plafond du trigger tombe ici si la vérification ci-dessus a couru
    // en même temps qu'un autre dépôt.
    console.error('[correction] création impossible', error.message)
    return { ok: false, error: 'plafond_journalier' }
  }

  const envois: Array<{ champ: ChampEnvoi; chemin: string; url: string }> = []

  for (const attendu of attendus) {
    const { data: signature, error: erreurSignature } = await supabase.storage
      .from('copies')
      .createSignedUploadUrl(attendu.chemin)

    if (erreurSignature || !signature) {
      // La ligne vient d'être créée : sans ce retrait, elle consommerait une
      // des cinq corrections du jour sans jamais rien corriger.
      await supabase.from('corrections').delete().eq('id', correctionId)
      console.error(
        '[correction] signature d’envoi impossible',
        erreurSignature?.message,
      )
      return { ok: false, error: 'serveur' }
    }

    envois.push({ ...attendu, url: signature.signedUrl })
  }

  return { ok: true, correctionId, envois }
}

export type ConfirmationCorrection =
  | { ok: true; jobId: string }
  | { ok: false; error: 'invalide' | 'introuvable' | 'stockage' | 'serveur' }

/**
 * Les fichiers sont arrivés : la correction entre en file.
 *
 * Le job est bien mis en file ici — contrairement au dépôt de cours, dont le
 * traitement `ingest_course` n'existe pas : `correct_copy` a le sien, et un
 * type sans traitement ferait échouer le job définitivement.
 *
 * L'appelant lance ensuite le traitement dans la même invocation, sans
 * attendre le cron : c'est l'objet du `jobId` rendu ici.
 */
export async function confirmerCorrection(
  supabase: ClientReviz,
  userId: string,
  correctionId: string,
): Promise<ConfirmationCorrection> {
  const parse = z.string().uuid().safeParse(correctionId)
  if (!parse.success) return { ok: false, error: 'invalide' }

  const { data: correction } = await supabase
    .from('corrections')
    .select('id, storage_paths, status')
    .eq('id', parse.data)
    .eq('user_id', userId)
    .maybeSingle()

  if (!correction) return { ok: false, error: 'introuvable' }

  // Une confirmation rejouée — reprise après coupure, double appui — ne doit
  // pas enfiler un second job pour la même copie.
  if (correction.status !== 'pending') {
    return { ok: false, error: 'invalide' }
  }

  const chemins = (correction.storage_paths as string[] | null) ?? []

  // Les fichiers sont-ils vraiment là ? Le client pourrait confirmer sans
  // avoir rien envoyé, et le gestionnaire ne trouverait alors aucune image
  // au bout d'un appel IA déjà payé.
  const { createAdminClient } = await import('@/lib/supabase/admin')
  const admin = createAdminClient()

  for (const chemin of chemins) {
    const dossier = chemin.slice(0, chemin.lastIndexOf('/'))
    const nom = chemin.slice(chemin.lastIndexOf('/') + 1)

    const { data: objets } = await admin.storage
      .from('copies')
      .list(dossier, { search: nom })

    if (!objets?.some((o) => o.name === nom)) {
      return { ok: false, error: 'stockage' }
    }
  }

  const { data: job, error } = await admin
    .from('jobs')
    .insert({
      type: 'correct_copy',
      payload: { correction_id: parse.data, user_id: userId, storage_paths: chemins },
    })
    .select('id')
    .single()

  if (error || !job) {
    console.error('[correction] mise en file impossible', error?.message)
    return { ok: false, error: 'serveur' }
  }

  return { ok: true, jobId: job.id }
}

/**
 * L'envoi n'a pas abouti : la ligne réservée est retirée.
 *
 * Sans cela, une coupure au milieu d'un envoi consommerait une des cinq
 * corrections du jour sans que rien ne soit corrigé.
 */
export async function annulerCorrection(
  supabase: ClientReviz,
  userId: string,
  correctionId: string,
): Promise<void> {
  const parse = z.string().uuid().safeParse(correctionId)
  if (!parse.success) return

  await supabase
    .from('corrections')
    .delete()
    .eq('id', parse.data)
    .eq('user_id', userId)
    .eq('status', 'pending')
}
