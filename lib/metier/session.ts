import 'server-only'
import { z } from 'zod'
import type { ClientReviz } from '@/lib/supabase/jeton'
import { gainsDeSession, type GainXp } from '@/lib/xp/attribution'
import { attribuerXp } from '@/lib/xp/attribuer'

/**
 * Fin de session : enregistrement des réponses et attribution des XP.
 *
 * Le client Supabase est injecté, pour que la Server Action de l'écran web et
 * la route `/api/session/terminer` partagent cette seule implémentation — une
 * Server Action n'est pas appelable depuis Flutter.
 *
 * Le client envoie ce qu'il a **choisi**, jamais s'il avait juste : la
 * correction est refaite ici depuis `questions.answer`. Sans cela, un étudiant
 * qui bricole la requête s'attribuerait dix bonnes réponses et la première
 * place du classement.
 */

export const entreeSession = z.object({
  courseId: z.string().uuid(),
  /**
   * Identifiant tiré par le téléphone pour cette série. Une série finie hors
   * ligne est renvoyée au retour du réseau, parfois deux fois si la première
   * réponse s'est perdue : ce numéro rend le renvoi sans effet. Facultatif,
   * pour les APK antérieurs.
   */
  sessionId: z.string().uuid().optional(),
  reponses: z
    .array(
      z.object({
        questionId: z.string().uuid(),
        // `null` : question passée sans répondre.
        choix: z.string().max(2000).nullable(),
      }),
    )
    .min(1)
    .max(50),
})

export type EntreeSession = z.input<typeof entreeSession>

export type ResultatEnregistrement =
  | {
      ok: true
      bonnes: number
      total: number
      gains: GainXp[]
      xp: number
      objectifAtteint: boolean
      serie: number
    }
  | { ok: false; error: string }

export async function enregistrerSession(
  supabase: ClientReviz,
  userId: string,
  brut: EntreeSession,
): Promise<ResultatEnregistrement> {
  const parse = entreeSession.safeParse(brut)
  if (!parse.success) return { ok: false, error: 'Requête invalide.' }
  const { courseId, reponses, sessionId } = parse.data

  // Les questions sont relues par le client de l'utilisateur : la RLS
  // garantit qu'elles appartiennent bien à un cours qu'il peut lire, donc
  // qu'il ne peut pas se faire corriger les questions d'un autre.
  const ids = [...new Set(reponses.map((r) => r.questionId))]
  const { data: questions, error: erreurQuestions } = await supabase
    .from('questions')
    .select('id, answer, chapters!inner(course_id)')
    .in('id', ids)

  if (erreurQuestions) return { ok: false, error: 'Questions introuvables.' }

  const attendues = new Map(
    (questions ?? [])
      .filter((q) => q.chapters?.course_id === courseId)
      .map((q) => [q.id, q.answer]),
  )

  // Une réponse dont la question n'appartient pas au cours annoncé est
  // écartée, pas comptée comme fausse : c'est un bug ou une manipulation,
  // dans les deux cas elle ne doit pas peser sur les statistiques.
  const corrigees = reponses
    .filter((r) => attendues.has(r.questionId))
    .map((r) => ({
      question_id: r.questionId,
      is_correct: r.choix !== null && r.choix === attendues.get(r.questionId),
    }))

  if (corrigees.length === 0) return { ok: false, error: 'Aucune réponse valide.' }

  const bonnes = corrigees.filter((c) => c.is_correct).length
  const total = corrigees.length

  // Déjà enregistrée : un renvoi de la file hors ligne dont la première
  // réponse s'était perdue. On rend le score sans rien réécrire.
  if (sessionId) {
    const { count } = await supabase
      .from('xp_events')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId)
      .eq('reason', 'quiz_completed')
      .eq('reference_id', sessionId)
    if ((count ?? 0) > 0) {
      const { data: profil } = await supabase
        .from('profiles')
        .select('current_streak')
        .eq('id', userId)
        .maybeSingle()
      return {
        ok: true,
        bonnes,
        total,
        gains: [],
        xp: 0,
        objectifAtteint: false,
        serie: profil?.current_streak ?? 0,
      }
    }
  }

  // Insertion sous l'identité de l'étudiant : la politique
  // « J'enregistre mes réponses » s'applique, et le trigger
  // `track_attempt()` remplit `daily_activity` et rafraîchit la série.
  const { error: erreurAttempts } = await supabase.from('attempts').insert(
    corrigees.map((c) => ({
      user_id: userId,
      question_id: c.question_id,
      is_correct: c.is_correct,
    })),
  )

  if (erreurAttempts) {
    return { ok: false, error: erreurAttempts.message }
  }

  // Objectif du jour et série : lus en base après l'insertion, car c'est le
  // trigger qui les a posés. L'écran ne connaît que sa propre session.
  const jour = new Date().toISOString().slice(0, 10)
  const [{ data: activite }, { data: profil }] = await Promise.all([
    supabase
      .from('daily_activity')
      .select('is_validated, questions_answered')
      .eq('user_id', userId)
      .eq('day', jour)
      .maybeSingle(),
    supabase.from('profiles').select('current_streak').eq('id', userId).maybeSingle(),
  ])

  const serie = profil?.current_streak ?? 0
  const objectifAtteint = activite?.is_validated ?? false

  const gains = gainsDeSession({ bonnes, total, objectifAtteint, serie })

  // L'objectif du jour ne se récompense qu'une fois : le journal est en ajout
  // seul, il faut donc vérifier avant d'écrire plutôt que corriger après.
  const aFiltrer = objectifAtteint ? await motifsDejaCredites(supabase, userId, jour) : new Set<string>()
  const aEcrire = gains.filter(
    (g) =>
      !(
        (g.reason === 'daily_goal' || g.reason === 'streak_bonus') &&
        aFiltrer.has(g.reason)
      ),
  )

  // Les réponses sont déjà enregistrées : si les XP échouent, la session
  // n'échoue pas pour autant. `attribuerXp` renvoie zéro dans ce cas, et
  // l'écran n'annonce donc pas des points qui n'existent pas.
  const xp = await attribuerXp({
    userId: userId,
    gains: aEcrire,
    // Le numéro de série quand le téléphone en donne un : c'est lui que
    // relit la vérification de renvoi ci-dessus.
    referenceId: sessionId ?? courseId,
  })

  return {
    ok: true,
    bonnes,
    total,
    gains: xp === 0 ? [] : aEcrire,
    xp,
    objectifAtteint,
    serie,
  }
}

/** Motifs déjà crédités aujourd'hui, pour ne pas les compter deux fois. */
async function motifsDejaCredites(
  supabase: ClientReviz,
  userId: string,
  jour: string,
): Promise<Set<string>> {
  const { data } = await supabase
    .from('xp_events')
    .select('reason')
    .eq('user_id', userId)
    .gte('created_at', `${jour}T00:00:00Z`)
    .in('reason', ['daily_goal', 'streak_bonus'])

  return new Set((data ?? []).map((l) => l.reason))
}
