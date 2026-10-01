import { after } from 'next/server'
import { authentifier, refusSession } from '@/lib/supabase/jeton'
import { enregistrerSession } from '@/lib/metier/session'
import { pousserNotifications } from '@/lib/notifications/envoyer'

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
  // La première XP d'une semaine clôt les ligues de la précédente
  // (`ligue_suivre_xp`) : leurs notifications partent après la réponse. Le
  // plus souvent, il n'y a rien à pousser, et la requête est indexée.
  after(() => pousserNotifications())

  return Response.json({ ok: true, data: donnees })
}
