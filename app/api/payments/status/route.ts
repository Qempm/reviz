/**
 * GET /api/payments/status
 *
 * Vérifie le statut du dernier paiement en attente de l'utilisateur.
 * Utilisé par l'écran de redirection pour faire du polling.
 *
 * Réponse :
 * { ok: true, status: 'pending' | 'success' | 'failed' }
 * { ok: false, error }
 */

import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

export async function GET(request: NextRequest) {
  try {
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

    // Récupère le dernier paiement de l'utilisateur
    const { data: payment, error } = await supabase
      .from('payments')
      .select('status')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle()

    if (error) {
      console.error('Failed to fetch payment status:', error)
      return NextResponse.json(
        { ok: false, error: 'Database error' },
        { status: 500 },
      )
    }

    if (!payment) {
      return NextResponse.json(
        { ok: false, error: 'No payment found' },
        { status: 404 },
      )
    }

    return NextResponse.json({
      ok: true,
      status: payment.status as 'pending' | 'success' | 'failed',
    })
  } catch (error) {
    console.error('GET /api/payments/status error:', error)
    return NextResponse.json(
      { ok: false, error: 'Internal server error' },
      { status: 500 },
    )
  }
}
