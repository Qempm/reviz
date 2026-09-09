'use server'

import { revalidatePath } from 'next/cache'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient, ConfigurationManquante } from '@/lib/supabase/admin'
import { activerPack, type Pack } from '@/lib/payments/subscriptions'

/**
 * Activation du pack Découverte.
 *
 * C'est le seul pack à 0 F : il n'a donc pas besoin du fournisseur de
 * paiement, et l'activer tout de suite débloque tout le parcours de révision
 * en attendant FedaPay (lot 5). Les packs payants restent inertes.
 *
 * `subscriptions` n'a aucune politique d'insertion — les tables financières
 * ne s'écrivent que par le rôle de service (règle : le client ne s'offre pas
 * un accès). L'unicité est vérifiée ici, pas par une contrainte : un étudiant
 * peut légitimement racheter un pack payant, mais Découverte est une fois
 * pour toutes.
 */
export type ResultatActivation =
  | { ok: true }
  | { ok: false; error: 'deja-utilise' | 'indisponible' | 'session' | 'serveur' }

export async function activerDecouverte(): Promise<ResultatActivation> {
  const supabase = await createClient()

  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) return { ok: false, error: 'session' }

  // Lu sous l'identité de l'étudiant : la politique « Je lis mes accès »
  // suffit, et un `count` évite de rapatrier les lignes.
  const { count } = await supabase
    .from('subscriptions')
    .select('pack_code', { count: 'exact', head: true })
    .eq('user_id', user.id)
    .eq('pack_code', 'decouverte')

  if ((count ?? 0) > 0) return { ok: false, error: 'deja-utilise' }

  const { data: ligne } = await supabase
    .from('packs')
    .select('code, duration_days, corrections_included, subjects_limit, price_fcfa')
    .eq('code', 'decouverte')
    .maybeSingle()

  // Un pack retiré du catalogue, ou dont le prix a changé, ne s'offre pas :
  // `active_from` / `active_to` sont faits pour cela et la grille peut
  // évoluer sans qu'on ait à redéployer.
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
      user_id: user.id,
      pack_code: abonnement.packCode,
      starts_at: abonnement.startsAt.toISOString(),
      ends_at: abonnement.endsAt.toISOString(),
      corrections_left: abonnement.correctionsLeft,
      source: 'bonus',
    })

    if (error) {
      console.error('Activation Découverte impossible', error.message)
      return { ok: false, error: 'serveur' }
    }
  } catch (e) {
    if (e instanceof ConfigurationManquante) {
      console.error(e.message)
      return { ok: false, error: 'serveur' }
    }
    throw e
  }

  revalidatePath('/boutique')
  revalidatePath('/reviser')
  revalidatePath('/')

  return { ok: true }
}
