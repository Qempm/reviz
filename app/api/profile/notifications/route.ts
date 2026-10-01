import { z } from 'zod'
import { authentifier, refusSession } from '@/lib/supabase/jeton'
import { createAdminClient } from '@/lib/supabase/admin'

/**
 * PUT /api/profile/notifications — les catégories de push que l'étudiant
 * veut recevoir : `{ cours, argent, compte, ligue }`, chacune vraie ou
 * fausse.
 *
 * Passé par ici, et non écrit par l'application directement, pour la même
 * raison que l'avatar : la colonne est un `jsonb` libre, et seul un schéma
 * garantit que `lib/notifications/envoyer.ts` lira des booléens. Le centre
 * de notifications, lui, montre tout, quelles que soient ces préférences.
 */

const prefsSchema = z
  .object({
    cours: z.boolean(),
    argent: z.boolean(),
    compte: z.boolean(),
    ligue: z.boolean(),
  })
  .strict()

export async function PUT(request: Request) {
  const appelant = await authentifier(request)
  if (!appelant) return refusSession()

  let brut: unknown
  try {
    brut = await request.json()
  } catch {
    brut = null
  }

  const analyse = prefsSchema.safeParse(brut)
  if (!analyse.success) {
    return Response.json(
      { ok: false, error: 'Ta demande n’a pas pu partir. Réessaie.', motif: 'invalide' },
      { status: 400 },
    )
  }

  const { error } = await createAdminClient()
    .from('profiles')
    .update({ notifications: analyse.data })
    .eq('id', appelant.user.id)

  if (error) {
    console.error('PUT /api/profile/notifications :', error.message)
    return Response.json(
      { ok: false, error: 'Ton choix n’a pas pu être enregistré. Réessaie.' },
      { status: 500 },
    )
  }
  return Response.json({ ok: true, data: analyse.data })
}
