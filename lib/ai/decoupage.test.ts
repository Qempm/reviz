import { describe, expect, it } from 'vitest'
import {
  decouperEnChapitres,
  estimerJetons,
  MAX_CARACTERES,
  MAX_CHAPITRES,
  MIN_CORPS,
  normaliser,
} from './decoupage'

/**
 * Tests du découpage en chapitres.
 *
 * C'est la pièce de l'ingestion qui décide de tout le reste : un chapitre trop
 * long fait tronquer le JSON du modèle, un chapitre trop court produit des
 * questions creuses, et un découpage qui ignore les titres du document mélange
 * deux sujets dans la même session de QCM.
 */

const POLYCOPIE = `
DROIT CONSTITUTIONNEL — LICENCE 1

CHAPITRE I — LA NOTION DE CONSTITUTION

La Constitution est la norme fondamentale de l'État. Elle organise les
pouvoirs publics et garantit les droits des citoyens.

Au Bénin, la Constitution du 11 décembre 1990 a été adoptée par référendum
le 2 décembre 1990, à l'issue de la Conférence des Forces Vives de la Nation.

CHAPITRE II — LE CONTRÔLE DE CONSTITUTIONNALITÉ

La Cour constitutionnelle est la plus haute juridiction de l'État en matière
constitutionnelle. Elle statue sur la constitutionnalité des lois.

Elle est composée de sept membres, dont quatre désignés par le Bureau de
l'Assemblée nationale et trois par le Président de la République.
`.trim()

describe('normalisation', () => {
  it('ramène les retours chariot et les espaces insécables', () => {
    const brut = 'Ligne un\r\nLigne deux\r\n\r\n\r\n\r\nLigne trois'
    const propre = normaliser(brut)
    expect(propre).not.toContain('\r')
    expect(propre).not.toContain(' ')
    // Trois retours ou plus ne disent rien de plus que deux.
    expect(propre).not.toMatch(/\n{3}/)
  })

  it('répare les ligatures des PDF', () => {
    // « ﬁn » et « ﬂeur » sortent des extracteurs de PDF et rendent un QCM
    // illisible.
    expect(normaliser('la ﬁn de la ﬂeur')).toBe('la fin de la fleur')
  })
})

describe('découpage sur les titres du document', () => {
  const chapitres = decouperEnChapitres(POLYCOPIE, 'Droit constitutionnel')

  it('trouve les deux chapitres', () => {
    expect(chapitres).toHaveLength(2)
  })

  it('numérote à partir de un, comme la colonne SQL', () => {
    expect(chapitres.map((c) => c.index)).toEqual([1, 2])
  })

  it('reprend les titres du document, sans les crier', () => {
    // « CHAPITRE I — LA NOTION DE CONSTITUTION » en capitales intégrales se
    // lit mal dans une liste.
    expect(chapitres[0].title).toBe('Chapitre I — La Notion De Constitution')
    expect(chapitres[1].title).toContain('Contrôle')
  })

  it('met chaque sujet dans son chapitre, et pas dans l’autre', () => {
    // C'est le point du découpage par titres : une session de QCM sur le
    // chapitre 2 ne doit pas poser de questions sur le chapitre 1.
    expect(chapitres[0].text).toContain('11 décembre 1990')
    expect(chapitres[0].text).not.toContain('sept membres')
    expect(chapitres[1].text).toContain('sept membres')
    expect(chapitres[1].text).not.toContain('11 décembre 1990')
  })

  it('garde le titre dans le corps, pour que le modèle le voie', () => {
    expect(chapitres[0].text).toContain('CHAPITRE I')
  })

  it('estime les jetons', () => {
    expect(chapitres[0].tokenCount).toBeGreaterThan(0)
    expect(chapitres[0].tokenCount).toBe(estimerJetons(chapitres[0].text))
  })

  it('reconnaît aussi les numérotations nues', () => {
    const texte = [
      'I. Les sources du droit',
      'La loi votée par l’Assemblée nationale, la coutume telle que les',
      'juridictions la constatent, et la jurisprudence de la Cour suprême.',
      '',
      '2) Les sources internationales',
      'Les traités régulièrement ratifiés ont, dès leur publication, une',
      'autorité supérieure à celle des lois, sous réserve de réciprocité.',
    ].join('\n')

    const c = decouperEnChapitres(texte, 'Sources')
    expect(c).toHaveLength(2)
    expect(c[0].title).toBe('I. Les sources du droit')
    expect(c[1].title).toBe('2) Les sources internationales')
  })

  it('ne prend pas une phrase qui commence par un chiffre pour un titre', () => {
    const texte =
      '2 décembre 1990, le référendum constitutionnel est organisé au Bénin, ' +
      'et la Constitution est promulguée le 11 décembre de la même année par ' +
      'le Président de la République nouvellement élu.'

    const c = decouperEnChapitres(texte, 'Histoire')
    expect(c).toHaveLength(1)
    // Le titre vient du cours, pas de la phrase.
    expect(c[0].title).toBe('Histoire')
  })

  it('ne prend pas une ligne qui continue pour un titre', () => {
    // Une ligne qui finit par un deux-points annonce une suite.
    const texte = ['1) Les trois pouvoirs sont :', "l'exécutif, le législatif et le judiciaire."].join('\n')
    const c = decouperEnChapitres(texte, 'Pouvoirs')
    expect(c).toHaveLength(1)
  })
})

describe('découpage par la longueur, à défaut de titres', () => {
  /** Un pavé sans structure, en paragraphes. */
  const pave = (paragraphes: number) =>
    Array.from(
      { length: paragraphes },
      (_, i) =>
        `Paragraphe ${i + 1}. ` +
        'La souveraineté nationale appartient au peuple qui l’exerce par ses ' +
        'représentants élus et par la voie du référendum. '.repeat(6),
    ).join('\n\n')

  it('coupe un document long en plusieurs chapitres', () => {
    const chapitres = decouperEnChapitres(pave(40), 'Droit public')
    expect(chapitres.length).toBeGreaterThan(1)
  })

  it('ne dépasse jamais le plafond de caractères', () => {
    // Au-delà, le JSON de sortie du modèle se fait tronquer.
    for (const c of decouperEnChapitres(pave(60), 'Droit public')) {
      expect(c.text.length).toBeLessThanOrEqual(MAX_CARACTERES)
    }
  })

  it('coupe sur une frontière de paragraphe, pas au milieu d’une phrase', () => {
    for (const c of decouperEnChapitres(pave(40), 'Droit public')) {
      // Un chapitre se termine sur une ponctuation forte, ou sur la fin du
      // document.
      expect(c.text.trim()).toMatch(/[.!?»]$/)
    }
  })

  it('nomme les parties avec le titre du cours', () => {
    const chapitres = decouperEnChapitres(pave(40), 'Droit public')
    expect(chapitres[0].title).toBe('Droit public — partie 1')
    expect(chapitres[1].title).toBe('Droit public — partie 2')
  })

  it('ne suffixe pas quand il n’y a qu’une partie', () => {
    const c = decouperEnChapitres('Un cours très court mais suffisant.', 'Logique')
    expect(c).toHaveLength(1)
    expect(c[0].title).toBe('Logique')
  })

  it('s’arrête au plafond de chapitres', () => {
    // Le plafond SQL est de 200 questions par cours ; au-delà de cinquante
    // chapitres, le document est un recueil, pas un cours.
    const enorme = Array.from(
      { length: 200 },
      (_, i) =>
        `CHAPITRE ${i + 1}\n\n` +
        'La souveraineté nationale appartient au peuple qui l’exerce par ses ' +
        'représentants élus et par la voie du référendum, selon les formes et ' +
        'conditions que la Constitution détermine elle-même.',
    ).join('\n\n')

    expect(decouperEnChapitres(enorme, 'Recueil').length).toBe(MAX_CHAPITRES)
  })
})

describe('les miettes', () => {
  it('recolle un bloc trop court au précédent', () => {
    const texte = [
      'CHAPITRE I',
      '',
      'Un contenu de chapitre parfaitement suffisant pour porter des questions, ' +
        'avec assez de matière pour que le modèle ait de quoi travailler dessus ' +
        'sans inventer.',
      '',
      'CHAPITRE II',
      '',
      'Trop court.',
    ].join('\n')

    const c = decouperEnChapitres(texte, 'Cours')
    // Le second bloc n'a pas de quoi porter une question : il appartient au
    // chapitre d'à côté plutôt qu'à un chapitre fantôme.
    expect(c).toHaveLength(1)
    expect(c[0].text).toContain('Trop court.')
  })

  it('ne recolle pas si cela dépasserait le plafond', () => {
    const long = 'Une phrase de contenu. '.repeat(Math.ceil(MAX_CARACTERES / 23))
    const texte = `CHAPITRE I\n\n${long}\n\nCHAPITRE II\n\nCourt.`
    for (const c of decouperEnChapitres(texte, 'Cours')) {
      expect(c.text.length).toBeLessThanOrEqual(MAX_CARACTERES)
    }
  })
})

describe('les cas qui ne doivent rien casser', () => {
  it('rend une liste vide sur un document vide', () => {
    // Un PDF scanné sans couche de texte : l'appelant doit pouvoir le
    // constater et le dire à l'étudiant, pas recevoir un chapitre vide.
    expect(decouperEnChapitres('', 'Cours')).toEqual([])
    expect(decouperEnChapitres('   \n\n  \n ', 'Cours')).toEqual([])
  })

  it('tient un document qui n’est qu’un titre', () => {
    const c = decouperEnChapitres('CHAPITRE I — INTRODUCTION', 'Cours')
    expect(c).toHaveLength(1)
    expect(c[0].text.length).toBeGreaterThan(0)
  })

  it('tronque un titre démesuré', () => {
    const titre = `1) ${'a'.repeat(300)}`
    const c = decouperEnChapitres(`${titre}\n\nDu contenu.`, 'Cours')
    expect(c[0].title.length).toBeLessThanOrEqual(200)
  })

  it('ne rend jamais de chapitre vide', () => {
    const texte = 'CHAPITRE I\n\n\n\nCHAPITRE II\n\n\n\nCHAPITRE III'
    for (const c of decouperEnChapitres(texte, 'Cours')) {
      expect(c.text.trim().length).toBeGreaterThan(0)
    }
  })

  it('accepte un texte sous le minimum plutôt que de le jeter', () => {
    // Un cours d'une page reste un cours.
    const court = 'Le droit est l’ensemble des règles qui régissent la société.'
    expect(court.length).toBeLessThan(MIN_CORPS)
    expect(decouperEnChapitres(court, 'Introduction')).toHaveLength(1)
  })
})
