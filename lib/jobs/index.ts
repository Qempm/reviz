/**
 * File de traitement Reviz.
 *
 * Table `jobs` dans Supabase, déclenchée par Vercel Cron toutes les minutes
 * via /api/jobs/run. Pas de Redis au MVP (CLAUDE.md, section Stack).
 */
export { runJobs } from './runner'
export type { JobStore, Handlers, RunResult, RunOptions } from './runner'

export { createSupabaseJobStore, enqueueJob, versJob } from './store'
export { handlers, notifyHandler } from './handlers'

export {
  backoffMinutes,
  prochaineTentative,
  issueApresEchec,
  messageErreur,
  estLourd,
  MAX_ATTEMPTS,
  STALE_AFTER_MINUTES,
  BATCH_SIZE,
  HEAVY_JOB_TYPES,
} from './policy'
export type { Issue } from './policy'

export { PermanentJobError } from './types'
export type {
  Job,
  JobType,
  JobStatus,
  JobPayload,
  JobHandler,
  JobContext,
} from './types'
