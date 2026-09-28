import { issueApresEchec, BATCH_SIZE, STALE_AFTER_MINUTES } from './policy'
import { PermanentJobError, type Job, type JobContext, type JobHandler, type JobType } from './types'

/**
 * Exécution d'un lot de jobs.
 *
 * Le magasin est injecté : le runner ne connaît pas Supabase, ce qui le rend
 * testable sans base et permettra d'en changer sans toucher à la logique.
 */
export type JobStore = {
  /** Prend un lot et le passe en `running` de façon atomique. */
  claim(batchSize: number, staleAfterMinutes: number): Promise<Job[]>
  /**
   * Prend **un job nommé**, aux mêmes conditions.
   *
   * Rend un tableau vide si le job est déjà pris, pas encore dû, ou bloqué
   * par les heures pleines : l'appelant n'a alors rien à faire.
   */
  claimUn(id: string, staleAfterMinutes: number): Promise<Job[]>
  markDone(id: string): Promise<void>
  markFailed(id: string, lastError: string): Promise<void>
  requeue(id: string, runAfter: Date, lastError: string): Promise<void>
}

export type Handlers = Partial<Record<JobType, JobHandler>>

export type RunResult = {
  claimed: number
  done: number
  requeued: number
  failed: number
  /** Détail par job, pour la réponse de la route et les journaux. */
  jobs: Array<{
    id: string
    type: JobType
    outcome: 'done' | 'requeued' | 'failed'
    attempts: number
    durationMs: number
    error?: string
  }>
}

export type RunOptions = {
  store: JobStore
  handlers: Handlers
  batchSize?: number
  staleAfterMinutes?: number
  now?: () => Date
  /**
   * Échéance de l'invocation. Passé ce délai, on ne démarre plus de nouveau
   * job : mieux vaut le laisser au passage suivant que se faire interrompre
   * en plein traitement.
   */
  deadline?: Date
  /**
   * Ne traiter qu'un job précis, au lieu du lot le plus ancien.
   *
   * C'est ce qui permet de lancer un traitement depuis l'invocation de
   * l'étudiant qui vient de déposer sa copie : sans cela, `claim()` lui
   * ferait traiter les jobs des autres, et l'attente resterait la même.
   * `batchSize` est alors sans objet.
   */
  jobId?: string
  log?: (message: string, extra?: Record<string, unknown>) => void
  signal?: AbortSignal
}

/**
 * Traite un lot de jobs, séquentiellement.
 *
 * Séquentiel et non parallèle : les traitements appellent des fournisseurs IA
 * qui limitent la concurrence, et une invocation serverless a peu de mémoire.
 * Le parallélisme viendra du nombre de passages du cron, pas d'ici.
 */
export async function runJobs(opts: RunOptions): Promise<RunResult> {
  const horloge = opts.now ?? (() => new Date())
  const log = opts.log ?? (() => {})
  const batchSize = opts.batchSize ?? BATCH_SIZE
  const staleAfter = opts.staleAfterMinutes ?? STALE_AFTER_MINUTES

  // Un seul endroit décide du sort d'un job : la prise change, tout le reste
  // — échéance, clôture, abandon, remise en file — est commun.
  const claimed = opts.jobId
    ? await opts.store.claimUn(opts.jobId, staleAfter)
    : await opts.store.claim(batchSize, staleAfter)

  const result: RunResult = {
    claimed: claimed.length,
    done: 0,
    requeued: 0,
    failed: 0,
    jobs: [],
  }

  for (const job of claimed) {
    // On ne démarre pas un job qu'on n'aura pas le temps de finir : il reste
    // en `running` et sera repris comme abandonné au passage suivant.
    if (opts.deadline && horloge() >= opts.deadline) {
      log('échéance atteinte, lot interrompu', { restants: result.claimed - result.jobs.length })
      break
    }

    const debut = Date.now()
    const handler = opts.handlers[job.type]

    const ctx: JobContext = {
      signal: opts.signal,
      log: (message, extra) => log(message, { jobId: job.id, type: job.type, ...extra }),
    }

    try {
      if (!handler) {
        // Un type sans traitement est un défaut de code, pas un aléa :
        // le réessayer cinq fois ne servirait à rien.
        throw new PermanentJobError(
          `Aucun traitement enregistré pour le type « ${job.type} ».`,
        )
      }

      await handler(job, ctx)

      await opts.store.markDone(job.id)
      result.done++
      result.jobs.push({
        id: job.id,
        type: job.type,
        outcome: 'done',
        attempts: job.attempts,
        durationMs: Date.now() - debut,
      })
    } catch (error) {
      const issue = issueApresEchec({
        attempts: job.attempts,
        error,
        permanent: error instanceof PermanentJobError,
        now: horloge(),
      })

      if (issue.status === 'failed') {
        await opts.store.markFailed(job.id, issue.lastError)
        result.failed++
      } else {
        await opts.store.requeue(job.id, issue.runAfter, issue.lastError)
        result.requeued++
      }

      result.jobs.push({
        id: job.id,
        type: job.type,
        outcome: issue.status === 'failed' ? 'failed' : 'requeued',
        attempts: job.attempts,
        durationMs: Date.now() - debut,
        error: issue.lastError,
      })

      log('job en échec', {
        jobId: job.id,
        type: job.type,
        attempts: job.attempts,
        issue: issue.status,
        error: issue.lastError,
      })
    }
  }

  return result
}
