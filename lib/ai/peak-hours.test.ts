import { describe, expect, it } from 'vitest'
import {
  canStartJob,
  isDeepSeekPeakHour,
  nextAllowedStart,
  estPhoto,
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
  const photo = { vision: true }

  it('bloque la lecture d’une photo en heure pleine', () => {
    const now = mercredi(7)
    expect(
      canStartJob({ type: 'ingest_course', createdAt: now, payload: photo, now }),
    ).toBe(false)
  })

  it('laisse lire un PDF ou un Word à toute heure', () => {
    // Aucun modèle n'est appelé pour les lire : les retenir n'économisait
    // rien et faisait attendre l'étudiant.
    const now = mercredi(7)
    expect(
      canStartJob({ type: 'ingest_course', createdAt: now, payload: { vision: false }, now }),
    ).toBe(true)
    // Un job d'avant le marquage, sans le champ : traité comme un document.
    expect(canStartJob({ type: 'ingest_course', createdAt: now, now })).toBe(true)
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
      canStartJob({ type: 'ingest_course', createdAt: vingtMinutes, payload: photo, now }),
    ).toBe(false)
    expect(
      canStartJob({ type: 'ingest_course', createdAt: unPeuPlus, payload: photo, now }),
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

describe('estPhoto', () => {
  it('reconnaît une photo à son extension', () => {
    expect(estPhoto('u1/c1/cours.jpg')).toBe(true)
    expect(estPhoto('u1/c1/cours.JPEG')).toBe(true)
    expect(estPhoto('u1/c1/cours.png')).toBe(true)
    expect(estPhoto('u1/c1/cours.heic')).toBe(true)
  })

  it('laisse les documents et les chemins absents', () => {
    expect(estPhoto('u1/c1/cours.pdf')).toBe(false)
    expect(estPhoto('u1/c1/cours.docx')).toBe(false)
    expect(estPhoto(null)).toBe(false)
    expect(estPhoto(undefined)).toBe(false)
  })
})
