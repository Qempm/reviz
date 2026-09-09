import { describe, expect, it } from 'vitest'
import {
  calculerCommission,
  finDeFenetre,
  SEUIL_RETRAIT_FCFA,
  soldeDepuisGrandLivre,
  TAUX_AMBASSADEUR,
  TAUX_STANDARD,
  verifierRetrait,
  type EtatFilleul,
  type EtatParrain,
  type Parrainage,
} from './commission'

const PARRAIN: EtatParrain = { id: 'a', isAmbassador: false }
const AMBASSADEUR: EtatParrain = { id: 'a', isAmbassador: true }
const FILLEUL: EtatFilleul = { id: 'b', verificationStatus: 'verified' }

const parrainage = (firstPaymentAt: Date | null = null): Parrainage => ({
  referrerId: 'a',
  referredId: 'b',
  firstPaymentAt,
})

const JANVIER = new Date('2026-01-15T10:00:00Z')

describe('calcul des commissions', () => {
  it('verse 25 % au parrain standard', () => {
    const c = calculerCommission({
      parrainage: parrainage(),
      parrain: PARRAIN,
      filleul: FILLEUL,
      amountFcfa: 3500,
      now: JANVIER,
    })

    expect(c.due).toBe(true)
    if (c.due) {
      expect(c.rate).toBe(TAUX_STANDARD)
      expect(c.amountFcfa).toBe(875)
      expect(c.referrerId).toBe('a')
    }
  })

  it('verse 35 % à l’ambassadeur', () => {
    const c = calculerCommission({
      parrainage: parrainage(),
      parrain: AMBASSADEUR,
      filleul: FILLEUL,
      amountFcfa: 3500,
      now: JANVIER,
    })

    expect(c.due).toBe(true)
    if (c.due) {
      expect(c.rate).toBe(TAUX_AMBASSADEUR)
      expect(c.amountFcfa).toBe(1225)
    }
  })

  it('commissionne le premier paiement et ouvre la fenêtre de 12 mois', () => {
    const c = calculerCommission({
      parrainage: parrainage(null),
      parrain: PARRAIN,
      filleul: FILLEUL,
      amountFcfa: 1500,
      now: JANVIER,
    })

    expect(c.due).toBe(true)
    if (c.due) {
      // Le premier paiement est celui qui qualifie le filleul : il compte.
      expect(c.opensWindow).toBe(true)
      expect(c.expiresAt.toISOString()).toBe('2027-01-15T10:00:00.000Z')
    }
  })

  it('ne verse rien si le filleul n’est pas vérifié', () => {
    for (const statut of ['none', 'pending', 'rejected'] as const) {
      const c = calculerCommission({
        parrainage: parrainage(),
        parrain: PARRAIN,
        filleul: { id: 'b', verificationStatus: statut },
        amountFcfa: 3500,
        now: JANVIER,
      })
      expect(c.due).toBe(false)
      if (!c.due) expect(c.reason).toBe('filleul_non_verifie')
    }
  })

  it('ne verse plus rien passé les 12 mois', () => {
    const premier = new Date('2026-01-15T10:00:00Z')

    // Onze mois après : encore dans la fenêtre.
    const dedans = calculerCommission({
      parrainage: parrainage(premier),
      parrain: PARRAIN,
      filleul: FILLEUL,
      amountFcfa: 3500,
      now: new Date('2026-12-15T10:00:00Z'),
    })
    expect(dedans.due).toBe(true)

    // Exactement 12 mois : la fenêtre est fermée, borne exclue.
    const pile = calculerCommission({
      parrainage: parrainage(premier),
      parrain: PARRAIN,
      filleul: FILLEUL,
      amountFcfa: 3500,
      now: new Date('2027-01-15T10:00:00Z'),
    })
    expect(pile.due).toBe(false)
    if (!pile.due) expect(pile.reason).toBe('fenetre_expiree')

    // Un an et un jour : fermée aussi.
    const apres = calculerCommission({
      parrainage: parrainage(premier),
      parrain: PARRAIN,
      filleul: FILLEUL,
      amountFcfa: 3500,
      now: new Date('2027-01-16T10:00:00Z'),
    })
    expect(apres.due).toBe(false)
  })

  it('refuse un parrainage de soi-même', () => {
    const c = calculerCommission({
      parrainage: { referrerId: 'a', referredId: 'a', firstPaymentAt: null },
      parrain: PARRAIN,
      filleul: { id: 'a', verificationStatus: 'verified' },
      amountFcfa: 3500,
      now: JANVIER,
    })
    expect(c.due).toBe(false)
    if (!c.due) expect(c.reason).toBe('parrain_est_le_filleul')
  })

  it('refuse un montant nul ou négatif', () => {
    for (const montant of [0, -500]) {
      const c = calculerCommission({
        parrainage: parrainage(),
        parrain: PARRAIN,
        filleul: FILLEUL,
        amountFcfa: montant,
        now: JANVIER,
      })
      expect(c.due).toBe(false)
    }
  })

  it('arrondit à l’unité : le FCFA n’a pas de subdivision', () => {
    const c = calculerCommission({
      parrainage: parrainage(),
      parrain: PARRAIN,
      filleul: FILLEUL,
      // 25 % de 501 = 125,25
      amountFcfa: 501,
      now: JANVIER,
    })
    expect(c.due).toBe(true)
    if (c.due) expect(Number.isInteger(c.amountFcfa)).toBe(true)
    if (c.due) expect(c.amountFcfa).toBe(125)
  })

  it('gère le 29 février sans déborder', () => {
    // 12 mois après le 29/02/2028 : 2029 n'est pas bissextile.
    const fin = finDeFenetre(new Date('2028-02-29T10:00:00Z'))
    expect(fin.getUTCFullYear()).toBe(2029)
    // Date JS reporte au 1er mars plutôt que de produire une date invalide.
    expect(Number.isNaN(fin.getTime())).toBe(false)
  })

  it('la grille de prix retenue donne des commissions entières', () => {
    // Grille « accessible » arbitrée le 08/09/2026.
    const prix = [500, 1500, 3500, 2000]
    for (const p of prix) {
      for (const parrainEtat of [PARRAIN, AMBASSADEUR]) {
        const c = calculerCommission({
          parrainage: parrainage(),
          parrain: parrainEtat,
          filleul: FILLEUL,
          amountFcfa: p,
          now: JANVIER,
        })
        if (c.due) {
          expect(c.amountFcfa).toBe(Math.round(p * c.rate))
          expect(Number.isInteger(c.amountFcfa)).toBe(true)
        }
      }
    }
  })
})

describe('solde du portefeuille', () => {
  it('est la somme du grand livre, retraits compris', () => {
    const solde = soldeDepuisGrandLivre([
      { amountFcfa: 875 },
      { amountFcfa: 875 },
      { amountFcfa: 1225 },
      { amountFcfa: -3000 }, // retrait
      { amountFcfa: 500 },
    ])
    expect(solde).toBe(475)
  })

  it('vaut zéro sur un grand livre vide', () => {
    expect(soldeDepuisGrandLivre([])).toBe(0)
  })
})

describe('demande de retrait', () => {
  it('exige le seuil de 3 000 F', () => {
    const r = verifierRetrait({ soldeFcfa: 5000, amountFcfa: 2999 })
    expect(r.autorise).toBe(false)
    if (!r.autorise) {
      expect(r.reason).toBe('sous_le_seuil')
      expect(r.seuil).toBe(SEUIL_RETRAIT_FCFA)
    }
  })

  it('accepte pile au seuil', () => {
    expect(verifierRetrait({ soldeFcfa: 3000, amountFcfa: 3000 }).autorise).toBe(
      true,
    )
  })

  it('distingue le seuil non atteint du solde insuffisant', () => {
    // Le message affiché n'est pas le même : « encore 1 200 F avant de
    // pouvoir retirer » n'est pas « solde insuffisant ».
    const r = verifierRetrait({ soldeFcfa: 3200, amountFcfa: 4000 })
    expect(r.autorise).toBe(false)
    if (!r.autorise) expect(r.reason).toBe('solde_insuffisant')
  })

  it('refuse un montant non entier ou négatif', () => {
    for (const m of [0, -3000, 3000.5]) {
      const r = verifierRetrait({ soldeFcfa: 10000, amountFcfa: m })
      expect(r.autorise).toBe(false)
      if (!r.autorise) expect(r.reason).toBe('montant_invalide')
    }
  })
})
