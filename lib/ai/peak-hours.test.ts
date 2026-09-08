import { describe, expect, it } from 'vitest'
import {
  canStartJob,
  isDeepSeekPeakHour,
  nextAllowedStart,
} from './peak-hours'

/** Mercredi 2026-09-09 à l'heure UTC demandée. */
const mercredi = (h: number, m = 0) =>
  new Date(Date.UTC(2026, 8, 9, h, m, 0))

/** Samedi 2026-09-12. */
const samedi = (h: number) => new Date(Date.UTC(2026, 8, 12, h, 0, 0))

describe('heures pleines DeepSeek', () => {
  it('couvre 01:00–04:00 et 06:00–10:00 UTC en semaine', () => {
    expect(isDeepSeekPeakHour(mercredi(0, 59))).toBe(false)
    expect(isDeepSeekPeakHour(mercredi(1, 0))).toBe(true)
    expect(isDeepSeekPeakHour(mercredi(3, 59))).toBe(true)
    // Borne haute exclue : à 04:00 le créneau est terminé.
    expect(isDeepSeekPeakHour(mercredi(4, 0))).toBe(false)
    expect(isDeepSeekPeakHour(mercredi(5, 30))).toBe(false)
    expect(isDeepSeekPeakHour(mercredi(6, 0))).toBe(true)
    expect(isDeepSeekPeakHour(mercredi(9, 59))).toBe(true)
    expect(isDeepSeekPeakHour(mercredi(10, 0))).toBe(false)
    expect(isDeepSeekPeakHour(mercredi(20, 0))).toBe(false)
  })

  it('ne s’applique pas le week-end', () => {
    expect(isDeepSeekPeakHour(samedi(2))).toBe(false)
    expect(isDeepSeekPeakHour(samedi(8))).toBe(false)
  })
})

describe('démarrage des jobs', () => {
  it('bloque un ingest_course en heure pleine', () => {
    const now = mercredi(7)
    expect(
      canStartJob({ type: 'ingest_course', createdAt: now, now }),
    ).toBe(false)
  })

  it('laisse passer les autres types en permanence', () => {
    const now = mercredi(7)
    for (const type of ['generate_questions', 'correct_copy', 'notify']) {
      expect(canStartJob({ type, createdAt: now, now })).toBe(true)
    }
  })

  it('passe outre au-delà de 20 minutes d’attente', () => {
    const now = mercredi(7)
    const vingtMinutes = new Date(now.getTime() - 20 * 60 * 1000)
    const unPeuPlus = new Date(now.getTime() - 20 * 60 * 1000 - 1)

    // Exactement 20 minutes : la dérogation n'est pas encore acquise.
    expect(
      canStartJob({ type: 'ingest_course', createdAt: vingtMinutes, now }),
    ).toBe(false)
    expect(
      canStartJob({ type: 'ingest_course', createdAt: unPeuPlus, now }),
    ).toBe(true)
  })

  it('donne la sortie du créneau en cours', () => {
    expect(nextAllowedStart(mercredi(2, 30)).toISOString()).toBe(
      '2026-09-09T04:00:00.000Z',
    )
    expect(nextAllowedStart(mercredi(9, 59)).toISOString()).toBe(
      '2026-09-09T10:00:00.000Z',
    )
    // Hors créneau : maintenant.
    expect(nextAllowedStart(mercredi(12)).toISOString()).toBe(
      '2026-09-09T12:00:00.000Z',
    )
  })
})
