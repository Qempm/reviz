import { z } from 'zod'
import { authentifier, refusSession } from '@/lib/supabase/jeton'
import { annulerDepot } from '@/lib/metier/cours'

const corpsSchema = z.object({ courseId: z.string().uuid() })

/**
 * POST /api/cours/annuler
 *
 * L'envoi du fichier a échoué : la ligne créée par /api/cours/preparer est
 * retirée. Sans cela l'empreinte resterait prise par
 * `unique (owner_id, file_hash)`, et le même document ne pourrait plus jamais
 * être redéposé.
 */
export async function POST(request: Request) {
  const appelant = await authentifier(request)
  if (!appelant) return refusSession()

  const parse = corpsSchema.safeParse(await request.json().catch(() => null))
  if (!parse.success) {
    return Response.json({ ok: false, error: 'Identifiant de cours invalide.' }, { status: 400 })
  }

  await annulerDepot(appelant.supabase, appelant.user.id, parse.data.courseId)

  return Response.json({ ok: true, data: { annule: true } })
}
