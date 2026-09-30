import { describe, expect, it } from 'vitest'
import {
  codeDepuisNom,
  nettoyerNom,
  nomValide,
  normaliserNom,
  trouverParNom,
} from './referentiel'

describe('normaliserNom', () => {
  it('voit la même filière derrière toutes les façons de l’écrire', () => {
    const variantes = ['FSEG', 'fseg', 'F.S.E.G', 'F S E G', ' F-S-E-G ', 'F.S.E.G.']
    for (const v of variantes) expect(normaliserNom(v), v).toBe('fseg')
  })

  it('ignore accents, casse et ponctuation', () => {
    expect(normaliserNom('Université d’Abomey-Calavi')).toBe(
      normaliserNom('universite d abomey calavi'),
    )
    expect(normaliserNom('Économie  Politique')).toBe('economie politique')
  })

  it('ne confond pas deux noms différents', () => {
    expect(normaliserNom('Droit public')).not.toBe(normaliserNom('Droit privé'))
    expect(normaliserNom('FSEG')).not.toBe(normaliserNom('FSS'))
  })
})

describe('nomValide', () => {
  it('accepte un nom réel', () => {
    expect(nomValide('FSEG')).toBe(true)
    expect(nomValide('Faculté de médecine')).toBe(true)
  })

  it('refuse le vide, le trop long et ce qui n’a pas de lettres', () => {
    expect(nomValide(' ')).toBe(false)
    expect(nomValide('a')).toBe(false)
    expect(nomValide('12345')).toBe(false)
    expect(nomValide('...')).toBe(false)
    expect(nomValide('x'.repeat(81))).toBe(false)
  })
})

describe('codeDepuisNom', () => {
  it('garde un sigle, fait les initiales d’un nom', () => {
    expect(codeDepuisNom('fseg')).toBe('FSEG')
    expect(codeDepuisNom('Université d’Abomey-Calavi')).toBe('UAC')
    expect(codeDepuisNom('Faculté des sciences de la santé')).toBe('FSS')
  })
})

describe('trouverParNom', () => {
  it('retrouve l’existant malgré l’écriture', () => {
    const lignes = [
      { id: '1', name: 'FSEG' },
      { id: '2', name: 'Faculté de droit' },
    ]
    expect(trouverParNom(lignes, 'f.s.e.g')?.id).toBe('1')
    expect(trouverParNom(lignes, 'FACULTE DE DROIT')?.id).toBe('2')
    expect(trouverParNom(lignes, 'Faculté de médecine')).toBeNull()
  })

  it('nettoie les espaces du nom rangé', () => {
    expect(nettoyerNom('  Droit   public ')).toBe('Droit public')
  })
})
