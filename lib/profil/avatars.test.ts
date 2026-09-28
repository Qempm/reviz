import { describe, expect, it } from 'vitest'
import { CLES_AVATAR, estCleAvatar } from './avatars'

/**
 * Tests de la liste blanche des avatars.
 *
 * `avatar_key` est une colonne `text` libre, et la route acceptait
 * **n'importe quelle chaîne de cent caractères**. C'est cette liste qui
 * garantit désormais que ce qu'un écran lit est bien un avatar.
 *
 * Les douze clés sont écrites en dur ici comme elles le sont dans
 * `apps/mobile/test/avatars_test.dart`. Deux listes dans deux langages ne
 * peuvent pas se valider l'une l'autre ; les épingler chacune sur le même
 * ensemble littéral est ce qui s'en approche le plus — un ajout d'un seul
 * côté casse ce test-là ou l'autre.
 */

const ATTENDUES = [
  'ton-01',
  'ton-02',
  'ton-03',
  'ton-04',
  'ton-05',
  'ton-06',
  'ton-07',
  'ton-08',
  'ton-09',
  'ton-10',
  'ton-11',
  'ton-12',
]

describe('liste blanche des avatars', () => {
  it('compte douze clés, celles que l’application connaît', () => {
    expect([...CLES_AVATAR]).toEqual(ATTENDUES)
  })

  it('n’a aucun doublon', () => {
    expect(new Set(CLES_AVATAR).size).toBe(CLES_AVATAR.length)
  })

  it('accepte une clé de la liste', () => {
    expect(estCleAvatar('ton-07')).toBe(true)
  })

  it('refuse ce qui n’en fait pas partie', () => {
    // Les clés descriptives de l'ancien écran web, qu'un compte existant peut
    // encore porter. L'application retombe sur l'avatar par défaut ; la route
    // refuse de les écrire à nouveau.
    expect(estCleAvatar('avatar-1-garcon-sourire')).toBe(false)
    expect(estCleAvatar('ton-13')).toBe(false)
    expect(estCleAvatar('')).toBe(false)
  })

  it('refuse ce qui n’est pas une chaîne', () => {
    // La route lit du JSON : un client peut envoyer ce qu'il veut.
    expect(estCleAvatar(null)).toBe(false)
    expect(estCleAvatar(7)).toBe(false)
    expect(estCleAvatar(['ton-01'])).toBe(false)
    expect(estCleAvatar({ cle: 'ton-01' })).toBe(false)
  })
})
