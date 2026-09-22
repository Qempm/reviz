/**
 * Ce qu'un webhook de paiement doit écrire — décidé hors de toute base.
 *
 * Le webhook faisait sa propre arithmétique : `Math.round(amount * rate)` sur
 * deux lignes, le taux lu sur le payeur, aucune vérification de la fenêtre de
 * douze mois ni du statut du filleul. `calculerCommission()`, couverte par
 * seize tests, n'était appelée que par ses propres tests.
 *
 * Ce module est la jonction : il lit un contexte déjà chargé et rend la
 * décision, en déléguant chaque règle à son porteur — `activerPack()` pour
 * l'accès, `calculerCommission()` pour la commission. Il n'écrit rien et ne
 * lit rien : c'est ce qui le rend testable, et c'est pour cela que la règle
 * ne peut plus être réécrite ailleurs par inadvertance.
 */

import {
  calculerCommission,
  type EtatFilleul,
  type EtatParrain,
  type MotifRefus,
  type Parrainage,
} from '@/lib/payments/commission'
import {
  activerPack,
  type Pack,
  type Subscription,
} from '@/lib/payments/subscriptions'

/** Les statuts que FedaPay envoie. */
export type StatutFournisseur = 'approved' | 'declined' | 'pending'

/** Les statuts que porte la colonne `payments.status`. */
export type StatutPaiement = 'pending' | 'success' | 'failed'

/**
 * Traduction des statuts du fournisseur.
 *
 * `null` signifie « ne rien faire » : une notification `pending` n'est pas une
 * issue, et la traiter ferait passer un paiement en cours pour un échec.
 */
export function statutDepuisFournisseur(
  statut: StatutFournisseur,
): Exclude<StatutPaiement, 'pending'> | null {
  switch (statut) {
    case 'approved':
      return 'success'
    case 'declined':
      return 'failed'
    case 'pending':
      return null
  }
}

export type PaiementCharge = {
  id: string
  userId: string
  packCode: Pack['code']
  amountFcfa: number
  /** Statut **déjà en base**, avant traitement de cet événement. */
  status: StatutPaiement
}

/** Tout ce qu'il faut avoir lu avant de décider. */
export type ContextePaiement = {
  paiement: PaiementCharge
  pack: Pack
  /** Le profil de celui qui paie — donc le filleul, s'il a un parrain. */
  payeur: EtatFilleul
  /** La ligne `referrals`, si elle existe. */
  parrainage: Parrainage | null
  /**
   * Le profil du **parrain**, et non celui du payeur.
   *
   * C'est la correction du défaut le plus discret de l'audit : le webhook
   * lisait `is_ambassador` sur le payeur. Un parrain ambassadeur était donc
   * payé 25 % si son filleul ne l'était pas, et un parrain ordinaire touchait
   * 35 % si son filleul l'était.
   */
  parrain: EtatParrain | null
  now?: Date
}

export type CommissionAVerser = {
  parrainId: string
  montantFcfa: number
  taux: number
}

export type Decision =
  /** Rien à écrire : statut intermédiaire, ou événement déjà traité. */
  | { action: 'ignorer'; motif: 'statut-intermediaire' | 'deja-traite' }
  /** Le paiement a échoué : seul le statut change. */
  | { action: 'echec' }
  /** Le paiement a réussi. */
  | {
      action: 'activer'
      abonnement: Subscription
      commission: CommissionAVerser | null
      /** Pourquoi aucune commission, quand il y avait un parrainage. */
      motifSansCommission: MotifRefus | 'aucun-parrainage' | null
    }

/**
 * Décide de ce qu'il faut écrire pour un événement de paiement.
 *
 * L'ordre compte : on écarte d'abord les événements sans effet, **avant** de
 * regarder quoi que ce soit d'autre. Un paiement déjà à `success` est une
 * relivraison — tout émetteur de webhook réémet — et la traiter accorderait
 * un second accès et une seconde commission.
 */
export function deciderPaiement(
  statutFournisseur: StatutFournisseur,
  contexte: ContextePaiement,
): Decision {
  const statut = statutDepuisFournisseur(statutFournisseur)
  if (statut === null) {
    return { action: 'ignorer', motif: 'statut-intermediaire' }
  }

  if (contexte.paiement.status === 'success') {
    return { action: 'ignorer', motif: 'deja-traite' }
  }

  if (statut === 'failed') return { action: 'echec' }

  const now = contexte.now ?? new Date()

  const abonnement = activerPack({
    pack: contexte.pack,
    source: 'payment',
    now,
  })

  const { parrainage, parrain } = contexte

  if (!parrainage || !parrain) {
    return {
      action: 'activer',
      abonnement,
      commission: null,
      motifSansCommission: 'aucun-parrainage',
    }
  }

  const commission = calculerCommission({
    parrainage,
    parrain,
    filleul: contexte.payeur,
    amountFcfa: contexte.paiement.amountFcfa,
    now,
  })

  if (!commission.due) {
    return {
      action: 'activer',
      abonnement,
      commission: null,
      motifSansCommission: commission.reason,
    }
  }

  return {
    action: 'activer',
    abonnement,
    commission: {
      parrainId: commission.referrerId,
      montantFcfa: commission.amountFcfa,
      taux: commission.rate,
    },
    motifSansCommission: null,
  }
}
