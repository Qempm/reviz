import 'server-only'
import { createSupabaseJobStore } from './store'
import { handlers } from './handlers'
import { runJobs } from './runner'

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
  } = {},
): Promise<void> {
  // La marge laisse `markDone` / `requeue` s'écrire avant que la plateforme
  // coupe l'invocation : un job dont l'issue n'est pas consignée reste en
  // `running` et attend le seuil d'abandon.
  const budget = (opts.budgetSecondes ?? 45) * 1000

  try {
    const resultat = await runJobs({
      store: createSupabaseJobStore(),
      handlers,
      jobId,
      deadline: new Date(Date.now() + budget),
      signal: opts.signal,
      log: (message, extra) =>
        console.log('[jobs:immediat]', message, extra ?? {}),
    })

    if (resultat.claimed === 0) {
      // Déjà pris ailleurs, pas encore dû, ou retenu par les heures pleines.
      console.log('[jobs:immediat] rien à prendre', { jobId })
    }
  } catch (erreur) {
    // Le job garde son état en base ; le cron reprendra. On journalise sans
    // relancer : personne n'attend cette promesse.
    console.error('[jobs:immediat] passage en échec', { jobId, erreur })
  }
}
