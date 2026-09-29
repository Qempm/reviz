import { timingSafeEqual } from 'node:crypto'
import { after, NextResponse } from 'next/server'
import { z } from 'zod'
import { createSupabaseJobStore, handlers, runJobs } from '@/lib/jobs'
import { lancerJobMaintenant, prochainJobDuCours } from '@/lib/jobs/immediat'

/**
 * Passage de la file, déclenché par Vercel Cron **une fois par jour** à 22:00
 * UTC (`vercel.json`) : c'est la seule cadence que permet l'offre Hobby.
 *
 * Le commentaire annonçait « toutes les minutes », ce qui a longtemps masqué
 * la conséquence : avec `BATCH_SIZE`, cinq jobs par jour au plus. Aucun
 * traitement que l'étudiant attend ne passe plus par ici — `correct_copy`,
 * `verify_card` et `ingest_course` partent de l'invocation du dépôt
 * (`lib/jobs/immediat.ts`), et `generate_questions` avance à chaque
 * interrogation de `GET /api/cours/:id`. Ce cron est le **filet** : il ramasse
 * ce qu'a laissé quelqu'un qui a fermé l'application.
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

  // Relance ciblée : un cours qui s'enchaîne lui-même (`lancerJobMaintenant`)
  // demande une invocation fraîche. On répond tout de suite et on travaille
  // après la réponse — l'appelant n'attend que l'accusé.
  const cours = new URL(request.url).searchParams.get('cours')
  if (cours !== null) {
    if (!z.string().uuid().safeParse(cours).success) {
      return NextResponse.json({ ok: false, error: 'Cours invalide.' }, { status: 400 })
    }
    const job = await prochainJobDuCours(cours)
    if (job) {
      const origine = new URL(request.url).origin
      after(() =>
        lancerJobMaintenant(job, {
          budgetSecondes: maxDuration - MARGE_MS / 1000,
          coursId: cours,
          origine,
        }),
      )
    }
    return NextResponse.json({ ok: true, data: { relance: job } }, { status: 202 })
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
