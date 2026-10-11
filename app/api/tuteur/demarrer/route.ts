import { authentifier, refusSession } from '@/lib/supabase/jeton'
import { demarrerTuteur } from '@/lib/metier/tuteur-serveur'
import { refusTuteur } from '@/lib/metier/tuteur-reponses'

/**
 * POST /api/tuteur/demarrer `{ courseId, chapterId }`
 * → `{ sessionId, essai, suite: { type: 'question', texte, numero: 1, total: 3 } }`
 *
 * Ouvre une vérification de maîtrise sur un chapitre. Réservée aux packs,
 * avec un essai gratuit par compte (`lib/metier/tuteur.ts`).
 */
export const maxDuration = 60

export async function POST(request: Request) {
  const appelant = await authentifier(request)
  if (!appelant) return refusSession()

  const corps = await request.json().catch(() => null)
  const resultat = await demarrerTuteur(appelant.supabase, appelant.user.id, corps)
  if (!resultat.ok) return refusTuteur(resultat.error)

  return Response.json({
    ok: true,
    data: { sessionId: resultat.sessionId, essai: resultat.essai, suite: resultat.suite },
  })
}
