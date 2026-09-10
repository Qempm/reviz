import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'

/**
 * POST /api/profile/delete
 *
 * Supprime le compte de l'utilisateur courant et toutes ses donnees.
 * Action irreversible : supprime profil, cours, corrections, paiements, etc.
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

    const admin = createAdminClient()

    // Supprime le compte Auth et le profil
    // Supabase suprime automatiquement les donnees associes via RLS et cascades
    const { error: deleteError } = await admin.auth.admin.deleteUser(user.id)

    if (deleteError) {
      console.error('User deletion error:', deleteError)
      return NextResponse.json(
        { ok: false, error: 'serveur' },
        { status: 500 },
      )
    }

    return NextResponse.json({ ok: true })
  } catch (e) {
    console.error('Profile delete error:', e)
    return NextResponse.json(
      { ok: false, error: 'serveur' },
      { status: 500 },
    )
  }
}
