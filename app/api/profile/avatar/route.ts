import { NextRequest, NextResponse } from 'next/server'
import { z } from 'zod'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'

const avatarSchema = z.object({
  avatar_key: z.string().min(1).max(100),
})

/**
 * PUT /api/profile/avatar
 *
 * Met a jour l'avatar de l'utilisateur courant.
 */
export async function PUT(req: NextRequest) {
  try {
    const supabase = await createClient()
    const {
      data: { user },
    } = await supabase.auth.getUser()

    if (!user) {
      return NextResponse.json({ ok: false, error: 'session' }, { status: 401 })
    }

    // Valide le payload
    const parsed = avatarSchema.safeParse(await req.json())
    if (!parsed.success) {
      return NextResponse.json(
        { ok: false, error: 'invalid_input' },
        { status: 400 },
      )
    }

    const { avatar_key } = parsed.data

    // Met a jour le profil
    const admin = createAdminClient()
    const { error } = await admin
      .from('profiles')
      .update({ avatar_key })
      .eq('id', user.id)

    if (error) {
      console.error('Avatar update error:', error)
      return NextResponse.json(
        { ok: false, error: 'serveur' },
        { status: 500 },
      )
    }

    return NextResponse.json({ ok: true })
  } catch (e) {
    console.error('Avatar route error:', e)
    return NextResponse.json(
      { ok: false, error: 'serveur' },
      { status: 500 },
    )
  }
}
