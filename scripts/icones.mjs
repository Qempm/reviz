#!/usr/bin/env node
/**
 * Fabrique les icônes Android et iPhone à partir d'un seul dessin.
 *
 * L'APK 2.0.0 publié porte **le logo de Flutter** sur l'écran d'accueil : le
 * `flutter create` d'origine n'a jamais été remplacé, et rien ne le
 * signalait — une icône par défaut s'installe sans erreur. C'est pourtant la
 * première chose qu'un étudiant voit, avant même d'ouvrir l'application.
 *
 *   node scripts/icones.mjs [chemin/vers/buste.png] [--apercu=planche.png]
 *
 * **Une seule entrée : le buste du panthéreau sur fond transparent**
 * (`assets-source/icone/reviz-panthere-buste.png`, identité du 3 octobre
 * 2026). C'est l'icône de la charte de marque, tête et épaules, dont on a
 * retiré le jaune : le script la repose sur le jaune exact du design system.
 *
 * Le buste est **coupé en bas**, aux épaules. Il ne se centre donc pas comme
 * un objet compact : on le pose **au pied** de la toile, et c'est le bord de
 * l'icône qui le coupe — un buste qui flotte au milieu du jaune, avec une
 * coupe nette sous les épaules, aurait l'air d'une découpe ratée. Le script
 * en tire :
 *
 *  - l'icône héritée (`ic_launcher.png`), cinq densités, sur le jaune — sur
 *    Android 7 c'est elle qui s'affiche, et un PNG transparent y donnerait
 *    une icône trouée ;
 *  - l'icône **adaptative** (Android 8+), en deux couches : un fond jaune et
 *    un premier plan transparent de 108 dp, buste au pied ;
 *  - l'icône de l'iPhone, celles du web, et les trois images de la marque
 *    dans l'application (`apps/mobile/assets/marque/`) : le logo de l'en-tête
 *    et les deux images de l'écran de lancement.
 *
 * Le calcul qui compte est celui de la zone sûre : sur les 108 dp du premier
 * plan, seuls les **72 dp** centraux sont affichés, et le lanceur y inscrit
 * sa forme — cercle, carré arrondi ou goutte. Les oreilles, en haut aux
 * coins, sont ce qui sort le premier d'un cercle : voir `PART_ADAPTATIVE`,
 * réglée en simulant le rendu (`--apercu`).
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
  RACINE, 'assets-source', 'icone', 'reviz-panthere-buste.png',
)

/** Le jaune de la charte (`jetons.dart`), fond de toutes les icônes. */
const JAUNE = { r: 0xff, g: 0xc4, b: 0x00, alpha: 1 }

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
 * Largeur du buste, en part de la toile, selon ce qui masque l'icône.
 *
 *  - `PART_PLEINE` : rien ne la masque, ou un simple carré arrondi (icône
 *    héritée, boutique, iPhone, logo) — le buste peut presque toucher les
 *    bords ;
 *  - `PART_ADAPTATIVE` : la couche de 108 dp, dont seuls les 72 dp centraux
 *    se voient, découpés en cercle sur bien des lanceurs. Les oreilles sont
 *    aux coins hauts du buste : c'est elles que le cercle coupe d'abord ;
 *  - `PART_DECOUPABLE` : l'icône web « maskable », dont la zone sûre est un
 *    disque de 80 %.
 *
 * Valeurs réglées sur la planche de `--apercu`, pas déduites.
 */
const PART_PLEINE = 0.86
const PART_ADAPTATIVE = 0.6

/**
 * Hauteur du pied du buste dans la couche adaptative, en part des 108 dp.
 * Seuls les 72 dp centraux se voient : leur bas est à 90 dp. Posé au bas de
 * la couche, le buste montrait les épaules et coupait le visage sous les
 * yeux (c'est ce que la planche `--apercu` a fait voir). On pose donc son
 * pied à 94 dp, juste sous le bas visible : la coupe des épaules reste
 * cachée, et la tête remplit le cadre.
 */
const BAS_ADAPTATIF = (108 - 94) / 108
const PART_DECOUPABLE = 0.66

// Le premier argument qui n'est pas une option : `--apercu=…` seul ne doit
// pas être pris pour le chemin du dessin.
const cheminDonne = process.argv.slice(2).find((a) => !a.startsWith('--'))
const source = cheminDonne ? path.resolve(cheminDonne) : SOURCE_DEFAUT

if (!existsSync(source)) {
  console.error(
    `Dessin introuvable : ${source}\n\n` +
      'Attendu : le buste du panthéreau, fond transparent, coupé en bas,\n' +
      '512 px de large au moins.\n\n' +
      `  node scripts/icones.mjs chemin/vers/buste.png`,
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

if (!meta.hasAlpha) {
  // Non bloquant : un dessin déjà sur fond jaune plein passe, mais l'icône
  // adaptative perdra la découpe et remplira toute la pastille.
  console.warn(
    'Attention : ce dessin n’a pas de canal alpha. Le premier plan adaptatif ' +
      'sera un rectangle plein au lieu d’un buste découpé.',
  )
}

/**
 * Le buste, large de `part` de la toile, **posé au pied** et centré.
 *
 * `bas` remonte le pied, en part de la toile : 0 pose le buste sur le bord
 * inférieur, ce que veulent toutes les icônes.
 *
 * Le `trim()` recadre sur le buste avant de calculer, pour que `part`
 * s'applique au dessin et non à une marge transparente.
 */
async function poser(cote, part, fond, bas = 0) {
  const interne = Math.round(cote * part)

  const { data: buste, info } = await sharp(source)
    .trim()
    .resize({ width: interne, height: interne, fit: 'inside' })
    .png()
    .toBuffer({ resolveWithObject: true })

  return sharp({
    create: {
      width: cote,
      height: cote,
      channels: 4,
      background: fond ?? { r: 0, g: 0, b: 0, alpha: 0 },
    },
  })
    .composite([
      {
        input: buste,
        left: Math.round((cote - info.width) / 2),
        top: cote - info.height - Math.round(cote * bas),
      },
    ])
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
  writeFileSync(heritee, await poser(cote, PART_PLEINE, JAUNE))
  ecrits.push(`${path.relative(RACINE, heritee)} (${cote}×${cote})`)

  // Premier plan adaptatif : 108 dp, transparent, tête dans la zone sûre.
  const coteAdaptatif = Math.round(108 * facteur)
  const premierPlan = path.join(dossier, 'ic_launcher_foreground.png')
  writeFileSync(premierPlan, await poser(coteAdaptatif, PART_ADAPTATIVE, null, BAS_ADAPTATIF))
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
<!-- Le jaune de la charte (jetons.dart). Écrit par
     scripts/icones.mjs : ne pas le modifier ici. -->
<resources>
    <color name="ic_launcher_background">#FFC400</color>
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
// Ni le Play Store ni une page web ne la masquent, donc le buste peut y être
// plus large que dans la couche adaptative.
const COTE_BOUTIQUE = 512

const boutique = await masquer(
  await poser(COTE_BOUTIQUE, PART_PLEINE, JAUNE),
  await masque(COTE_BOUTIQUE, arrondi(COTE_BOUTIQUE)),
)

const cheminBoutique = path.join(
  RACINE, 'assets-source', 'icone', 'reviz-icone-512.png',
)
writeFileSync(cheminBoutique, boutique)
ecrits.push(`${path.relative(RACINE, cheminBoutique)} (512x512, squircle)`)

// --- iPhone ------------------------------------------------------------------
//
// Une seule image de 1024 px, déclarée « universal » : Xcode 14 et plus en
// tirent toutes les tailles. Deux exigences de l'App Store, vérifiées à
// l'envoi et non à la compilation : **aucun canal alpha** (d'où le
// `removeAlpha`, le fond jaune étant déjà plein) et **pas de coins
// arrondis** — iOS pose son propre masque, un squircle dessiné ici se
// verrait en double. Le buste a la largeur de l'icône de boutique.
const IOS = path.join(
  RACINE, 'apps', 'mobile', 'ios', 'Runner', 'Assets.xcassets',
  'AppIcon.appiconset',
)
if (existsSync(path.dirname(IOS))) {
  const { readdirSync, rmSync } = await import('node:fs')
  mkdirSync(IOS, { recursive: true })
  // Les tailles que `flutter create` y avait laissées : le logo de Flutter.
  for (const f of readdirSync(IOS)) {
    if (f.endsWith('.png')) rmSync(path.join(IOS, f))
  }
  const ios = await sharp(await poser(1024, PART_PLEINE, JAUNE))
    .removeAlpha()
    .png({ compressionLevel: 9 })
    .toBuffer()
  writeFileSync(path.join(IOS, 'Icon-App-1024x1024@1x.png'), ios)
  writeFileSync(
    path.join(IOS, 'Contents.json'),
    JSON.stringify(
      {
        images: [
          {
            filename: 'Icon-App-1024x1024@1x.png',
            idiom: 'universal',
            platform: 'ios',
            size: '1024x1024',
          },
        ],
        info: { author: 'scripts/icones.mjs', version: 1 },
      },
      null,
      2,
    ) + '\n',
  )
  ecrits.push(
    `${path.relative(RACINE, path.join(IOS, 'Icon-App-1024x1024@1x.png'))} (1024x1024, sans alpha)`,
  )
}

// --- Web (`npm run web`) -------------------------------------------------
//
// Quatre usages, quatre règles :
//  - `Icon-192/512` (« any ») : affichées telles quelles par Chrome sur un
//    bureau ou dans le lanceur d'apps — squircle complet, comme la boutique ;
//  - `Icon-maskable-*` : Android les découpe en cercle ou en goutte. La zone
//    sûre est un disque de 80 % : `PART_DECOUPABLE` ;
//  - `apple-touch-icon` (180 px) : l'iPhone l'arrondit lui-même et noircit
//    la transparence — plein cadre, sans alpha ;
//  - `favicon.png` (32 px) : l'onglet, en squircle.
const WEB = path.join(RACINE, 'apps', 'mobile', 'web')
if (existsSync(WEB)) {
  const icones = path.join(WEB, 'icons')
  mkdirSync(icones, { recursive: true })
  const squircle = async (c) =>
    masquer(await poser(c, PART_PLEINE, JAUNE), await masque(c, arrondi(c)))
  const ecrire = (chemin, octets, note) => {
    writeFileSync(chemin, octets)
    ecrits.push(`${path.relative(RACINE, chemin)} (${note})`)
  }
  for (const c of [192, 512]) {
    ecrire(path.join(icones, `Icon-${c}.png`), await squircle(c), `${c}, squircle`)
    ecrire(
      path.join(icones, `Icon-maskable-${c}.png`),
      await sharp(await poser(c, PART_DECOUPABLE, JAUNE)).removeAlpha().png().toBuffer(),
      `${c}, découpable`,
    )
  }
  ecrire(
    path.join(icones, 'apple-touch-icon.png'),
    await sharp(await poser(180, PART_PLEINE, JAUNE)).removeAlpha().png().toBuffer(),
    '180, plein cadre',
  )
  ecrire(path.join(WEB, 'favicon.png'), await squircle(32), '32, squircle')
}

// --- La marque dans l'application ------------------------------------------
//
// Trois images, dans `apps/mobile/assets/marque/` :
//  - `logo.png` (288 px) : le logo de l'en-tête et de la connexion, l'icône
//    du téléphone en squircle — on reconnaît dans l'application ce qu'on a
//    touché pour l'ouvrir ;
//  - `logo-objet.png` (432 px) : l'écran de lancement, au centre du
//    **crème**. Le même squircle jaune : le buste seul flotterait, coupé net
//    sous les épaules, au milieu de l'écran ;
//  - `logo-lancement-a12.png` (1152 px) : l'écran de lancement d'Android 12,
//    qui découpe l'image dans un disque de 768 px sur fond jaune
//    (`icon_background_color` dans `pubspec.yaml`). Le buste y est posé un
//    peu sous le bas du disque, dont la courbe le coupe comme le bord d'une
//    icône ronde.
const MARQUE = path.join(RACINE, 'apps', 'mobile', 'assets', 'marque')
if (existsSync(MARQUE)) {
  const tuile = async (c) =>
    masquer(await poser(c, PART_PLEINE, JAUNE), await masque(c, arrondi(c)))
  const ecrire = (nom, octets, note) => {
    writeFileSync(path.join(MARQUE, nom), octets)
    ecrits.push(`${path.relative(RACINE, path.join(MARQUE, nom))} (${note})`)
  }

  ecrire('logo.png', await tuile(288), '288, squircle')

  // La tuile au centre d'une toile transparente, avec la marge que
  // `flutter_native_splash` laisse d'ordinaire autour de l'objet.
  const objet = await sharp({
    create: {
      width: 432,
      height: 432,
      channels: 4,
      background: { r: 0, g: 0, b: 0, alpha: 0 },
    },
  })
    .composite([{ input: await tuile(288), left: 72, top: 72 }])
    .png({ compressionLevel: 9 })
    .toBuffer()
  ecrire('logo-objet.png', objet, '432, tuile centrée')

  // Disque visible de 768 px centré dans 1152 : son bas est à 960 px. Le pied
  // du buste se pose 30 px plus bas, hors du disque.
  ecrire(
    'logo-lancement-a12.png',
    await poser(1152, 0.6, null, (1152 - 990) / 1152),
    '1152, buste au bas du disque',
  )
}

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
      { input: await poser(C, PART_ADAPTATIVE, null, BAS_ADAPTATIF), top: 0, left: 0 },
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
