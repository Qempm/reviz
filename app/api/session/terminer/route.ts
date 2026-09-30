import { authentifier, refusSession } from '@/lib/supabase/jeton'
import { enregistrerSession } from '@/lib/metier/session'

/**
 * POST /api/session/terminer
 *
 * Enregistre les réponses d'une session et attribue les XP. Le client envoie
 * ce qu'il a **choisi**, jamais s'il avait juste : le serveur recorrige depuis
 * `questions.answer`. Sans cela, une requête bricolée vaudrait dix bonnes
 * réponses et la première place du classement.
 */
export async function POST(request: Request) {
  const appelant = await authentifier(request)
  if (!appelant) return refusSession()

  const corps = await request.json().catch(() => null)
  if (corps === null) {
    return Response.json({ ok: false, error: 'Ta demande n’a pas pu partir. Réessaie.' }, { status: 400 })
  }

  const resultat = await enregistrerSession(
    appelant.supabase,
    appelant.user.id,
    corps as never,
  )

  if (!resultat.ok) {
    return Response.json({ ok: false, error: resultat.error }, { status: 400 })
  }

  const { ok: _ignore, ...donnees } = resultat
  return Response.json({ ok: true, data: donnees })
}
