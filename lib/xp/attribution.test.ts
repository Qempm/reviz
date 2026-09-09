import { describe, expect, it } from 'vitest'
import {
  BAREME,
  BONUS_SERIE_MAX,
  bonusSerie,
  gainsDeSession,
  totalGains,
} from './attribution'

describe('bonusSerie', () => {
  it('ne récompense pas une série de un jour', () => {
    // Le premier jour n'est pas une série : c'est un jour.
    expect(bonusSerie(0)).toBe(0)
    expect(bonusSerie(1)).toBe(0)
  })

  it('donne 5 points par jour', () => {
    expect(bonusSerie(2)).toBe(10)
    expect(bonusSerie(7)).toBe(35)
  })

  it('plafonne, pour que le classement ne se fige pas', () => {
    expect(bonusSerie(10)).toBe(BONUS_SERIE_MAX)
    expect(bonusSerie(180)).toBe(BONUS_SERIE_MAX)
  })

  it('ignore une valeur absurde', () => {
    expect(bonusSerie(-3)).toBe(0)
    expect(bonusSerie(Number.NaN)).toBe(0)
  })
})

describe('gainsDeSession', () => {
  it('agrège les bonnes réponses en une seule ligne', () => {
    const gains = gainsDeSession({ bonnes: 7, total: 10, objectifAtteint: false })

    expect(gains).toEqual([
      { reason: 'correct_answer', amount: 7 * BAREME.correct_answer },
      { reason: 'quiz_completed', amount: BAREME.quiz_completed },
    ])
  })

  it('ne donne rien pour une session sans réponse', () => {
    // Ouvrir puis quitter l'écran ne doit rien rapporter.
    expect(gainsDeSession({ bonnes: 0, total: 0, objectifAtteint: false })).toEqual([])
  })

  it('récompense une session entièrement fausse pour l’avoir finie', () => {
    const gains = gainsDeSession({ bonnes: 0, total: 10, objectifAtteint: false })

    expect(gains).toEqual([
      { reason: 'quiz_completed', amount: BAREME.quiz_completed },
    ])
  })

  it('ajoute objectif du jour et bonus de série', () => {
    const gains = gainsDeSession({
      bonnes: 8,
      total: 10,
      objectifAtteint: true,
      serie: 4,
    })

    expect(gains.map((g) => g.reason)).toEqual([
      'correct_answer',
      'quiz_completed',
      'daily_goal',
      'streak_bonus',
    ])
    expect(totalGains(gains)).toBe(80 + 20 + 30 + 20)
  })

  it('n’ajoute pas de bonus de série au premier jour validé', () => {
    const gains = gainsDeSession({
      bonnes: 10,
      total: 10,
      objectifAtteint: true,
      serie: 1,
    })

    expect(gains.map((g) => g.reason)).not.toContain('streak_bonus')
  })

  it('ne compte pas de bonus quand l’objectif n’est pas atteint', () => {
    const gains = gainsDeSession({
      bonnes: 2,
      total: 3,
      objectifAtteint: false,
      serie: 30,
    })

    expect(gains.map((g) => g.reason)).not.toContain('daily_goal')
    expect(gains.map((g) => g.reason)).not.toContain('streak_bonus')
  })

  it('arrondit une entrée non entière plutôt que d’inventer des points', () => {
    const gains = gainsDeSession({ bonnes: 2.9, total: 3, objectifAtteint: false })

    expect(gains[0]).toEqual({ reason: 'correct_answer', amount: 20 })
  })
})
