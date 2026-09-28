/**
 * Essai de bout en bout de la chaîne IA, contre la vraie base et le vrai
 * fournisseur.
 *
 *   node scripts/essai-ingestion.mjs
 *
 * Ce qu'il fait : dépose un petit cours en texte dans le seau `cours`, crée la
 * ligne `courses`, enfile `ingest_course`, appelle `/api/jobs/run` autant de
 * fois qu'il faut pour vider la file, puis affiche ce qui est sorti —
 * chapitres, questions, fiches, et ce que les appels ont coûté d'après
 * `ai_usage`. Il nettoie tout derrière lui.
 *
 * Il faut un serveur de développement en marche (`npm run dev`) et, dans
 * `.env.local` : NEXT_PUBLIC_SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY,
 * CRON_SECRET et DEEPSEEK_API_KEY.
 *
 * Aucun secret n'est affiché : le script lit `.env.local` et ne recopie que
 * des identifiants et des compteurs.
 */

import fs from 'node:fs'
import path from 'node:path'
import { pdfDepuisTexte } from './pdf-minimal.mjs'

const racine = process.cwd()

const env = Object.fromEntries(
  fs
    .readFileSync(path.join(racine, '.env.local'), 'utf8')
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

const manquantes = Object.entries({
  NEXT_PUBLIC_SUPABASE_URL: URL_BASE,
  SUPABASE_SERVICE_ROLE_KEY: CLE,
  CRON_SECRET: CRON,
  DEEPSEEK_API_KEY: env.DEEPSEEK_API_KEY,
})
  .filter(([, v]) => !v)
  .map(([k]) => k)

if (manquantes.length > 0) {
  console.error(`Manque dans .env.local : ${manquantes.join(', ')}`)
  process.exit(1)
}

const entetes = {
  apikey: CLE,
  Authorization: `Bearer ${CLE}`,
  'content-type': 'application/json',
}

const rest = async (chemin, init = {}) => {
  const r = await fetch(`${URL_BASE}/rest/v1/${chemin}`, {
    ...init,
    headers: { ...entetes, ...(init.headers ?? {}) },
  })
  const texte = await r.text()
  if (!r.ok) throw new Error(`${chemin} → ${r.status} ${texte.slice(0, 300)}`)
  return texte ? JSON.parse(texte) : null
}

/** Un cours court mais structuré, pour que le découpage ait de quoi mordre. */
const COURS = `DROIT CONSTITUTIONNEL — LICENCE 1

CHAPITRE I — LA NOTION DE CONSTITUTION

La Constitution est la norme fondamentale de l'État : elle organise les
pouvoirs publics, fixe leurs compétences et garantit les droits des citoyens.
On distingue la Constitution au sens matériel, qui désigne l'ensemble des
règles relatives à l'organisation du pouvoir, et la Constitution au sens
formel, qui désigne le document adopté selon une procédure solennelle.

Une Constitution est dite rigide lorsque sa révision suit une procédure plus
lourde que celle des lois ordinaires. Elle est souple dans le cas contraire.
La Constitution béninoise du 11 décembre 1990 est rigide : sa révision exige
une majorité qualifiée et, dans certains cas, un référendum.

Au Bénin, cette Constitution a été adoptée par référendum le 2 décembre 1990,
à l'issue de la Conférence des Forces Vives de la Nation tenue en février de
la même année. Elle a ouvert la période dite du Renouveau démocratique.

CHAPITRE II — LE CONTRÔLE DE CONSTITUTIONNALITÉ

La Cour constitutionnelle est la plus haute juridiction de l'État en matière
constitutionnelle. Elle statue sur la constitutionnalité des lois, veille à la
régularité des élections nationales et garantit les droits fondamentaux.

Elle est composée de sept membres : quatre désignés par le Bureau de
l'Assemblée nationale et trois par le Président de la République. Leur mandat
est de cinq ans, renouvelable une seule fois. La présidence est assurée par un
magistrat élu par ses pairs.

Le contrôle peut être exercé avant la promulgation de la loi, sur saisine du
Président de la République ou de députés : c'est le contrôle a priori. Il peut
aussi l'être après, à l'occasion d'un litige, par la voie de l'exception
d'inconstitutionnalité que tout citoyen peut soulever.
`

async function main() {
  console.log('— Préparation')

  const [profil] = await rest('profiles?select=id,faculty_id&limit=1')
  if (!profil) throw new Error('Aucun profil en base : inscris-toi d’abord.')

  const [matiere] = await rest('subjects?select=id&limit=1')
  if (!matiere) throw new Error('Aucune matière en base.')

  const empreinte = `essai${Date.now()}`.padEnd(64, '0').slice(0, 64)
  const chemin = `${profil.id}/essai-${Date.now()}/source.pdf`

  // Un vrai PDF, avec une vraie couche de texte : l'essai doit emprunter le
  // chemin de production — `unpdf` — et non un format de contournement. Le
  // seau n'accepte de toute façon que PDF, Word et images.
  const pdf = pdfDepuisTexte(COURS)
  console.log(`  PDF fabriqué : ${(pdf.length / 1024).toFixed(1)} ko`)

  const envoi = await fetch(`${URL_BASE}/storage/v1/object/cours/${chemin}`, {
    method: 'POST',
    headers: {
      apikey: CLE,
      Authorization: `Bearer ${CLE}`,
      'content-type': 'application/pdf',
    },
    body: pdf,
  })
  if (!envoi.ok) {
    throw new Error(`Dépôt du fichier : ${envoi.status} ${(await envoi.text()).slice(0, 200)}`)
  }

  const [cours] = await rest('courses', {
    method: 'POST',
    headers: { Prefer: 'return=representation' },
    body: JSON.stringify({
      owner_id: profil.id,
      subject_id: matiere.id,
      title: 'Droit constitutionnel — essai',
      file_hash: empreinte,
      storage_path: chemin,
      status: 'processing',
    }),
  })
  console.log(`  cours ${cours.id}`)

  await rest('jobs', {
    method: 'POST',
    body: JSON.stringify({
      type: 'ingest_course',
      payload: { course_id: cours.id },
    }),
  })

  console.log('— Traitement')
  for (let passage = 1; passage <= 12; passage++) {
    const r = await fetch(`${API}/api/jobs/run`, {
      headers: { Authorization: `Bearer ${CRON}` },
    })
    const corps = await r.json()
    const data = corps.data ?? {}
    console.log(
      `  passage ${passage} : pris ${data.claimed ?? 0}, faits ${data.done ?? 0}, ` +
        `refaits ${data.requeued ?? 0}, abandonnés ${data.failed ?? 0}`,
    )
    for (const j of data.jobs ?? []) {
      if (j.error) console.log(`     ${j.type} → ${j.error.slice(0, 160)}`)
    }
    if ((data.claimed ?? 0) === 0) break
  }

  console.log('— Résultat')
  const [apres] = await rest(`courses?id=eq.${cours.id}&select=status,page_count`)
  const chapitres = await rest(
    `chapters?course_id=eq.${cours.id}&select=index,title,token_count,questions(id,type,statement),flashcards(id)&order=index`,
  )

  console.log(`  statut : ${apres.status}, pages : ${apres.page_count ?? '—'}`)
  for (const c of chapitres) {
    console.log(
      `  ${c.index}. ${c.title} — ${c.questions.length} questions, ` +
        `${c.flashcards.length} fiches, ~${c.token_count} jetons`,
    )
    const q = c.questions[0]
    if (q) console.log(`     ex. : ${q.statement.slice(0, 110)}`)
  }

  const usage = await rest(
    'ai_usage?select=provider,model,prompt_tokens,completion_tokens,cost_usd_estimate&order=created_at.desc&limit=20',
  )
  const cout = usage.reduce((t, u) => t + Number(u.cost_usd_estimate ?? 0), 0)
  console.log(`  appels consignés : ${usage.length}, coût estimé : ${cout.toFixed(4)} $`)

  console.log('— Nettoyage')
  await rest(`courses?id=eq.${cours.id}`, { method: 'DELETE' })
  await fetch(`${URL_BASE}/storage/v1/object/cours/${chemin}`, {
    method: 'DELETE',
    headers: { apikey: CLE, Authorization: `Bearer ${CLE}` },
  })
  await rest(`jobs?payload->>course_id=eq.${cours.id}`, { method: 'DELETE' })
  console.log('  fait')
}

main().catch((e) => {
  console.error('ÉCHEC :', e.message)
  process.exit(1)
})
