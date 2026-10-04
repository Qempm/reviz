/**
 * Régénère les questions d'un cours resté sur des questions de secours.
 *
 *   API_BASE=https://revizapp.fun node scripts/regenerer-cours.mjs <course_id>
 *
 * Le 29 septembre 2026, faute de clé IA en production, chaque chapitre des
 * cours traités a reçu la question de secours (« Relis … et résume-le en
 * cinq lignes ») et le cours est passé « prêt » — sans aucun QCM. Rien ne
 * relance un cours prêt : ce script le fait, pour un cours donné.
 *
 * Il ne supprime **que** les questions de secours (type `open`, énoncé
 * « Relis « … » et résume-le en cinq lignes. »), jamais un QCM ni une
 * tentative d'étudiant ; remet le cours en `processing` ; met un job
 * `generate_questions` en file ; et demande une invocation au serveur, qui
 * s'enchaîne ensuite seul. Puis il regarde, jusqu'à « prêt ».
 *
 * Il faut, dans `.env.local` : NEXT_PUBLIC_SUPABASE_URL,
 * SUPABASE_SERVICE_ROLE_KEY et CRON_SECRET. Aucun secret n'est affiché.
 */

import fs from 'node:fs'
import path from 'node:path'

const env = Object.fromEntries(
  fs
    .readFileSync(path.join(process.cwd(), '.env.local'), 'utf8')
    .split(/\r?\n/)
    .filter((l) => l.includes('=') && !l.trimStart().startsWith('#'))
    .map((l) => {
      const i = l.indexOf('=')
      return [l.slice(0, i).trim(), l.slice(i + 1).trim().replace(/^["']|["']$/g, '')]
    }),
)

const URL_BASE = env.NEXT_PUBLIC_SUPABASE_URL
const CLE = env.SUPABASE_SERVICE_ROLE_KEY
const CRON = env.CRON_SECRET
const API = process.env.API_BASE ?? 'http://localhost:3000'
const coursId = process.argv[2]

if (!coursId || !/^[0-9a-f-]{36}$/.test(coursId)) {
  console.error('Usage : node scripts/regenerer-cours.mjs <course_id>')
  process.exit(1)
}

const entetes = { apikey: CLE, Authorization: `Bearer ${CLE}`, 'content-type': 'application/json' }
const rest = async (chemin, init = {}) => {
  const r = await fetch(`${URL_BASE}/rest/v1/${chemin}`, { ...init, headers: { ...entetes, ...(init.headers ?? {}) } })
  const texte = await r.text()
  if (!r.ok) throw new Error(`${chemin} → ${r.status} ${texte.slice(0, 300)}`)
  return texte ? JSON.parse(texte) : null
}
const attendre = (ms) => new Promise((r) => setTimeout(r, ms))

const estSecours = (q) =>
  q.type === 'open' && /^Relis « .* » et résume-le en cinq lignes\.$/.test(q.statement)

async function etat() {
  const chapitres = await rest(
    `chapters?course_id=eq.${coursId}&select=id,questions(id,type,statement),flashcards(id)`,
  )
  const qs = chapitres.flatMap((c) => c.questions)
  return {
    chapitres,
    qcm: qs.filter((q) => q.type === 'mcq').length,
    secours: qs.filter(estSecours),
    fiches: chapitres.reduce((t, c) => t + c.flashcards.length, 0),
  }
}

async function main() {
  const [cours] = await rest(`courses?id=eq.${coursId}&select=id,title,status`)
  if (!cours) throw new Error('Cours introuvable.')

  const avant = await etat()
  console.log(
    `« ${cours.title} » (${cours.status}) : ${avant.chapitres.length} chapitres, ` +
      `${avant.qcm} QCM, ${avant.secours.length} questions de secours, ${avant.fiches} fiches`,
  )

  if (avant.secours.length === 0) {
    console.log('Aucune question de secours : rien à régénérer.')
    return
  }

  // Seulement les questions de secours, par leur identifiant.
  const ids = avant.secours.map((q) => q.id)
  for (let i = 0; i < ids.length; i += 50) {
    await rest(`questions?id=in.(${ids.slice(i, i + 50).join(',')})`, { method: 'DELETE' })
  }
  await rest(`courses?id=eq.${coursId}`, {
    method: 'PATCH',
    body: JSON.stringify({ status: 'processing' }),
  })
  await rest('jobs', {
    method: 'POST',
    body: JSON.stringify({ type: 'generate_questions', payload: { course_id: coursId } }),
  })
  console.log(`${ids.length} questions de secours retirées ; cours remis en préparation.`)

  const t0 = Date.now()
  const relance = await fetch(`${API}/api/jobs/run?cours=${coursId}`, {
    headers: { authorization: `Bearer ${CRON}` },
  })
  console.log(`Relance : HTTP ${relance.status}`)

  let dernier = ''
  while ((Date.now() - t0) / 1000 < 600) {
    await attendre(5000)
    const [c] = await rest(`courses?id=eq.${coursId}&select=status`)
    const e = await etat()
    const faits = e.chapitres.filter((ch) => ch.questions.length > 0).length
    const ligne = `${c.status} — ${faits}/${e.chapitres.length} chapitres, ${e.qcm} QCM, ${e.fiches} fiches`
    if (ligne !== dernier) {
      console.log(`  ${((Date.now() - t0) / 1000).toFixed(0).padStart(4)} s : ${ligne}`)
      dernier = ligne
    }
    if (c.status === 'ready' || c.status === 'failed') break
  }

  const jobs = await rest(
    `jobs?select=type,status,attempts,last_error&payload->>course_id=eq.${coursId}&last_error=not.is.null&order=created_at.desc&limit=3`,
  )
  for (const j of jobs) {
    console.log(`  ${j.type} (${j.status}) : ${j.last_error.replace(/(sk|pk|wh)[-_][A-Za-z0-9_-]+/g, '$1-…').slice(0, 300)}`)
  }
}

main().catch((e) => {
  console.error('ÉCHEC :', e.message)
  process.exit(1)
})
