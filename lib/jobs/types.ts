/** File de traitement : types partagés (CLAUDE.md, section Stack). */

export type JobType =
  | 'ingest_course'
  | 'generate_questions'
  | 'correct_copy'
  | 'verify_card'
  | 'notify'

export type JobStatus = 'queued' | 'running' | 'done' | 'failed'

export type Job = {
  id: string
  type: JobType
  payload: Record<string, unknown>
  status: JobStatus
  /** Déjà incrémenté par claim_jobs au moment où le job est pris. */
  attempts: number
  lastError: string | null
  runAfter: Date
  createdAt: Date
  startedAt: Date | null
  finishedAt: Date | null
}

/**
 * Traitement d'un type de job.
 *
 * Une erreur levée fait échouer la tentative ; la politique de reprise décide
 * ensuite d'un nouvel essai ou d'un abandon.
 */
export type JobHandler = (job: Job, ctx: JobContext) => Promise<void>

export type JobContext = {
  /** Coupe court quand la fonction serverless approche de son échéance. */
  signal?: AbortSignal
  /** Journalisation, injectable pour les tests. */
  log: (message: string, extra?: Record<string, unknown>) => void
}

/** Erreur qui ne sera jamais réparée par un nouvel essai. */
export class PermanentJobError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'PermanentJobError'
  }
}
