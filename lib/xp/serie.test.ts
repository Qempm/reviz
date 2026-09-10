import { describe, expect, it } from 'vitest'
import {
  etatSerie,
  jourUtc,
  progressionDuJour,
  resteAvantObjectif,
  veille,
} from './serie'

/** Mercredi 10 septembre 2026, 14 h UTC. */
const MAINTENANT = new Date('2026-09-10T14:00:00Z')

describe('jourUtc et veille', () => {
  it('donne le jour en UTC', () => {
    expect(jourUtc(MAINTENANT)).toBe('2026-09-10')
  })

  it('reste en UTC juste après minuit à Cotonou', () => {
    // 00 h 30 au Bénin (UTC+1) est 23 h 30 la veille en UTC. La base compte
    // ainsi, l'affichage doit compter pareil.
    expect(jourUtc(new Date('2026-09-10T23:30:00Z'))).toBe('2026-09-10')
    expect(jourUtc(new Date('2026-09-11T00:30:00Z'))).toBe('2026-09-11')
  })

  it('recule d’un jour, y compris en changeant de mois', () => {
    expect(veille('2026-09-10')).toBe('2026-09-09')
    expect(veille('2026-09-01')).toBe('2026-08-31')
    expect(veille('2026-01-01')).toBe('2025-12-31')
  })

  it('recule correctement au 1er mars d’une année bissextile', () => {
    expect(veille('2028-03-01')).toBe('2028-02-29')
  })
})

describe('etatSerie', () => {
  it('affiche zéro quand rien n’a jamais été validé', () => {
    expect(
      etatSerie({ current: 0, lastValidatedOn: null, now: MAINTENANT }),
    ).toEqual({ jours: 0, rompue: true, valideAujourdhui: false, enJeu: false })
  })

  it('rompt la série quand le dernier jour validé est trop ancien', () => {
    // C'est le cas que personne ne traitait : la base garde 5, l'écran
    // affichait 5, alors que la série est morte depuis une semaine.
    const etat = etatSerie({
      current: 5,
      lastValidatedOn: '2026-09-03',
      now: MAINTENANT,
    })

    expect(etat.rompue).toBe(true)
    expect(etat.jours).toBe(0)
  })

  it('garde la série quand aujourd’hui est validé', () => {
    expect(
      etatSerie({
        current: 6,
        lastValidatedOn: '2026-09-10',
        now: MAINTENANT,
      }),
    ).toEqual({ jours: 6, rompue: false, valideAujourdhui: true, enJeu: false })
  })

  it('met la série en jeu quand seule la veille est validée', () => {
    expect(
      etatSerie({
        current: 3,
        lastValidatedOn: '2026-09-09',
        now: MAINTENANT,
      }),
    ).toEqual({ jours: 3, rompue: false, valideAujourdhui: false, enJeu: true })
  })

  it('accepte un horodatage complet et n’en garde que la date', () => {
    // Postgres renvoie une date nue, mais un `timestamptz` mal typé
    // arriverait avec son heure : on ne veut pas que la comparaison échoue
    // pour un « T00:00:00+00:00 » de trop.
    const etat = etatSerie({
      current: 2,
      lastValidatedOn: '2026-09-10T00:00:00+00:00',
      now: MAINTENANT,
    })

    expect(etat.valideAujourdhui).toBe(true)
  })

  it('ne fait pas confiance à un compteur négatif', () => {
    const etat = etatSerie({
      current: -4,
      lastValidatedOn: '2026-09-10',
      now: MAINTENANT,
    })

    expect(etat.jours).toBe(0)
  })

  it('tient au passage d’un mois', () => {
    const etat = etatSerie({
      current: 9,
      lastValidatedOn: '2026-08-31',
      now: new Date('2026-09-01T08:00:00Z'),
    })

    expect(etat).toEqual({
      jours: 9,
      rompue: false,
      valideAujourdhui: false,
      enJeu: true,
    })
  })
})

describe('progressionDuJour', () => {
  it('rend une fraction', () => {
    expect(progressionDuJour(3, 10)).toBeCloseTo(0.3)
  })

  it('borne à 1 : trente questions ne remplissent pas la barre trois fois', () => {
    expect(progressionDuJour(30, 10)).toBe(1)
  })

  it('ne descend pas sous zéro', () => {
    expect(progressionDuJour(-5, 10)).toBe(0)
  })

  it('ne divise pas par zéro si l’objectif est retiré', () => {
    expect(progressionDuJour(0, 0)).toBe(1)
  })
})

describe('resteAvantObjectif', () => {
  it('compte les questions manquantes', () => {
    expect(resteAvantObjectif(4, 10)).toBe(6)
  })

  it('vaut zéro une fois l’objectif dépassé', () => {
    expect(resteAvantObjectif(12, 10)).toBe(0)
  })
})
