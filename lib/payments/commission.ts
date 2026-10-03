/**
 * Commissions de parrainage (CLAUDE.md, règle métier 2).
 *
 * **Suspendues depuis le 3 octobre 2026** (`COMMISSIONS_ACTIVES`) : le
 * propriétaire, seul, ne pouvait pas tenir 25 % de chaque paiement. Le jour où
 * elles reprennent, c'est à 10 % du montant de chaque paiement du filleul,
 * 15 % si le parrain est ambassadeur, pendant 12 mois à partir du premier
 * paiement. Créditées dans `wallet_ledger` au webhook de paiement réussi.
 *
 * Un filleul ne compte que s'il est vérifié et a payé au moins une fois : le
 * premier paiement est donc celui qui ouvre la fenêtre, et il est lui-même
 * commissionné.
 *
 * **Depuis le 3 octobre 2026, le parrain doit avoir 3 000 XP** (sauf
 * ambassadeur) : le parrainage récompense qui utilise vraiment l'application.
 * Pas de rattrapage — un paiement de filleul fait avant le seuil ne rapporte
 * rien, et la fenêtre de 12 mois part du premier paiement commissionné.
 *
 * Aucun accès à la base ici : ces fonctions sont pures pour être testables et
 * pour que la règle reste lisible d'un seul endroit.
 */

/**
 * L'interrupteur des commissions. Faux : aucun paiement de filleul ne
 * rapporte d'argent, quels que soient le seuil et le statut du parrain. La
 * base porte le même (`public.commissions_actives()`), et l'application aussi
 * (`commissionsActives`, `apps/mobile/lib/metier/commission.dart`) : la
 * reprise se fait aux trois endroits, avec une migration.
 */
export const COMMISSIONS_ACTIVES = false

/**
 * Taux ramenés de 25 % et 35 % le 3 octobre 2026 : 10 % reste motivant sur
 * les packs chers, sans peser sur une marge qui doit déjà payer l'IA et
 * FedaPay. La base accepte encore 25 % et 35 % pour les parrainages
 * enregistrés avant.
 */
export const TAUX_STANDARD = 0.1
export const TAUX_AMBASSADEUR = 0.15

/** Seuil de retrait, en FCFA (règle métier 2). */
export const SEUIL_RETRAIT_FCFA = 3000

/** Durée de la fenêtre de commission après le premier paiement. */
export const FENETRE_MOIS = 12

/**
 * XP qu'un parrain doit avoir atteints pour toucher ses commissions (règle
 * métier 2, arbitrage du 3 octobre 2026). Les ambassadeurs en sont dispensés.
 * La base porte la même valeur (`public.seuil_xp_parrainage()`).
 */
export const SEUIL_XP_PARRAINAGE = 3000

export type StatutVerification = 'none' | 'pending' | 'verified' | 'rejected'

export type Parrainage = {
  referrerId: string
  referredId: string
  /** Null tant que le filleul n'a jamais payé. */
  firstPaymentAt: Date | null
}

export type EtatParrain = {
  id: string
  isAmbassador: boolean
  /** `profiles.xp_total` au moment du paiement du filleul. */
  xpTotal: number
}

export type EtatFilleul = {
  id: string
  verificationStatus: StatutVerification
}

export type MotifRefus =
  | 'commissions_suspendues'
  | 'filleul_non_verifie'
  | 'fenetre_expiree'
  | 'parrain_est_le_filleul'
  | 'parrain_sous_seuil_xp'
  | 'montant_nul'

export type Commission =
  | {
      due: true
      referrerId: string
      /** Taux appliqué : 0.10 ou 0.15. */
      rate: number
      amountFcfa: number
      /** Fin de la fenêtre de 12 mois, telle qu'elle doit être enregistrée. */
      expiresAt: Date
      /** Vrai si ce paiement est celui qui ouvre la fenêtre. */
      opensWindow: boolean
    }
  | { due: false; reason: MotifRefus }

/**
 * Fin de la fenêtre de commission pour un premier paiement donné.
 *
 * Arithmétique de calendrier, volontairement : « la même date douze mois plus
 * tard », et non 8 760 heures. Ne pas remplacer par un calcul en
 * millisecondes, qui décalerait la date d'un jour les années bissextiles.
 * Le 29 février bascule au 1er mars, comportement natif de Date.
 */
export function finDeFenetre(firstPaymentAt: Date): Date {
  const fin = new Date(firstPaymentAt)
  fin.setMonth(fin.getMonth() + FENETRE_MOIS)
  return fin
}

/**
 * Taux applicable à un parrain.
 *
 * DÉCISION : le taux est déterminé par le statut d'ambassadeur **au moment du
 * paiement**, pas figé à la création du parrainage. Devenir ambassadeur
 * améliore donc immédiatement les commissions à venir, sans rétroactivité sur
 * celles déjà versées. `referrals.commission_rate` conserve le dernier taux
 * appliqué. Pour figer le taux à l'inscription, c'est ici qu'il faut agir.
 */
export function tauxParrain(parrain: EtatParrain): number {
  return parrain.isAmbassador ? TAUX_AMBASSADEUR : TAUX_STANDARD
}

/** Le parrain touche-t-il ses commissions ? Ambassadeur, ou 3 000 XP atteints. */
export function parrainDebloque(
  parrain: Pick<EtatParrain, 'isAmbassador' | 'xpTotal'>,
): boolean {
  return parrain.isAmbassador || parrain.xpTotal >= SEUIL_XP_PARRAINAGE
}

/**
 * Calcule la commission due au parrain pour un paiement réussi du filleul.
 *
 * À appeler depuis le webhook de paiement, après avoir constaté le succès.
 */
export function calculerCommission(opts: {
  parrainage: Parrainage
  parrain: EtatParrain
  filleul: EtatFilleul
  /** Montant du paiement du filleul, en FCFA. */
  amountFcfa: number
  now?: Date
  /** L'interrupteur, `COMMISSIONS_ACTIVES` par défaut. Pour les tests. */
  actives?: boolean
}): Commission {
  const now = opts.now ?? new Date()
  const { parrainage, parrain, filleul } = opts

  // Suspendues : rien n'est dû, avant toute autre règle.
  if (!(opts.actives ?? COMMISSIONS_ACTIVES)) {
    return { due: false, reason: 'commissions_suspendues' }
  }

  // Anti-fraude : on ne se parraine pas soi-même (règle métier 3). La base
  // l'interdit déjà, on ne verse rien si la ligne existait malgré tout.
  if (parrainage.referrerId === parrainage.referredId) {
    return { due: false, reason: 'parrain_est_le_filleul' }
  }

  // Le parrainage s'ouvre à 3 000 XP, évalués au moment du paiement — comme
  // le taux. Les ambassadeurs, choisis à la main pour recruter, en sont
  // dispensés.
  if (!parrainDebloque(parrain)) {
    return { due: false, reason: 'parrain_sous_seuil_xp' }
  }

  if (filleul.verificationStatus !== 'verified') {
    return { due: false, reason: 'filleul_non_verifie' }
  }

  if (opts.amountFcfa <= 0) {
    return { due: false, reason: 'montant_nul' }
  }

  // Premier paiement : il ouvre la fenêtre et est lui-même commissionné.
  const opensWindow = parrainage.firstPaymentAt === null
  const debut = parrainage.firstPaymentAt ?? now
  const expiresAt = finDeFenetre(debut)

  if (!opensWindow && now >= expiresAt) {
    return { due: false, reason: 'fenetre_expiree' }
  }

  const rate = tauxParrain(parrain)

  return {
    due: true,
    referrerId: parrain.id,
    rate,
    // Le FCFA n'a pas de subdivision : on arrondit à l'unité.
    amountFcfa: Math.round(opts.amountFcfa * rate),
    expiresAt,
    opensWindow,
  }
}

/** Solde du portefeuille : somme du grand livre, jamais une colonne. */
export function soldeDepuisGrandLivre(
  lignes: ReadonlyArray<{ amountFcfa: number }>,
): number {
  return lignes.reduce((total, l) => total + l.amountFcfa, 0)
}

export type RefusRetrait =
  | 'sous_le_seuil'
  | 'solde_insuffisant'
  | 'montant_invalide'

export type Retrait =
  | { autorise: true; amountFcfa: number }
  | { autorise: false; reason: RefusRetrait; seuil: number; solde: number }

/**
 * Un retrait est-il possible ?
 *
 * Deux conditions distinctes : atteindre le seuil de 3 000 F, et disposer du
 * solde. Les distinguer permet d'afficher le bon message — « encore 1 200 F
 * avant de pouvoir retirer » n'est pas « solde insuffisant ».
 */
export function verifierRetrait(opts: {
  soldeFcfa: number
  amountFcfa: number
}): Retrait {
  const { soldeFcfa, amountFcfa } = opts

  if (!Number.isInteger(amountFcfa) || amountFcfa <= 0) {
    return {
      autorise: false,
      reason: 'montant_invalide',
      seuil: SEUIL_RETRAIT_FCFA,
      solde: soldeFcfa,
    }
  }

  if (amountFcfa < SEUIL_RETRAIT_FCFA) {
    return {
      autorise: false,
      reason: 'sous_le_seuil',
      seuil: SEUIL_RETRAIT_FCFA,
      solde: soldeFcfa,
    }
  }

  if (amountFcfa > soldeFcfa) {
    return {
      autorise: false,
      reason: 'solde_insuffisant',
      seuil: SEUIL_RETRAIT_FCFA,
      solde: soldeFcfa,
    }
  }

  return { autorise: true, amountFcfa }
}
