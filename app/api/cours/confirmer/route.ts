import { after } from 'next/server'
import { z } from 'zod'
import { authentifier, refusSession } from '@/lib/supabase/jeton'
import { confirmerDepot } from '@/lib/metier/cours'
import { lancerJobMaintenant } from '@/lib/jobs/immediat'

const corpsSchema = z.object({ courseId: z.string().uuid() })

/**
 * POST /api/cours/confirmer
 *
 * Le fichier est arrivé dans le seau : le cours passe en `processing`, le
 * dépôt est récompensé, et **le traitement démarre tout de suite**. La
 * transition n'a lieu qu'une fois, même si le client rappelle la route après
 * une coupure.
 *
 * Le découpage tourne après la réponse, via `after()` : l'écran enchaîne sur
 * son attente sans rester bloqué le temps d'une extraction de PDF. Le cron
 * quotidien reste le filet.
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
    return Response.json({ ok: false, error: 'On ne retrouve pas ce cours.' }, { status: 400 })
  }

  const resultat = await confirmerDepot(
    appelant.supabase,
    appelant.user.id,
    parse.data.courseId,
  )

  if (!resultat.ok) {
    return Response.json(
      { ok: false, error: 'On n’a pas pu lancer la préparation du cours.' },
      { status: 500 },
    )
  }

  if (resultat.jobId) {
    after(() =>
      lancerJobMaintenant(resultat.jobId!, {
        budgetSecondes: BUDGET_TRAITEMENT_S,
        // La lecture, puis les chapitres, s'enchaînent d'eux-mêmes.
        coursId: parse.data.courseId,
        origine: new URL(request.url).origin,
      }),
    )
  }

  return Response.json({ ok: true, data: { courseId: parse.data.courseId } })
}
