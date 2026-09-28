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
import { spawnSync } from 'node:child_process'
import { existsSync, readFileSync, statSync } from 'node:fs'
import path from 'node:path'
import process from 'node:process'

const RACINE = path.resolve(import.meta.dirname, '..')
const MOBILE = path.join(RACINE, 'apps', 'mobile')

/**
 * Ce que le client a besoin de savoir, et son origine dans `.env.local`.
 *
 * `GOOGLE_WEB_CLIENT_ID` est facultatif : sans lui le bouton Google reste
 * désactivé, ce qui est honnête et n'empêche pas la connexion par e-mail.
 */
const DEFINES = [
  { define: 'SUPABASE_URL', env: 'NEXT_PUBLIC_SUPABASE_URL', requis: true },
  {
    define: 'SUPABASE_ANON_KEY',
    env: 'NEXT_PUBLIC_SUPABASE_ANON_KEY',
    requis: true,
  },
  { define: 'API_BASE', env: 'API_BASE', requis: true },
  { define: 'GOOGLE_WEB_CLIENT_ID', env: 'GOOGLE_WEB_CLIENT_ID', requis: false },
  // Facultatif aussi : sans lui, l'écran d'aide ne propose pas de contact
  // plutôt que d'ouvrir un numéro qui ne répond pas.
  { define: 'CONTACT_WHATSAPP', env: 'CONTACT_WHATSAPP', requis: false },
]

/** Lecture minimale d'un `.env` : `CLE=valeur`, guillemets optionnels. */
function lireEnv(fichier) {
  let brut
  try {
    brut = readFileSync(fichier, 'utf8')
  } catch {
    return {}
  }

  const valeurs = {}
  for (const ligne of brut.split(/\r?\n/)) {
    const nette = ligne.trim()
    if (nette.length === 0 || nette.startsWith('#')) continue

    const coupe = nette.indexOf('=')
    if (coupe <= 0) continue

    const cle = nette.slice(0, coupe).trim()
    let valeur = nette.slice(coupe + 1).trim()
    if (
      (valeur.startsWith('"') && valeur.endsWith('"')) ||
      (valeur.startsWith("'") && valeur.endsWith("'"))
    ) {
      valeur = valeur.slice(1, -1)
    }
    valeurs[cle] = valeur
  }
  return valeurs
}

function echouer(message) {
  console.error(`\n${message}\n`)
  process.exit(1)
}

const env = { ...lireEnv(path.join(RACINE, '.env.local')), ...process.env }

// Ce que l'appelant ajoute (`npm run apk -- --split-per-abi`) passe tel quel.
const supplements = process.argv.slice(2)

const args = ['build', 'apk', '--release']
const manquantes = []

for (const { define, env: cle, requis } of DEFINES) {
  const valeur = env[cle]
  if (!valeur) {
    if (requis) manquantes.push(cle)
    continue
  }
  args.push(`--dart-define=${define}=${valeur}`)
}

if (manquantes.length > 0) {
  echouer(
    `Configuration incomplète : ${manquantes.join(', ')}.\n\n` +
      'Ces valeurs vivent dans .env.local, que git ignore. Sans elles, ' +
      'l’APK démarrerait sur un bandeau « configuration absente » — et un ' +
      'fichier partagé par WhatsApp ne se reprend pas.\n' +
      'API_BASE est l’origine des routes Next.js déployées.',
  )
}

// La clé de service ne doit jamais descendre dans un APK. Ce contrôle est là
// pour qu'un ajout distrait à DEFINES se voie tout de suite.
if (args.some((a) => /SERVICE_ROLE|DEEPSEEK|FEDAPAY|DASHSCOPE|ZAI_|CRON/i.test(a))) {
  echouer(
    'Un secret serveur figure parmi les --dart-define. Un APK se décompile : ' +
      'tout ce qu’il embarque est public. Compilation refusée.',
  )
}

args.push(...supplements)

/**
 * Où est Flutter.
 *
 * Pas d'hypothèse sur le `PATH` : sur une machine où Flutter est installé par
 * Android Studio, il n'y est pas, et la compilation échouait alors sur
 * « 'flutter.bat' n'est pas reconnu » après avoir déjà lu la configuration.
 * L'ordre : `FLUTTER_BIN` s'il est posé, puis le `PATH`, puis les endroits
 * habituels.
 */
function trouverFlutter() {
  const nom = process.platform === 'win32' ? 'flutter.bat' : 'flutter'

  if (env.FLUTTER_BIN) {
    if (!existsSync(env.FLUTTER_BIN)) {
      echouer(`FLUTTER_BIN ne désigne aucun fichier : ${env.FLUTTER_BIN}`)
    }
    return env.FLUTTER_BIN
  }

  // Sur le PATH ? `--version` est inoffensif et rapide.
  const essai = spawnSync(nom, ['--version'], {
    stdio: 'ignore',
    shell: process.platform === 'win32',
  })
  if (essai.status === 0) return nom

  const habituels =
    process.platform === 'win32'
      // Barres obliques : Windows les accepte, et elles évitent une famille
      // de bogues silencieux — en JavaScript, 'C:\src' vaut « C:src », parce
      // que \s, \f et \b sont des séquences d'échappement.
      ? [
          'C:/src/flutter/bin/flutter.bat',
          path.join(env.LOCALAPPDATA ?? '', 'flutter', 'bin', 'flutter.bat'),
          path.join(env.USERPROFILE ?? '', 'flutter', 'bin', 'flutter.bat'),
          'C:/flutter/bin/flutter.bat',
        ]
      : [
          '/opt/flutter/bin/flutter',
          path.join(env.HOME ?? '', 'flutter', 'bin', 'flutter'),
          '/usr/local/flutter/bin/flutter',
        ]

  for (const candidat of habituels) {
    if (candidat && existsSync(candidat)) return candidat
  }

  echouer(
    'Flutter est introuvable.\n\n' +
      'Ajoute son dossier `bin` au PATH, ou pose FLUTTER_BIN dans ' +
      '.env.local :\n' +
      `  FLUTTER_BIN=${
        process.platform === 'win32'
          ? 'C:/src/flutter/bin/flutter.bat'
          : '/opt/flutter/bin/flutter'
      }`,
  )
}

const flutter = trouverFlutter()
console.log(
  `\n$ ${flutter} ${args
    // Les valeurs sont masquées : ce journal finit souvent collé quelque part.
    .map((a) => a.replace(/^(--dart-define=[A-Z_]+=).+$/, '$1…'))
    .join(' ')}\n`,
)

const resultat = spawnSync(flutter, args, {
  cwd: MOBILE,
  stdio: 'inherit',
  shell: process.platform === 'win32',
})

if (resultat.status !== 0) {
  // Le gradle arrête lui-même une release sans clé de signature, avec la
  // marche à suivre : on ne la répète pas ici.
  process.exit(resultat.status ?? 1)
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
