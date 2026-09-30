import { z } from 'zod'
import { authentifier, refusSession } from '@/lib/supabase/jeton'
import { annulerCorrection } from '@/lib/metier/corrections'

const corpsSchema = z.object({ correctionId: z.string().uuid() })

/**
 * POST /api/corrections/annuler
 *
 * L'envoi de la photo n'a pas abouti : la ligne réservée est retirée. Sans
 * cette route, une coupure au milieu d'un envoi consommerait une des cinq
 * corrections du jour sans que rien ne soit corrigé.
 *
 * Idempotente et silencieuse : annuler deux fois, ou annuler une correction
 * déjà lancée, ne fait rien et ne dit rien de mal.
 */
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

  await annulerCorrection(
    appelant.supabase,
    appelant.user.id,
    parse.data.correctionId,
  )

  return Response.json({ ok: true, data: { annule: true } })
}
