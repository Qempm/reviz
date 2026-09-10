/**
 * POST /api/payments/init
 *
 * Initialiser une transaction de paiement.
 * 1. Valider l'entrée (user, pack, operator, phone)
 * 2. Créer un enregistrement payments avec status='pending'
 * 3. Appeler le fournisseur (FedaPay)
 * 4. Retourner l'URL de redirection
 *
 * Réponse :
 * { ok: true, redirectUrl, transactionId }
 * { ok: false, error }
 */

import { NextRequest, NextResponse } from 'next/server'
import { z } from 'zod'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'
import { createPaymentProvider } from '@/lib/payments/provider'

const InitPaymentSchema = z.object({
  packCode: z.enum(['decouverte', 'controle', 'partiel', 'semestre', 'rattrapage']),
  operator: z.enum(['mtn', 'moov', 'wave', 'orange']).optional(),
  phone: z.string().min(8).max(15).optional(),
})

type InitPaymentInput = z.infer<typeof InitPaymentSchema>

export async function POST(request: NextRequest) {
  try {
    // 1. Parse et valide l'entrée
    const body = await request.json().catch(() => null)
    if (!body) {
      return NextResponse.json(
        { ok: false, error: 'Invalid JSON' },
        { status: 400 },
      )
    }

    const input = InitPaymentSchema.safeParse(body)
    if (!input.success) {
      return NextResponse.json(
        { ok: false, error: 'Invalid input', details: input.error.errors },
        { status: 400 },
      )
    }

    // 2. Vérifie la session de l'utilisateur
    const supabase = await createClient()
    const {
      data: { user },
    } = await supabase.auth.getUser()
    if (!user) {
      return NextResponse.json(
        { ok: false, error: 'Unauthorized' },
        { status: 401 },
      )
    }

    // 3. Récupère les détails du pack et la souscription existante
    const [{ data: pack }, { count: alreadyHasDiscovery }] = await Promise.all([
      supabase
        .from('packs')
        .select('code, price_fcfa, duration_days, corrections_included, subjects_limit')
        .eq('code', input.data.packCode)
        .maybeSingle(),
      supabase
        .from('subscriptions')
        .select('pack_code', { count: 'exact', head: true })
        .eq('user_id', user.id)
        .eq('pack_code', 'decouverte'),
    ])

    if (!pack) {
      return NextResponse.json(
        { ok: false, error: 'Pack not found' },
        { status: 404 },
      )
    }

    // Découverte est une fois pour toutes
    if (input.data.packCode === 'decouverte' && (alreadyHasDiscovery ?? 0) > 0) {
      return NextResponse.json(
        { ok: false, error: 'Découverte pack already activated' },
        { status: 400 },
      )
    }

    // Packs gratuits vont via activerDecouverte(), pas par ce endpoint
    if (pack.price_fcfa === 0) {
      return NextResponse.json(
        { ok: false, error: 'Use activerDecouverte() for free packs' },
        { status: 400 },
      )
    }

    // 4. Crée l'enregistrement payment avec status='pending'
    const admin = createAdminClient()
    const { data: payment, error: paymentError } = await admin
      .from('payments')
      .insert({
        user_id: user.id,
        provider: 'fedapay',
        amount_fcfa: pack.price_fcfa,
        operator: input.data.operator || null,
        phone: input.data.phone || null,
        status: 'pending',
        pack_code: input.data.packCode,
        raw: null,
      })
      .select('id')
      .single()

    if (paymentError || !payment) {
      console.error('Failed to create payment record:', paymentError)
      return NextResponse.json(
        { ok: false, error: 'Failed to create payment record' },
        { status: 500 },
      )
    }

    // 5. Appelle FedaPay pour initialiser la transaction
    const provider = createPaymentProvider('fedapay')
    const result = await provider.initPayment({
      userId: user.id,
      amount: pack.price_fcfa,
      packCode: input.data.packCode,
      operator: input.data.operator as 'mtn' | 'moov' | 'wave' | undefined,
      phone: input.data.phone,
    })

    if (!result.ok) {
      // Marquer le payment comme failed
      await admin
        .from('payments')
        .update({ status: 'failed' })
        .eq('id', payment.id)

      return NextResponse.json(
        { ok: false, error: result.error },
        { status: 500 },
      )
    }

    // 6. Mettre à jour payment.provider_ref et raw
    await admin
      .from('payments')
      .update({
        provider_ref: result.transactionId,
        raw: { redirectUrl: result.redirectUrl },
      })
      .eq('id', payment.id)

    // 7. Retourner l'URL de redirection
    return NextResponse.json({
      ok: true,
      redirectUrl: result.redirectUrl,
      transactionId: result.transactionId,
      amount: pack.price_fcfa,
    })
  } catch (error) {
    console.error('POST /api/payments/init error:', error)
    return NextResponse.json(
      { ok: false, error: 'Internal server error' },
      { status: 500 },
    )
  }
}
