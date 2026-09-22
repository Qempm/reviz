import { z } from 'zod'
import { authentifier, refusSession } from '@/lib/supabase/jeton'
import { confirmerDepot } from '@/lib/metier/cours'

const corpsSchema = z.object({ courseId: z.string().uuid() })

/**
 * POST /api/cours/confirmer
 *
 * Le fichier est arrivé dans le bucket : le cours passe en `processing` et le
 * dépôt est récompensé. La transition n'a lieu qu'une fois, même si le client
 * rappelle la route après une coupure.
 */
export async function POST(request: Request) {
  const appelant = await authentifier(request)
  if (!appelant) return refusSession()

  const parse = corpsSchema.safeParse(await request.json().catch(() => null))
  if (!parse.success) {
    return Response.json({ ok: false, error: 'Identifiant de cours invalide.' }, { status: 400 })
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

  return Response.json({ ok: true, data: { courseId: parse.data.courseId } })
}
