'use server'

import { revalidatePath } from 'next/cache'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'
import {
  activerDecouverte as activerDecouverteMetier,
  type ResultatActivation,
} from '@/lib/metier/packs'

/**
 * Boutique — portes web.
 *
 * L'activation du pack Découverte vit dans `lib/metier/packs.ts`, partagée
 * avec `/api/packs/decouverte`.
 */
export type { ResultatActivation } from '@/lib/metier/packs'

export async function activerDecouverte(): Promise<ResultatActivation> {
  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) return { ok: false, error: 'session' }

  const resultat = await activerDecouverteMetier(supabase, user.id)

  if (resultat.ok) {
    revalidatePath('/boutique')
    revalidatePath('/reviser')
    revalidatePath('/')
  }

  return resultat
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
