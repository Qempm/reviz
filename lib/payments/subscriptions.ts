/**
 * Accès achetés et expiration des packs (CLAUDE.md, règle métier 1).
 *
 * Achat unique, à durée limitée, **sans aucun renouvellement automatique**.
 * À `ends_at`, l'accès s'arrête : les cours et l'historique restent lisibles,
 * plus rien n'est générable, et l'écran « pack expiré » propose une
 * réactivation.
 *
 * Fonctions pures : aucun accès à la base, pour que la règle soit testable et
 * tienne en un seul endroit.
 */

export type PackCode =
  | 'decouverte'
  | 'controle'
  | 'partiel'
  | 'semestre'
  | 'rattrapage'

export type Pack = {
  code: PackCode
  durationDays: number
  correctionsIncluded: number
  /** Null vaut illimité. */
  subjectsLimit: number | null
}

export type SubscriptionSource = 'payment' | 'class_purchase' | 'bonus'

export type Subscription = {
  packCode: PackCode
  startsAt: Date
  endsAt: Date
  correctionsLeft: number
  subjectsLimit: number | null
}

/**
 * Valeurs d'une nouvelle ligne `subscriptions` à l'activation d'un pack.
 *
 * Un nouvel achat ne prolonge pas l'accès en cours : il crée une ligne qui
 * démarre maintenant. Les packs se cumulent donc, et l'accès effectif est
 * l'union des lignes actives — c'est ce que fait la vue SQL
 * `active_subscriptions`. Cela évite d'avoir à fusionner des plafonds de
 * matières hétérogènes en une seule ligne.
 */
export function activerPack(opts: {
  pack: Pack
  source: SubscriptionSource
  now?: Date
}): Subscription {
  const startsAt = opts.now ?? new Date()
  // Arithmétique de calendrier : « la même heure, N jours plus tard ». Un
  // pack de 7 jours acheté à 08:00 expire à 08:00, pas à 07:00 après un
  // changement d'heure. Vercel tourne en UTC et le Bénin est en UTC+1 sans
  // heure d'été, donc les deux coïncident en production.
  const endsAt = new Date(startsAt)
  endsAt.setDate(endsAt.getDate() + opts.pack.durationDays)

  return {
    packCode: opts.pack.code,
    startsAt,
    endsAt,
    correctionsLeft: opts.pack.correctionsIncluded,
    subjectsLimit: opts.pack.subjectsLimit,
  }
}

export function estActif(sub: Subscription, now: Date = new Date()): boolean {
  return sub.startsAt <= now && sub.endsAt > now
}

export type EtatAcces =
  /** Au moins un pack en cours : tout est ouvert. */
  | {
      state: 'active'
      /** Fin de l'accès la plus lointaine. */
      endsAt: Date
      /** Jours entiers restants, arrondis au plus proche par le bas. */
      daysLeft: number
      correctionsLeft: number
      /** Null vaut illimité. */
      subjectsLimit: number | null
      packCodes: PackCode[]
    }
  /** Des packs ont existé mais aucun n'est en cours : lecture seule. */
  | { state: 'expired'; expiredAt: Date }
  /** Aucun pack n'a jamais été acheté. */
  | { state: 'none' }

const JOUR_MS = 24 * 60 * 60 * 1000

/**
 * État d'accès d'un étudiant à partir de ses lignes d'abonnement.
 *
 * Les plafonds se cumulent : le plafond de matières effectif est le plus
 * généreux des packs actifs, et illimité l'emporte sur tout. Les corrections
 * restantes s'additionnent.
 */
export function etatAcces(
  subscriptions: ReadonlyArray<Subscription>,
  now: Date = new Date(),
): EtatAcces {
  if (subscriptions.length === 0) return { state: 'none' }

  const actifs = subscriptions.filter((s) => estActif(s, now))

  if (actifs.length === 0) {
    // Lecture seule : on garde la date de fin la plus récente pour l'écran
    // « pack expiré ».
    const expiredAt = subscriptions
      .map((s) => s.endsAt)
      .reduce((a, b) => (a > b ? a : b))
    return { state: 'expired', expiredAt }
  }

  const endsAt = actifs.map((s) => s.endsAt).reduce((a, b) => (a > b ? a : b))

  // Illimité l'emporte : une seule ligne à null suffit.
  const illimite = actifs.some((s) => s.subjectsLimit === null)
  const subjectsLimit = illimite
    ? null
    : Math.max(...actifs.map((s) => s.subjectsLimit ?? 0))

  return {
    state: 'active',
    endsAt,
    daysLeft: Math.max(0, Math.floor((endsAt.getTime() - now.getTime()) / JOUR_MS)),
    correctionsLeft: actifs.reduce((t, s) => t + s.correctionsLeft, 0),
    subjectsLimit,
    packCodes: actifs.map((s) => s.packCode),
  }
}

/** Plafond de corrections par jour, tous packs confondus (règle métier 5). */
export const CORRECTIONS_PAR_JOUR = 5

export type RefusCorrection =
  | 'pack_expire'
  | 'aucun_pack'
  | 'credit_epuise'
  | 'plafond_journalier'

export type DroitCorrection =
  | { autorise: true; correctionsLeft: number }
  | { autorise: false; reason: RefusCorrection }

/**
 * L'étudiant peut-il demander une correction ?
 *
 * Le plafond journalier s'applique **même en pack illimité** : c'est une
 * protection de coût, pas une limite commerciale. Le trigger SQL
 * `corrections_daily_cap` refuse de toute façon la sixième, mais l'interface
 * doit pouvoir l'annoncer avant.
 */
export function peutCorriger(opts: {
  acces: EtatAcces
  /** Corrections déjà demandées aujourd'hui. */
  correctionsAujourdhui: number
}): DroitCorrection {
  const { acces, correctionsAujourdhui } = opts

  if (acces.state === 'none') return { autorise: false, reason: 'aucun_pack' }
  if (acces.state === 'expired') return { autorise: false, reason: 'pack_expire' }

  if (correctionsAujourdhui >= CORRECTIONS_PAR_JOUR) {
    return { autorise: false, reason: 'plafond_journalier' }
  }

  if (acces.correctionsLeft <= 0) {
    return { autorise: false, reason: 'credit_epuise' }
  }

  return { autorise: true, correctionsLeft: acces.correctionsLeft }
}

/**
 * Une matière de plus est-elle activable ?
 *
 * `subjectsLimit` à null vaut illimité.
 */
export function peutAjouterMatiere(opts: {
  acces: EtatAcces
  matieresActives: number
}): boolean {
  if (opts.acces.state !== 'active') return false
  if (opts.acces.subjectsLimit === null) return true
  return opts.matieresActives < opts.acces.subjectsLimit
}
