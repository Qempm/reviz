#!/usr/bin/env node
/**
 * Détoure un dessin généré sur fond magenta.
 *
 *   node scripts/detourer.mjs entree.jpg sortie.png
 *
 * Pourquoi un fond magenta plutôt que blanc : le museau du panthéreau est
 * crème (`#FCF9F8`), à deux doigts du blanc. Un détourage par luminosité le
 * mangerait avec le fond. Le magenta pur n'existe nulle part dans la palette
 * Reviz — strictement chaude, jaune, orange, encre, rouge —, donc aucun pixel
 * du sujet ne lui ressemble.
 *
 * Et pourquoi ce script plutôt qu'un service de détourage : celui du projet
 * n'est pas autorisé côté connecteur. Un fond uni se découpe de toute façon
 * mieux par un seuil que par un modèle, qui inventerait des bords doux là où
 * le dessin est net.
 *
 * Le point délicat est le **liseré**. Flow rend un JPEG, donc la frontière
 * entre le magenta et le sujet porte des pixels intermédiaires — un halo rose
 * qu'un seuil binaire laisse en place et qu'on verrait sur le jaune de
 * l'icône. D'où l'érosion : on retire `--marge` pixels au sujet, ce qui
 * emporte le halo. Sur un dessin plat réduit ensuite à 432 px au plus, deux
 * pixels sur 1024 ne se voient pas.
 */

import { existsSync, writeFileSync } from 'node:fs'
import path from 'node:path'
import process from 'node:process'
import sharp from 'sharp'

const args = process.argv.slice(2)
const positionnels = args.filter((a) => !a.startsWith('--'))
const option = (nom, defaut) => {
  const trouve = args.find((a) => a.startsWith(`--${nom}=`))
  return trouve ? Number(trouve.split('=')[1]) : defaut
}

const [entree, sortie] = positionnels

if (!entree || !sortie) {
  console.error(
    'Usage : node scripts/detourer.mjs entree.jpg sortie.png ' +
      '[--marge=2] [--seuil=60]\n\n' +
      '  --marge   pixels retirés au sujet pour emporter le liseré JPEG\n' +
      '  --seuil   écart minimal entre le rose et le vert pour juger un\n' +
      '            pixel « magenta » (0-255, plus bas = plus agressif)',
  )
  process.exit(1)
}

if (!existsSync(entree)) {
  console.error(`Introuvable : ${entree}`)
  process.exit(1)
}

const MARGE = option('marge', 2)
const SEUIL = option('seuil', 60)

const { data, info } = await sharp(entree)
  .ensureAlpha()
  .raw()
  .toBuffer({ resolveWithObject: true })

const { width: L, height: H, channels: C } = info

/**
 * Ce pixel est-il du fond ?
 *
 * Le magenta a le rouge **et** le bleu hauts, le vert bas. On ne teste pas
 * une égalité à une couleur précise : la compression JPEG fait varier la
 * teinte de quelques unités, et la valeur exacte rendue par le modèle n'est
 * pas forcément `#FF00FF`.
 */
function estFond(i) {
  const r = data[i]
  const v = data[i + 1]
  const b = data[i + 2]
  return r - v > SEUIL && b - v > SEUIL && r > 120 && b > 120
}

// 1. Masque brut : 1 = sujet, 0 = fond.
const sujet = new Uint8Array(L * H)
for (let p = 0; p < L * H; p++) {
  sujet[p] = estFond(p * C) ? 0 : 1
}

// 2. Érosion du sujet de `MARGE` pixels : c'est ce qui emporte le halo rose.
//    Une passe par axe plutôt qu'un voisinage carré — même résultat sur une
//    forme pleine, et linéaire au lieu de quadratique.
function eroder(masque, rayon) {
  if (rayon <= 0) return masque

  let courant = masque

  for (const horizontal of [true, false]) {
    const suivant = new Uint8Array(courant.length)
    for (let y = 0; y < H; y++) {
      for (let x = 0; x < L; x++) {
        let garde = 1
        for (let d = -rayon; d <= rayon && garde; d++) {
          const xx = horizontal ? x + d : x
          const yy = horizontal ? y : y + d
          // Hors cadre : traité comme du fond, donc le bord de l'image
          // n'agrandit jamais le sujet.
          if (xx < 0 || xx >= L || yy < 0 || yy >= H) garde = 0
          else if (!courant[yy * L + xx]) garde = 0
        }
        suivant[y * L + x] = garde
      }
    }
    courant = suivant
  }

  return courant
}

const garde = eroder(sujet, MARGE)

// 3. Alpha, et remise à zéro des canaux du fond : un pixel transparent qui
//    garde sa couleur rose ressort au redimensionnement, quand les voisins
//    se mélangent.
let opaques = 0
for (let p = 0; p < L * H; p++) {
  const i = p * C
  if (garde[p]) {
    data[i + 3] = 255
    opaques++
  } else {
    data[i] = 0
    data[i + 1] = 0
    data[i + 2] = 0
    data[i + 3] = 0
  }
}

const png = await sharp(data, { raw: { width: L, height: H, channels: C } })
  .png({ compressionLevel: 9 })
  .toBuffer()

writeFileSync(sortie, png)

const part = ((opaques / (L * H)) * 100).toFixed(1)

console.log(`Détouré : ${path.basename(entree)} → ${sortie}`)
console.log(`  ${L}×${H}, sujet sur ${part} % de la surface, marge ${MARGE} px`)

if (opaques === 0) {
  console.error(
    '\nAucun pixel gardé : le fond n’était pas magenta, ou le seuil est trop ' +
      'bas.',
  )
  process.exit(1)
}

if (part > 95) {
  console.warn(
    '\nAttention : presque toute l’image a été gardée. Le fond n’a ' +
      'probablement pas été reconnu — vérifie le rendu.',
  )
}
