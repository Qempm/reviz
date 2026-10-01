import 'server-only'
import { createSupabaseJobStore } from './store'
import { handlers } from './handlers'
import { runJobs } from './runner'
import { pousserNotifications } from '@/lib/notifications/envoyer'

/**
 * Temps qu'il faut encore avoir pour démarrer un job de plus dans la même
 * invocation : un lot de chapitres prend d'ordinaire 15 à 25 s, et chaque
 * appel IA est coupé à 30 s (`DELAI_APPEL_MS`).
 */
export const MARGE_JOB_SUIVANT_S = 35

/** Les jobs qui font avancer un cours, dans l'ordre où ils s'enchaînent. */
const JOBS_DE_COURS = ['ingest_course', 'generate_questions'] as const

/**
 * Traiter un job **tout de suite**, depuis l'invocation qui vient de le créer.
 *
 * Pourquoi : `vercel.json` planifie `/api/jobs/run` une fois par jour à 22:00
 * UTC — c'est la limite de l'offre Hobby. Une copie photographiée à 21:00
 * avant un contrôle serait donc corrigée le lendemain soir. Inacceptable pour
 * ce produit.
 *
 * Comment, sans sortir de l'offre Hobby et **sans mettre `CRON_SECRET` dans
 * le téléphone** : le déclencheur vit à l'intérieur de l'invocation déjà
 * authentifiée de l'étudiant. La route répond d'abord, puis `after()` fait
 * tourner le job. Le client n'appelle jamais `/api/jobs/run` et n'apprend
 * jamais le secret.
 *
 * Trois filets, dans cet ordre :
 *
 *  1. `claim_job()` prend la ligne en `for update skip locked` : l'exécution
 *     immédiate et le cron sont inoffensifs l'un pour l'autre — le second
 *     arrivé ne voit rien à prendre et repart sans rien faire.
 *  2. Un `after()` jamais exécuté (invocation tuée après la réponse) laisse
 *     le job en `queued` : le cron le reprendra.
 *  3. Une invocation coupée en plein appel IA laisse le job en `running` :
 *     `claim_jobs()` reprend tout `running` plus vieux que
 *     `STALE_AFTER_MINUTES`.
 *
 * Rien de tout cela ne fait échouer la requête de l'étudiant : le dépôt est
 * enregistré, et le traitement suivra même si ce raccourci rate.
 */
export async function lancerJobMaintenant(
  jobId: string,
  opts: {
    /** Temps dont l'invocation dispose encore, en secondes. */
    budgetSecondes?: number
    signal?: AbortSignal
    /**
     * Le cours dont ce job fait partie. Donné, le traitement **s'enchaîne** :
     * le job suivant du même cours part dans la foulée tant qu'il reste du
     * temps, puis dans une invocation fraîche (`/api/jobs/run?cours=…`). Le
     * cours finit sans attendre que l'écran interroge — et même si
     * l'étudiant a fermé l'application.
     */
    coursId?: string
    /** Origine du déploiement, pour la relance. */
    origine?: string
  } = {},
): Promise<void> {
  // La marge laisse `markDone` / `requeue` s'écrire avant que la plateforme
  // coupe l'invocation : un job dont l'issue n'est pas consignée reste en
  // `running` et attend le seuil d'abandon.
  const fin = Date.now() + (opts.budgetSecondes ?? 45) * 1000
  let courant: string | null = jobId

  try {
    while (courant) {
      const resultat = await runJobs({
        store: createSupabaseJobStore(),
        handlers,
        jobId: courant,
        deadline: new Date(fin),
        signal: opts.signal,
        log: (message, extra) =>
          console.log('[jobs:immediat]', message, extra ?? {}),
      })

      if (resultat.claimed === 0) {
        // Déjà pris ailleurs, pas encore dû, ou retenu par les heures pleines.
        console.log('[jobs:immediat] rien à prendre', { jobId: courant })
        return
      }

      if (!opts.coursId) return

      const suivant = await prochainJobDuCours(opts.coursId)
      if (!suivant) return

      if (fin - Date.now() >= MARGE_JOB_SUIVANT_S * 1000) {
        courant = suivant
        continue
      }

      // Plus assez de temps ici : une invocation fraîche prend la suite.
      await relancer(opts.coursId, opts.origine)
      return
    }
  } catch (erreur) {
    // Le job garde son état en base ; le cron reprendra. On journalise sans
    // relancer : personne n'attend cette promesse.
    console.error('[jobs:immediat] passage en échec', { jobId: courant, erreur })
  } finally {
    // Un job qui finit écrit souvent un statut (cours prêt, copie corrigée,
    // carte vérifiée) : son déclencheur a créé une notification, qu'on
    // pousse tout de suite plutôt qu'au cron du soir.
    await pousserNotifications()
  }
}

/** Le prochain job dû d'un cours, ou `null`. */
export async function prochainJobDuCours(coursId: string): Promise<string | null> {
  const { createAdminClient } = await import('@/lib/supabase/admin')
  const { data } = await createAdminClient()
    .from('jobs')
    .select('id')
    .in('type', [...JOBS_DE_COURS])
    .eq('payload->>course_id', coursId)
    .eq('status', 'queued')
    .lte('run_after', new Date().toISOString())
    .order('created_at', { ascending: true })
    .limit(1)
    .maybeSingle()
  return data?.id ?? null
}

/**
 * Demande à une nouvelle invocation de continuer le cours.
 *
 * Par `/api/jobs/run?cours=…`, authentifié par `CRON_SECRET` — un secret du
 * serveur, jamais du téléphone. La route répond aussitôt et travaille dans
 * son `after()` : cette attente-ci ne dure que le temps de l'aller-retour.
 * Un échec n'est pas grave : le prochain sondage de l'écran, ou le cron,
 * reprendra le job resté en file.
 */
async function relancer(coursId: string, origine?: string): Promise<void> {
  const secret = process.env.CRON_SECRET
  const base =
    origine ??
    (process.env.VERCEL_PROJECT_PRODUCTION_URL
      ? `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}`
      : undefined)
  if (!secret || !base) return

  try {
    await fetch(`${base}/api/jobs/run?cours=${encodeURIComponent(coursId)}`, {
      headers: { authorization: `Bearer ${secret}` },
      signal: AbortSignal.timeout(8000),
    })
  } catch (erreur) {
    console.error('[jobs:immediat] relance impossible', { coursId, erreur })
  }
}
