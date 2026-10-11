import { authentifier, refusSession } from '@/lib/supabase/jeton'
import { repondreTuteur } from '@/lib/metier/tuteur-serveur'
import { refusTuteur } from '@/lib/metier/tuteur-reponses'

/**
 * POST /api/tuteur/repondre `{ sessionId, reponse }`
 * → `{ evaluation: { niveau, retour }, suite }`, où `suite` est la question
 * suivante ou, après la troisième réponse, le bilan
 * `{ type: 'fin', verdict, score, bilan, aRevoir }`.
 */
export const maxDuration = 60

export async function POST(request: Request) {
  const appelant = await authentifier(request)
  if (!appelant) return refusSession()

  const corps = await request.json().catch(() => null)
  const resultat = await repondreTuteur(appelant.supabase, appelant.user.id, corps)
  if (!resultat.ok) return refusTuteur(resultat.error)

  return Response.json({
    ok: true,
    data: { evaluation: resultat.evaluation, suite: resultat.suite },
  })
}
