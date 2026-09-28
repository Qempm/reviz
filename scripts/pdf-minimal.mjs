/**
 * Fabriquer un PDF d'une ou plusieurs pages, avec une vraie couche de texte.
 *
 * Sert à l'essai de la chaîne d'ingestion (`essai-ingestion.mjs`) : le seau
 * `cours` n'accepte que PDF, Word et images, et l'essai doit emprunter le
 * chemin réel — `unpdf` sur un PDF — plutôt qu'un format de contournement.
 *
 * Écrit à la main, sans dépendance : une bibliothèque de génération de PDF
 * pèserait plus lourd que ce fichier, pour un usage qui ne sort pas des
 * scripts. Le PDF est non compressé et porte une table `xref` correcte — sans
 * elle, pdf.js passe par sa récupération d'erreur, ce qui vérifierait sa
 * tolérance plutôt que notre extraction.
 */

/**
 * Caractères typographiques que `latin1` ne sait pas écrire.
 *
 * WinAnsi leur réserve les positions 0x80 à 0x9F, là où latin1 n'a que des
 * caractères de contrôle. Sans cette table, `Buffer.from(…, 'latin1')`
 * écrivait 0x14 pour un tiret cadratin et l'extracteur le perdait : le banc
 * d'essai modifiait donc son entrée sans le dire — le titre du chapitre II
 * ressortait sans son tiret, et j'ai d'abord cru à un défaut du découpage.
 */
const WINANSI = {
  '€': 0x80, // euro
  '‚': 0x82,
  'ƒ': 0x83,
  '„': 0x84,
  '…': 0x85, // points de suspension
  '†': 0x86,
  '‡': 0x87,
  'ˆ': 0x88,
  '‰': 0x89,
  'Š': 0x8a,
  '‹': 0x8b,
  'Œ': 0x8c, // OE lié
  'Ž': 0x8e,
  '‘': 0x91, // apostrophe simple ouvrante
  '’': 0x92, // apostrophe typographique
  '“': 0x93, // guillemet anglais ouvrant
  '”': 0x94, // guillemet anglais fermant
  '•': 0x95, // puce
  '–': 0x96, // tiret demi-cadratin
  '—': 0x97, // tiret cadratin
  '˜': 0x98,
  '™': 0x99,
  'š': 0x9a,
  '›': 0x9b,
  'œ': 0x9c, // oe lié
  'ž': 0x9e,
  'Ÿ': 0x9f,
}

/** Échappe une chaîne pour un littéral PDF, en WinAnsi. */
function litteral(texte) {
  return [...texte]
    .map((c) => {
      const winansi = WINANSI[c]
      if (winansi !== undefined) return String.fromCharCode(winansi)
      // Au-delà de WinAnsi on ne sait pas écrire : mieux vaut un point
      // d'interrogation visible qu'un octet de contrôle que l'extracteur
      // avale en silence.
      return c.codePointAt(0) > 0xff ? '?' : c
    })
    .join('')
    .replace(/\\/g, '\\\\')
    .replace(/\(/g, '\\(')
    .replace(/\)/g, '\\)')
}

/** Découpe une ligne trop longue pour la largeur de page. */
function replier(ligne, maxi = 92) {
  if (ligne.length <= maxi) return [ligne]

  const lignes = []
  let courante = ''
  for (const mot of ligne.split(' ')) {
    if (courante.length + mot.length + 1 > maxi) {
      lignes.push(courante)
      courante = mot
    } else {
      courante = courante ? `${courante} ${mot}` : mot
    }
  }
  if (courante) lignes.push(courante)
  return lignes
}

/** Le flux de contenu d'une page. */
function contenuPage(lignes) {
  const corps = lignes
    .map((l) => `(${litteral(l)}) Tj T*`)
    .join('\n')

  return `BT\n/F1 10 Tf\n40 800 Td\n13 TL\n${corps}\nET`
}

/**
 * Rend un `Uint8Array` de PDF contenant `texte`.
 *
 * 58 lignes par page, ce qui tient dans une A4 à 10 points sur 13.
 */
export function pdfDepuisTexte(texte, lignesParPage = 58) {
  const lignes = texte
    .split('\n')
    .flatMap((l) => (l.trim() === '' ? [''] : replier(l)))

  const pages = []
  for (let i = 0; i < lignes.length; i += lignesParPage) {
    pages.push(lignes.slice(i, i + lignesParPage))
  }
  if (pages.length === 0) pages.push([''])

  // Numérotation : 1 catalogue, 2 arbre de pages, 3 police, puis deux objets
  // par page (la page et son contenu).
  const premierePage = 4
  const idsPages = pages.map((_, i) => premierePage + i * 2)

  const objets = [
    `<< /Type /Catalog /Pages 2 0 R >>`,
    `<< /Type /Pages /Kids [${idsPages.map((n) => `${n} 0 R`).join(' ')}] /Count ${pages.length} >>`,
    `<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>`,
  ]

  for (const [i, page] of pages.entries()) {
    const idPage = idsPages[i]
    const idContenu = idPage + 1
    objets.push(
      `<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] ` +
        `/Resources << /Font << /F1 3 0 R >> >> /Contents ${idContenu} 0 R >>`,
    )
    const flux = contenuPage(page)
    objets.push(
      `<< /Length ${Buffer.byteLength(flux, 'latin1')} >>\nstream\n${flux}\nendstream`,
    )
  }

  // Assemblage, en suivant les décalages d'octets pour la table xref.
  let pdf = '%PDF-1.4\n'
  const decalages = []

  for (const [i, corps] of objets.entries()) {
    decalages.push(Buffer.byteLength(pdf, 'latin1'))
    pdf += `${i + 1} 0 obj\n${corps}\nendobj\n`
  }

  const debutXref = Buffer.byteLength(pdf, 'latin1')
  pdf += `xref\n0 ${objets.length + 1}\n0000000000 65535 f \n`
  for (const d of decalages) {
    pdf += `${String(d).padStart(10, '0')} 00000 n \n`
  }
  pdf +=
    `trailer\n<< /Size ${objets.length + 1} /Root 1 0 R >>\n` +
    `startxref\n${debutXref}\n%%EOF\n`

  return new Uint8Array(Buffer.from(pdf, 'latin1'))
}
