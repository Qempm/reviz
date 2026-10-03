#!/usr/bin/env node
/**
 * Produit les douze avatars en buste 3D.
 *
 *   node scripts/avatars.mjs [--apercu=planche.png]
 *
 * Identité du 3 octobre 2026 : les douze pochoirs 2D, teintés à l'écran,
 * deviennent douze **bustes en peluche 3D** — tête et épaules, face caméra —
 * de la même famille que le panthéreau. Ils sont générés **un par un** dans
 * Flow (Nano Banana 2), avec l'icône Reviz en référence de style, sur fond
 * blanc : `assets-source/avatars/<clé>-source.jpg`.
 *
 * Chaque source est détourée par `scripts/detourer-blanc.mjs` (le fond est
 * ce qui est neutre, clair et relié au bord), rognée à son sujet, puis posée
 * dans un carré : **centrée**, à la même hauteur pour tous, le bas des
 * épaules au pied du carré. Dans le disque de couleur de l'écran
 * (`AvatarInitiale`), le cercle coupe alors les épaules comme sur une photo
 * d'identité, et toutes les têtes ont la même taille dans un classement.
 *
 * Sortie : `apps/mobile/assets/avatars/<clé>.webp`, 288 px — le plus grand
 * affichage (96 dp) à la densité ×3. Les clés n'ont pas changé depuis les
 * pochoirs : aucune ligne de base ni route ne bouge.
 */

import { execFileSync } from 'node:child_process'
import { existsSync, mkdirSync, mkdtempSync, rmSync, statSync } from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import process from 'node:process'
import sharp from 'sharp'

/**
 * Les clés, l'animal et le fond du disque — le même ordre et les mêmes fonds
 * que `apps/mobile/lib/metier/avatars.dart`, repris ici pour la seule planche
 * d'aperçu.
 */
const AVATARS = [
  { cle: 'ton-01', animal: 'léopard', fond: '#FFC400' },
  { cle: 'ton-02', animal: 'éléphant', fond: '#FFEDB0' },
  { cle: 'ton-03', animal: 'perroquet', fond: '#F4793B' },
  { cle: 'ton-04', animal: 'tortue', fond: '#FDE3D3' },
  { cle: 'ton-05', animal: 'singe', fond: '#BCCDEB' },
  { cle: 'ton-06', animal: 'gazelle', fond: '#E3ECFF' },
  { cle: 'ton-07', animal: 'coq', fond: '#D9A400' },
  { cle: 'ton-08', animal: 'poisson', fond: '#C9531F' },
  { cle: 'ton-09', animal: 'lion', fond: '#FEE4E2' },
  { cle: 'ton-10', animal: 'escargot', fond: '#E5D3A6' },
  { cle: 'ton-11', animal: 'papillon', fond: '#EADBB4' },
  { cle: 'ton-12', animal: 'hibou', fond: '#263030' },
]

/** Avatars dont la peluche est elle-même gris clair : détourage strict. */
const STRICTS = new Set(['ton-02'])

const SOURCES = 'assets-source/avatars'
const SORTIE = 'apps/mobile/assets/avatars'
const COTE = 288

/** Part du carré occupée par le buste, en largeur comme en hauteur. */
const PART = 0.9

const apercu = process.argv
  .find((a) => a.startsWith('--apercu='))
  ?.split('=')[1]

const temporaire = mkdtempSync(path.join(os.tmpdir(), 'reviz-avatars-'))
mkdirSync(SORTIE, { recursive: true })

try {
  for (const { cle, animal } of AVATARS) {
    const source = path.join(SOURCES, `${cle}-source.jpg`)
    if (!existsSync(source)) {
      console.error(`Introuvable : ${source} (${animal})`)
      process.exit(1)
    }
    const detoure = path.join(temporaire, `${cle}.png`)
    const options = STRICTS.has(cle) ? ['--strict'] : []
    execFileSync(
      process.execPath,
      ['scripts/detourer-blanc.mjs', source, detoure, ...options],
      { stdio: ['ignore', 'ignore', 'inherit'] },
    )

    // Rogné au buste, puis réduit pour tenir dans `PART` du carré.
    const interne = Math.round(COTE * PART)
    const { data: buste, info } = await sharp(detoure)
      .trim({ threshold: 0 })
      .resize({ width: interne, height: interne, fit: 'inside' })
      .png()
      .toBuffer({ resolveWithObject: true })

    // Centré en largeur, posé au pied : les épaules touchent le bas du carré.
    const fichier = path.join(SORTIE, `${cle}.webp`)
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
          input: buste,
          left: Math.round((COTE - info.width) / 2),
          top: COTE - info.height,
        },
      ])
      .webp({ quality: 88, alphaQuality: 100, effort: 6 })
      .toFile(fichier)

    const ko = (statSync(fichier).size / 1024).toFixed(0)
    console.log(`${cle} ${animal.padEnd(10)} → ${fichier} (${ko} ko)`)
  }

  // Planche d'aperçu : chaque buste dans son disque de couleur, comme dans
  // l'application.
  if (apercu) {
    const case_ = 200
    const vignettes = []
    for (const [i, { cle, fond }] of AVATARS.entries()) {
      const disque = Buffer.from(
        `<svg width="${case_}" height="${case_}"><circle cx="${case_ / 2}" cy="${case_ / 2}" r="${case_ / 2 - 10}" fill="${fond}"/></svg>`,
      )
      const tete = await sharp(path.join(SORTIE, `${cle}.webp`))
        .resize(case_ - 20, case_ - 20)
        .png()
        .toBuffer()
      const masque = Buffer.from(
        `<svg width="${case_ - 20}" height="${case_ - 20}"><circle cx="${(case_ - 20) / 2}" cy="${(case_ - 20) / 2}" r="${(case_ - 20) / 2}" fill="#fff"/></svg>`,
      )
      const teteRonde = await sharp(tete)
        .composite([{ input: masque, blend: 'dest-in' }])
        .png()
        .toBuffer()
      vignettes.push({
        input: await sharp(disque)
          .composite([{ input: teteRonde, left: 10, top: 10 }])
          .png()
          .toBuffer(),
        left: (i % 6) * case_,
        top: Math.floor(i / 6) * case_,
      })
    }
    await sharp({
      create: {
        width: case_ * 6,
        height: case_ * 2,
        channels: 4,
        background: { r: 0xfc, g: 0xef, b: 0xd0, alpha: 1 },
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
