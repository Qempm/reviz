'use server'

import { headers } from 'next/headers'
import { redirect } from 'next/navigation'
import { z } from 'zod'
import { createClient } from '@/lib/supabase/server'

/**
 * Actions d'authentification.
 *
 * Deux portes d'entrée depuis le 9 septembre 2026 : Google, et un code à
 * 6 chiffres envoyé par email. L'OTP téléphone est abandonné — le numéro reste
 * une donnée de profil facultative (CLAUDE.md, règle métier 3).
 *
 * Le code par email plutôt qu'un lien magique : sur un Android d'entrée de
 * gamme avec une connexion instable, quitter l'app pour ouvrir un lien puis y
 * revenir est un point d'abandon. Six chiffres se recopient.
 *
 * Toute action valide son entrée par Zod et répond `{ ok, data | error }`.
 */

export type Reponse<T = undefined> =
  | { ok: true; data: T }
  | { ok: false; error: string; champ?: string }

const emailSchema = z.object({
  email: z.string().trim().toLowerCase().email().max(320),
})

const verificationSchema = z.object({
  email: z.string().trim().toLowerCase().email().max(320),
  code: z.string().regex(/^\d{6}$/),
})

/**
 * Traduit les erreurs Supabase, en anglais et techniques, en messages
 * affichables devant un étudiant.
 */
function traduireErreur(message: string): string {
  const m = message.toLowerCase()

  if (m.includes('expired')) {
    return 'Ce code a expiré. Demandes-en un nouveau.'
  }
  if (m.includes('invalid') || m.includes('incorrect') || m.includes('token')) {
    return 'Ce code ne marche pas. Vérifie, ou demandes-en un nouveau.'
  }
  if (m.includes('rate limit') || m.includes('too many') || m.includes('security purposes')) {
    return 'Trop d’essais. Patiente une minute avant de réessayer.'
  }
  if (m.includes('signups not allowed') || m.includes('disabled')) {
    return 'Les inscriptions sont fermées pour le moment.'
  }
  return 'Quelque chose a coincé de notre côté. Réessaie.'
}

/** URL de base du site, pour les retours OAuth. */
async function origine(): Promise<string> {
  const h = await headers()
  // Derrière Vercel, l'hôte réel est dans x-forwarded-host.
  const hote = h.get('x-forwarded-host') ?? h.get('host') ?? 'localhost:3000'
  const protocole = h.get('x-forwarded-proto') ?? (hote.startsWith('localhost') ? 'http' : 'https')
  return `${protocole}://${hote}`
}

/** Envoie un code à 6 chiffres par email. */
export async function envoyerCodeEmail(
  entree: z.input<typeof emailSchema>,
): Promise<Reponse<{ email: string }>> {
  const parsed = emailSchema.safeParse(entree)
  if (!parsed.success) {
    return {
      ok: false,
      error: 'Cette adresse ne ressemble pas à un email.',
      champ: 'email',
    }
  }

  const supabase = await createClient()
  const base = await origine()

  const { error } = await supabase.auth.signInWithOtp({
    email: parsed.data.email,
    options: {
      shouldCreateUser: true,
      // Le gabarit d'email peut contenir un code à recopier, un lien, ou les
      // deux. En déclarant la destination du lien, les deux chemins
      // fonctionnent : l'étudiant saisit les six chiffres, ou clique — et
      // /auth/rappel échange le code contre une session dans les deux cas.
      emailRedirectTo: new URL('/auth/rappel', base).toString(),
    },
  })

  if (error) {
    return { ok: false, error: traduireErreur(error.message) }
  }

  return { ok: true, data: { email: parsed.data.email } }
}

/** Vérifie le code reçu par email et ouvre la session. */
export async function verifierCodeEmail(
  entree: z.input<typeof verificationSchema>,
): Promise<Reponse<{ profilExistant: boolean }>> {
  const parsed = verificationSchema.safeParse(entree)
  if (!parsed.success) {
    return { ok: false, error: 'Il manque des chiffres.', champ: 'code' }
  }

  const supabase = await createClient()
  const { data, error } = await supabase.auth.verifyOtp({
    email: parsed.data.email,
    token: parsed.data.code,
    type: 'email',
  })

  if (error || !data.user) {
    return { ok: false, error: traduireErreur(error?.message ?? ''), champ: 'code' }
  }

  const { data: profil } = await supabase
    .from('profiles')
    .select('id')
    .eq('id', data.user.id)
    .maybeSingle()

  return { ok: true, data: { profilExistant: profil !== null } }
}

/**
 * Démarre la connexion Google.
 *
 * Redirige vers Google, qui renverra vers /auth/rappel avec un code à
 * échanger contre une session.
 */
export async function connexionGoogle(suite?: string): Promise<void> {
  const supabase = await createClient()
  const base = await origine()

  const rappel = new URL('/auth/rappel', base)
  if (suite) rappel.searchParams.set('suite', suite)

  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: rappel.toString(),
      queryParams: {
        // Force le choix du compte : sur un téléphone partagé, enchaîner
        // sans écran de sélection connecterait le mauvais étudiant.
        prompt: 'select_account',
      },
    },
  })

  if (error || !data.url) {
    redirect(`/connexion?erreur=${encodeURIComponent(traduireErreur(error?.message ?? ''))}`)
  }

  redirect(data.url)
}

/** Ferme la session. */
export async function deconnexion(): Promise<void> {
  const supabase = await createClient()
  await supabase.auth.signOut()
  redirect('/connexion')
}
