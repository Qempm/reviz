/**
 * Chronomètre la préparation d'un cours, **de la relance au statut « prêt »**,
 * contre le vrai déploiement.
 *
 *   API_BASE=https://revizapp.fun node scripts/mesure-lecture.mjs
 *
 * Ce qui est mesuré, c'est l'enchaînement : le script dépose un PDF de douze
 * chapitres, met la lecture en file, demande **une seule fois**
 * `/api/jobs/run?cours=…`, puis se contente de regarder. Aucun sondage ne
 * pousse le cours : s'il arrive à « prêt », c'est que le serveur s'est
 * enchaîné tout seul — lecture, puis lots de chapitres en parallèle.
 *
 * Le cours est rattaché au premier profil de la base, comme dans
 * `essai-ingestion.mjs`, et supprimé à la fin avec son fichier et ses jobs.
 * Il faut, dans `.env.local` : NEXT_PUBLIC_SUPABASE_URL,
 * SUPABASE_SERVICE_ROLE_KEY et CRON_SECRET (celui du déploiement visé).
 * Aucun secret n'est affiché.
 */

import fs from 'node:fs'
import path from 'node:path'
import { pdfDepuisTexte } from './pdf-minimal.mjs'

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
const LIMITE_S = Number(process.env.LIMITE_S ?? 420)

for (const [nom, v] of Object.entries({ NEXT_PUBLIC_SUPABASE_URL: URL_BASE, SUPABASE_SERVICE_ROLE_KEY: CLE, CRON_SECRET: CRON })) {
  if (!v) {
    console.error(`Manque dans .env.local : ${nom}`)
    process.exit(1)
  }
}

const entetes = { apikey: CLE, Authorization: `Bearer ${CLE}`, 'content-type': 'application/json' }
const rest = async (chemin, init = {}) => {
  const r = await fetch(`${URL_BASE}/rest/v1/${chemin}`, { ...init, headers: { ...entetes, ...(init.headers ?? {}) } })
  const texte = await r.text()
  if (!r.ok) throw new Error(`${chemin} → ${r.status} ${texte.slice(0, 300)}`)
  return texte ? JSON.parse(texte) : null
}

/** Douze chapitres de droit constitutionnel, de longueur réaliste. */
const THEMES = [
  ['LA NOTION DE CONSTITUTION', 'La Constitution est la norme fondamentale de l’État : elle organise les pouvoirs publics, fixe leurs compétences et garantit les droits des citoyens. On distingue la Constitution au sens matériel et la Constitution au sens formel, adoptée selon une procédure solennelle. Une Constitution est rigide lorsque sa révision suit une procédure plus lourde que celle des lois ordinaires.'],
  ['LA CONSTITUTION BÉNINOISE DE 1990', 'La Constitution béninoise du 11 décembre 1990 a été adoptée par référendum le 2 décembre 1990, à l’issue de la Conférence des Forces Vives de la Nation tenue en février de la même année. Elle a ouvert la période dite du Renouveau démocratique et consacre un régime présidentiel.'],
  ['LA COUR CONSTITUTIONNELLE', 'La Cour constitutionnelle est la plus haute juridiction de l’État en matière constitutionnelle. Elle statue sur la constitutionnalité des lois, veille à la régularité des élections nationales et garantit les droits fondamentaux. Elle compte sept membres, dont quatre désignés par le Bureau de l’Assemblée nationale et trois par le Président de la République.'],
  ['LE CONTRÔLE DE CONSTITUTIONNALITÉ', 'Le contrôle peut être exercé avant la promulgation de la loi, sur saisine du Président de la République ou de députés : c’est le contrôle a priori. Il peut aussi l’être après, par la voie de l’exception d’inconstitutionnalité que tout citoyen peut soulever devant un tribunal.'],
  ['LE PRÉSIDENT DE LA RÉPUBLIQUE', 'Le Président de la République est élu au suffrage universel direct pour un mandat de cinq ans, renouvelable une seule fois. Il est le chef de l’État et le chef du Gouvernement. Il détermine et conduit la politique de la Nation, et nomme les ministres.'],
  ['L’ASSEMBLÉE NATIONALE', 'L’Assemblée nationale exerce le pouvoir législatif et contrôle l’action du Gouvernement. Ses membres, les députés, sont élus au suffrage universel direct. Elle vote les lois et consent l’impôt ; elle peut interpeller le Gouvernement et constituer des commissions d’enquête.'],
  ['LA SÉPARATION DES POUVOIRS', 'La séparation des pouvoirs distingue l’exécutif, le législatif et le judiciaire, afin qu’aucun ne concentre toute l’autorité. Théorisée par Montesquieu, elle se traduit par des organes distincts et par des mécanismes de contrôle réciproque, les freins et contrepoids.'],
  ['LE POUVOIR JUDICIAIRE', 'Le pouvoir judiciaire est indépendant du pouvoir législatif et du pouvoir exécutif. Il est exercé par la Cour suprême, les cours et les tribunaux. Les juges ne sont soumis, dans l’exercice de leurs fonctions, qu’à l’autorité de la loi.'],
  ['LES DROITS FONDAMENTAUX', 'La Constitution garantit les droits et libertés de la personne humaine : droit à la vie, liberté d’opinion et d’expression, liberté de réunion et d’association, droit à l’éducation. La Charte africaine des droits de l’homme et des peuples fait partie intégrante de la Constitution.'],
  ['LA RÉVISION CONSTITUTIONNELLE', 'L’initiative de la révision appartient concurremment au Président de la République et aux députés. La révision exige une majorité qualifiée à l’Assemblée nationale et, dans certains cas, un référendum. La forme républicaine et la laïcité de l’État ne peuvent faire l’objet d’une révision.'],
  ['LA HAUTE COUR DE JUSTICE', 'La Haute Cour de justice est compétente pour juger le Président de la République et les membres du Gouvernement à raison de faits qualifiés de haute trahison ou d’infractions commises dans l’exercice de leurs fonctions.'],
  ['LES COLLECTIVITÉS TERRITORIALES', 'Les collectivités territoriales s’administrent librement par des conseils élus, dans les conditions prévues par la loi. La décentralisation rapproche l’administration des citoyens et confie aux communes des compétences propres en matière de développement local.'],
]

const COURS =
  'DROIT CONSTITUTIONNEL — LICENCE 1\n\n' +
  THEMES.map(([titre, texte], i) => {
    const romain = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII'][i]
    // Trois fois le paragraphe : un chapitre de cours, pas une ligne.
    return `CHAPITRE ${romain} — ${titre}\n\n${texte}\n\n${texte}\n\n${texte}\n`
  }).join('\n')

const attendre = (ms) => new Promise((r) => setTimeout(r, ms))

async function main() {
  const [profil] = await rest('profiles?select=id&limit=1')
  const [matiere] = await rest('subjects?select=id&limit=1')
  if (!profil || !matiere) throw new Error('Il faut un profil et une matière en base.')

  const chemin = `${profil.id}/mesure-${Date.now()}/source.pdf`
  const pdf = pdfDepuisTexte(COURS)

  const envoi = await fetch(`${URL_BASE}/storage/v1/object/cours/${chemin}`, {
    method: 'POST',
    headers: { apikey: CLE, Authorization: `Bearer ${CLE}`, 'content-type': 'application/pdf' },
    body: pdf,
  })
  if (!envoi.ok) throw new Error(`Dépôt du fichier : ${envoi.status}`)

  const [cours] = await rest('courses', {
    method: 'POST',
    headers: { Prefer: 'return=representation' },
    body: JSON.stringify({
      owner_id: profil.id,
      subject_id: matiere.id,
      title: 'Mesure de lecture (supprimé à la fin)',
      file_hash: `mesure${Date.now()}`.padEnd(64, '0').slice(0, 64),
      storage_path: chemin,
      status: 'processing',
    }),
  })

  try {
    await rest('jobs', {
      method: 'POST',
      body: JSON.stringify({ type: 'ingest_course', payload: { course_id: cours.id, vision: false } }),
    })

    console.log(`PDF de ${THEMES.length} chapitres déposé ; une seule relance, puis on regarde.`)
    const t0 = Date.now()

    const relance = await fetch(`${API}/api/jobs/run?cours=${cours.id}`, {
      headers: { authorization: `Bearer ${CRON}` },
    })
    console.log(`  relance : HTTP ${relance.status}`)

    let dernier = ''
    while ((Date.now() - t0) / 1000 < LIMITE_S) {
      await attendre(3000)
      const [etat] = await rest(`courses?id=eq.${cours.id}&select=status`)
      const chapitres = await rest(`chapters?course_id=eq.${cours.id}&select=id,questions(id)`)
      const faits = chapitres.filter((c) => c.questions.length > 0).length
      const ligne = `${etat.status} — ${faits}/${chapitres.length} chapitres prêts`
      if (ligne !== dernier) {
        console.log(`  ${((Date.now() - t0) / 1000).toFixed(0).padStart(4)} s : ${ligne}`)
        dernier = ligne
      }
      if (etat.status === 'ready' || etat.status === 'failed') break
    }

    console.log(`Durée totale : ${((Date.now() - t0) / 1000).toFixed(0)} s`)

    // Une durée courte ne prouve rien si l'IA a échoué : un chapitre raté
    // reçoit une question ouverte de secours, instantanément. On compte.
    const questions = await rest(
      `questions?select=type,chapters!inner(course_id)&chapters.course_id=eq.${cours.id}`,
    )
    const fiches = await rest(
      `flashcards?select=id,chapters!inner(course_id)&chapters.course_id=eq.${cours.id}`,
    )
    const qcm = questions.filter((q) => q.type === 'mcq').length
    console.log(
      `Contenu : ${qcm} QCM, ${questions.length - qcm} question(s) de secours, ${fiches.length} fiches`,
    )

    // Pas prêt : on dit pourquoi, tel que la file l'a consigné. Les erreurs
    // des fournisseurs ne portent pas de secret, mais on masque par principe
    // tout ce qui ressemblerait à une clé.
    const jobs = await rest(
      `jobs?select=type,status,attempts,last_error&payload->>course_id=eq.${cours.id}&order=created_at`,
    )
    for (const j of jobs) {
      if (j.last_error) {
        console.log(
          `  ${j.type} (${j.status}, essai ${j.attempts}) : ` +
            j.last_error.replace(/(sk|pk|wh)[-_][A-Za-z0-9_-]+/g, '$1-…').slice(0, 400),
        )
      }
    }
  } finally {
    await rest(`courses?id=eq.${cours.id}`, { method: 'DELETE' })
    await fetch(`${URL_BASE}/storage/v1/object/cours/${chemin}`, {
      method: 'DELETE',
      headers: { apikey: CLE, Authorization: `Bearer ${CLE}` },
    })
    await rest(`jobs?payload->>course_id=eq.${cours.id}`, { method: 'DELETE' })
    console.log('Nettoyé.')
  }
}

main().catch((e) => {
  console.error('ÉCHEC :', e.message)
  process.exit(1)
})
