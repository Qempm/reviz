/**
 * Heures pleines DeepSeek (CLAUDE.md, règle métier 6).
 *
 * Les traitements lourds (`ingest_course`) ne s'exécutent pas entre
 * 01:00–04:00 et 06:00–10:00 UTC du lundi au vendredi, sauf si le job attend
 * depuis plus de 20 minutes.
 *
 * Ce module double la fonction SQL `public.job_peut_demarrer` : la règle vit
 * dans les deux, la base tranchant en dernier ressort. Toute correction ici
 * doit être répercutée dans supabase/migrations/20260908120500_jobs_et_ia.sql.
 */

/** Créneaux chargés, en heures UTC. Borne haute exclue. */
const CRENEAUX: ReadonlyArray<readonly [number, number]> = [
  [1, 4],
  [6, 10],
]

/**
 * Types de jobs considérés comme lourds.
 *
 * Défini ici et réexporté par `lib/jobs/policy.ts`, jamais dupliqué : deux
 * définitions divergentes rendraient `import { HEAVY_JOB_TYPES } from '@/lib/ai'`
 * et `from '@/lib/jobs'` différents, ce qui est indétectable à la lecture.
 */
export const HEAVY_JOB_TYPES = ['ingest_course'] as const
export type HeavyJobType = (typeof HEAVY_JOB_TYPES)[number]

/** Délai au-delà duquel un job passe outre les heures pleines. */
export const MAX_WAIT_MS = 20 * 60 * 1000

export function isDeepSeekPeakHour(at: Date = new Date()): boolean {
  const jour = at.getUTCDay() // 0 = dimanche, 6 = samedi
  if (jour === 0 || jour === 6) return false

  const heure = at.getUTCHours()
  return CRENEAUX.some(([debut, fin]) => heure >= debut && heure < fin)
}

/**
 * Un job peut-il démarrer maintenant ?
 *
 * Seuls les types lourds sont concernés : tout le reste passe en permanence.
 */
export function canStartJob(opts: {
  type: string
  /** Date de création du job, pour la dérogation des 20 minutes. */
  createdAt: Date
  now?: Date
}): boolean {
  const now = opts.now ?? new Date()

  if (!(HEAVY_JOB_TYPES as readonly string[]).includes(opts.type)) return true
  if (now.getTime() - opts.createdAt.getTime() > MAX_WAIT_MS) return true

  return !isDeepSeekPeakHour(now)
}

/**
 * Prochain instant où un job lourd pourra démarrer — sert à renseigner
 * `jobs.run_after` plutôt que de laisser le cron repasser toutes les minutes.
 */
export function nextAllowedStart(from: Date = new Date()): Date {
  if (!isDeepSeekPeakHour(from)) return new Date(from)

  const heure = from.getUTCHours()
  const creneau = CRENEAUX.find(([debut, fin]) => heure >= debut && heure < fin)
  if (!creneau) return new Date(from)

  const sortie = new Date(from)
  sortie.setUTCHours(creneau[1], 0, 0, 0)
  return sortie
}
