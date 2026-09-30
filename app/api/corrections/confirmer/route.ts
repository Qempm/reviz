import { after } from 'next/server'
import { z } from 'zod'
import { authentifier, refusSession } from '@/lib/supabase/jeton'
import { confirmerCorrection } from '@/lib/metier/corrections'
import { lancerJobMaintenant } from '@/lib/jobs/immediat'

const corpsSchema = z.object({ correctionId: z.string().uuid() })

/**
 * POST /api/corrections/confirmer
 *
 * Les photos sont arrivées dans le seau : la correction entre en file, **et
 * part tout de suite**. On ne peut pas laisser un étudiant attendre le cron
 * quotidien de 22:00 (voir `lib/jobs/immediat.ts`).
 *
 * La réponse part avant le traitement : `after()` s'exécute une fois la
 * réponse envoyée, dans la même invocation. L'écran enchaîne donc sur son
 * attente sans rester bloqué le temps d'un appel de vision.
 */

// Le traitement tourne après la réponse : il faut le budget complet.
export const maxDuration = 60

/** Marge laissée à la plateforme pour clore proprement. */
const BUDGET_TRAITEMENT_S = 45

export async function POST(request: Request) {
  const appelant = await authentifier(request)
  if (!appelant) return refusSession()

  const parse = corpsSchema.safeParse(await request.json().catch(() => null))
  if (!parse.success) {
    return Response.json(
      { ok: false, error: 'On ne retrouve pas cette correction.' },
      { status: 400 },
    )
  }

  const resultat = await confirmerCorrection(
    appelant.supabase,
    appelant.user.id,
    parse.data.correctionId,
  )

  if (!resultat.ok) {
    const messages: Record<typeof resultat.error, string> = {
      invalide: 'Cette correction a déjà été lancée.',
      introuvable: 'On ne retrouve pas cette correction.',
      stockage: 'Ta photo n’est pas arrivée. Réessaie l’envoi.',
      serveur: 'On n’a pas pu lancer la correction. Réessaie dans un instant.',
    }

    const statut =
      resultat.error === 'introuvable'
        ? 404
        : resultat.error === 'serveur'
          ? 500
          : 400

    return Response.json(
      { ok: false, error: messages[resultat.error], motif: resultat.error },
      { status: statut },
    )
  }

  // Après la réponse, et sans que personne n'attende cette promesse : si elle
  // n'aboutit pas, le job reste en file et le cron le reprendra.
  after(() =>
    lancerJobMaintenant(resultat.jobId, {
      budgetSecondes: BUDGET_TRAITEMENT_S,
    }),
  )

  return Response.json({
    ok: true,
    data: { correctionId: parse.data.correctionId },
  })
}
