/**
 * POST /api/payments/webhook
 *
 * Webhook FedaPay : reçoit les changements de statut de transaction.
 * 1. Vérifie la signature
 * 2. Met à jour la transaction (status = success/failed/cancelled)
 * 3. Si succès :
 *    a) Crée la souscription
 *    b) Crédite la commission parrain
 *    c) Notifie via WhatsApp
 */

import { NextRequest, NextResponse } from 'next/server'
import { z } from 'zod'
import { createAdminClient } from '@/lib/supabase/admin'
import { validateWebhookSignature } from '@/lib/payments/provider'
import { activerPack } from '@/lib/payments/subscriptions'
import { TAUX_STANDARD, TAUX_AMBASSADEUR } from '@/lib/payments/commission'

const WebhookSchema = z.object({
  event: z.string(),
  data: z.object({
    id: z.union([z.string(), z.number()]),
    status: z.enum(['approved', 'declined', 'pending']),
    amount: z.number(),
    customer: z.object({ phone: z.string() }).optional(),
    metadata: z.object({
      user_id: z.string().uuid().optional(),
      pack_code: z.string().optional(),
    }).optional(),
  }),
})

export async function POST(request: NextRequest) {
  const admin = createAdminClient()

  try {
    // 1. Récupère le payload brut pour vérifier la signature
    const payload = await request.text()
    const signature = request.headers.get('X-Fedapay-Signature') || ''

    const webhookSecret = process.env.FEDAPAY_WEBHOOK_SECRET || ''
    if (!webhookSecret) {
      console.error('FEDAPAY_WEBHOOK_SECRET missing')
      return NextResponse.json(
        { ok: false, error: 'Configuration error' },
        { status: 500 },
      )
    }

    if (!validateWebhookSignature(payload, signature, webhookSecret)) {
      console.warn('Invalid webhook signature')
      return NextResponse.json(
        { ok: false, error: 'Invalid signature' },
        { status: 401 },
      )
    }

    // 2. Parse le payload
    const body = JSON.parse(payload)
    const parsed = WebhookSchema.safeParse(body)
    if (!parsed.success) {
      console.warn('Invalid webhook payload:', parsed.error)
      return NextResponse.json(
        { ok: false, error: 'Invalid payload' },
        { status: 400 },
      )
    }

    const { data: txData } = parsed.data
    const transactionId = String(txData.id)

    // Maps FedaPay statuses to our payment_status enum
    const statusMap: Record<string, 'success' | 'failed' | null> = {
      approved: 'success',
      declined: 'failed',
      pending: null, // ignore pending notifications
    }

    const status = statusMap[txData.status]
    if (!status) {
      // Ignore pending status or unknown statuses
      return NextResponse.json({ ok: true })
    }

    // 3. Trouvé le payment record par provider_ref
    const { data: payment, error: paymentError } = await admin
      .from('payments')
      .select('id, user_id, pack_code, amount_fcfa, status')
      .eq('provider', 'fedapay')
      .eq('provider_ref', transactionId)
      .maybeSingle()

    if (paymentError) {
      console.error('Failed to fetch payment:', paymentError)
      return NextResponse.json(
        { ok: false, error: 'Database error' },
        { status: 500 },
      )
    }

    if (!payment) {
      // Transaction inconnue : idempotence => répondre 200
      console.warn(`Payment not found for transaction ${transactionId}`)
      return NextResponse.json({ ok: true })
    }

    // 4. Mettre à jour le statut du payment (idempotence : unique constraint sur provider + provider_ref)
    const { error: updateError } = await admin
      .from('payments')
      .update({ status, raw: { ...body } })
      .eq('id', payment.id)

    if (updateError) {
      console.error('Failed to update payment:', updateError)
      return NextResponse.json(
        { ok: false, error: 'Failed to update payment' },
        { status: 500 },
      )
    }

    // 5. Si succès, activer la souscription et créditer le parrain
    if (status === 'success') {
      // Récupère les détails du pack
      const { data: packData, error: packError } = await admin
        .from('packs')
        .select('code, duration_days, corrections_included, subjects_limit')
        .eq('code', payment.pack_code)
        .maybeSingle()

      if (packError || !packData) {
        console.error('Failed to fetch pack details:', packError)
        return NextResponse.json(
          { ok: false, error: 'Pack not found' },
          { status: 500 },
        )
      }

      const packDetails = activerPack({
        pack: {
          code: packData.code as typeof payment.pack_code,
          durationDays: packData.duration_days,
          correctionsIncluded: packData.corrections_included,
          subjectsLimit: packData.subjects_limit,
        },
        source: 'payment',
      })
      const pack = packDetails

      // a) Créer la souscription
      const { error: subError } = await admin
        .from('subscriptions')
        .insert({
          user_id: payment.user_id,
          pack_code: payment.pack_code,
          starts_at: pack.startsAt.toISOString(),
          ends_at: pack.endsAt.toISOString(),
          corrections_left: pack.correctionsLeft,
          source: 'payment',
          payment_id: payment.id,
        })

      if (subError) {
        console.error('Failed to create subscription:', subError)
        return NextResponse.json(
          { ok: false, error: 'Failed to create subscription' },
          { status: 500 },
        )
      }

      // b) Créditer la commission parrain
      // Récupère le profil de l'utilisateur et son parrain
      const { data: user, error: userError } = await admin
        .from('profiles')
        .select('referred_by, is_ambassador')
        .eq('id', payment.user_id)
        .maybeSingle()

      if (!userError && user?.referred_by) {
        const rate = (user.is_ambassador ? TAUX_AMBASSADEUR : TAUX_STANDARD)
        const commission = Math.round(payment.amount_fcfa * rate)

        // Créditer dans wallet_ledger (append-only)
        const { error: ledgerError } = await admin
          .from('wallet_ledger')
          .insert({
            user_id: user.referred_by,
            type: 'referral_commission',
            amount_fcfa: commission,
            reference_id: payment.id,
          })

        if (ledgerError) {
          console.error('Failed to credit referral commission:', ledgerError)
          // Non-bloquant : la transaction est déjà validée
        }

        // Mettre à jour first_payment_at dans referrals (une fois seulement)
        const { error: refError } = await admin
          .from('referrals')
          .update({ first_payment_at: new Date().toISOString() })
          .eq('referrer_id', user.referred_by)
          .eq('referred_id', payment.user_id)
          .is('first_payment_at', null) // only if null

        if (refError) {
          console.error('Failed to update referrals:', refError)
          // Non-bloquant
        }
      }

      // c) Notifier via WhatsApp (non-bloquant)
      const webhookUrl = process.env.N8N_WHATSAPP_WEBHOOK_URL
      if (webhookUrl && user?.referred_by) {
        fetch(webhookUrl, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            type: 'payment_success',
            user_id: payment.user_id,
            pack_code: payment.pack_code,
            amount: payment.amount_fcfa,
          }),
        }).catch(err => console.error('Webhook notification failed:', err))
      }
    }

    return NextResponse.json({ ok: true })
  } catch (error) {
    console.error('POST /api/payments/webhook error:', error)
    return NextResponse.json(
      { ok: false, error: 'Internal server error' },
      { status: 500 },
    )
  }
}
