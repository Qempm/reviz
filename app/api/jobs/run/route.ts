import { timingSafeEqual } from 'node:crypto'
import { NextResponse } from 'next/server'
import { createSupabaseJobStore, handlers, runJobs } from '@/lib/jobs'

/**
 * Passage de la file, déclenché par Vercel Cron toutes les minutes.
 *
 * Protégée par CRON_SECRET : Vercel place le secret dans l'en-tête
 * Authorization des appels planifiés. Sans secret configuré, la route refuse
 * tout — mieux vaut une file à l'arrêt qu'une file ouverte à tous.
 */

// La file lit et écrit à chaque appel : aucun cache possible.
export const dynamic = 'force-dynamic'

/**
 * Plafond d'exécution. La marge d'échéance ci-dessous s'arrête avant, pour
 * qu'un job en cours ne soit pas coupé net.
 */
export const maxDuration = 60

/** Marge gardée pour clôturer proprement le lot. */
const MARGE_MS = 10_000

function secretValide(entete: string | null, attendu: string): boolean {
  if (!entete) return false

  const fourni = entete.startsWith('Bearer ') ? entete.slice(7) : entete
  const a = Buffer.from(fourni)
  const b = Buffer.from(attendu)

  // Comparaison à temps constant : une comparaison naïve laisse deviner le
  // secret caractère par caractère.
  if (a.length !== b.length) return false
  return timingSafeEqual(a, b)
}

export async function GET(request: Request) {
  const attendu = process.env.CRON_SECRET

  if (!attendu) {
    return NextResponse.json(
      { ok: false, error: 'CRON_SECRET n’est pas configurée.' },
      { status: 503 },
    )
  }

  if (!secretValide(request.headers.get('authorization'), attendu)) {
    return NextResponse.json({ ok: false, error: 'Non autorisé.' }, { status: 401 })
  }

  const deadline = new Date(Date.now() + maxDuration * 1000 - MARGE_MS)

  try {
    const data = await runJobs({
      store: createSupabaseJobStore(),
      handlers,
      deadline,
      signal: request.signal,
      log: (message, extra) => console.log('[jobs]', message, extra ?? {}),
    })

    return NextResponse.json({ ok: true, data })
  } catch (error) {
    // Un échec ici concerne la file elle-même, pas un job : les échecs de
    // jobs sont consignés dans leur ligne et n'arrivent pas jusqu'ici.
    console.error('[jobs] passage en échec', error)
    return NextResponse.json(
      {
        ok: false,
        error: error instanceof Error ? error.message : 'Erreur inconnue.',
      },
      { status: 500 },
    )
  }
}
