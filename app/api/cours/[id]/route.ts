import { after } from 'next/server'
import { z } from 'zod'
import { authentifier, refusSession } from '@/lib/supabase/jeton'
import { createAdminClient } from '@/lib/supabase/admin'
import { lancerJobMaintenant } from '@/lib/jobs/immediat'

/**
 * GET /api/cours/:id
 *
 * L'état d'un cours en préparation — et, comme pour les corrections,
 * **l'appel relance le traitement**.
 *
 * C'est la pièce qui manquait, et son absence était le plus gros défaut
 * fonctionnel restant. La chaîne d'un dépôt est en deux temps :
 * `ingest_course` découpe le document en chapitres, puis `generate_questions`
 * traite **un chapitre par passage** et se remet en file pour le suivant —
 * découpage volontaire, pour ne pas se faire couper au milieu d'un chapitre.
 * Seul le premier job partait tout de suite, depuis l'invocation du dépôt
 * (`/api/cours/confirmer`). Les suivants attendaient le cron, planifié **une
 * fois par jour** sur l'offre Hobby et limité à cinq jobs par passage : un
 * cours de six chapitres aurait mis plusieurs jours à être prêt, pour un
 * produit dont la promesse est « la nuit avant le contrôle ».
 *
 * L'attente de l'étudiant devient donc le moteur de la chaîne : chaque
 * interrogation de l'écran fait avancer un chapitre. Sans cron
 * supplémentaire, sans plan payant, et sans `CRON_SECRET` dans le téléphone.
 * Le cron quotidien reste le filet pour qui a fermé l'application.
 */

export const maxDuration = 60

const BUDGET_TRAITEMENT_S = 45

/** Les deux types qui composent la chaîne d'un dépôt. */
const TYPES = ['ingest_course', 'generate_questions'] as const

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
      { ok: false, error: 'Identifiant de cours invalide.' },
      { status: 400 },
    )
  }

  // Sous l'identité de l'appelant, et depuis la même vue que la lecture
  // directe : la RLS décide ce qu'il voit, et l'écran réutilise sa fabrique
  // sans convertir quoi que ce soit.
  const { data: cours, error } = await appelant.supabase
    .from('course_overview')
    // Une seule chaîne littérale : PostgREST déduit le type de la ligne de
    // ce texte, et une concaténation lui rend un `string` quelconque.
    .select(
      'id, title, status, is_demo, subject_name, exam_date, nb_chapitres, nb_questions, nb_fiches, nb_tentees',
    )
    .eq('id', parse.data)
    .maybeSingle()

  if (error) {
    console.error('[cours] lecture impossible', error.message)
    return Response.json(
      { ok: false, error: 'On n’a pas pu lire ce cours.' },
      { status: 500 },
    )
  }

  if (!cours) {
    return Response.json(
      { ok: false, error: 'On ne retrouve pas ce cours.' },
      { status: 404 },
    )
  }

  // Prêt ou en échec : plus rien à relancer.
  if (cours.status === 'uploaded' || cours.status === 'processing') {
    const admin = createAdminClient()

    const { data: job } = await admin
      .from('jobs')
      .select('id, type, status, run_after')
      .in('type', TYPES)
      .eq('payload->>course_id', parse.data)
      .eq('status', 'queued')
      // Le plus ancien d'abord : la chaîne est séquentielle, et `ingest`
      // précède toujours la génération.
      .order('created_at', { ascending: true })
      .limit(1)
      .maybeSingle()

    // L'heure venue seulement : un job reporté après un 429 doit garder son
    // report, sinon on martèle le fournisseur. `claim_job` refusera de toute
    // façon si quelqu'un d'autre l'a déjà pris.
    if (job && new Date(job.run_after) <= new Date()) {
      after(() =>
        lancerJobMaintenant(job.id, { budgetSecondes: BUDGET_TRAITEMENT_S }),
      )
    }
  }

  return Response.json({ ok: true, data: cours })
}
