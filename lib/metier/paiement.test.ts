import { describe, expect, it } from 'vitest'
import {
  deciderPaiement,
  statutDepuisFournisseur,
  type ContextePaiement,
} from './paiement'
import { TAUX_AMBASSADEUR, TAUX_STANDARD } from '@/lib/payments/commission'

/**
 * Tests de la décision de paiement.
 *
 * Ce sont les quatre défauts critiques de l'audit qui sont vérifiés ici :
 * la relivraison qui payait deux fois, le taux lu sur le payeur, les règles de
 * commission contournées, et la notification conditionnée au parrainage. Un
 * test qui repasse au rouge signifie que l'un d'eux est revenu.
 */

const MAINTENANT = new Date('2026-09-22T10:00:00.000Z')

const PACK: ContextePaiement['pack'] = {
  code: 'controle',
  durationDays: 7,
  correctionsIncluded: 3,
  subjectsLimit: 2,
}

const contexte = (
  partiel: Partial<ContextePaiement> = {},
): ContextePaiement => ({
  paiement: {
    id: 'p1',
    userId: 'filleul',
    packCode: 'controle',
    amountFcfa: 1000,
    status: 'pending',
  },
  pack: PACK,
  payeur: { id: 'filleul', verificationStatus: 'verified' },
  parrainage: {
    referrerId: 'parrain',
    referredId: 'filleul',
    firstPaymentAt: null,
  },
  parrain: { id: 'parrain', isAmbassador: false },
  now: MAINTENANT,
  ...partiel,
})

describe('statutDepuisFournisseur', () => {
  it('traduit les deux issues', () => {
    expect(statutDepuisFournisseur('approved')).toBe('success')
    expect(statutDepuisFournisseur('declined')).toBe('failed')
  })

  it('ne traduit pas « pending »', () => {
    // Un paiement en cours n'est pas un échec : le traduire en `failed`
    // fermerait l'accès d'un étudiant en train de payer.
    expect(statutDepuisFournisseur('pending')).toBeNull()
  })
})

describe('deciderPaiement — ce qui ne doit rien écrire', () => {
  it('ignore une notification « pending »', () => {
    const d = deciderPaiement('pending', contexte())
    expect(d).toEqual({ action: 'ignorer', motif: 'statut-intermediaire' })
  })

  it('ignore une relivraison d’un paiement déjà réussi', () => {
    // Le défaut § 4.3 : le code lisait `payment.status` et ne le testait
    // jamais. À la deuxième livraison de `approved`, l'étudiant recevait un
    // second abonnement — `activerPack()` cumule les packs par conception —
    // et le parrain une seconde commission, dans un journal immuable.
    const d = deciderPaiement(
      'approved',
      contexte({
        paiement: {
          id: 'p1',
          userId: 'filleul',
          packCode: 'controle',
          amountFcfa: 1000,
          status: 'success',
        },
      }),
    )

    expect(d).toEqual({ action: 'ignorer', motif: 'deja-traite' })
  })

  it('enregistre un échec sans rien activer', () => {
    const d = deciderPaiement('declined', contexte())
    expect(d).toEqual({ action: 'echec' })
  })

  it('n’ignore pas une relivraison d’un paiement encore en échec', () => {
    // Un paiement `failed` peut légitimement passer à `success` : certains
    // opérateurs Mobile Money réémettent après une première tentative
    // refusée. Seul `success` est définitif.
    const d = deciderPaiement(
      'approved',
      contexte({
        paiement: {
          id: 'p1',
          userId: 'filleul',
          packCode: 'controle',
          amountFcfa: 1000,
          status: 'failed',
        },
      }),
    )

    expect(d.action).toBe('activer')
  })
})

describe('deciderPaiement — l’accès', () => {
  it('ouvre un accès de la durée du pack', () => {
    const d = deciderPaiement('approved', contexte())
    expect(d.action).toBe('activer')
    if (d.action !== 'activer') return

    expect(d.abonnement.startsAt).toEqual(MAINTENANT)
    expect(d.abonnement.endsAt).toEqual(new Date('2026-09-29T10:00:00.000Z'))
    expect(d.abonnement.correctionsLeft).toBe(3)
    expect(d.abonnement.packCode).toBe('controle')
  })

  it('prend la durée du pack tel que la base le décrit', () => {
    // Le pack vient de `packs`, pas des métadonnées du fournisseur : sans
    // cela, un appelant choisirait la durée de son accès.
    const d = deciderPaiement(
      'approved',
      contexte({ pack: { ...PACK, durationDays: 90, correctionsIncluded: 20 } }),
    )
    if (d.action !== 'activer') throw new Error('accès attendu')
    expect(d.abonnement.endsAt).toEqual(new Date('2026-12-21T10:00:00.000Z'))
    expect(d.abonnement.correctionsLeft).toBe(20)
  })
})

describe('deciderPaiement — la commission', () => {
  it('verse 25 % au parrain ordinaire', () => {
    const d = deciderPaiement('approved', contexte())
    if (d.action !== 'activer') throw new Error('accès attendu')

    expect(d.commission).toEqual({
      parrainId: 'parrain',
      montantFcfa: 250,
      taux: TAUX_STANDARD,
    })
  })

  it('lit le drapeau ambassadeur sur le parrain, pas sur le payeur', () => {
    // Le défaut § 4.4, et le plus discret de tous : le webhook lisait
    // `is_ambassador` sur `payment.user_id`, c'est-à-dire sur le filleul.
    const d = deciderPaiement(
      'approved',
      contexte({ parrain: { id: 'parrain', isAmbassador: true } }),
    )
    if (d.action !== 'activer') throw new Error('accès attendu')

    expect(d.commission?.taux).toBe(TAUX_AMBASSADEUR)
    expect(d.commission?.montantFcfa).toBe(350)
  })

  it('ne verse rien si le filleul n’est pas vérifié', () => {
    // Règle métier 2 : un filleul ne compte que s'il est vérifié. Le webhook
    // créditait sans la vérifier (§ 4.5).
    const d = deciderPaiement(
      'approved',
      contexte({ payeur: { id: 'filleul', verificationStatus: 'pending' } }),
    )
    if (d.action !== 'activer') throw new Error('accès attendu')

    expect(d.commission).toBeNull()
    expect(d.motifSansCommission).toBe('filleul_non_verifie')
    // L'accès, lui, est bien ouvert : il a payé.
    expect(d.abonnement.correctionsLeft).toBe(3)
  })

  it('ne verse rien après douze mois', () => {
    const d = deciderPaiement(
      'approved',
      contexte({
        parrainage: {
          referrerId: 'parrain',
          referredId: 'filleul',
          firstPaymentAt: new Date('2025-01-01T00:00:00.000Z'),
        },
      }),
    )
    if (d.action !== 'activer') throw new Error('accès attendu')

    expect(d.commission).toBeNull()
    expect(d.motifSansCommission).toBe('fenetre_expiree')
  })

  it('verse encore à onze mois', () => {
    const d = deciderPaiement(
      'approved',
      contexte({
        parrainage: {
          referrerId: 'parrain',
          referredId: 'filleul',
          firstPaymentAt: new Date('2025-11-01T00:00:00.000Z'),
        },
      }),
    )
    if (d.action !== 'activer') throw new Error('accès attendu')
    expect(d.commission?.montantFcfa).toBe(250)
  })

  it('refuse un auto-parrainage même si la ligne existe', () => {
    const d = deciderPaiement(
      'approved',
      contexte({
        parrainage: {
          referrerId: 'filleul',
          referredId: 'filleul',
          firstPaymentAt: null,
        },
        parrain: { id: 'filleul', isAmbassador: true },
      }),
    )
    if (d.action !== 'activer') throw new Error('accès attendu')

    expect(d.commission).toBeNull()
    expect(d.motifSansCommission).toBe('parrain_est_le_filleul')
  })

  it('active sans commission quand il n’y a pas de parrain', () => {
    const d = deciderPaiement(
      'approved',
      contexte({ parrainage: null, parrain: null }),
    )
    if (d.action !== 'activer') throw new Error('accès attendu')

    // Le cas le plus courant, et celui où la version précédente sautait aussi
    // la notification WhatsApp (§ 4.14) : l'étudiant payait et n'était
    // jamais prévenu.
    expect(d.commission).toBeNull()
    expect(d.motifSansCommission).toBe('aucun-parrainage')
    expect(d.abonnement.packCode).toBe('controle')
  })

  it('n’invente pas de parrain si seule la ligne de parrainage existe', () => {
    // Profil de parrain illisible ou supprimé : on n'applique pas un taux par
    // défaut à un parrain dont on ne sait rien.
    const d = deciderPaiement('approved', contexte({ parrain: null }))
    if (d.action !== 'activer') throw new Error('accès attendu')
    expect(d.commission).toBeNull()
  })

  it('arrondit à l’unité de FCFA', () => {
    // Le franc CFA n'a pas de subdivision : 333 × 0,25 = 83,25 → 83.
    const d = deciderPaiement(
      'approved',
      contexte({
        paiement: {
          id: 'p1',
          userId: 'filleul',
          packCode: 'controle',
          amountFcfa: 333,
          status: 'pending',
        },
      }),
    )
    if (d.action !== 'activer') throw new Error('accès attendu')
    expect(d.commission?.montantFcfa).toBe(83)
  })
})
