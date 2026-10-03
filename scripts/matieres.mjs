#!/usr/bin/env node
/**
 * Produit les dix illustrations des familles de matières.
 *
 *   node scripts/matieres.mjs [--apercu=planche.png]
 *
 * Une matière n'a pas de type en base : sa famille se déduit de son nom
 * (`apps/mobile/lib/metier/matieres.dart`), et chaque famille a son objet en
 * peluche 3D, dans le style du panthéreau — balance de justice pour le droit,
 * stéthoscope pour la santé, et ainsi de suite. Généré **un par un** dans Flow
 * (Nano Banana 2), sur fond blanc : `assets-source/matieres/<famille>-source.jpg`.
 *
 * Détouré par `scripts/detourer-blanc.mjs`, rogné, puis **centré** dans un
 * carré : chaque objet remplit son médaillon, contrairement à la mascotte,
 * dont tous les états partagent une échelle et un pied.
 *
 * Sortie : `apps/mobile/assets/matieres/<famille>.webp`, 256 px — le plus
 * grand médaillon (88 dp) à la densité ×3 ne demande pas plus.
 */

import { execFileSync } from 'node:child_process'
import { existsSync, mkdirSync, mkdtempSync, rmSync, statSync } from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import process from 'node:process'
import sharp from 'sharp'

/** Les familles, dans l'ordre de `FamilleMatiere`. */
const FAMILLES = [
  'droit',
  'economie',
  'sante',
  'maths',
  'sciences',
  'agronomie',
  'lettres',
  'informatique',
  'education',
  'generique',
]

const SOURCES = 'assets-source/matieres'
const SORTIE = 'apps/mobile/assets/matieres'
const COTE = 256

/** Part du carré occupée par l'objet. */
const PART = 0.92

const apercu = process.argv
  .find((a) => a.startsWith('--apercu='))
  ?.split('=')[1]

const temporaire = mkdtempSync(path.join(os.tmpdir(), 'reviz-matieres-'))
mkdirSync(SORTIE, { recursive: true })

try {
  for (const famille of FAMILLES) {
    const source = path.join(SOURCES, `${famille}-source.jpg`)
    if (!existsSync(source)) {
      console.error(`Introuvable : ${source}`)
      process.exit(1)
    }
    const detoure = path.join(temporaire, `${famille}.png`)
    execFileSync(process.execPath, ['scripts/detourer-blanc.mjs', source, detoure], {
      stdio: ['ignore', 'ignore', 'inherit'],
    })

    const interne = Math.round(COTE * PART)
    const { data: objet, info } = await sharp(detoure)
      .trim({ threshold: 0 })
      .resize({ width: interne, height: interne, fit: 'inside' })
      .png()
      .toBuffer({ resolveWithObject: true })

    const fichier = path.join(SORTIE, `${famille}.webp`)
    await sharp({
      create: {
        width: COTE,
        height: COTE,
        channels: 4,
        background: { r: 0, g: 0, b: 0, alpha: 0 },
      },
    })
      .composite([
        {
          input: objet,
          left: Math.round((COTE - info.width) / 2),
          top: Math.round((COTE - info.height) / 2),
        },
      ])
      .webp({ quality: 88, alphaQuality: 100, effort: 6 })
      .toFile(fichier)

    const ko = (statSync(fichier).size / 1024).toFixed(0)
    console.log(`${famille.padEnd(13)} → ${fichier} (${ko} ko)`)
  }

  // Planche d'aperçu : chaque objet dans un médaillon crème sur une carte
  // blanche, comme sur l'accueil.
  if (apercu) {
    const case_ = 180
    const vignettes = []
    for (const [i, famille] of FAMILLES.entries()) {
      const disque = Buffer.from(
        `<svg width="${case_}" height="${case_}"><rect width="${case_}" height="${case_}" fill="#FFFFFF"/><circle cx="${case_ / 2}" cy="${case_ / 2}" r="${case_ / 2 - 12}" fill="#FCEFD0"/></svg>`,
      )
      const objet = await sharp(path.join(SORTIE, `${famille}.webp`))
        .resize(case_ - 60, case_ - 60)
        .png()
        .toBuffer()
      vignettes.push({
        input: await sharp(disque)
          .composite([{ input: objet, left: 30, top: 30 }])
          .png()
          .toBuffer(),
        left: (i % 5) * case_,
        top: Math.floor(i / 5) * case_,
      })
    }
    await sharp({
      create: {
        width: case_ * 5,
        height: case_ * 2,
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
