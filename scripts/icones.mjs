#!/usr/bin/env node
/**
 * Fabrique l'icône Android à partir d'un seul dessin.
 *
 * L'APK 2.0.0 publié porte **le logo de Flutter** sur l'écran d'accueil : le
 * `flutter create` d'origine n'a jamais été remplacé, et rien ne le
 * signalait — une icône par défaut s'installe sans erreur. C'est pourtant la
 * première chose qu'un étudiant voit, avant même d'ouvrir l'application.
 *
 *   node scripts/icones.mjs [chemin/vers/tete-1024.png]
 *
 * **Une seule entrée : la tête de la mascotte sur fond transparent**, carrée,
 * 1024 px au moins. C'est exactement ce que rend un détourage, donc la chaîne
 * est faite pour ce format-là. Le script en tire :
 *
 *  - l'icône héritée (`ic_launcher.png`), cinq densités, la tête posée sur le
 *    jaune du design system — sur Android 7 c'est elle qui s'affiche, et un
 *    PNG transparent y donnerait une icône trouée ;
 *  - l'icône **adaptative** (Android 8+), en deux couches : un fond de
 *    couleur et un premier plan transparent de 108 dp. Sans elle, Android
 *    pose l'icône héritée dans une pastille blanche et le rendu paraît
 *    inachevé.
 *
 * Le calcul qui compte est celui de la zone sûre : sur les 108 dp du premier
 * plan, seuls les **72 dp** centraux sont affichés — les 18 dp de chaque côté
 * sont la réserve de parallaxe. Et le lanceur inscrit ensuite sa forme dans
 * ces 72 dp : cercle, carré arrondi ou goutte selon l'appareil. Un objet
 * compact doit donc y entrer **par sa diagonale**, pas par son côté. Voir
 * `PART_ADAPTATIVE` plus bas : ce détail-là a été réglé en simulant le rendu,
 * après avoir constaté que le premier réglage coupait le dessin.
 */

import { existsSync, mkdirSync, writeFileSync } from 'node:fs'
import path from 'node:path'
import process from 'node:process'
import sharp from 'sharp'

const RACINE = path.resolve(import.meta.dirname, '..')
const RES = path.join(
  RACINE,
  'apps', 'mobile', 'android', 'app', 'src', 'main', 'res',
)

const SOURCE_DEFAUT = path.join(
  RACINE, 'assets-source', 'icone', 'reviz-tete-1024.png',
)

/** Le jaune du design system (`docs/DESIGN.md`), fond des deux icônes. */
const JAUNE = { r: 0xff, g: 0xc3, b: 0x00, alpha: 1 }

/**
 * Densités Android. `ic_launcher` fait 48 dp, le premier plan adaptatif
 * 108 dp — d'où deux tailles par densité.
 */
const DENSITES = [
  { nom: 'mdpi', facteur: 1 },
  { nom: 'hdpi', facteur: 1.5 },
  { nom: 'xhdpi', facteur: 2 },
  { nom: 'xxhdpi', facteur: 3 },
  { nom: 'xxxhdpi', facteur: 4 },
]

/**
 * Part de la toile occupée par le dessin, par couche.
 *
 * Ces deux nombres ont été réglés en simulant le vrai rendu, pas déduits.
 *
 * `PART_ADAPTATIVE` a d'abord été posée à 0,62 — un peu en dedans des 66,7 %
 * de la zone sûre — et c'était **faux**. La zone sûre de 66,7 % est le côté du
 * carré visible ; un lanceur rond y inscrit un cercle, et les coins d'un
 * objet carré sortent alors de ce cercle. Pour qu'un objet compact tienne
 * entier, c'est sa **diagonale** qui doit entrer dans les 72 dp : côté ≤
 * 72/√2, soit 47 % de la couche. La simulation montrait les fiches coupées
 * net en bas ; elle ne les montre plus.
 *
 * `PART_HERITEE` peut être plus généreuse : l'icône héritée n'est masquée par
 * rien. On garde tout de même une marge, un dessin qui touche le bord d'un
 * carré paraissant toujours à l'étroit.
 */
const PART_HERITEE = 0.76
const PART_ADAPTATIVE = 0.47

const source = process.argv[2]
  ? path.resolve(process.argv[2])
  : SOURCE_DEFAUT

if (!existsSync(source)) {
  console.error(
    `Dessin introuvable : ${source}\n\n` +
      'Attendu : la tête de la mascotte, carrée, fond transparent, 1024 px ou\n' +
      'plus. C’est le format que rend un détourage.\n\n' +
      `  node scripts/icones.mjs chemin/vers/tete.png`,
  )
  process.exit(1)
}

const meta = await sharp(source).metadata()

if (!meta.width || !meta.height) {
  console.error('Impossible de lire les dimensions de ce fichier.')
  process.exit(1)
}

if (meta.width < 512 || meta.height < 512) {
  console.error(
    `Ce dessin fait ${meta.width}×${meta.height}. Il en faut au moins 512, ` +
      'sinon la densité xxxhdpi (432 px) serait un agrandissement flou.',
  )
  process.exit(1)
}

if (Math.abs(meta.width - meta.height) > 2) {
  console.error(
    `Ce dessin n’est pas carré (${meta.width}×${meta.height}). Une icône ` +
      'Android l’est, et le recadrage automatique couperait au hasard.',
  )
  process.exit(1)
}

if (!meta.hasAlpha) {
  // Non bloquant : un dessin déjà sur fond jaune plein passe, mais l'icône
  // adaptative perdra la découpe et remplira toute la pastille.
  console.warn(
    'Attention : ce dessin n’a pas de canal alpha. Le premier plan adaptatif ' +
      'sera un carré plein au lieu d’une tête découpée.',
  )
}

/**
 * La tête, réduite à `part` d'une toile de `cote`, centrée.
 *
 * Le `trim()` n'est pas décoratif : sans lui, `part` s'appliquerait à la
 * marge transparente que porte déjà le dessin d'origine, et la tête sortirait
 * bien plus petite que voulu — deux réductions au lieu d'une. On recadre donc
 * sur la tête, puis on calcule.
 */
async function poser(cote, part, fond) {
  const interne = Math.round(cote * part)

  const tete = await sharp(source)
    .trim()
    .resize(interne, interne, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
    .png()
    .toBuffer()

  return sharp({
    create: {
      width: cote,
      height: cote,
      channels: 4,
      background: fond ?? { r: 0, g: 0, b: 0, alpha: 0 },
    },
  })
    .composite([{ input: tete, gravity: 'center' }])
    .png({ compressionLevel: 9 })
    .toBuffer()
}

const ecrits = []

for (const { nom, facteur } of DENSITES) {
  const dossier = path.join(RES, `mipmap-${nom}`)
  mkdirSync(dossier, { recursive: true })

  // Héritée : 48 dp, sur le jaune — Android 7 n'a pas d'icône adaptative, et
  // un PNG transparent y donnerait une icône trouée.
  const cote = Math.round(48 * facteur)
  const heritee = path.join(dossier, 'ic_launcher.png')
  writeFileSync(heritee, await poser(cote, PART_HERITEE, JAUNE))
  ecrits.push(`${path.relative(RACINE, heritee)} (${cote}×${cote})`)

  // Premier plan adaptatif : 108 dp, transparent, tête dans la zone sûre.
  const coteAdaptatif = Math.round(108 * facteur)
  const premierPlan = path.join(dossier, 'ic_launcher_foreground.png')
  writeFileSync(premierPlan, await poser(coteAdaptatif, PART_ADAPTATIVE, null))
  ecrits.push(
    `${path.relative(RACINE, premierPlan)} (${coteAdaptatif}×${coteAdaptatif})`,
  )
}

// L'icône adaptative elle-même : deux couches, lues par Android 8 et plus.
const anydpi = path.join(RES, 'mipmap-anydpi-v26')
mkdirSync(anydpi, { recursive: true })

const xmlIcone = `<?xml version="1.0" encoding="utf-8"?>
<!-- Icône adaptative (Android 8+). Deux couches, que le lanceur recadre en
     cercle, en carré arrondi ou en goutte selon l'appareil : d'où la zone
     sûre de 72 dp sur 108 respectée par scripts/icones.mjs. Sans ce fichier,
     Android pose l'icône héritée dans une pastille blanche. -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
`

writeFileSync(path.join(anydpi, 'ic_launcher.xml'), xmlIcone, 'utf8')
ecrits.push(path.relative(RACINE, path.join(anydpi, 'ic_launcher.xml')))

const valeurs = path.join(RES, 'values')
mkdirSync(valeurs, { recursive: true })

const xmlFond = `<?xml version="1.0" encoding="utf-8"?>
<!-- Le jaune du design system (docs/DESIGN.md § 2). Écrit par
     scripts/icones.mjs : ne pas le modifier ici. -->
<resources>
    <color name="ic_launcher_background">#FFC300</color>
</resources>
`

writeFileSync(
  path.join(valeurs, 'ic_launcher_background.xml'),
  xmlFond,
  'utf8',
)
ecrits.push(
  path.relative(RACINE, path.join(valeurs, 'ic_launcher_background.xml')),
)

/** Masque d'une forme, rastérisé à la taille exacte. */
async function masque(cote, svg) {
  return sharp(Buffer.from(svg)).resize(cote, cote).png().toBuffer()
}

/**
 * Applique un masque. **Deux passes, et non une chaîne** : sharp exécute
 * `resize` avant `composite`, donc enchaîner les deux réduirait la toile
 * avant l'arrivée du masque, et échouerait sur « must have same dimensions ».
 */
async function masquer(image, m) {
  return sharp(image)
    .composite([{ input: m, blend: 'dest-in' }])
    .png()
    .toBuffer()
}

const arrondi = (c) =>
  `<svg width="${c}" height="${c}"><rect width="${c}" height="${c}" rx="${Math.round(c * 0.235)}" ry="${Math.round(c * 0.235)}" fill="#fff"/></svg>`

const disque = (c) =>
  `<svg width="${c}" height="${c}"><circle cx="${c / 2}" cy="${c / 2}" r="${c / 2}" fill="#fff"/></svg>`

// L'icône de la boutique et du web : un squircle complet, fond compris.
//
// Ni le Play Store ni une page web ne la masquent, donc le dessin peut y être
// plus généreux que dans la couche adaptative — 62 % au lieu de 47 %.
const COTE_BOUTIQUE = 512

const boutique = await masquer(
  await poser(COTE_BOUTIQUE, 0.62, JAUNE),
  await masque(COTE_BOUTIQUE, arrondi(COTE_BOUTIQUE)),
)

const cheminBoutique = path.join(
  RACINE, 'assets-source', 'icone', 'reviz-icone-512.png',
)
writeFileSync(cheminBoutique, boutique)
ecrits.push(`${path.relative(RACINE, cheminBoutique)} (512x512, squircle)`)

// --- Aperçu de vérification, sur demande -----------------------------------
//
// `--apercu=chemin.png` écrit une planche de trois vignettes : ce que montre
// un lanceur à carré arrondi, un lanceur rond, et le rendu réel à 48 px.
//
// Ce n'est pas un gadget. Le réglage de `PART_ADAPTATIVE` a été corrigé grâce
// à cette planche : la première version coupait les fiches en bas, ce
// qu'aucune lecture du code ne montrait.
const apercu = process.argv.find((a) => a.startsWith('--apercu='))

if (apercu) {
  const chemin = apercu.split('=')[1]
  const C = 432

  const compose = await sharp({
    create: { width: C, height: C, channels: 4, background: JAUNE },
  })
    .composite([
      { input: await poser(C, PART_ADAPTATIVE, null), top: 0, left: 0 },
    ])
    .png()
    .toBuffer()

  // La zone réellement affichée : 72 dp sur 108, soit 66,7 %. Le reste est la
  // réserve de parallaxe, que le lanceur n'affiche pas.
  const visible = Math.round((C * 72) / 108)
  const bord = Math.round((C - visible) / 2)

  const vu = await sharp(compose)
    .extract({ left: bord, top: bord, width: visible, height: visible })
    .png()
    .toBuffer()

  const vignette = (image) => sharp(image).resize(260, 260).png().toBuffer()

  const planche = await sharp({
    create: {
      width: 840,
      height: 300,
      channels: 4,
      background: { r: 240, g: 237, b: 237, alpha: 1 },
    },
  })
    .composite([
      {
        input: await vignette(
          await masquer(vu, await masque(visible, arrondi(visible))),
        ),
        left: 20,
        top: 20,
      },
      {
        input: await vignette(
          await masquer(vu, await masque(visible, disque(visible))),
        ),
        left: 290,
        top: 20,
      },
      {
        // Agrandi au plus proche voisin : on veut voir les pixels réels du
        // 48 px, pas une interpolation qui les flatte.
        input: await sharp(path.join(RES, 'mipmap-mdpi', 'ic_launcher.png'))
          .resize(260, 260, { kernel: 'nearest' })
          .png()
          .toBuffer(),
        left: 560,
        top: 20,
      },
    ])
    .png()
    .toBuffer()

  writeFileSync(chemin, planche)
  ecrits.push(`${chemin} (aperçu : carré arrondi, rond, 48 px réel)`)
}

console.log(`Icône fabriquée depuis ${path.relative(RACINE, source)} :\n`)
for (const f of ecrits) console.log('  ' + f)
console.log(
  '\nRelancer avec --apercu=chemin.png pour voir ce qu’en font un lanceur ' +
    'rond\net un lanceur à carré arrondi, avant de committer. C’est ce ' +
    'contrôle qui a\nmontré que le premier réglage coupait le dessin.',
)
