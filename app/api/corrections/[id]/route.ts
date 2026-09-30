import { after } from 'next/server'
import { z } from 'zod'
import { authentifier, refusSession } from '@/lib/supabase/jeton'
import { createAdminClient } from '@/lib/supabase/admin'
import { lancerJobMaintenant } from '@/lib/jobs/immediat'

/**
 * GET /api/corrections/:id
 *
 * L'état d'une correction. L'écran l'interroge toutes les quelques secondes
 * tant qu'elle n'est ni prête ni en échec.
 *
 * Et il fait plus que lire : **si le traitement attend une reprise dont le
 * report est écoulé, cet appel le relance**. L'attente de l'étudiant devient
 * ainsi le moteur des réessais — sans cron supplémentaire, sans plan payant,
 * et sans secret dans le téléphone. Le cron quotidien reste le filet pour
 * ceux qui ont fermé l'application.
 *
 * Pourquoi cette route plutôt qu'une lecture directe de PostgREST, que la
 * politique « Je lis mes corrections » autoriserait : précisément pour cette
 * relance.
 */

export const maxDuration = 60

const BUDGET_TRAITEMENT_S = 45

export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const appelant = await authentifier(request)
  if (!appelant) return refusSession()

  const { id } = await params
  const parse = z.string().uuid().safeParse(id)
  if (!parse.success) {
    return Response.json(
      { ok: false, error: 'On ne retrouve pas cette correction.' },
      { status: 400 },
    )
  }

  // Lecture sous l'identité de l'appelant : la RLS garantit qu'on ne rend
  // pas la copie de quelqu'un d'autre.
  const { data: correction, error } = await appelant.supabase
    .from('corrections')
    .select(
      'id, course_id, status, grade, max_grade, rubric, feedback, model_used, created_at',
    )
    .eq('id', parse.data)
    .maybeSingle()

  if (error) {
    console.error('[correction] lecture impossible', error.message)
    return Response.json(
      { ok: false, error: 'On n’a pas pu lire cette correction.' },
      { status: 500 },
    )
  }

  if (!correction) {
    return Response.json(
      { ok: false, error: 'On ne retrouve pas cette correction.' },
      { status: 404 },
    )
  }

  // Encore en cours : le traitement attend-il une reprise ?
  if (correction.status === 'pending' || correction.status === 'processing') {
    const admin = createAdminClient()

    const { data: job } = await admin
      .from('jobs')
      .select('id, status, run_after')
      .eq('type', 'correct_copy')
      .eq('payload->>correction_id', parse.data)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle()

    // `queued` et l'heure venue : c'est un réessai dont le report est
    // écoulé. `claim_job` refusera si quelqu'un d'autre l'a déjà pris.
    if (job && job.status === 'queued' && new Date(job.run_after) <= new Date()) {
      after(() =>
        lancerJobMaintenant(job.id, { budgetSecondes: BUDGET_TRAITEMENT_S }),
      )
    }
  }

  return Response.json({ ok: true, data: correction })
}
