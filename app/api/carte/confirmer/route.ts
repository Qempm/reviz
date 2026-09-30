import { after } from 'next/server'
import { z } from 'zod'
import { authentifier, refusSession } from '@/lib/supabase/jeton'
import { confirmerCarte } from '@/lib/metier/depot-carte'
import { lancerJobMaintenant } from '@/lib/jobs/immediat'

const corpsSchema = z.object({ chemin: z.string().min(1).max(500) })

/**
 * POST /api/carte/confirmer
 *
 * La photo est dans le seau : la vérification entre en file et **part tout de
 * suite**. Un étudiant qui vient de s'inscrire n'attend pas le cron quotidien
 * de 22:00 pour savoir si sa carte passe — c'est le geste qui lui ouvre le
 * parrainage et la boutique.
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
      { ok: false, error: 'Cette photo n’a pas pu être envoyée. Reprends-la.' },
      { status: 400 },
    )
  }

  const resultat = await confirmerCarte(
    appelant.supabase,
    appelant.user.id,
    parse.data.chemin,
  )

  if (!resultat.ok) {
    const messages: Record<typeof resultat.error, string> = {
      invalide: 'Chemin de photo invalide.',
      stockage: 'Ta photo n’est pas arrivée. Réessaie l’envoi.',
      serveur:
        'On n’a pas pu lancer la vérification. Réessaie dans un instant.',
    }

    return Response.json(
      { ok: false, error: messages[resultat.error], motif: resultat.error },
      { status: resultat.error === 'serveur' ? 500 : 400 },
    )
  }

  // Après la réponse, et sans que personne n'attende cette promesse : si elle
  // n'aboutit pas, le job reste en file et le cron le reprendra.
  after(() =>
    lancerJobMaintenant(resultat.jobId, {
      budgetSecondes: BUDGET_TRAITEMENT_S,
    }),
  )

  return Response.json({ ok: true, data: { jobId: resultat.jobId } })
}
