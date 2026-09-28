import 'server-only'

/**
 * Tirer du texte d'un cours déposé.
 *
 * Trois formats, trois chemins, et une décision pour chacun :
 *
 *  * **PDF** — `unpdf`, qui embarque une compilation de pdf.js utilisable dans
 *    une fonction serverless, sans dépendance native. Il ne rend que la
 *    couche de texte : un PDF qui n'est qu'une suite de photos scannées en
 *    ressort vide, et c'est à l'appelant de le dire à l'étudiant plutôt que
 *    de générer des questions sur rien.
 *  * **Word (.docx)** — `mammoth`. Le vieux format binaire `.doc` n'est pas
 *    lisible et se refuse avec un message clair : mieux vaut demander un
 *    export en PDF que de laisser un cours en attente pour toujours.
 *  * **Photos** — le modèle de vision transcrit l'image. C'est le format le
 *    plus courant chez le public visé, qui photographie le tableau ou le
 *    polycopié d'un camarade.
 *
 * Le découpage en chapitres, lui, est dans `decoupage.ts` : sans réseau, et
 * testé.
 */

import { texteSuffisant, voieDeLecture } from './formats'

export type RefusExtraction =
  | 'format-non-lisible'
  | 'document-vide'
  | 'document-illisible'

export type Extraction =
  | { ok: true; texte: string; pages: number | null; parVision: boolean }
  | { ok: false; error: RefusExtraction; detail?: string }

export async function extraireTexte(opts: {
  octets: ArrayBuffer
  mime: string
  /** URL signée de l'objet, nécessaire au modèle de vision. */
  urlSignee?: string
  /** Injecté pour les tests : la transcription d'une image par le modèle. */
  transcrire?: (url: string) => Promise<string | null>
}): Promise<Extraction> {
  const lecture = voieDeLecture(opts.mime)

  switch (lecture.voie) {
    case 'pdf':
      return extrairePdf(opts.octets)

    case 'docx':
      return extraireDocx(opts.octets)

    case 'vision':
      if (!opts.urlSignee || !opts.transcrire) {
        return {
          ok: false,
          error: 'format-non-lisible',
          detail: 'Lecture par vision demandée sans URL signée.',
        }
      }
      return transcrireImage(opts.urlSignee, opts.transcrire)

    case 'refuse':
      return {
        ok: false,
        error: 'format-non-lisible',
        detail: lecture.motif,
      }
  }
}

async function extrairePdf(octets: ArrayBuffer): Promise<Extraction> {
  try {
    const { extractText, getDocumentProxy } = await import('unpdf')
    const document = await getDocumentProxy(new Uint8Array(octets))
    const { text, totalPages } = await extractText(document, {
      mergePages: true,
    })

    // `mergePages: true` rend une chaîne ; le type de retour d'`unpdf` est
    // une union sur cette option, et TypeScript a déjà écarté le tableau.
    const texte = text

    if (!texteSuffisant(texte)) {
      return {
        ok: false,
        error: 'document-vide',
        detail:
          'Ce PDF n’a pas de texte : c’est probablement un scan. Dépose les ' +
          'pages en photos, on saura les lire.',
      }
    }

    return { ok: true, texte, pages: totalPages, parVision: false }
  } catch (e) {
    return {
      ok: false,
      error: 'document-illisible',
      detail: e instanceof Error ? e.message : String(e),
    }
  }
}

async function extraireDocx(octets: ArrayBuffer): Promise<Extraction> {
  try {
    const mammoth = await import('mammoth')
    const { value } = await mammoth.extractRawText({
      buffer: Buffer.from(octets),
    })

    if (!texteSuffisant(value)) {
      return {
        ok: false,
        error: 'document-vide',
        detail: 'Ce document ne contient presque pas de texte.',
      }
    }

    // `mammoth` rend un paragraphe par ligne : on rétablit les doubles
    // retours, dont le découpage a besoin pour trouver ses frontières.
    return {
      ok: true,
      texte: value.replace(/\n(?!\n)/g, '\n\n'),
      pages: null,
      parVision: false,
    }
  } catch (e) {
    return {
      ok: false,
      error: 'document-illisible',
      detail: e instanceof Error ? e.message : String(e),
    }
  }
}

async function transcrireImage(
  url: string,
  transcrire: (url: string) => Promise<string | null>,
): Promise<Extraction> {
  const texte = await transcrire(url)

  if (texte === null) {
    return {
      ok: false,
      error: 'document-illisible',
      detail:
        'On n’arrive pas à lire cette photo. Reprends-la à la lumière, à ' +
        'plat, sans ombre sur le texte.',
    }
  }

  if (!texteSuffisant(texte)) {
    return {
      ok: false,
      error: 'document-vide',
      detail:
        'Cette photo ne contient pas assez de texte pour en tirer des ' +
        'questions.',
    }
  }

  // Une photo, c'est une page.
  return { ok: true, texte, pages: 1, parVision: true }
}
