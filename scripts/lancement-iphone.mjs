#!/usr/bin/env node
/**
 * Les écrans de lancement de l'app web installée sur iPhone.
 *
 *   node scripts/lancement-iphone.mjs
 *
 * Sans compte développeur Apple, Reviz s'installe sur iPhone depuis Safari
 * (« Sur l'écran d'accueil »). iOS montre alors, le temps du chargement,
 * l'image `apple-touch-startup-image` qui correspond exactement à l'écran —
 * ou un écran blanc. Une image par taille d'iPhone en usage : le crème de
 * l'application, l'icône au centre, comme l'écran de lancement de l'APK.
 *
 * Sortie : `apps/mobile/web/lancement/<largeur>x<hauteur>.png`, déclarées
 * dans `apps/mobile/web/index.html`.
 */

import { mkdirSync, statSync } from 'node:fs'
import path from 'node:path'
import sharp from 'sharp'

const ICONE = 'assets-source/icone/reviz-icone-512.png'
const SORTIE = 'apps/mobile/web/lancement'
const CREME = { r: 0xfc, g: 0xef, b: 0xd0, alpha: 1 }

/** [largeur, hauteur] en pixels, portrait. */
const ECRANS = [
  [1290, 2796], // 14 Pro Max, 15 Plus, 15 Pro Max, 16 Plus
  [1179, 2556], // 14 Pro, 15, 15 Pro, 16
  [1284, 2778], // 12 Pro Max, 13 Pro Max, 14 Plus
  [1170, 2532], // 12, 12 Pro, 13, 13 Pro, 14
  [1125, 2436], // X, XS, 11 Pro, 12 mini, 13 mini
  [1242, 2688], // XS Max, 11 Pro Max
  [828, 1792], // XR, 11
  [750, 1334], // SE (2e et 3e), 8
]

mkdirSync(SORTIE, { recursive: true })
for (const [l, h] of ECRANS) {
  const cote = Math.round(l * 0.3)
  const icone = await sharp(ICONE).resize(cote, cote).png().toBuffer()
  const fichier = path.join(SORTIE, `${l}x${h}.png`)
  await sharp({ create: { width: l, height: h, channels: 4, background: CREME } })
    .composite([{ input: icone, left: Math.round((l - cote) / 2), top: Math.round((h - cote) / 2 - h * 0.04) }])
    .png({ compressionLevel: 9, palette: true, quality: 90 })
    .toFile(fichier)
  console.log(`${fichier} (${(statSync(fichier).size / 1024).toFixed(0)} ko)`)
}
