import 'server-only'
import { AiError, runAiTask, recordAiUsage, tuteurTourSchema, type TuteurTour } from '@/lib/ai'
import { createAdminClient } from '@/lib/supabase/admin'
import type { ClientReviz } from '@/lib/supabase/jeton'
import { etatAcces, type PackCode } from '@/lib/payments/subscriptions'
import {
  entreeDemarrer,
  entreeRepondre,
  messagesTuteur,
  peutVerifier,
  QUESTIONS_PAR_SESSION,
  scoreDe,
  suiteAttendue,
  verdictDe,
  type ContexteTuteur,
  type Echange,
  type Niveau,
  type RefusTuteur,
} from './tuteur'

/**
 * Le tuteur de maîtrise, côté base et modèle. Les règles sont dans
 * `tuteur.ts` ; ici, on lit, on appelle Claude, on écrit.
 *
 * L'accès se lit sous l'identité de l'étudiant (sa RLS) ; les écritures
 * passent par le rôle de service, la seule voie que la RLS laisse ouverte sur
 * `tuteur_sessions` et `tuteur_messages`.
 */

export type ErreurTuteur =
  | 'invalide'
  | RefusTuteur
  | 'introuvable'
  | 'terminee'
  | 'ia-indisponible'
  | 'serveur'

export type Evaluation = { niveau: Niveau; retour: string }

export type SuiteTuteur =
  | { type: 'question'; texte: string; numero: number; total: number }
  | {
      type: 'fin'
      verdict: 'maitrise' | 'a_revoir'
      score: number
      bilan: string
      aRevoir: string[]
    }

export type Demarrage =
  | { ok: true; sessionId: string; essai: boolean; suite: SuiteTuteur }
  | { ok: false; error: ErreurTuteur }

export type Tour =
  | { ok: true; evaluation: Evaluation; suite: SuiteTuteur }
  | { ok: false; error: ErreurTuteur }

function debutDuJour(maintenant: Date): string {
  const d = new Date(maintenant)
  d.setUTCHours(0, 0, 0, 0)
  return d.toISOString()
}

/** Le chapitre et son cours, lus sous la RLS de l'étudiant. */
async function lireContexte(
  supabase: ClientReviz,
  courseId: string,
  chapterId: string,
): Promise<ContexteTuteur | null> {
  const { data } = await supabase
    .from('chapters')
    .select('id, title, text, course_id, courses(title, subjects(name))')
    .eq('id', chapterId)
    .maybeSingle()
  if (!data || data.course_id !== courseId || !data.text?.trim()) return null
  const cours = data.courses as { title: string; subjects: { name: string } | null } | null
  return {
    coursTitre: cours?.title ?? 'Cours',
    matiere: cours?.subjects?.name ?? null,
    chapitreTitre: data.title,
    chapitreTexte: data.text,
  }
}

/** Les énoncés des QCM ratés récemment sur ce chapitre, quatre au plus. */
async function erreursRecentes(
  supabase: ClientReviz,
  userId: string,
  chapterId: string,
): Promise<string[]> {
  const { data: questions } = await supabase
    .from('questions')
    .select('id, statement')
    .eq('chapter_id', chapterId)
    .eq('type', 'mcq')
  if (!questions?.length) return []
  const enonces = new Map(questions.map((q) => [q.id, q.statement]))
  const { data: ratees } = await supabase
    .from('attempts')
    .select('question_id, answered_at')
    .eq('user_id', userId)
    .eq('is_correct', false)
    .in('question_id', [...enonces.keys()])
    .order('answered_at', { ascending: false })
    .limit(10)
  const vus = new Set<string>()
  const sortie: string[] = []
  for (const r of ratees ?? []) {
    if (vus.has(r.question_id)) continue
    vus.add(r.question_id)
    const e = enonces.get(r.question_id)
    if (e) sortie.push(e)
    if (sortie.length === 4) break
  }
  return sortie
}

function suiteDepuis(tour: TuteurTour, niveaux: Niveau[], numero: number): SuiteTuteur {
  if (tour.suite.type === 'question') {
    return { type: 'question', texte: tour.suite.texte, numero, total: QUESTIONS_PAR_SESSION }
  }
  return {
    type: 'fin',
    verdict: verdictDe(niveaux),
    score: scoreDe(niveaux),
    bilan: tour.suite.bilan,
    aRevoir: tour.suite.aRevoir.slice(0, 3),
  }
}

/** Ouvre une session et rend la première question. */
export async function demarrerTuteur(
  supabase: ClientReviz,
  userId: string,
  brut: unknown,
  maintenant: Date = new Date(),
): Promise<Demarrage> {
  const parse = entreeDemarrer.safeParse(brut)
  if (!parse.success) return { ok: false, error: 'invalide' }
  const { courseId, chapterId } = parse.data

  const { data: lignes } = await supabase
    .from('subscriptions')
    .select('pack_code, starts_at, ends_at, corrections_left, packs(subjects_limit)')
    .eq('user_id', userId)
  const acces = etatAcces(
    (lignes ?? []).map((l) => ({
      packCode: l.pack_code as PackCode,
      startsAt: new Date(l.starts_at),
      endsAt: new Date(l.ends_at),
      correctionsLeft: l.corrections_left,
      subjectsLimit:
        (l.packs as { subjects_limit: number | null } | null)?.subjects_limit ?? null,
    })),
    maintenant,
  )

  const [{ count: essais }, { count: duJour }] = await Promise.all([
    supabase
      .from('tuteur_sessions')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId)
      .eq('essai', true),
    supabase
      .from('tuteur_sessions')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId)
      .gte('created_at', debutDuJour(maintenant)),
  ])

  const droit = peutVerifier({
    acces,
    essaiUtilise: (essais ?? 0) > 0,
    sessionsAujourdhui: duJour ?? 0,
  })
  if (!droit.autorise) return { ok: false, error: droit.raison }

  const contexte = await lireContexte(supabase, courseId, chapterId)
  if (!contexte) return { ok: false, error: 'introuvable' }
  const erreurs = await erreursRecentes(supabase, userId, chapterId)

  const admin = createAdminClient()
  const { data: session, error: erreurSession } = await admin
    .from('tuteur_sessions')
    .insert({ user_id: userId, course_id: courseId, chapter_id: chapterId, essai: droit.essai })
    .select('id')
    .single()
  if (erreurSession || !session) {
    // La base a le dernier mot : un second essai (index unique) ou le
    // plafond du jour (déclencheur), arrivés entre la lecture et l'écriture.
    if (erreurSession?.code === '23505') return { ok: false, error: 'essai-utilise' }
    if (erreurSession?.code === '23514') return { ok: false, error: 'plafond-du-jour' }
    console.error('[tuteur] session non créée', erreurSession?.message)
    return { ok: false, error: 'serveur' }
  }

  try {
    const resultat = await runAiTask<TuteurTour>({
      task: 'tuteur',
      schema: tuteurTourSchema.refine((t) => t.suite.type === 'question', {
        message: 'Le premier tour doit poser une question.',
      }),
      messages: messagesTuteur({ contexte, erreurs, historique: [] }),
      userId,
      recordUsage: recordAiUsage,
    })
    const texte = resultat.data.suite.type === 'question' ? resultat.data.suite.texte : ''
    await admin.from('tuteur_messages').insert({ session_id: session.id, role: 'tuteur', texte })
    return {
      ok: true,
      sessionId: session.id,
      essai: droit.essai,
      suite: { type: 'question', texte, numero: 1, total: QUESTIONS_PAR_SESSION },
    }
  } catch (e) {
    // Rien n'a été posé : la session disparaît, et avec elle l'essai, que
    // l'étudiant n'a pas eu.
    await admin.from('tuteur_sessions').delete().eq('id', session.id)
    if (e instanceof AiError) {
      console.error('[tuteur] aucun fournisseur', e.attempts.map((a) => `${a.model}:${a.outcome}`))
      return { ok: false, error: 'ia-indisponible' }
    }
    throw e
  }
}

/** Juge une réponse, puis rend la question suivante ou le bilan. */
export async function repondreTuteur(
  supabase: ClientReviz,
  userId: string,
  brut: unknown,
): Promise<Tour> {
  const parse = entreeRepondre.safeParse(brut)
  if (!parse.success) return { ok: false, error: 'invalide' }
  const { sessionId, reponse } = parse.data

  const admin = createAdminClient()
  const { data: session } = await admin
    .from('tuteur_sessions')
    .select('id, user_id, course_id, chapter_id, statut')
    .eq('id', sessionId)
    .maybeSingle()
  if (!session || session.user_id !== userId) return { ok: false, error: 'introuvable' }
  if (session.statut !== 'en_cours') return { ok: false, error: 'terminee' }

  const { data: lignes } = await admin
    .from('tuteur_messages')
    .select('role, texte, evaluation, created_at')
    .eq('session_id', sessionId)
    .order('created_at', { ascending: true })

  const historique: Echange[] = (lignes ?? []).map((l) =>
    l.role === 'tuteur'
      ? { role: 'tuteur', texte: l.texte }
      : {
          role: 'etudiant',
          texte: l.texte,
          evaluation: (l.evaluation as Evaluation | null) ?? { niveau: 'faux', retour: '' },
        },
  )
  const donnees = historique.filter((e) => e.role === 'etudiant').length
  // Une réponse attend toujours une question posée et sans réponse.
  if (historique.length === 0 || historique[historique.length - 1].role !== 'tuteur') {
    return { ok: false, error: 'terminee' }
  }

  const contexte = await lireContexte(supabase, session.course_id, session.chapter_id)
  if (!contexte) return { ok: false, error: 'introuvable' }
  const erreurs = await erreursRecentes(supabase, userId, session.chapter_id)

  const attendue = suiteAttendue(donnees + 1)
  let tour: TuteurTour
  try {
    const resultat = await runAiTask<TuteurTour>({
      task: 'tuteur',
      schema: tuteurTourSchema.refine(
        (t) => t.evaluation !== null && t.suite.type === attendue,
        { message: `Il faut juger la réponse, puis « ${attendue} ».` },
      ),
      messages: messagesTuteur({ contexte, erreurs, historique, reponse }),
      userId,
      recordUsage: recordAiUsage,
    })
    tour = resultat.data
  } catch (e) {
    if (e instanceof AiError) {
      console.error('[tuteur] aucun fournisseur', e.attempts.map((a) => `${a.model}:${a.outcome}`))
      return { ok: false, error: 'ia-indisponible' }
    }
    throw e
  }

  const evaluation = tour.evaluation as Evaluation
  const niveaux: Niveau[] = [
    ...historique.flatMap((e) => (e.role === 'etudiant' ? [e.evaluation.niveau] : [])),
    evaluation.niveau,
  ]
  const suite = suiteDepuis(tour, niveaux, donnees + 2)

  await admin
    .from('tuteur_messages')
    .insert({ session_id: sessionId, role: 'etudiant', texte: reponse, evaluation })

  if (suite.type === 'question') {
    await admin.from('tuteur_messages').insert({ session_id: sessionId, role: 'tuteur', texte: suite.texte })
  } else {
    await admin
      .from('tuteur_sessions')
      .update({
        statut: 'terminee',
        verdict: suite.verdict,
        score: suite.score,
        finished_at: new Date().toISOString(),
      })
      .eq('id', sessionId)
    if (suite.verdict === 'maitrise') {
      const { attribuerXp } = await import('@/lib/xp/attribuer')
      const { BAREME } = await import('@/lib/xp/attribution')
      await attribuerXp({
        userId,
        gains: [{ reason: 'mastery_check', amount: BAREME.mastery_check }],
        referenceId: sessionId,
      })
    }
  }

  return { ok: true, evaluation, suite }
}
