import 'server-only'
import type { ClientReviz } from '@/lib/supabase/jeton'
import { createAdminClient, ConfigurationManquante } from '@/lib/supabase/admin'
import { activerPack, type Pack } from '@/lib/payments/subscriptions'

/**
 * Activation du pack Découverte.
 *
 * C'est le seul pack à 0 F : il n'a donc pas besoin du fournisseur de
 * paiement, et l'activer débloque tout le parcours de révision en attendant
 * FedaPay. Les packs payants restent inertes.
 *
 * `subscriptions` n'a aucune politique d'insertion — les tables financières
 * ne s'écrivent que par le rôle de service. L'unicité est vérifiée ici et non
 * par une contrainte : un étudiant peut légitimement racheter un pack payant,
 * mais Découverte est une fois pour toutes.
 *
 * Le client de lecture est injecté, pour que la Server Action et
 * `/api/packs/decouverte` partagent cette implémentation.
 */

export type ResultatActivation =
  | { ok: true }
  | { ok: false; error: 'deja-utilise' | 'indisponible' | 'session' | 'serveur' }

export async function activerDecouverte(
  supabase: ClientReviz,
  userId: string,
): Promise<ResultatActivation> {
  // Lu sous l'identité de l'étudiant : la politique « Je lis mes accès »
  // suffit, et un `count` évite de rapatrier les lignes.
  const { count } = await supabase
    .from('subscriptions')
    .select('pack_code', { count: 'exact', head: true })
    .eq('user_id', userId)
    .eq('pack_code', 'decouverte')

  if ((count ?? 0) > 0) return { ok: false, error: 'deja-utilise' }

  const { data: ligne } = await supabase
    .from('packs')
    .select('code, duration_days, corrections_included, subjects_limit, price_fcfa')
    .eq('code', 'decouverte')
    .maybeSingle()

  // Un pack retiré du catalogue, ou dont le prix a changé, ne s'offre pas :
  // `active_from` / `active_to` sont faits pour cela et la grille peut
  // évoluer sans redéploiement.
  if (!ligne || ligne.price_fcfa !== 0) return { ok: false, error: 'indisponible' }

  const pack: Pack = {
    code: 'decouverte',
    durationDays: ligne.duration_days,
    correctionsIncluded: ligne.corrections_included,
    subjectsLimit: ligne.subjects_limit,
  }

  const abonnement = activerPack({ pack, source: 'bonus' })

  try {
    const admin = createAdminClient()
    const { error } = await admin.from('subscriptions').insert({
      user_id: userId,
      pack_code: abonnement.packCode,
      starts_at: abonnement.startsAt.toISOString(),
      ends_at: abonnement.endsAt.toISOString(),
      corrections_left: abonnement.correctionsLeft,
      source: 'bonus',
    })

    if (error) {
      console.error('[packs] activation Découverte impossible', error.message)
      return { ok: false, error: 'serveur' }
    }
  } catch (e) {
    if (e instanceof ConfigurationManquante) {
      console.error(e.message)
      return { ok: false, error: 'serveur' }
    }
    throw e
  }

  return { ok: true }
}
