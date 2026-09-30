import { describe, expect, it } from 'vitest'
import {
  chapitresFaibles,
  lireDemande,
  ordonnerPages,
  rattacherChapitres,
} from './contexte-correction'

describe('ordonnerPages', () => {
  it('pages dans l’ordre, sujet à la fin, étiquetées', () => {
    const r = ordonnerPages(['u/c/sujet.jpg', 'u/c/copie-3.jpg', 'u/c/copie.jpg', 'u/c/copie-2.png'])
    expect(r.map((p) => p.etiquette)).toEqual([
      'Page 1 de la copie',
      'Page 2 de la copie',
      'Page 3 de la copie',
      'Sujet',
    ])
    expect(r[0].chemin).toBe('u/c/copie.jpg')
  })

  it('une seule page se dit « Copie »', () => {
    expect(ordonnerPages(['u/c/copie.jpg'])[0].etiquette).toBe('Copie')
  })
})

describe('lireDemande', () => {
  it('garde ce qui est valide', () => {
    expect(lireDemande({ demande: { typeEpreuve: 'partiel', bareme: 40 } })).toEqual({
      typeEpreuve: 'partiel',
      bareme: 40,
    })
  })

  it('ne croit pas un client qui écrit n’importe quoi', () => {
    expect(lireDemande({ demande: { typeEpreuve: 'triche', bareme: 5000 } })).toEqual({
      typeEpreuve: null,
      bareme: null,
    })
    expect(lireDemande(null)).toEqual({ typeEpreuve: null, bareme: null })
  })
})

describe('chapitresFaibles', () => {
  it('sur la dernière réponse, deux tentées au moins, moins de la moitié juste', () => {
    const r = chapitresFaibles([
      { questionId: 'q1', chapitre: 'A', juste: false, le: '2026-09-01' },
      { questionId: 'q2', chapitre: 'A', juste: false, le: '2026-09-01' },
      { questionId: 'q3', chapitre: 'B', juste: false, le: '2026-09-01' },
      { questionId: 'q3', chapitre: 'B', juste: true, le: '2026-09-02' },
      { questionId: 'q4', chapitre: 'B', juste: true, le: '2026-09-02' },
      { questionId: 'q5', chapitre: 'C', juste: false, le: '2026-09-02' },
    ])
    expect(r).toEqual(['A'])
  })
})

describe('rattacherChapitres', () => {
  const chapitres = [1, 2, 3, 4, 5].map((i) => ({ id: `c${i}`, index: i, titre: `T${i}` }))
  it('écarte les numéros inconnus et les doublons, trois au plus', () => {
    expect(rattacherChapitres([9, 2, 2, 4, 1, 5], chapitres).map((c) => c.id)).toEqual([
      'c2',
      'c4',
      'c1',
    ])
  })
})
