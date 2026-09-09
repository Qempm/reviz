import { describe, expect, it } from 'vitest'
import {
  backoffMinutes,
  estLourd,
  issueApresEchec,
  MAX_ATTEMPTS,
  messageErreur,
  prochaineTentative,
} from './policy'

const T0 = new Date('2026-09-09T12:00:00Z')

describe('délais de reprise', () => {
  it('croît puis plafonne', () => {
    expect(backoffMinutes(1)).toBe(1)
    expect(backoffMinutes(2)).toBe(5)
    expect(backoffMinutes(3)).toBe(15)
    expect(backoffMinutes(4)).toBe(60)
    // Au-delà de la table, on reste au dernier palier.
    expect(backoffMinutes(5)).toBe(60)
    expect(backoffMinutes(99)).toBe(60)
  })

  it('supporte un compteur nul ou négatif', () => {
    expect(backoffMinutes(0)).toBe(1)
    expect(backoffMinutes(-3)).toBe(1)
  })

  it('donne une date, pas une durée', () => {
    expect(prochaineTentative(2, T0).toISOString()).toBe('2026-09-09T12:05:00.000Z')
  })
})

describe('issue après échec', () => {
  it('remet en file tant qu’il reste des tentatives', () => {
    const i = issueApresEchec({ attempts: 2, error: new Error('boum'), now: T0 })
    expect(i.status).toBe('queued')
    if (i.status === 'queued') {
      expect(i.runAfter.toISOString()).toBe('2026-09-09T12:05:00.000Z')
      expect(i.lastError).toContain('boum')
    }
  })

  it('abandonne à la dernière tentative', () => {
    expect(
      issueApresEchec({ attempts: MAX_ATTEMPTS, error: new Error('x'), now: T0 })
        .status,
    ).toBe('failed')
    expect(
      issueApresEchec({ attempts: MAX_ATTEMPTS - 1, error: new Error('x'), now: T0 })
        .status,
    ).toBe('queued')
  })

  it('abandonne immédiatement si l’erreur est permanente', () => {
    const i = issueApresEchec({
      attempts: 1,
      error: new Error('type inconnu'),
      permanent: true,
      now: T0,
    })
    expect(i.status).toBe('failed')
  })
})

describe('message d’erreur', () => {
  it('reprend nom et message', () => {
    expect(messageErreur(new TypeError('mauvais type'))).toBe(
      'TypeError: mauvais type',
    )
  })

  it('accepte une chaîne ou un objet', () => {
    expect(messageErreur('panne sèche')).toBe('panne sèche')
    expect(messageErreur({ code: 42 })).toBe('{"code":42}')
  })

  it('tronque pour ne pas gonfler last_error', () => {
    const m = messageErreur(new Error('x'.repeat(5000)))
    expect(m.length).toBeLessThanOrEqual(1000)
    expect(m.endsWith('…')).toBe(true)
  })
})

describe('traitements lourds', () => {
  it('ne concerne que ingest_course (règle métier 6)', () => {
    expect(estLourd('ingest_course')).toBe(true)
    for (const t of ['generate_questions', 'correct_copy', 'verify_card', 'notify'] as const) {
      expect(estLourd(t)).toBe(false)
    }
  })
})
