import { NextRequest, NextResponse } from 'next/server'
import { z } from 'zod'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'
import { SEUIL_RETRAIT_FCFA } from '@/lib/payments/commission'

const withdrawalSchema = z.object({
  amount_fcfa: z.number().min(SEUIL_RETRAIT_FCFA),
  operator: z.enum(['mtn', 'moov', 'wave']),
  phone: z.string().regex(/^\+?[0-9]{8,15}$/),
})

/**
 * POST /api/wallet/withdrawal
 *
 * Crée une demande de retrait si le solde est suffisant.
 */
export async function POST(req: NextRequest) {
  try {
    const supabase = await createClient()
    const {
      data: { user },
    } = await supabase.auth.getUser()

    if (!user) {
      return NextResponse.json({ ok: false, error: 'session' }, { status: 401 })
    }

    // Valide le payload
    const parsed = withdrawalSchema.safeParse(await req.json())
    if (!parsed.success) {
      return NextResponse.json(
        { ok: false, error: 'invalid_input' },
        { status: 400 },
      )
    }

    const { amount_fcfa, operator, phone } = parsed.data

    // Vérifie le solde
    const { data: balance } = await supabase.rpc('wallet_balance')
    const solde = typeof balance === 'number' ? balance : 0

    if (solde < amount_fcfa) {
      return NextResponse.json(
        { ok: false, error: 'insufficient_balance' },
        { status: 402 },
      )
    }

    // Crée l'enregistrement withdrawal
    const admin = createAdminClient()
    const { data: withdrawal, error: insertError } = await admin
      .from('withdrawals')
      .insert({
        user_id: user.id,
        amount_fcfa,
        operator: operator.toUpperCase(),
        phone,
        status: 'requested',
        requested_at: new Date().toISOString(),
      })
      .select('id')
      .single()

    if (insertError || !withdrawal) {
      console.error('Withdrawal insert error:', insertError)
      return NextResponse.json(
        { ok: false, error: 'serveur' },
        { status: 500 },
      )
    }

    // Enregistre le débit dans wallet_ledger
    const { error: ledgerError } = await admin
      .from('wallet_ledger')
      .insert({
        user_id: user.id,
        type: 'withdrawal',
        amount_fcfa: -amount_fcfa,
        reference_id: withdrawal.id,
        created_at: new Date().toISOString(),
      })

    if (ledgerError) {
      console.error('Ledger insert error:', ledgerError)
      // Annule le withdrawal
      await admin.from('withdrawals').delete().eq('id', withdrawal.id)
      return NextResponse.json(
        { ok: false, error: 'serveur' },
        { status: 500 },
      )
    }

    // Notifie via WhatsApp (job notify)
    const { error: jobError } = await admin
      .from('jobs')
      .insert({
        type: 'notify',
        payload: {
          phone,
          template: 'withdrawal_requested',
          variables: {
            amount_fcfa: amount_fcfa.toString(),
            operator,
          },
        },
        status: 'queued',
        attempts: 0,
        run_after: new Date().toISOString(),
        created_at: new Date().toISOString(),
      })

    if (jobError) {
      console.error('Job insert error:', jobError)
      // Continue malgré tout
    }

    return NextResponse.json({ ok: true, withdrawal_id: withdrawal.id })
  } catch (e) {
    console.error('Withdrawal error:', e)
    return NextResponse.json(
      { ok: false, error: 'serveur' },
      { status: 500 },
    )
  }
}
