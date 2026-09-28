import { describe, expect, it } from 'vitest'
import { MIN_TEXTE, texteSuffisant, voieDeLecture } from './formats'

describe('choix du chemin de lecture', () => {
  it('lit un PDF et un Word sans modèle', () => {
    // Zéro appel payant sur les deux formats les plus courants : c'est ce qui
    // fait tenir un budget de cinq dollars.
    expect(voieDeLecture('application/pdf').voie).toBe('pdf')
    expect(
      voieDeLecture(
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      ).voie,
    ).toBe('docx')
  })

  it('envoie les photos au modèle de vision', () => {
    // Le format le plus courant chez le public visé, qui photographie le
    // tableau ou le polycopié d'un camarade.
    for (const mime of ['image/jpeg', 'image/png', 'image/webp']) {
      expect(voieDeLecture(mime).voie).toBe('vision')
    }
  })

  it('refuse l’ancien format Word, en disant quoi faire', () => {
    // `preparerDepot` accepte `.doc` au dépôt : sans message clair ici, le
    // cours resterait en attente pour toujours.
    const r = voieDeLecture('application/msword')
    expect(r.voie).toBe('refuse')
    expect(r.motif).toContain('PDF')
  })

  it('refuse un format inconnu en le nommant', () => {
    const r = voieDeLecture('application/zip')
    expect(r.voie).toBe('refuse')
    expect(r.motif).toContain('application/zip')
  })

  it('tolère les paramètres et la casse du type', () => {
    // Un navigateur envoie volontiers « image/jpeg; charset=utf-8 », et
    // Android « IMAGE/JPEG ».
    expect(voieDeLecture('image/jpeg; charset=utf-8').voie).toBe('vision')
    expect(voieDeLecture('APPLICATION/PDF').voie).toBe('pdf')
    expect(voieDeLecture('  application/pdf  ').voie).toBe('pdf')
  })

  it('refuse une chaîne vide plutôt que de deviner', () => {
    expect(voieDeLecture('').voie).toBe('refuse')
  })
})

describe('seuil de texte', () => {
  it('refuse un document quasi vide', () => {
    // Un PDF scanné rend un filigrane et un numéro de page. Générer quatre
    // questions là-dessus donnerait quatre questions inventées — et un
    // étudiant qui révise sur des questions fausses perd son examen.
    expect(texteSuffisant('Page 1')).toBe(false)
    expect(texteSuffisant('')).toBe(false)
    expect(texteSuffisant('   \n\n  ')).toBe(false)
  })

  it('accepte un document qui a de la matière', () => {
    expect(texteSuffisant('a'.repeat(MIN_TEXTE))).toBe(true)
  })

  it('ne compte pas les blancs', () => {
    // Un PDF mal extrait rend parfois des milliers d'espaces.
    expect(texteSuffisant(' '.repeat(5000))).toBe(false)
  })
})
