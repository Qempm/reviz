/**
 * Quel chemin pour quel format, et à partir de quand un texte compte.
 *
 * Séparé de `extraction.ts` parce que ce sont des **règles**, pas des
 * entrées-sorties : elles se testent sans fichier ni réseau. `extraction.ts`
 * porte `import 'server-only'` et charge `unpdf` et `mammoth` — il n'est pas
 * testable, et il n'a pas à l'être : ce qui décide est ici.
 */

/** Les trois chemins, plus le refus. */
export type Voie = 'pdf' | 'docx' | 'vision' | 'refuse'

export type Lecture = {
  voie: Voie
  /** Ce qu'on dira à l'étudiant, quand on refuse. */
  motif?: string
}

const PDF = 'application/pdf'
const DOCX =
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
const DOC = 'application/msword'
const IMAGES = ['image/jpeg', 'image/png', 'image/webp']

/**
 * En dessous, on considère qu'il n'y a pas de texte.
 *
 * Un PDF scanné rend souvent quelques caractères — un filigrane, un numéro de
 * page —, pas rien du tout. Générer des questions sur deux cents caractères
 * produirait quatre questions inventées, ce qui est pire qu'un refus : un
 * étudiant qui révise sur des questions fausses perd son examen.
 */
export const MIN_TEXTE = 500

export function voieDeLecture(mime: string): Lecture {
  const m = mime.trim().toLowerCase().split(';')[0]

  if (m === PDF) return { voie: 'pdf' }
  if (m === DOCX) return { voie: 'docx' }
  if (IMAGES.includes(m)) return { voie: 'vision' }

  if (m === DOC) {
    // Le vieux format binaire de Word n'est pas lisible par `mammoth`, et
    // aucune bibliothèque utilisable en serverless ne le fait proprement.
    // `preparerDepot` l'accepte pourtant au dépôt : mieux vaut un message
    // clair ici qu'un cours en attente pour toujours.
    return {
      voie: 'refuse',
      motif:
        'Ce fichier est un ancien format Word (.doc) qu’on ne sait pas lire. ' +
        'Enregistre-le en PDF et redépose-le.',
    }
  }

  return {
    voie: 'refuse',
    motif: `On ne sait pas lire ce type de fichier (${mime}).`,
  }
}

/** Y a-t-il de quoi générer des questions ? */
export function texteSuffisant(texte: string): boolean {
  return texte.trim().length >= MIN_TEXTE
}
