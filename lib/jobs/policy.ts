import { HEAVY_JOB_TYPES } from '@/lib/ai/peak-hours'
import type { JobType } from './types'

/**
 * Politique de reprise de la file.
 *
 * Fonctions pures : la décision « réessaie-t-on, et quand ? » se lit et se
 * teste d'un seul endroit, indépendamment de Supabase.
 */

/** Nombre maximal de tentatives avant abandon définitif. */
export const MAX_ATTEMPTS = 5

/**
 * Délais avant nouvelle tentative, en minutes, indexés par numéro d'essai.
 *
 * Progression volontairement lente sur la fin : un cours qui échoue trois fois
 * a un vrai problème, et le relancer aussitôt ne fait que consommer des jetons.
 * Le dernier délai laisse le temps d'un correctif avant l'abandon.
 */
const BACKOFF_MINUTES = [1, 5, 15, 60]

/**
 * Délai au-delà duquel un job resté en `running` est considéré abandonné.
 *
 * Doit rester supérieur à la durée maximale d'une invocation serverless,
 * sinon un job encore en cours serait repris en parallèle de lui-même.
 */
export const STALE_AFTER_MINUTES = 10

/** Combien de jobs on prend par passage du cron. */
export const BATCH_SIZE = 5

export function backoffMinutes(attempts: number): number {
  const i = Math.max(0, attempts - 1)
  return BACKOFF_MINUTES[Math.min(i, BACKOFF_MINUTES.length - 1)]
}

/** Date de la prochaine tentative après un échec. */
export function prochaineTentative(attempts: number, now: Date = new Date()): Date {
  const d = new Date(now)
  d.setMinutes(d.getMinutes() + backoffMinutes(attempts))
  return d
}

export type Issue =
  | { status: 'queued'; runAfter: Date; lastError: string }
  | { status: 'failed'; lastError: string }

/**
 * Que devient un job dont la tentative vient d'échouer ?
 *
 * `attempts` est la valeur **après** incrément par `claim_jobs`, c'est-à-dire
 * le nombre de tentatives consommées.
 */
export function issueApresEchec(opts: {
  attempts: number
  error: unknown
  /** Erreur qu'un nouvel essai ne réparera pas : on abandonne tout de suite. */
  permanent?: boolean
  now?: Date
}): Issue {
  const now = opts.now ?? new Date()
  const message = messageErreur(opts.error)

  if (opts.permanent || opts.attempts >= MAX_ATTEMPTS) {
    return { status: 'failed', lastError: message }
  }

  return {
    status: 'queued',
    runAfter: prochaineTentative(opts.attempts, now),
    lastError: message,
  }
}

/** Message d'erreur borné : `jobs.last_error` n'a pas vocation à tout stocker. */
export function messageErreur(error: unknown, max = 1000): string {
  const brut =
    error instanceof Error
      ? `${error.name}: ${error.message}`
      : typeof error === 'string'
        ? error
        : JSON.stringify(error)

  return brut.length > max ? `${brut.slice(0, max - 1)}…` : brut
}

/**
 * Types de jobs lourds, au sens de la règle métier 6.
 *
 * Réexporté depuis `lib/ai/peak-hours.ts` plutôt que redéfini : la liste
 * existait en double, avec deux types différents.
 */
export { HEAVY_JOB_TYPES }

export function estLourd(type: JobType): boolean {
  return (HEAVY_JOB_TYPES as readonly string[]).includes(type)
}
