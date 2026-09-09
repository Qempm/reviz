'use server'

import { z } from 'zod'
import { createClient } from '@/lib/supabase/server'
import { normaliserTelephone, paysParCode, PAYS_PAR_DEFAUT } from '@/lib/auth/phone'

/**
 * Actions d'authentification.
 *
 * L'OTP est géré par Supabase Auth : c'est lui qui génère le code, le stocke
 * et le vérifie. Sa livraison passe par le « Send SMS Hook » configuré côté
 * Supabase, qui appelle n8n, qui envoie le WhatsApp — Reviz n'appelle jamais
 * l'API WhatsApp directement (CLAUDE.md, section Stack).
 *
 * Toute action valide son entrée par Zod et répond `{ ok, data | error }`.
 */

export type Reponse<T = undefined> =
  | { ok: true; data: T }
  | { ok: false; error: string; champ?: string }

const envoiSchema = z.object({
  telephone: z.string().min(1).max(30),
  pays: z.string().length(2).default('BJ'),
})

const verificationSchema = z.object({
  telephone: z.string().min(1).max(30),
  code: z.string().regex(/^\d{6}$/),
})

/**
 * Traduit les erreurs Supabase en messages utilisables.
 *
 * Les messages bruts sont en anglais et parlent de « OTP » : inutilisables
 * tels quels devant un étudiant.
 */
function traduireErreur(message: string): { cle: string; texte: string } {
  const m = message.toLowerCase()

  if (m.includes('expired')) {
    return { cle: 'codeExpire', texte: 'Ce code a expiré. Demandes-en un nouveau.' }
  }
  if (m.includes('invalid') || m.includes('incorrect')) {
    return {
      cle: 'codeInvalide',
      texte: 'Ce code ne marche pas. Vérifie, ou demandes-en un nouveau.',
    }
  }
  if (m.includes('rate limit') || m.includes('too many')) {
    return {
      cle: 'tropDeTentatives',
      texte: 'Trop d’essais. Patiente une minute avant de réessayer.',
    }
  }
  return {
    cle: 'inconnue',
    texte: 'Quelque chose a coincé de notre côté. Réessaie.',
  }
}

/** Demande l'envoi d'un code à usage unique. */
export async function envoyerCode(
  entree: z.input<typeof envoiSchema>,
): Promise<Reponse<{ telephone: string }>> {
  const parsed = envoiSchema.safeParse(entree)
  if (!parsed.success) {
    return { ok: false, error: 'Entre ton numéro pour continuer.', champ: 'telephone' }
  }

  const pays = paysParCode(parsed.data.pays) ?? PAYS_PAR_DEFAUT
  const numero = normaliserTelephone(parsed.data.telephone, pays)

  if (!numero.ok) {
    const messages: Record<string, string> = {
      vide: 'Entre ton numéro pour continuer.',
      longueur: `Ce numéro ne ressemble pas à un numéro ${pays.nom}.`,
      pays_inconnu: 'On ne reconnaît pas cet indicatif.',
    }
    return { ok: false, error: messages[numero.raison], champ: 'telephone' }
  }

  const supabase = await createClient()
  const { error } = await supabase.auth.signInWithOtp({
    phone: numero.e164,
    // Le profil est créé après vérification, pas ici : on ne veut pas de
    // compte fantôme pour chaque numéro saisi par erreur.
    options: { shouldCreateUser: true },
  })

  if (error) {
    const t = traduireErreur(error.message)
    return {
      ok: false,
      error:
        t.cle === 'inconnue'
          ? 'On n’a pas pu envoyer le code. Vérifie ta connexion et réessaie.'
          : t.texte,
    }
  }

  return { ok: true, data: { telephone: numero.e164 } }
}

/** Vérifie le code et ouvre la session. */
export async function verifierCode(
  entree: z.input<typeof verificationSchema>,
): Promise<Reponse<{ profilExistant: boolean }>> {
  const parsed = verificationSchema.safeParse(entree)
  if (!parsed.success) {
    return { ok: false, error: 'Il manque des chiffres.', champ: 'code' }
  }

  const supabase = await createClient()
  const { data, error } = await supabase.auth.verifyOtp({
    phone: parsed.data.telephone,
    token: parsed.data.code,
    type: 'sms',
  })

  if (error || !data.user) {
    return { ok: false, error: traduireErreur(error?.message ?? '').texte, champ: 'code' }
  }

  // Le profil existe-t-il déjà ? Il décide de la suite : tableau de bord pour
  // un retour, parcours d'inscription pour une première fois.
  const { data: profil } = await supabase
    .from('profiles')
    .select('id')
    .eq('id', data.user.id)
    .maybeSingle()

  return { ok: true, data: { profilExistant: profil !== null } }
}
