#!/usr/bin/env node
/**
 * Fabrique la version web de l'application et la pose dans `public/web/`.
 *
 *   npm run web
 *
 * La même application Flutter que l'APK, compilée pour le navigateur
 * (arbitrage du 1er octobre 2026) : pour qui a un ordinateur ou un iPhone.
 * Next.js sert `public/web/` tel quel sur `/web` — même domaine que les
 * routes `/api/*`, donc aucun réglage CORS — et `next.config.mjs` fait de
 * `/web` la page d'entrée.
 *
 * Le résultat est **commité** : Vercel n'a pas Flutter, il ne compile que
 * Next.js. Après chaque changement de l'application, relancer ce script et
 * committer `public/web/` avec le reste.
 *
 * Pas de `GOOGLE_WEB_CLIENT_ID` : sur le web, la connexion se fait par e-mail
 * (`lib/metier/plateforme.dart`). Et comme pour l'APK, aucun secret serveur
 * ne passe : ce qui est compilé ici se lit dans le navigateur de n'importe
 * qui.
 */

import { createHash } from 'node:crypto'
import { cpSync, existsSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs'
import path from 'node:path'
import process from 'node:process'
import { defines, echouer, lancerFlutter, MOBILE, RACINE } from './flutter-commun.mjs'

const args = [
  'build',
  'web',
  '--release',
  '--base-href',
  '/web/',
  ...defines({
    // Ni Google ni push dans le navigateur (lib/metier/plateforme.dart).
    sauf: [
      'GOOGLE_WEB_CLIENT_ID',
      'FIREBASE_PROJECT_ID',
      'FIREBASE_SENDER_ID',
      'FIREBASE_ANDROID_API_KEY',
      'FIREBASE_ANDROID_APP_ID',
      'FIREBASE_IOS_API_KEY',
      'FIREBASE_IOS_APP_ID',
    ],
    pourquoi: 'Sans elles, la page s’ouvrirait sur un bandeau « configuration absente ».',
  }),
  ...process.argv.slice(2),
]

const statut = lancerFlutter(args)
if (statut !== 0) process.exit(statut)

const source = path.join(MOBILE, 'build', 'web')
const cible = path.join(RACINE, 'public', 'web')
if (!existsSync(path.join(source, 'index.html'))) {
  echouer(`Compilation réussie, mais ${source} n’a pas d’index.html.`)
}

rmSync(cible, { recursive: true, force: true })
cpSync(source, cible, { recursive: true })

// CanvasKit (le moteur de rendu) se charge par défaut depuis le CDN de
// Google, www.gstatic.com/flutter-canvaskit — `useLocalCanvasKit` n'est pas
// posé. La copie locale ne servirait donc jamais, et pèse 37 des 43 Mo de
// la compilation : committée à chaque version, elle alourdirait le dépôt
// pour rien.
rmSync(path.join(cible, 'canvaskit'), { recursive: true, force: true })

// Le service worker de Flutter ne fait que se désinscrire : le nôtre
// (`apps/mobile/web/sw.js`) garde l'application pour le hors-ligne. On lui
// donne la liste des fichiers à garder et une version tirée de leur contenu :
// une nouvelle compilation remplace l'ancienne copie d'un coup.
rmSync(path.join(cible, 'flutter_service_worker.js'), { force: true })

/** Ce qui n'a rien à faire dans la copie hors ligne. */
const HORS_COPIE = new Set([
  'sw.js',
  '.last_build_id',
  'assets/NOTICES', // les licences : 1,4 Mo, lues par personne hors ligne
  'icons/Icon-512.png', // pour le manifeste seulement
  'icons/Icon-maskable-512.png',
])

function lister(dossier, prefixe = '') {
  const fichiers = []
  for (const nom of readdirSync(dossier).sort()) {
    const chemin = path.join(dossier, nom)
    const relatif = prefixe + nom
    if (statSync(chemin).isDirectory()) {
      // Les écrans de lancement, iOS les lit lui-même à l'installation.
      if (relatif === 'lancement') continue
      fichiers.push(...lister(chemin, relatif + '/'))
    } else if (!HORS_COPIE.has(relatif)) {
      fichiers.push(relatif)
    }
  }
  return fichiers
}

const aGarder = lister(cible)
const empreinte = createHash('sha256')
for (const f of aGarder) empreinte.update(f).update(readFileSync(path.join(cible, f)))
const version = empreinte.digest('hex').slice(0, 12)
const sw = path.join(cible, 'sw.js')
if (!existsSync(sw)) echouer('public/web/sw.js manque : apps/mobile/web/sw.js a-t-il disparu ?')
writeFileSync(
  sw,
  readFileSync(sw, 'utf8')
    .replace("'__VERSION__'", JSON.stringify(version))
    .replace('__FICHIERS__', JSON.stringify(aGarder, null, 2)),
)

function taille(dossier) {
  let total = 0
  for (const nom of readdirSync(dossier)) {
    const chemin = path.join(dossier, nom)
    const s = statSync(chemin)
    total += s.isDirectory() ? taille(chemin) : s.size
  }
  return total
}

const mo = (o) => `${(o / 1024 / 1024).toFixed(1)} Mo`
console.log(`
Version web posée dans public/web/ (${mo(taille(cible))} sur disque).
  main.dart.js : ${mo(statSync(path.join(cible, 'main.dart.js')).size)}
  hors ligne   : ${aGarder.length} fichiers gardés par sw.js (version ${version})

À committer avec le reste, puis : https://revizapp.fun/web
`)
