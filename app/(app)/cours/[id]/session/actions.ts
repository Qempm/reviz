'use server'

import { z } from 'zod'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient, ConfigurationManquante } from '@/lib/supabase/admin'
import { gainsDeSession, totalGains, type GainXp } from '@/lib/xp/attribution'

/**
 * Fin de session : enregistrement des réponses et attribution des XP.
 *
 * Le client envoie ce qu'il a **choisi**, jamais s'il avait juste : la
 * correction est refaite ici depuis `questions.answer`. Sans cela, un étudiant
 * qui bricole la requête s'attribuerait dix bonnes réponses et la première
 * place du classement.
 */

const entree = z.object({
  courseId: z.string().uuid(),
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
  brut: z.input<typeof entree>,
): Promise<ResultatEnregistrement> {
  const parse = entree.safeParse(brut)
  if (!parse.success) return { ok: false, error: 'Requête invalide.' }
  const { courseId, reponses } = parse.data

  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) return { ok: false, error: 'Session expirée.' }

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

  // Insertion sous l'identité de l'étudiant : la politique
  // « J'enregistre mes réponses » s'applique, et le trigger
  // `track_attempt()` remplit `daily_activity` et rafraîchit la série.
  const { error: erreurAttempts } = await supabase.from('attempts').insert(
    corrigees.map((c) => ({
      user_id: user.id,
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
      .eq('user_id', user.id)
      .eq('day', jour)
      .maybeSingle(),
    supabase.from('profiles').select('current_streak').eq('id', user.id).maybeSingle(),
  ])

  const serie = profil?.current_streak ?? 0
  const objectifAtteint = activite?.is_validated ?? false

  const gains = gainsDeSession({ bonnes, total, objectifAtteint, serie })

  // L'objectif du jour ne se récompense qu'une fois : le journal est en ajout
  // seul, il faut donc vérifier avant d'écrire plutôt que corriger après.
  const aFiltrer = objectifAtteint ? await motifsDejaCredites(user.id, jour) : new Set<string>()
  const aEcrire = gains.filter(
    (g) =>
      !(
        (g.reason === 'daily_goal' || g.reason === 'streak_bonus') &&
        aFiltrer.has(g.reason)
      ),
  )

  const xp = totalGains(aEcrire)

  if (aEcrire.length > 0) {
    try {
      const admin = createAdminClient()
      const { error } = await admin.from('xp_events').insert(
        aEcrire.map((g) => ({
          user_id: user.id,
          reason: g.reason,
          amount: g.amount,
          reference_id: g.referenceId ?? courseId,
        })),
      )
      // Les réponses sont enregistrées, seuls les XP manquent : on le signale
      // dans le journal serveur sans faire échouer la session de l'étudiant.
      if (error) console.error('XP non attribués', error.message)
    } catch (e) {
      if (e instanceof ConfigurationManquante) console.error(e.message)
      else throw e
    }
  }

  return { ok: true, bonnes, total, gains: aEcrire, xp, objectifAtteint, serie }
}

/** Motifs déjà crédités aujourd'hui, pour ne pas les compter deux fois. */
async function motifsDejaCredites(userId: string, jour: string): Promise<Set<string>> {
  const supabase = await createClient()
  const { data } = await supabase
    .from('xp_events')
    .select('reason')
    .eq('user_id', userId)
    .gte('created_at', `${jour}T00:00:00Z`)
    .in('reason', ['daily_goal', 'streak_bonus'])

  return new Set((data ?? []).map((l) => l.reason))
}
