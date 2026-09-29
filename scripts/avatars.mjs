#!/usr/bin/env node
/**
 * Découpe la planche des douze avatars en douze pochoirs.
 *
 *   node scripts/avatars.mjs planche.jpg [--apercu=chemin.png]
 *
 * Les douze silhouettes sont générées **en une seule image**, en grille 4×3 :
 * c'est ce qui garantit qu'elles forment un jeu — même trait, même poids, même
 * simplification — au lieu de douze dessins étrangers les uns aux autres.
 *
 * **Les fichiers produits ne portent aucune couleur.** Ce sont des pochoirs :
 * une forme opaque sur du transparent, les yeux et les détails évidés. Le fond
 * et l'encre de chaque clé restent dans `apps/mobile/lib/metier/avatars.dart`,
 * où la palette vit déjà, et l'écran teinte la forme à l'affichage. Trois
 * conséquences :
 *
 *  - aucune couleur n'est dupliquée entre Dart et des pixels, donc aucune ne
 *    peut diverger ;
 *  - un fond sombre reçoit la même forme en crème, sans second jeu d'images ;
 *  - les fichiers sont minuscules, ce qui compte pour un APK déjà lourd et un
 *    public au forfait data limité.
 *
 * **Le découpage ne suppose pas une grille régulière**, et c'est le cœur du
 * script. Deux tentatives plus naïves ont échoué :
 *
 *  1. Diviser l'image en douze parts égales : le modèle avait laissé une bande
 *     vide en bas, donc les coupes tombaient au milieu des animaux — une case
 *     contenait deux têtes, la suivante un fragment.
 *  2. Diviser la boîte englobante de l'avant-plan : cette bande vide portait
 *     des poussières de compression JPEG, qui étiraient la boîte jusqu'en bas.
 *
 * D'où les **profils de projection** : on compte les pixels de forme par ligne
 * puis par colonne, on ne garde que les bandes qui dépassent un seuil — ce qui
 * écarte les poussières —, et on exige d'en trouver exactement trois puis
 * quatre. Un découpage qui se trompe s'arrête, au lieu de livrer des
 * fragments sans rien dire.
 */

import { existsSync, mkdirSync, writeFileSync } from 'node:fs'
import path from 'node:path'
import process from 'node:process'
import sharp from 'sharp'

const RACINE = path.resolve(import.meta.dirname, '..')
const SORTIE = path.join(RACINE, 'apps', 'mobile', 'assets', 'avatars')

const COLONNES = 4
const RANGEES = 3

/**
 * Les clés, dans le même ordre que la grille **et** que `avatars.dart`.
 *
 * Le nom de l'animal sert d'étiquette d'accessibilité : un lecteur d'écran
 * doit pouvoir annoncer « avatar panthère » plutôt que « image ».
 */
const CASES = [
  { cle: 'ton-01', animal: 'panthère' },
  { cle: 'ton-02', animal: 'éléphant' },
  { cle: 'ton-03', animal: 'perroquet' },
  { cle: 'ton-04', animal: 'tortue' },
  { cle: 'ton-05', animal: 'singe' },
  { cle: 'ton-06', animal: 'gazelle' },
  { cle: 'ton-07', animal: 'coq' },
  { cle: 'ton-08', animal: 'poisson' },
  { cle: 'ton-09', animal: 'lion' },
  { cle: 'ton-10', animal: 'escargot' },
  { cle: 'ton-11', animal: 'papillon' },
  { cle: 'ton-12', animal: 'hibou' },
]

/** Côté des pochoirs. 256 px couvre le plus grand usage (96 dp) en xxxhdpi. */
const COTE = 256

/** Part du carré occupée par la forme. */
const PART = 0.78

const source = process.argv[2]

if (!source || !existsSync(source)) {
  console.error(
    'Usage : node scripts/avatars.mjs planche.jpg [--apercu=chemin.png]\n\n' +
      'La planche est une grille 4×3 de douze silhouettes sombres sur fond\n' +
      'magenta, dans l’ordre de CASES.',
  )
  process.exit(1)
}

const { data, info } = await sharp(source)
  .ensureAlpha()
  .raw()
  .toBuffer({ resolveWithObject: true })

const { width: L, height: H, channels: C } = info

/**
 * Masque de la forme : opaque là où ce n'est **pas** le fond.
 *
 * Même test que `scripts/detourer.mjs` — rouge et bleu hauts, vert bas. Les
 * détails évidés restent transparents puisqu'ils laissent voir le fond, ce
 * qui est exactement l'effet voulu.
 */
const SEUIL = 60
const forme = new Uint8Array(L * H)

for (let p = 0; p < L * H; p++) {
  const i = p * C
  const r = data[i]
  const v = data[i + 1]
  const b = data[i + 2]
  forme[p] = r - v > SEUIL && b - v > SEUIL && r > 120 && b > 120 ? 0 : 1
}

/**
 * Bandes occupées le long d'un axe.
 *
 * `compte[i]` est le nombre de pixels de forme sur la ligne (ou la colonne)
 * `i`. Une bande commence là où ce compte dépasse `seuil` et finit là où il
 * repasse en dessous. Le seuil est ce qui écarte les poussières de
 * compression : une tache de trois pixels ne fait pas une rangée.
 */
function bandes(compte, seuil) {
  const trouvees = []
  let debut = -1

  for (let i = 0; i < compte.length; i++) {
    const occupe = compte[i] > seuil
    if (occupe && debut < 0) debut = i
    if (!occupe && debut >= 0) {
      trouvees.push([debut, i - 1])
      debut = -1
    }
  }

  if (debut >= 0) trouvees.push([debut, compte.length - 1])
  return trouvees
}

/** Seuil proportionnel au côté : 1 %, soit une dizaine de pixels ici. */
const seuilBande = Math.max(4, Math.round(Math.min(L, H) * 0.01))

const parLigne = new Int32Array(H)
for (let y = 0; y < H; y++) {
  let n = 0
  for (let x = 0; x < L; x++) if (forme[y * L + x]) n++
  parLigne[y] = n
}

const lignes = bandes(parLigne, seuilBande)

if (lignes.length !== RANGEES) {
  console.error(
    `${lignes.length} rangée(s) détectée(s) au lieu de ${RANGEES} : ` +
      'la planche n’a pas la disposition attendue.\n' +
      lignes.map(([a, b]) => `  y ${a}…${b}`).join('\n'),
  )
  process.exit(1)
}

/** Les douze boîtes, en ordre de lecture. */
const boites = []

for (const [y0, y1] of lignes) {
  const parColonne = new Int32Array(L)
  for (let x = 0; x < L; x++) {
    let n = 0
    for (let y = y0; y <= y1; y++) if (forme[y * L + x]) n++
    parColonne[x] = n
  }

  const colonnes = bandes(parColonne, Math.max(2, Math.round(seuilBande / 2)))

  if (colonnes.length !== COLONNES) {
    console.error(
      `Rangée y ${y0}…${y1} : ${colonnes.length} colonne(s) au lieu de ` +
        `${COLONNES}. Deux formes se touchent, ou l’une manque.`,
    )
    process.exit(1)
  }

  for (const [x0, x1] of colonnes) {
    // La bande donne les bords gauche et droit. On resserre ensuite en
    // hauteur sur cette forme-là : sinon un papillon large et plat
    // hériterait de la hauteur du coq d'à côté, et sortirait minuscule
    // dans son carré.
    let haut = y1
    let bas = y0
    for (let y = y0; y <= y1; y++) {
      let vu = false
      for (let x = x0; x <= x1 && !vu; x++) if (forme[y * L + x]) vu = true
      if (vu) {
        if (y < haut) haut = y
        if (y > bas) bas = y
      }
    }

    boites.push({ x0, y0: haut, x1, y1: bas })
  }
}

mkdirSync(SORTIE, { recursive: true })

const ecrits = []

for (let index = 0; index < CASES.length; index++) {
  const { cle, animal } = CASES[index]
  const { x0, y0, x1, y1 } = boites[index]

  const l = x1 - x0 + 1
  const h = y1 - y0 + 1

  // Le pochoir : seule l'opacité compte, l'écran applique un `srcIn`.
  const decoupe = Buffer.alloc(l * h * 4)
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < l; x++) {
      decoupe[(y * l + x) * 4 + 3] = forme[(y0 + y) * L + (x0 + x)] ? 255 : 0
    }
  }

  const interne = Math.round(COTE * PART)

  const dessin = await sharp(decoupe, {
    raw: { width: l, height: h, channels: 4 },
  })
    .resize(interne, interne, {
      fit: 'contain',
      background: { r: 0, g: 0, b: 0, alpha: 0 },
    })
    .png()
    .toBuffer()

  const vignette = await sharp({
    create: {
      width: COTE,
      height: COTE,
      channels: 4,
      background: { r: 0, g: 0, b: 0, alpha: 0 },
    },
  })
    .composite([{ input: dessin, gravity: 'center' }])
    .png({ compressionLevel: 9 })
    .toBuffer()

  writeFileSync(path.join(SORTIE, `${cle}.png`), vignette)

  ecrits.push(
    `${cle}.png  ${animal.padEnd(10)} ${String(l).padStart(3)}×${String(h).padStart(3)} → ${COTE}×${COTE}  ${(vignette.length / 1024).toFixed(1)} ko`,
  )
}

// --- Aperçu de vérification -------------------------------------------------
//
// `--apercu=chemin.png` compose les douze avatars **tels que l'écran les
// montrera** : la forme teintée de l'encre de sa clé, sur le fond de sa clé,
// dans un disque. C'est ce contrôle qui a montré que les deux découpages
// précédents livraient des fragments — rien dans la sortie du script ne le
// disait.
//
// Les couleurs sont recopiées ici depuis `theme/jetons.dart`. C'est la seule
// duplication du lot, et elle ne concerne que cet aperçu — les fichiers
// livrés n'en portent aucune.
const APERCU_COULEURS = [
  ['#FFC300', '#6D5200'],
  ['#FFDF9A', '#785A00'],
  ['#FE6A2B', '#FFFFFF'],
  ['#FFDBCF', '#802900'],
  ['#BCCDEB', '#1C1B1B'],
  ['#D4E3FF', '#785A00'],
  ['#D9A400', '#FFFFFF'],
  ['#D94E15', '#FFFFFF'],
  ['#FFDAD6', '#93000A'],
  ['#D3C5AB', '#1C1B1B'],
  ['#EAE7E7', '#4F4632'],
  ['#785A00', '#FFFFFF'],
]

const apercu = process.argv.find((a) => a.startsWith('--apercu='))

if (apercu) {
  const chemin = apercu.split('=')[1]
  const D = 160
  const ECART = 16
  const largeur = COLONNES * D + (COLONNES + 1) * ECART
  const hauteur = RANGEES * D + (RANGEES + 1) * ECART

  const masqueRond = await sharp(
    Buffer.from(
      `<svg width="${D}" height="${D}"><circle cx="${D / 2}" cy="${D / 2}" r="${D / 2}" fill="#fff"/></svg>`,
    ),
  )
    .resize(D, D)
    .png()
    .toBuffer()

  const pieces = []

  for (let index = 0; index < CASES.length; index++) {
    const [fond, encre] = APERCU_COULEURS[index]

    // `blend: 'in'` ne garde que l'alpha du pochoir : c'est l'équivalent du
    // `BlendMode.srcIn` que fera Flutter.
    const teintee = await sharp(path.join(SORTIE, `${CASES[index].cle}.png`))
      .resize(D, D)
      .composite([
        {
          input: {
            create: { width: D, height: D, channels: 4, background: encre },
          },
          blend: 'in',
        },
      ])
      .png()
      .toBuffer()

    const plein = await sharp({
      create: { width: D, height: D, channels: 4, background: fond },
    })
      .composite([{ input: teintee, top: 0, left: 0 }])
      .png()
      .toBuffer()

    pieces.push({
      input: await sharp(plein)
        .composite([{ input: masqueRond, blend: 'dest-in' }])
        .png()
        .toBuffer(),
      left: ECART + (index % COLONNES) * (D + ECART),
      top: ECART + Math.floor(index / COLONNES) * (D + ECART),
    })
  }

  writeFileSync(
    chemin,
    await sharp({
      create: {
        width: largeur,
        height: hauteur,
        channels: 4,
        background: { r: 252, g: 249, b: 248, alpha: 1 },
      },
    })
      .composite(pieces)
      .png()
      .toBuffer(),
  )

  console.log(`Aperçu : ${chemin}\n`)
}

console.log(`Douze pochoirs écrits dans ${path.relative(RACINE, SORTIE)} :\n`)
for (const e of ecrits) console.log('  ' + e)
console.log(
  '\nLes couleurs ne sont pas ici : chaque clé porte son fond et son encre ' +
    'dans\napps/mobile/lib/metier/avatars.dart.',
)
