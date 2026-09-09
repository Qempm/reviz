/**
 * Barème d'expérience.
 *
 * Fonctions pures, sans Supabase : le barème se lit, se teste et se discute
 * d'un seul endroit. L'écriture en base est faite par le rôle de service —
 * `xp_events` n'a volontairement aucune politique d'insertion côté client
 * (supabase/migrations/20260908140000_xp_et_series.sql), sans quoi un étudiant
 * s'offrirait la première place du classement.
 */

/** Motifs de `xp_events.reason`, tels que l'énumération Postgres les nomme. */
export type MotifXp =
  | 'correct_answer'
  | 'quiz_completed'
  | 'daily_goal'
  | 'streak_bonus'
  | 'course_added'
  | 'correction_done'
  | 'referral'
  | 'adjustment'

export type GainXp = {
  reason: MotifXp
  amount: number
  /** Ligne d'origine — question, cours, correction, filleul. */
  referenceId?: string | null
}

/**
 * Points par événement.
 *
 * Une bonne réponse vaut peu et une journée validée vaut beaucoup : c'est la
 * régularité qu'on récompense, pas le volume. Un étudiant qui enchaîne
 * 300 questions un dimanche ne doit pas dépasser celui qui en fait dix par
 * jour toute la semaine.
 */
export const BAREME: Record<Exclude<MotifXp, 'streak_bonus' | 'adjustment'>, number> = {
  correct_answer: 10,
  quiz_completed: 20,
  daily_goal: 30,
  course_added: 25,
  correction_done: 40,
  referral: 500,
}

/** Plafond du bonus de série, atteint à dix jours. */
export const BONUS_SERIE_MAX = 50

/**
 * Bonus de série : 5 points par jour consécutif, plafonné.
 *
 * Sans plafond, une série de six mois vaudrait 900 points par jour et le
 * classement se figerait sur les premiers inscrits.
 */
export function bonusSerie(jours: number): number {
  if (!Number.isFinite(jours) || jours <= 1) return 0
  return Math.min(BONUS_SERIE_MAX, Math.floor(jours) * 5)
}

export type ResultatSession = {
  /** Réponses justes de la session. */
  bonnes: number
  /** Questions répondues, justes et fausses. */
  total: number
  /**
   * L'objectif du jour vient-il d'être atteint ?
   *
   * Se lit sur `daily_activity.is_validated`, posé par le trigger
   * `track_attempt()`, et non recalculé ici : la base a le compte exact des
   * questions du jour, l'écran n'a que celles de sa session.
   */
  objectifAtteint: boolean
  /** Série en jours, pour le bonus. Nulle si l'objectif n'est pas atteint. */
  serie?: number
}

/**
 * Gains d'une session terminée.
 *
 * Une seule ligne par motif, jamais une par bonne réponse : le journal doit
 * rester lisible, et `xp_events` sert aussi à l'audit d'un litige de
 * classement.
 */
export function gainsDeSession(r: ResultatSession): GainXp[] {
  const gains: GainXp[] = []

  const bonnes = Math.max(0, Math.floor(r.bonnes))
  const total = Math.max(0, Math.floor(r.total))

  if (bonnes > 0) {
    gains.push({
      reason: 'correct_answer',
      amount: bonnes * BAREME.correct_answer,
    })
  }

  // Une session vide ne se « termine » pas : sans quoi ouvrir puis quitter
  // l'écran rapporterait 20 points.
  if (total > 0) {
    gains.push({ reason: 'quiz_completed', amount: BAREME.quiz_completed })
  }

  if (r.objectifAtteint) {
    gains.push({ reason: 'daily_goal', amount: BAREME.daily_goal })

    const bonus = bonusSerie(r.serie ?? 0)
    if (bonus > 0) gains.push({ reason: 'streak_bonus', amount: bonus })
  }

  return gains
}

/** Total d'une liste de gains, pour l'afficher d'un chiffre. */
export function totalGains(gains: GainXp[]): number {
  return gains.reduce((s, g) => s + g.amount, 0)
}
