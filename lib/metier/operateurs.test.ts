import { describe, expect, it } from 'vitest'
import { MODE_TEST, modeFedaPay, operateursDuPays } from './operateurs'

describe('operateursDuPays', () => {
  it('propose les trois réseaux du Bénin', () => {
    expect(operateursDuPays('BJ')).toEqual(['mtn', 'moov', 'celtiis'])
  })

  it('ne propose que ce qui se paie sans quitter l’application', () => {
    // Orange et Moov Côte d'Ivoire, Wave : page hébergée seulement.
    expect(operateursDuPays('CI')).toEqual(['mtn'])
    expect(operateursDuPays('SN')).toEqual(['free'])
    expect(operateursDuPays('TG')).toEqual(['moov', 'togocel'])
  })

  it('ne propose rien au Burkina, plutôt qu’un bouton qui ferait sortir', () => {
    expect(operateursDuPays('BF')).toEqual([])
    expect(operateursDuPays('XX')).toEqual([])
  })

  it('ignore la casse du code pays', () => {
    expect(operateursDuPays('bj')).toEqual(operateursDuPays('BJ'))
  })
})

describe('modeFedaPay', () => {
  it('rend le mode FedaPay de chaque réseau', () => {
    expect(modeFedaPay('mtn', 'BJ', false)).toBe('mtn_open')
    expect(modeFedaPay('moov', 'BJ', false)).toBe('moov')
    expect(modeFedaPay('celtiis', 'BJ', false)).toBe('sbin')
    expect(modeFedaPay('moov', 'TG', false)).toBe('moov_tg')
    expect(modeFedaPay('togocel', 'TG', false)).toBe('togocel')
    expect(modeFedaPay('mtn', 'CI', false)).toBe('mtn_ci')
    expect(modeFedaPay('free', 'SN', false)).toBe('free_sn')
  })

  it('refuse un réseau absent du pays', () => {
    expect(modeFedaPay('celtiis', 'TG', false)).toBeNull()
    expect(modeFedaPay('moov', 'CI', false)).toBeNull()
    expect(modeFedaPay('wave', 'SN', false)).toBeNull()
  })

  it('passe par le mode de test, sans rien accepter de plus', () => {
    expect(modeFedaPay('mtn', 'BJ', true)).toBe(MODE_TEST)
    // Un essai doit refuser ce que la production refuserait.
    expect(modeFedaPay('celtiis', 'TG', true)).toBeNull()
  })
})
