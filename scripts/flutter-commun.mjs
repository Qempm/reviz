/**
 * Ce que partagent les compilations de l'application : `npm run apk` et
 * `npm run web`.
 *
 * Les deux lisent `.env.local`, refusent de compiler si une valeur manque, et
 * refusent surtout qu'un secret serveur passe en `--dart-define` : un APK se
 * décompile, et une application web se lit dans le navigateur — tout ce
 * qu'elles embarquent est public. Le contrôle vit ici pour n'exister qu'une
 * fois.
 */

import { spawnSync } from 'node:child_process'
import { existsSync, readFileSync } from 'node:fs'
import path from 'node:path'
import process from 'node:process'

export const RACINE = path.resolve(import.meta.dirname, '..')
export const MOBILE = path.join(RACINE, 'apps', 'mobile')

/**
 * Ce que le client a besoin de savoir, et son origine dans `.env.local`.
 *
 * `GOOGLE_WEB_CLIENT_ID` est facultatif : sans lui le bouton Google reste
 * désactivé, ce qui est honnête et n'empêche pas la connexion par e-mail.
 */
export const DEFINES = [
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
export function lireEnv(fichier) {
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

export function echouer(message) {
  console.error(`\n${message}\n`)
  process.exit(1)
}

export const env = { ...lireEnv(path.join(RACINE, '.env.local')), ...process.env }

/**
 * Les `--dart-define`, lus dans l'environnement.
 *
 * `sauf` retire des clés que la cible n'utilise pas (le web n'a pas de
 * connexion Google). Refuse de continuer si une valeur requise manque, ou si
 * un secret serveur s'y est glissé.
 */
export function defines({ sauf = [], pourquoi = '' } = {}) {
  const args = []
  const manquantes = []

  for (const { define, env: cle, requis } of DEFINES) {
    if (sauf.includes(define)) continue
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
        'Ces valeurs vivent dans .env.local, que git ignore. ' +
        pourquoi +
        '\nAPI_BASE est l’origine des routes Next.js déployées.',
    )
  }

  // La clé de service ne doit jamais descendre dans un client. Ce contrôle
  // est là pour qu'un ajout distrait à DEFINES se voie tout de suite.
  if (args.some((a) => /SERVICE_ROLE|DEEPSEEK|FEDAPAY|DASHSCOPE|ZAI_|CRON/i.test(a))) {
    echouer(
      'Un secret serveur figure parmi les --dart-define. Une application se ' +
        'décompile : tout ce qu’elle embarque est public. Compilation refusée.',
    )
  }

  return args
}

/**
 * Où est Flutter.
 *
 * Pas d'hypothèse sur le `PATH` : sur une machine où Flutter est installé par
 * Android Studio, il n'y est pas, et la compilation échouait alors sur
 * « 'flutter.bat' n'est pas reconnu » après avoir déjà lu la configuration.
 * L'ordre : `FLUTTER_BIN` s'il est posé, puis le `PATH`, puis les endroits
 * habituels.
 */
export function trouverFlutter() {
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

/** Lance Flutter dans `apps/mobile`, en masquant les valeurs dans le journal. */
export function lancerFlutter(args) {
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
  return resultat.status ?? 1
}
