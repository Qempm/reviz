#!/usr/bin/env node
/**
 * Détoure un dessin généré sur fond blanc (ou gris très clair).
 *
 *   node scripts/detourer-blanc.mjs entree.jpg sortie.png [--fins]
 *
 * Les poses 3D du panthéreau (identité du 3 octobre 2026) sortent de Flow sur
 * un fond blanc, parfois légèrement grisé. Un seuil de luminosité seul ne
 * suffit pas : le museau du panthéreau est **crème**, presque blanc, et
 * partirait avec le fond. La règle est donc topologique :
 *
 *   le fond, c'est ce qui est **neutre, clair et relié au bord** de l'image.
 *
 * Le museau, enfermé dans la fourrure noire, n'est relié à rien : il reste.
 * Les pattes crème ne partent pas non plus, parce qu'elles sont **saturées**
 * (un crème a une teinte, le blanc n'en a pas).
 *
 * Deux cas particuliers :
 *  - un trou de fond **enfermé** par le sujet (entre un bras et le corps) :
 *    s'il est très clair, parfaitement neutre et assez grand, c'est du fond
 *    — un museau est crème, pas blanc pur ;
 *  - `--fins` : un objet **blanc et fin** touche le fond (le câble de l'état
 *    `horsLigne`). On n'appelle alors « fond » que ce qui survit à une
 *    ouverture large : les formes fines restent au sujet. Sans cette option,
 *    le câble disparaissait et la prise était rongée.
 *
 * Le bord est ensuite érodé d'un pixel (le liseré JPEG, gris clair autour de
 * la fourrure) puis adouci, et les miettes isolées (ombre résiduelle,
 * poussière de compression) sont retirées.
 */

import { existsSync, writeFileSync } from 'node:fs'
import path from 'node:path'
import process from 'node:process'
import sharp from 'sharp'

const args = process.argv.slice(2)
const [entree, sortie] = args.filter((a) => !a.startsWith('--'))
const fins = args.includes('--fins')

if (!entree || !sortie) {
  console.error('Usage : node scripts/detourer-blanc.mjs entree.jpg sortie.png [--fins]')
  process.exit(1)
}
if (!existsSync(entree)) {
  console.error(`Introuvable : ${entree}`)
  process.exit(1)
}

/** Écart maximal entre canaux pour un pixel « neutre », et luminosité minimale. */
const SATURATION_FOND = 22
const LUMIERE_FOND = 165
/** Un trou enfermé n'est du fond que s'il est blanc pur et assez grand. */
const SATURATION_TROU = 10
const LUMIERE_TROU = 235
const TAILLE_TROU = 400
/** Une composante du sujet plus petite que ceci est une miette. */
const TAILLE_MIETTE = 1500
/** Rayon de l'ouverture de `--fins`, en pixels. */
const RAYON_FINS = 6

const { data, info } = await sharp(entree)
  .removeAlpha()
  .raw()
  .toBuffer({ resolveWithObject: true })
const { width: L, height: H } = info
const N = L * H

const saturation = new Uint8Array(N)
const lumiere = new Uint8Array(N)
for (let p = 0; p < N; p++) {
  const r = data[p * 3]
  const v = data[p * 3 + 1]
  const b = data[p * 3 + 2]
  saturation[p] = Math.max(r, v, b) - Math.min(r, v, b)
  lumiere[p] = (r + v + b) / 3
}

/**
 * Étiquette les composantes 4-connexes de `masque`. Rend le tableau des
 * étiquettes (0 = hors masque) et la taille de chaque composante.
 */
function composantes(masque) {
  const etiquettes = new Int32Array(N)
  const tailles = [0]
  const pile = new Int32Array(N)
  let n = 0
  for (let depart = 0; depart < N; depart++) {
    if (!masque[depart] || etiquettes[depart]) continue
    n++
    let haut = 0
    let taille = 0
    pile[haut++] = depart
    etiquettes[depart] = n
    while (haut) {
      const p = pile[--haut]
      taille++
      const x = p % L
      const voisins = [
        x > 0 ? p - 1 : -1,
        x < L - 1 ? p + 1 : -1,
        p - L,
        p + L,
      ]
      for (const q of voisins) {
        if (q < 0 || q >= N || !masque[q] || etiquettes[q]) continue
        etiquettes[q] = n
        pile[haut++] = q
      }
    }
    tailles.push(taille)
  }
  return { etiquettes, tailles }
}

/** Érosion (`garder = 0`) ou dilatation (`garder = 1`) carrée, par axe. */
function morpho(masque, rayon, dilater) {
  let courant = masque
  for (const horizontal of [true, false]) {
    const suivant = new Uint8Array(N)
    for (let y = 0; y < H; y++) {
      for (let x = 0; x < L; x++) {
        let v = dilater ? 0 : 1
        for (let d = -rayon; d <= rayon; d++) {
          const xx = horizontal ? x + d : x
          const yy = horizontal ? y : y + d
          const dedans = xx >= 0 && xx < L && yy >= 0 && yy < H
          const m = dedans ? courant[yy * L + xx] : 0
          if (dilater && m) { v = 1; break }
          if (!dilater && !m) { v = 0; break }
        }
        suivant[y * L + x] = v
      }
    }
    courant = suivant
  }
  return courant
}

// 1. Fond : neutre, clair, et relié au bord.
const candidat = new Uint8Array(N)
for (let p = 0; p < N; p++) {
  candidat[p] = saturation[p] < SATURATION_FOND && lumiere[p] > LUMIERE_FOND ? 1 : 0
}
const { etiquettes, tailles } = composantes(candidat)
const auBord = new Set()
for (let x = 0; x < L; x++) {
  auBord.add(etiquettes[x])
  auBord.add(etiquettes[(H - 1) * L + x])
}
for (let y = 0; y < H; y++) {
  auBord.add(etiquettes[y * L])
  auBord.add(etiquettes[y * L + L - 1])
}
auBord.delete(0)
let fond = new Uint8Array(N)
for (let p = 0; p < N; p++) fond[p] = auBord.has(etiquettes[p]) ? 1 : 0

// 2. Trous enfermés, blancs purs et assez grands : du fond aussi.
if (!fins) {
  const trou = new Uint8Array(N)
  for (let p = 0; p < N; p++) {
    trou[p] =
      candidat[p] && !fond[p] && lumiere[p] > LUMIERE_TROU && saturation[p] < SATURATION_TROU
        ? 1
        : 0
  }
  const t = composantes(trou)
  for (let p = 0; p < N; p++) {
    if (t.etiquettes[p] && t.tailles[t.etiquettes[p]] > TAILLE_TROU) fond[p] = 1
  }
} else {
  fond = morpho(morpho(fond, RAYON_FINS, false), RAYON_FINS, true)
}
void tailles

// 3. Sujet : ouverture d'un pixel (les poussières), érosion d'un pixel (le
//    liseré), puis seules les composantes notables.
let sujet = new Uint8Array(N)
for (let p = 0; p < N; p++) sujet[p] = fond[p] ? 0 : 1
sujet = morpho(morpho(sujet, 1, false), 1, true)
sujet = morpho(sujet, 1, false)
const s = composantes(sujet)
for (let p = 0; p < N; p++) {
  if (sujet[p] && s.tailles[s.etiquettes[p]] <= TAILLE_MIETTE) sujet[p] = 0
}

// 4. Alpha adouci, assemblé aux couleurs d'origine.
const masque = Buffer.alloc(N)
let opaques = 0
for (let p = 0; p < N; p++) {
  masque[p] = sujet[p] ? 255 : 0
  opaques += sujet[p]
}
const alpha = await sharp(masque, { raw: { width: L, height: H, channels: 1 } })
  .blur(0.8)
  // Un seul canal en sortie : sans cela, sharp rend le flou en trois canaux
  // et l'alpha se décale d'un facteur trois.
  .extractChannel(0)
  .raw()
  .toBuffer()

// Couleurs remises à zéro là où l'alpha est nul : un pixel transparent qui
// garde son blanc bruité ressort au redimensionnement, et empêche surtout
// `trim()` de reconnaître la marge comme vide.
const rgba = Buffer.alloc(N * 4)
for (let p = 0; p < N; p++) {
  if (!alpha[p]) continue
  rgba[p * 4] = data[p * 3]
  rgba[p * 4 + 1] = data[p * 3 + 1]
  rgba[p * 4 + 2] = data[p * 3 + 2]
  rgba[p * 4 + 3] = alpha[p]
}
const png = await sharp(rgba, { raw: { width: L, height: H, channels: 4 } })
  .png({ compressionLevel: 9 })
  .toBuffer()
writeFileSync(sortie, png)

const part = ((opaques / N) * 100).toFixed(1)
console.log(`Détouré : ${path.basename(entree)} → ${sortie} (${L}×${H}, sujet ${part} %)`)
if (opaques === 0 || part > 95) {
  console.error('Le fond n’a pas été reconnu : ce dessin est-il bien sur fond blanc ?')
  process.exit(1)
}
