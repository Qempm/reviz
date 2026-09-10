import 'server-only'
import { createAdminClient, ConfigurationManquante } from '@/lib/supabase/admin'
import type { GainXp } from './attribution'
import { totalGains } from './attribution'

/**
 * Écriture des gains d'XP dans le journal.
 *
 * Passe par le rôle de service : `xp_events` n'a volontairement aucune
 * politique d'insertion côté client
 * (supabase/migrations/20260908140000_xp_et_series.sql). Un étudiant qui
 * pourrait y insérer s'offrirait la première place du classement.
 *
 * **N'échoue jamais vers l'appelant.** L'XP est une récompense, pas une
 * donnée métier : perdre vingt points parce que la clé de service manque ne
 * doit pas faire échouer la session qu'on vient de terminer, ni le cours
 * qu'on vient de déposer. L'écart part au journal serveur, et le total se
 * recalcule au besoin avec `public.recompute_xp_total()`.
 *
 * Retourne le nombre de points effectivement écrits — zéro si rien n'a pu
 * l'être, pour que l'écran n'annonce pas des points qui n'existent pas.
 */
export async function attribuerXp(opts: {
  userId: string
  gains: GainXp[]
  /** Ligne d'origine par défaut, quand un gain n'en porte pas. */
  referenceId?: string | null
}): Promise<number> {
  if (opts.gains.length === 0) return 0

  try {
    const admin = createAdminClient()

    const { error } = await admin.from('xp_events').insert(
      opts.gains.map((g) => ({
        user_id: opts.userId,
        reason: g.reason,
        amount: g.amount,
        reference_id: g.referenceId ?? opts.referenceId ?? null,
      })),
    )

    if (error) {
      console.error('XP non attribués', error.message)
      return 0
    }
  } catch (e) {
    if (e instanceof ConfigurationManquante) {
      console.error(e.message)
      return 0
    }
    throw e
  }

  return totalGains(opts.gains)
}
