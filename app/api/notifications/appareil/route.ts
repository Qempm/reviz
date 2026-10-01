import { z } from 'zod'
import { authentifier, refusSession } from '@/lib/supabase/jeton'
import { createAdminClient } from '@/lib/supabase/admin'

/**
 * POST   /api/notifications/appareil — enregistre le jeton de push du téléphone.
 * DELETE /api/notifications/appareil — l'oublie (déconnexion).
 *
 * La table `appareils` n'a aucune politique client : un jeton de push permet
 * d'écrire sur l'écran de quelqu'un, il ne se lit ni ne s'écrit depuis
 * l'application. Le rôle de service fait l'écriture, pour l'étudiant
 * authentifié et lui seul.
 *
 * Un téléphone prêté puis reconnecté sous un autre compte garde le même
 * jeton : l'insertion le **réattribue** (le jeton est la clé), pour que
 * l'ancien titulaire ne reçoive plus rien sur un appareil qui n'est plus le
 * sien.
 */

const appareilSchema = z.object({
  token: z.string().min(20).max(4096),
  plateforme: z.enum(['android', 'ios']),
})

const oubliSchema = z.object({ token: z.string().min(20).max(4096) })

async function lireCorps(request: Request): Promise<unknown> {
  try {
    return await request.json()
  } catch {
    return null
  }
}

const invalide = () =>
  Response.json(
    { ok: false, error: 'Ta demande n’a pas pu partir. Réessaie.', motif: 'invalide' },
    { status: 400 },
  )

export async function POST(request: Request) {
  const appelant = await authentifier(request)
  if (!appelant) return refusSession()

  const analyse = appareilSchema.safeParse(await lireCorps(request))
  if (!analyse.success) return invalide()

  const { error } = await createAdminClient()
    .from('appareils')
    .upsert(
      {
        token: analyse.data.token,
        plateforme: analyse.data.plateforme,
        user_id: appelant.user.id,
        vu_le: new Date().toISOString(),
      },
      { onConflict: 'token' },
    )

  if (error) {
    console.error('POST /api/notifications/appareil :', error.message)
    return Response.json(
      { ok: false, error: 'Les notifications n’ont pas pu s’activer. Réessaie plus tard.' },
      { status: 500 },
    )
  }
  return Response.json({ ok: true, data: { enregistre: true } })
}

export async function DELETE(request: Request) {
  const appelant = await authentifier(request)
  if (!appelant) return refusSession()

  const analyse = oubliSchema.safeParse(await lireCorps(request))
  if (!analyse.success) return invalide()

  const { error } = await createAdminClient()
    .from('appareils')
    .delete()
    .eq('token', analyse.data.token)
    .eq('user_id', appelant.user.id)

  if (error) {
    console.error('DELETE /api/notifications/appareil :', error.message)
    return Response.json({ ok: false, error: 'Réessaie plus tard.' }, { status: 500 })
  }
  return Response.json({ ok: true, data: { oublie: true } })
}
