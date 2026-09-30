import { describe, expect, it } from 'vitest'
import { consigneCorrection, extraitsDuCours, normaliserNote } from './consignes'

const chapitres = [
  { index: 2, titre: 'Le contrôle de constitutionnalité', texte: 'Le Conseil constitutionnel '.repeat(200) },
  { index: 1, titre: 'La notion de Constitution', texte: 'Une Constitution est la norme suprême.' },
]

describe('consigneCorrection', () => {
  it('situe la copie : matière, niveau, filière, épreuve, barème', () => {
    const c = consigneCorrection({
      matiere: 'Droit constitutionnel',
      annee: 1,
      filiere: 'FADESP',
      universite: 'UAC',
      typeEpreuve: 'partiel',
      bareme: 40,
    })
    expect(c).toContain('Matière : Droit constitutionnel.')
    expect(c).toContain('L1')
    expect(c).toContain('FADESP')
    expect(c).toContain('un partiel')
    expect(c).toContain('note sur 40')
    expect(c).toContain('"maxGrade": 40')
  })

  it('juge par rapport au cours quand il y en a un', () => {
    const c = consigneCorrection({ chapitres })
    expect(c).toContain('Juge la copie')
    expect(c).toContain('ne sanctionne pas')
    expect(c).toContain('[Chapitre 1] La notion de Constitution')
  })

  it('sans cours, pas de paragraphe de cours', () => {
    const c = consigneCorrection({})
    expect(c).not.toContain('Juge la copie')
    expect(c).toContain('note sur 20')
  })

  it('rappelle les points faibles et les corrections passées', () => {
    const c = consigneCorrection({
      chapitresFaibles: ['Le contrôle de constitutionnalité'],
      precedentes: [{ note: 9, sur: 20, aRetravailler: ['citer les articles'] }],
    })
    expect(c).toContain('se trompe souvent sur : Le contrôle de constitutionnalité')
    expect(c).toContain('9/20, à retravailler : citer les articles')
  })

  it('un master se dit master', () => {
    expect(consigneCorrection({ annee: 4 })).toContain('M1')
  })
})

describe('extraitsDuCours', () => {
  it('tient dans le budget, dans l’ordre des chapitres', () => {
    const e = extraitsDuCours(chapitres, 1000)
    expect(e.length).toBeLessThan(1200)
    expect(e.indexOf('[Chapitre 1]')).toBeLessThan(e.indexOf('[Chapitre 2]'))
    expect(e).toContain('…')
  })

  it('rien sans chapitre', () => {
    expect(extraitsDuCours([])).toBe('')
  })
})

describe('normaliserNote', () => {
  const rubric = [
    { criterion: 'A', points: 4, maxPoints: 5 },
    { criterion: 'B', points: 6, maxPoints: 15 },
  ]

  it('la note devient la somme du détail', () => {
    const n = normaliserNote({ grade: 14, maxGrade: 20, rubric })
    expect(n.grade).toBe(10)
    expect(n.maxGrade).toBe(20)
  })

  it('ramène une copie notée sur 20 au barème demandé', () => {
    const n = normaliserNote({ grade: 10, maxGrade: 20, rubric }, 40)
    expect(n.maxGrade).toBe(40)
    expect(n.rubric.map((l) => l.maxPoints)).toEqual([10, 30])
    expect(n.grade).toBe(20)
  })

  it('arrondit au quart et ne dépasse jamais le barème', () => {
    const n = normaliserNote(
      { grade: 30, maxGrade: 20, rubric: [{ criterion: 'A', points: 7.1, maxPoints: 7 }] },
      20,
    )
    expect(n.grade).toBeLessThanOrEqual(20)
    expect(n.rubric[0].points).toBeLessThanOrEqual(n.rubric[0].maxPoints)
    expect((n.grade * 4) % 1).toBe(0)
  })
})
