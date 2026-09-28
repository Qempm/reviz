import { z } from 'zod'
import { authentifier, refusSession } from '@/lib/supabase/jeton'
import { createAdminClient } from '@/lib/supabase/admin'
import { CLES_AVATAR } from '@/lib/profil/avatars'

/**
 * PUT /api/profile/avatar
 *
 * Choisit son avatar. Trois corrections par rapport à la version précédente :
 *
 *  * elle construisait son client depuis les cookies uniquement, donc tout
 *    appel depuis l'application Flutter recevait 401 ;
 *  * elle rendait `{ ok: true }` à plat au lieu de l'enveloppe commune, et
 *    des codes crus (`session`, `invalid_input`) au lieu de phrases
 *    françaises ;
 *  * elle acceptait **n'importe quelle chaîne de cent caractères** dans
 *    `avatar_key`. La colonne est un `text` libre : sans liste blanche, rien
 *    ne garantissait que ce que lit un écran soit un avatar.
 *
 * `avatar_key` est écrit par le rôle de service et non par le client : le
 * trigger `protect_profile_columns` ne gèle pas cette colonne, mais passer
 * par ici est ce qui permet la liste blanche.
 */

const corpsSchema = z.object({
  avatar_key: z.enum(CLES_AVATAR),
})

export async function PUT(request: Request) {
  const appelant = await authentifier(request)
  if (!appelant) return refusSession()

  let brut: unknown
  try {
    brut = await request.json()
  } catch {
    return Response.json(
      { ok: false, error: 'Corps de requête illisible.', motif: 'invalide' },
      { status: 400 },
    )
  }

  const analyse = corpsSchema.safeParse(brut)
  if (!analyse.success) {
    return Response.json(
      {
        ok: false,
        error: 'Cet avatar n’existe pas.',
        motif: 'avatar-inconnu',
      },
      { status: 400 },
    )
  }

  const admin = createAdminClient()
  const { error } = await admin
    .from('profiles')
    .update({ avatar_key: analyse.data.avatar_key })
    .eq('id', appelant.user.id)

  if (error) {
    console.error('[avatar] mise à jour impossible', error.message)
    return Response.json(
      {
        ok: false,
        error: 'On n’a pas pu enregistrer ton avatar. Réessaie.',
        motif: 'serveur',
      },
      { status: 500 },
    )
  }

  return Response.json({
    ok: true,
    data: { avatarKey: analyse.data.avatar_key },
  })
}
