import { describe, expect, it } from 'vitest'
import { extraireCode } from './otp'

describe('extraction du code collé', () => {
  it('prend six chiffres nus', () => {
    expect(extraireCode('123456')).toBe('123456')
  })

  it('trouve le code au milieu d’une phrase du mail', () => {
    // Ce que l'étudiant sélectionne vraiment dans son application de mail.
    expect(extraireCode('Ton code Reviz : 123456')).toBe('123456')
    expect(extraireCode('Ton code Reviz : 123456\nIl expire dans une heure.')).toBe('123456')
    expect(extraireCode('  123456  ')).toBe('123456')
  })

  it('ignore les autres nombres autour du code', () => {
    expect(extraireCode('Code 654321 valable jusqu’à 18h')).toBe('654321')
  })

  it('recolle les chiffres quand ils sont espacés ou séparés', () => {
    expect(extraireCode('1 2 3 4 5 6')).toBe('123456')
    expect(extraireCode('123-456')).toBe('123456')
  })

  it('tronque au-delà de la longueur demandée', () => {
    expect(extraireCode('12345678901234')).toBe('123456')
  })

  it('rend une chaîne vide quand il n’y a rien à prendre', () => {
    expect(extraireCode('aucun chiffre ici')).toBe('')
    expect(extraireCode('')).toBe('')
  })

  it('accepte un code partiel en cours de frappe', () => {
    expect(extraireCode('123')).toBe('123')
  })

  it('respecte une longueur différente', () => {
    expect(extraireCode('Code : 1234', 4)).toBe('1234')
  })
})
