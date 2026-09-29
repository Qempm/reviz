#!/usr/bin/env node
/**
 * Produit les états du panthéreau pour l'application.
 *
 *   node scripts/mascotte.mjs [--apercu=chemin.png]
 *
 * Entrée : `assets-source/mascotte/<etat>-source.jpg`, dessins générés dans
 * Flow sur fond magenta, **tous à partir du même dessin de référence** (l'état
 * `salut`) pour que ce soit toujours le même personnage.
 * Sortie : `apps/mobile/assets/mascotte/<etat>.webp`, 512 px de côté.
 *
 * **Tous les états partagent la même échelle.** Chaque dessin est détouré puis
 * rogné à son sujet, mais on ne l'étire pas pour remplir son carré : un
 * panthéreau endormi, roulé en boule, serait agrandi jusqu'à paraître deux
 * fois plus gros que le même debout. On prend le plus grand des sujets comme
 * mesure commune et on pose chacun **au pied du carré**, centré : les pattes
 * restent à la même hauteur d'un état à l'autre, et la respiration du
 * composant `Mascotte`, ancrée en bas, soulève le corps sans décoller les
 * pieds.
 *
 * Le détourage lui-même est celui de `scripts/detourer.mjs` (seuil magenta et
 * érosion du liseré JPEG) ; ce script l'appelle au lieu de le recopier.
 */

import { execFileSync } from 'node:child_process'
import { existsSync, mkdirSync, mkdtempSync, rmSync, statSync } from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import process from 'node:process'
import sharp from 'sharp'

const ETATS = [
  'salut',
  'bravo',
  'courage',
  'champion',
  'reflexion',
  'dodo',
  'curieux',
  'oups',
  'horsLigne',
  'chantier',
]

const SOURCES = 'assets-source/mascotte'
const SORTIE = 'apps/mobile/assets/mascotte'
const COTE = 512

/** Air laissé autour du plus grand sujet, en part du carré. */
const MARGE = 0.04

const apercu = process.argv
  .find((a) => a.startsWith('--apercu='))
  ?.split('=')[1]

const temporaire = mkdtempSync(path.join(os.tmpdir(), 'reviz-mascotte-'))
mkdirSync(SORTIE, { recursive: true })

try {
  // 1. Détourage et rognage de chaque état.
  const sujets = []
  for (const etat of ETATS) {
    const source = path.join(SOURCES, `${etat}-source.jpg`)
    if (!existsSync(source)) {
      console.error(`Introuvable : ${source}`)
      process.exit(1)
    }
    const detoure = path.join(temporaire, `${etat}.png`)
    execFileSync(process.execPath, ['scripts/detourer.mjs', source, detoure], {
      stdio: ['ignore', 'ignore', 'inherit'],
    })
    const { data, info } = await sharp(detoure)
      .trim({ threshold: 0 })
      .png()
      .toBuffer({ resolveWithObject: true })
    sujets.push({ etat, data, largeur: info.width, hauteur: info.height })
  }

  // 2. Une seule échelle pour tous : le plus grand côté de tous les sujets.
  const plusGrand = Math.max(...sujets.flatMap((s) => [s.largeur, s.hauteur]))
  const toile = Math.round(plusGrand / (1 - 2 * MARGE))
  const pied = Math.round(toile * MARGE)

  for (const s of sujets) {
    const gauche = Math.round((toile - s.largeur) / 2)
    const haut = toile - pied - s.hauteur

    // Deux passes : dans une même chaîne sharp, `resize` s'applique avant
    // `composite`, ce qui poserait le sujet sur une toile déjà réduite.
    const pose = await sharp({
      create: {
        width: toile,
        height: toile,
        channels: 4,
        background: { r: 0, g: 0, b: 0, alpha: 0 },
      },
    })
      .composite([{ input: s.data, left: gauche, top: haut }])
      .png()
      .toBuffer()

    const fichier = path.join(SORTIE, `${s.etat}.webp`)
    await sharp(pose)
      .resize(COTE, COTE)
      .webp({ quality: 88, alphaQuality: 100, effort: 6 })
      .toFile(fichier)

    const ko = (statSync(fichier).size / 1024).toFixed(0)
    console.log(`${s.etat.padEnd(10)} ${s.largeur}×${s.hauteur} → ${fichier} (${ko} ko)`)
  }

  // 3. Planche d'aperçu : chaque état sur le fond de l'application, puis sur
  //    le jaune — c'est là qu'un liseré rose se verrait.
  if (apercu) {
    const case_ = 240
    const fonds = [
      { r: 0xf5, g: 0xf5, b: 0xf7 },
      { r: 0xff, g: 0xc3, b: 0x00 },
    ]
    const vignettes = []
    for (const [ligne, fond] of fonds.entries()) {
      for (const [colonne, etat] of ETATS.entries()) {
        const image = await sharp(path.join(SORTIE, `${etat}.webp`))
          .resize(case_ - 20, case_ - 20)
          .png()
          .toBuffer()
        vignettes.push({
          input: await sharp({
            create: { width: case_, height: case_, channels: 4, background: fond },
          })
            .composite([{ input: image, left: 10, top: 10 }])
            .png()
            .toBuffer(),
          left: colonne * case_,
          top: ligne * case_,
        })
      }
    }
    await sharp({
      create: {
        width: case_ * ETATS.length,
        height: case_ * fonds.length,
        channels: 4,
        background: { r: 255, g: 255, b: 255, alpha: 1 },
      },
    })
      .composite(vignettes)
      .png()
      .toFile(apercu)
    console.log(`Aperçu : ${apercu}`)
  }
} finally {
  rmSync(temporaire, { recursive: true, force: true })
}
