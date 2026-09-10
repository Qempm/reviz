/**
 * État réel d'une série de révision.
 *
 * `public.refresh_streak()` ne remet jamais `profiles.current_streak` à zéro
 * de lui-même : il n'y a pas de tâche qui passe à minuit, et il n'en faut
 * pas — cela réécrirait chaque nuit la ligne de tous les étudiants inactifs.
 * Le commentaire de la migration le dit explicitement :
 *
 * > La série affichée reste celle du dernier jour validé : elle ne se remet
 * > pas à zéro d'elle-même à minuit. C'est à l'affichage de la présenter
 * > comme rompue si last_validated_on est antérieur à hier.
 *
 * Personne ne s'en chargeait : un étudiant qui avait validé cinq jours puis
 * abandonné une semaine lisait toujours « 5 jours de flamme ». C'est ce
 * calcul-là, et il vit ici pour être testable sans base.
 *
 * **Le jour de référence est en UTC**, comme `daily_activity.day` et
 * `streak_week()`, qui tronquent `answered_at at time zone 'UTC'`. Le Bénin
 * est à UTC+1 sans heure d'été : une réponse donnée à 00 h 30 à Cotonou
 * compte donc pour la veille. Le décalage est réel mais cohérent de bout en
 * bout ; le corriger demanderait de changer la base, pas l'affichage.
 */

/** Jour courant en UTC, au format `YYYY-MM-DD`. */
export function jourUtc(now: Date = new Date()): string {
  return now.toISOString().slice(0, 10)
}

/** Jour précédent celui donné, au même format. */
export function veille(jour: string): string {
  const [a, m, j] = jour.split('-').map(Number)
  const d = new Date(Date.UTC(a, m - 1, j))
  d.setUTCDate(d.getUTCDate() - 1)
  return d.toISOString().slice(0, 10)
}

export type EtatSerie = {
  /** Jours à afficher : 0 dès que la série est rompue. */
  jours: number
  /** Le dernier jour validé est trop ancien : la série ne court plus. */
  rompue: boolean
  /** Aujourd'hui est déjà validé. */
  valideAujourdhui: boolean
  /**
   * La série court encore mais aujourd'hui n'est pas validé : c'est le seul
   * moment où il y a quelque chose à perdre, et donc le seul où il vaut la
   * peine de le dire.
   */
  enJeu: boolean
}

export function etatSerie(opts: {
  /** `profiles.current_streak`, tel quel. */
  current: number
  /** `profiles.last_validated_on`, date nue ou null. */
  lastValidatedOn: string | null
  now?: Date
}): EtatSerie {
  const aujourdhui = jourUtc(opts.now ?? new Date())
  const hier = veille(aujourdhui)
  const dernier = opts.lastValidatedOn?.slice(0, 10) ?? null
  const current = Math.max(0, Math.floor(opts.current))

  if (dernier === null || dernier < hier) {
    return { jours: 0, rompue: true, valideAujourdhui: false, enJeu: false }
  }

  if (dernier === aujourdhui) {
    return {
      jours: current,
      rompue: false,
      valideAujourdhui: true,
      enJeu: false,
    }
  }

  // `dernier === hier` : la série tient, mais elle tombe à minuit UTC si
  // rien n'est répondu aujourd'hui.
  return { jours: current, rompue: false, valideAujourdhui: false, enJeu: true }
}

/**
 * Progression vers l'objectif du jour, bornée à 1.
 *
 * Répondre à trente questions ne remplit pas la barre trois fois : au-delà
 * de l'objectif, le jour est validé, point.
 */
export function progressionDuJour(repondues: number, objectif: number): number {
  if (objectif <= 0) return 1
  return Math.min(1, Math.max(0, repondues) / objectif)
}

/** Questions restantes avant de valider la journée. */
export function resteAvantObjectif(repondues: number, objectif: number): number {
  return Math.max(0, Math.ceil(objectif - Math.max(0, repondues)))
}
