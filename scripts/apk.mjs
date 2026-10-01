#!/usr/bin/env node
/**
 * Fabrique l'APK de release, avec sa configuration.
 *
 * Le piège que ce script existe pour éviter : `flutter build apk --release`
 * sans `--dart-define` produit un APK qui **s'installe et démarre**, puis
 * affiche un bandeau rouge « configuration absente » — `Config.supabaseUrl`
 * est une chaîne vide, donc rien ne se connecte. Rien dans la compilation ne
 * le signale, et un APK partagé par WhatsApp ne se reprend pas.
 *
 * Il lit donc `.env.local`, refuse de compiler si une valeur manque, et rend
 * à la fin exactement ce que `lib/metier/publication.ts` attend : le chemin,
 * la taille en octets et l'empreinte SHA-256.
 *
 *   npm run apk
 *   npm run apk -- --split-per-abi     # trois fichiers, un par architecture
 *
 * Tout argument passé après `--` est transmis à `flutter build apk`. Cela
 * compte : l'APK unique **mesure 55,5 Mo** (mesuré le 28 septembre 2026), ce
 * qui est beaucoup pour un forfait data béninois et un partage par WhatsApp.
 * `--split-per-abi` le ramène à un tiers, au prix d'avoir à choisir le bon
 * fichier — et un mauvais choix ne s'installe pas. Le fichier unique reste
 * donc le défaut, mais le levier est là.
 *
 * Aucun secret ne traverse ce fichier autrement que par l'environnement :
 * `.env.local` est ignoré par git, et la clé de service **n'est jamais
 * passée** — un APK se décompile, tout ce qu'il embarque est public.
 */

import { createHash } from 'node:crypto'
import { readFileSync, statSync } from 'node:fs'
import path from 'node:path'
import process from 'node:process'
import { defines, echouer, lancerFlutter, MOBILE } from './flutter-commun.mjs'

// Ce que l'appelant ajoute (`npm run apk -- --split-per-abi`) passe tel quel.
const supplements = process.argv.slice(2)

const args = [
  'build',
  'apk',
  '--release',
  ...defines({
    pourquoi:
      'Sans elles, l’APK démarrerait sur un bandeau « configuration absente » ' +
      '— et un fichier partagé par WhatsApp ne se reprend pas.',
  }),
  ...supplements,
]

const statut = lancerFlutter(args)
if (statut !== 0) {
  // Le gradle arrête lui-même une release sans clé de signature, avec la
  // marche à suivre : on ne la répète pas ici.
  process.exit(statut)
}

const apk = path.join(
  MOBILE,
  'build',
  'app',
  'outputs',
  'flutter-apk',
  'app-release.apk',
)

let octets
try {
  octets = statSync(apk).size
} catch {
  echouer(
    `Compilation réussie, mais ${path.basename(apk)} est absent.
` +
      'Avec --split-per-abi, les fichiers sont nommés par architecture : ' +
      'regarde build/app/outputs/flutter-apk/ et calcule l’empreinte du ' +
      'fichier que tu publies (sha256sum).',
  )
}
const sha256 = createHash('sha256').update(readFileSync(apk)).digest('hex')

console.log(`
APK : ${apk}

À reporter dans lib/metier/publication.ts, une fois le fichier publié en
release GitHub :

export const APK: Apk = {
  publie: true,
  url: 'https://github.com/<owner>/reviz/releases/download/v<version>/reviz-<version>.apk',
  tailleOctets: ${octets},
  sha256: '${sha256}',
}
`)
