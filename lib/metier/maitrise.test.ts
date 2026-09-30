import { describe, expect, it } from 'vitest'
import { cheminDuCours, maitriseChapitre, type Maitrise, type Tentative } from './maitrise'

// Mêmes cas que apps/mobile/test/maitrise_test.dart.
const huit = Array.from({ length: 8 }, (_, i) => `q${i + 1}`)
const t = (questionId: string, juste: boolean, j: number, heure = 10): Tentative => ({
  questionId,
  juste,
  le: new Date(Date.UTC(2026, 8, j, heure)),
})
const m = (ts: Tentative[]) => maitriseChapitre(huit, ts)

describe('maitriseChapitre', () => {
  it('rien de tenté : à découvrir', () => {
    expect(m([])).toMatchObject({ etat: 'a_decouvrir', couronnes: 0 })
  })

  it('une seule bonne réponse ne fait pas un chapitre maîtrisé', () => {
    expect(m([t('q1', true, 1)])).toMatchObject({ etat: 'a_decouvrir', couronnes: 0, justes: 1 })
  })

  it('la moitié tentée et presque tout faux : à revoir', () => {
    const r = m([t('q1', false, 1), t('q2', false, 1), t('q3', false, 1), t('q4', true, 1)])
    expect(r.etat).toBe('a_revoir')
  })

  it('tout tenté : 1, 2 couronnes selon les justes', () => {
    expect(m(huit.map((id, i) => t(id, i < 4, 1))).couronnes).toBe(1)
    expect(m(huit.map((id, i) => t(id, i < 7, 1))).couronnes).toBe(2)
  })

  it('tout tenté, moins de la moitié juste : à revoir', () => {
    expect(m(huit.map((id, i) => t(id, i < 3, 1)))).toMatchObject({ etat: 'a_revoir', couronnes: 0 })
  })

  it('8 sur 8 le même jour : 2 couronnes, pas 3', () => {
    expect(m(huit.map((id) => t(id, true, 1))).couronnes).toBe(2)
  })

  it('8 sur 8, deux jours différents : 3 couronnes', () => {
    expect(m([...huit.map((id) => t(id, true, 1)), ...huit.map((id) => t(id, true, 3))]).couronnes).toBe(3)
  })

  it('deux fois juste le même jour ne compte que pour un jour', () => {
    expect(m([...huit.map((id) => t(id, true, 1, 9)), ...huit.map((id) => t(id, true, 1, 20))]).couronnes).toBe(2)
  })

  it('une couronne se perd si la dernière réponse devient fausse', () => {
    const avant = [...huit.map((id) => t(id, true, 1)), ...huit.map((id) => t(id, true, 3))]
    expect(m(avant).couronnes).toBe(3)
    expect(m([...avant, t('q1', false, 5), t('q2', false, 5)]).couronnes).toBe(1)
  })

  it('les réponses hors du chapitre sont ignorées', () => {
    expect(m([t('autre', true, 1)]).tentees).toBe(0)
  })

  it('un chapitre sans QCM ne se mesure pas', () => {
    expect(maitriseChapitre([], []).etat).toBe('sans_qcm')
  })
})

describe('cheminDuCours', () => {
  const c = (couronnes: 0 | 1 | 2 | 3): Maitrise => ({
    etat: couronnes > 0 ? 'couronne' : 'a_decouvrir',
    couronnes,
    total: 8,
    tentees: couronnes > 0 ? 8 : 0,
    justes: 0,
  })
  const vide: Maitrise = { etat: 'sans_qcm', couronnes: 0, total: 0, tentees: 0, justes: 0 }

  it('le premier est ouvert, la suite s’ouvre couronne après couronne', () => {
    expect(cheminDuCours([c(1), c(0), c(0)]).map((x) => x.etat)).toEqual([
      'couronne',
      'a_decouvrir',
      'verrouille',
    ])
  })

  it('un chapitre commencé reste ouvert si le précédent perd sa couronne', () => {
    const commence: Maitrise = { etat: 'a_decouvrir', couronnes: 0, total: 8, tentees: 3, justes: 3 }
    expect(cheminDuCours([c(0), commence, c(0)]).map((x) => x.etat)).toEqual([
      'a_decouvrir',
      'a_decouvrir',
      'verrouille',
    ])
  })

  it('un chapitre sans QCM ne bloque pas la suite', () => {
    expect(cheminDuCours([c(2), vide, c(0)]).map((x) => x.etat)).toEqual([
      'couronne',
      'sans_qcm',
      'a_decouvrir',
    ])
  })
})
