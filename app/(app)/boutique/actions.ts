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

/**
 * Initiate payment for a non-free pack.
 *
 * Creates a payment record and calls FedaPay to get the redirect URL.
 * This is a server action, so it has direct access to auth and admin client.
 */
export type ResultatPaiement =
  | { ok: true; redirectUrl: string }
  | { ok: false; error: 'session' | 'pack-invalide' | 'serveur' }

export async function initiatePayment(
  packCode: 'decouverte' | 'controle' | 'partiel' | 'semestre' | 'rattrapage',
): Promise<ResultatPaiement> {
  const supabase = await createClient()

  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) return { ok: false, error: 'session' }

  try {
    // Récupère les détails du pack
    const { data: pack, error: packError } = await supabase
      .from('packs')
      .select('code, price_fcfa, duration_days, corrections_included, subjects_limit')
      .eq('code', packCode)
      .maybeSingle()

    if (packError || !pack || pack.price_fcfa === 0) {
      return { ok: false, error: 'pack-invalide' }
    }

    // Crée le paiement record (avec le rôle service pour l'écriture)
    const admin = createAdminClient()
    const { data: payment, error: paymentError } = await admin
      .from('payments')
      .insert({
        user_id: user.id,
        provider: 'fedapay',
        amount_fcfa: pack.price_fcfa,
        status: 'pending',
        pack_code: packCode,
        raw: null,
      })
      .select('id')
      .single()

    if (paymentError || !payment) {
      console.error('Failed to create payment record:', paymentError)
      return { ok: false, error: 'serveur' }
    }

    // Appelle FedaPay pour initialiser la transaction
    const { createPaymentProvider } = await import('@/lib/payments/provider')
    const provider = createPaymentProvider('fedapay')
    const result = await provider.initPayment({
      userId: user.id,
      amount: pack.price_fcfa,
      packCode,
    })

    if (!result.ok) {
      // Marquer le payment comme failed
      await admin
        .from('payments')
        .update({ status: 'failed' })
        .eq('id', payment.id)

      return { ok: false, error: 'serveur' }
    }

    // Mettre à jour payment.provider_ref et raw
    await admin
      .from('payments')
      .update({
        provider_ref: result.transactionId,
        raw: { redirectUrl: result.redirectUrl },
      })
      .eq('id', payment.id)

    return { ok: true, redirectUrl: result.redirectUrl }
  } catch (error) {
    console.error('Payment initiation error:', error)
    return { ok: false, error: 'serveur' }
  }
}
