import 'server-only'
import { z } from 'zod'
import type { ClientReviz } from '@/lib/supabase/jeton'
import { cheminDeSonDossier } from './carte'

/**
 * Dépôt de la photo de carte étudiante.
 *
 * Même chemin que les cours et les copies : URL signée, `PUT` direct au
 * stockage, confirmation. Une photo de carte est petite, mais la faire
 * traverser une fonction serverless n'aurait rien apporté et aurait dupliqué
 * un chemin qui existe déjà.
 *
 * Un point propre à la carte : **on ne réserve rien à l'avance**. Le dépôt
 * d'un cours crée sa ligne `courses` avant l'envoi, parce que le plafond
 * journalier doit trancher tôt ; ici il n'y a rien à créer — le profil
 * existe déjà, et c'est son `verification_status` qui bougera.
 */

const MIMES = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
} as const

/** 10 Mo, comme le seau `cartes`. */
export const TAILLE_MAX_CARTE = 10_485_760

export const entreeCarte = z.object({
  mime: z.enum(
    Object.keys(MIMES) as [keyof typeof MIMES, ...(keyof typeof MIMES)[]],
  ),
  taille: z.number().int().positive().max(TAILLE_MAX_CARTE),
})

export type EntreeCarte = z.input<typeof entreeCarte>

export type RefusCarte =
  | 'invalide'
  | 'deja-verifie'
  | 'en-cours'
  | 'serveur'

export type PreparationCarte =
  | { ok: true; chemin: string; uploadUrl: string }
  | { ok: false; error: RefusCarte }

/**
 * Signe une URL d'envoi pour la photo de carte.
 *
 * Le chemin porte un horodatage : une carte redéposée ne doit pas écraser la
 * précédente, qui sert de pièce en cas de contestation.
 */
export async function preparerCarte(
  supabase: ClientReviz,
  userId: string,
  brut: EntreeCarte,
): Promise<PreparationCarte> {
  const parse = entreeCarte.safeParse(brut)
  if (!parse.success) return { ok: false, error: 'invalide' }

  const { data: profil } = await supabase
    .from('profiles')
    .select('verification_status')
    .eq('id', userId)
    .maybeSingle()

  // Déjà vérifié : rien à redéposer. Laisser faire permettrait de tenter
  // plusieurs cartes jusqu'à ce qu'une passe.
  if (profil?.verification_status === 'verified') {
    return { ok: false, error: 'deja-verifie' }
  }

  if (profil?.verification_status === 'pending') {
    return { ok: false, error: 'en-cours' }
  }

  const chemin = `${userId}/carte-${Date.now()}.${MIMES[parse.data.mime]}`

  // Signée sous l'identité de l'étudiant : la politique « Je dépose ma
  // carte » s'applique au moment de la signature.
  const { data: signature, error } = await supabase.storage
    .from('cartes')
    .createSignedUploadUrl(chemin)

  if (error || !signature) {
    console.error('[carte] signature d’envoi impossible', error?.message)
    return { ok: false, error: 'serveur' }
  }

  return { ok: true, chemin, uploadUrl: signature.signedUrl }
}

export type ConfirmationCarte =
  | { ok: true; jobId: string }
  | { ok: false; error: 'invalide' | 'stockage' | 'serveur' }

/**
 * La photo est arrivée : la vérification entre en file.
 *
 * Le profil passe en `pending` **ici** et non dans le traitement : c'est ce
 * qui fait que l'écran annonce « on regarde ta carte » dès le retour de la
 * route, sans attendre le premier appel de modèle.
 */
export async function confirmerCarte(
  supabase: ClientReviz,
  userId: string,
  chemin: string,
): Promise<ConfirmationCarte> {
  // Le chemin doit être dans le dossier de l'appelant : sans ce contrôle, un
  // client pourrait faire vérifier la carte de quelqu'un d'autre — et
  // s'attribuer son empreinte.
  if (!cheminDeSonDossier(chemin, userId)) {
    return { ok: false, error: 'invalide' }
  }

  const { createAdminClient } = await import('@/lib/supabase/admin')
  const admin = createAdminClient()

  const dossier = chemin.slice(0, chemin.lastIndexOf('/'))
  const nom = chemin.slice(chemin.lastIndexOf('/') + 1)

  const { data: objets } = await admin.storage
    .from('cartes')
    .list(dossier, { search: nom })

  if (!objets?.some((o) => o.name === nom)) {
    return { ok: false, error: 'stockage' }
  }

  const { error: erreurStatut } = await admin
    .from('profiles')
    .update({ verification_status: 'pending' })
    .eq('id', userId)

  if (erreurStatut) {
    console.error('[carte] passage en attente impossible', erreurStatut.message)
    return { ok: false, error: 'serveur' }
  }

  const { data: job, error } = await admin
    .from('jobs')
    .insert({
      type: 'verify_card',
      payload: { profile_id: userId, storage_path: chemin },
    })
    .select('id')
    .single()

  if (error || !job) {
    console.error('[carte] mise en file impossible', error?.message)
    return { ok: false, error: 'serveur' }
  }

  return { ok: true, jobId: job.id }
}
