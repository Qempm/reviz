#!/usr/bin/env node
/**
 * Le serveur Next branché sur la pile Supabase **locale**, pour les essais
 * de bout en bout.
 *
 *   supabase start          # une fois : Postgres, Auth, Storage, Mailpit
 *   npm run dev:local       # Next sur http://localhost:3001
 *
 * Ce que ce lanceur garantit :
 *
 *  - l'URL et les clés Supabase sont celles de la pile locale
 *    (`supabase status`), jamais celles de la production ;
 *  - FedaPay tourne en **sandbox** : `FEDAPAY_SECRET_KEY` prend la valeur de
 *    `FEDAPAY_SANDBOX_SECRET_KEY` (`.env.local`) ; sans elle, la clé est
 *    vidée plutôt que de laisser partir la clé de production depuis un poste
 *    d'essai ;
 *  - aucune valeur n'est écrite sur le disque ni affichée : elles ne vivent
 *    que dans l'environnement du processus lancé.
 *
 * Les clés IA restent celles de `.env.local` : un essai de bout en bout lit
 * un vrai cours.
 */

import { execFileSync, spawn } from 'node:child_process'
import { readFileSync } from 'node:fs'
import process from 'node:process'

const PORT = process.env.PORT ?? '3001'

function lireEnv(fichier) {
  const valeurs = {}
  let brut = ''
  try {
    brut = readFileSync(fichier, 'utf8')
  } catch {
    return valeurs
  }
  for (const ligne of brut.split(/\r?\n/)) {
    const m = /^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/.exec(ligne.trim())
    if (m) valeurs[m[1]] = m[2].replace(/^["']|["']$/g, '')
  }
  return valeurs
}

let statut
try {
  statut = JSON.parse(
    execFileSync('supabase', ['status', '-o', 'json'], {
      encoding: 'utf8',
      shell: process.platform === 'win32',
      stdio: ['ignore', 'pipe', 'ignore'],
    }),
  )
} catch {
  console.error('La pile Supabase locale ne répond pas. Lance d’abord : supabase start')
  process.exit(1)
}

const locales = lireEnv('.env.local')
const sandbox = locales.FEDAPAY_SANDBOX_SECRET_KEY ?? ''
if (sandbox && !sandbox.startsWith('sk_sandbox_')) {
  console.error('FEDAPAY_SANDBOX_SECRET_KEY doit commencer par sk_sandbox_.')
  process.exit(1)
}

const env = {
  ...process.env,
  NEXT_PUBLIC_SUPABASE_URL: statut.API_URL,
  NEXT_PUBLIC_SUPABASE_ANON_KEY: statut.ANON_KEY,
  SUPABASE_SERVICE_ROLE_KEY: statut.SERVICE_ROLE_KEY,
  FEDAPAY_SECRET_KEY: sandbox,
  // Le webhook FedaPay ne joint pas un poste local : le suivi passe par
  // /api/payments/status, qui relit la transaction chez FedaPay.
  FEDAPAY_WEBHOOK_SECRET: '',
}

console.log(
  `Next sur http://localhost:${PORT} — Supabase local (${statut.API_URL}), FedaPay ${
    sandbox ? 'sandbox' : 'désactivé (pas de clé sandbox)'
  }.`,
)

const next = spawn('npx', ['next', 'dev', '-p', PORT], {
  env,
  stdio: 'inherit',
  shell: process.platform === 'win32',
})
next.on('exit', (code) => process.exit(code ?? 0))
