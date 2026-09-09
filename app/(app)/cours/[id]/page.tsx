import Link from 'next/link'
import { notFound, redirect } from 'next/navigation'
import { Button, Card, Chip, CircularProgress, Icon, MascotState } from '@/components/ui'
import { CoursEnTraitement } from '@/components/reviz/cours-en-traitement'
import {
  OngletsCours,
  type ChapitreVue,
  type QuestionProbable,
} from '@/components/reviz/onglets-cours'
import type { Fiche } from '@/components/reviz/paquet-fiches'
import { createClient } from '@/lib/supabase/server'
import { fr } from '@/lib/i18n/fr'

/**
 * Écran D4 — page cours.
 *
 * Trois états selon `courses.status` : en traitement, prêt, échoué. Un cours
 * qui vient d'être déposé n'a ni chapitre ni question : montrer une page vide
 * laisserait croire à une panne.
 */

/** Questions probables montrées d'emblée. Au-delà, la liste devient un mur. */
const PROBABLES_MAX = 20

/**
 * Jours restants avant l'examen, `null` s'il est passé.
 *
 * Arithmétique de calendrier, pas de millisecondes : « demain » doit rester
 * « demain » quelle que soit l'heure qu'il est. Un compte à rebours à la
 * seconde n'aurait aucun sens pour une date sans heure.
 */
function joursAvant(iso: string): number | null {
  const [a, m, j] = iso.slice(0, 10).split('-').map(Number)
  if (!a || !m || !j) return null

  const examen = new Date(a, m - 1, j)
  const aujourdhui = new Date()
  aujourdhui.setHours(0, 0, 0, 0)

  const jours = Math.round(
    (examen.getTime() - aujourdhui.getTime()) / 86_400_000,
  )
  return jours < 0 ? null : jours
}

export default async function PageCours({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  const { id } = await params
  const supabase = await createClient()

  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) redirect('/connexion')

  const { data: cours } = await supabase
    .from('course_overview')
    .select(
      'id, title, status, is_demo, subject_name, exam_date, nb_chapitres, nb_questions, nb_fiches, nb_tentees',
    )
    .eq('id', id)
    .maybeSingle()

  // La RLS renvoie simplement rien si le cours n'est pas lisible : on ne
  // distingue pas « inexistant » de « pas à toi », ce qui évite de révéler
  // l'existence du cours d'un autre.
  if (!cours) notFound()

  if (cours.status === 'failed') {
    return (
      <div className="flex flex-1 flex-col items-center justify-center gap-space-24">
        <MascotState
          mood="echec"
          title={fr.cours.echecTitre}
          description={fr.cours.echecDetail}
        />
        <Link href="/reviser" className="w-full">
          <Button variant="secondary" icon="arrow_back">
            {fr.commun.retour}
          </Button>
        </Link>
      </div>
    )
  }

  if (cours.status !== 'ready') return <CoursEnTraitement />

  // Trois lectures en parallèle : le contenu du cours ne change pas d'une
  // requête à l'autre, autant ne pas les enchaîner.
  const [{ data: chapitres }, { data: questions }, { data: cartes }] =
    await Promise.all([
      supabase
        .from('chapter_stats')
        .select('chapter_id, index, title, nb_questions, nb_fiches, nb_tentees, nb_justes, taux, is_weak')
        .eq('course_id', id)
        .order('index'),
      supabase
        .from('questions')
        .select('id, statement, answer, explanation, probability, chapters!inner(course_id, title)')
        .eq('chapters.course_id', id)
        .order('probability')
        .limit(PROBABLES_MAX),
      supabase
        .from('flashcards')
        .select('id, front, back, chapters!inner(course_id, title)')
        .eq('chapters.course_id', id)
        .order('id'),
    ])

  const vueChapitres: ChapitreVue[] = (chapitres ?? [])
    .filter((c) => c.chapter_id !== null)
    .map((c) => ({
      id: c.chapter_id as string,
      index: c.index ?? 0,
      titre: c.title ?? '',
      nbQuestions: c.nb_questions ?? 0,
      nbFiches: c.nb_fiches ?? 0,
      nbTentees: c.nb_tentees ?? 0,
      nbJustes: c.nb_justes ?? 0,
      // `taux` est un `numeric` : PostgREST le sérialise en chaîne pour ne
      // pas perdre de précision. Le convertir ici, une fois.
      taux: c.taux === null ? null : Number(c.taux),
      faible: c.is_weak ?? false,
    }))

  const probables: QuestionProbable[] = (questions ?? []).map((q) => ({
    id: q.id,
    statement: q.statement,
    answer: q.answer,
    explanation: q.explanation,
    probability: q.probability,
    chapitre: q.chapters?.title ?? null,
  }))

  const fiches: Fiche[] = (cartes ?? []).map((f) => ({
    id: f.id,
    front: f.front,
    back: f.back,
    chapitre: f.chapters?.title ?? null,
  }))

  const jours = cours.exam_date ? joursAvant(cours.exam_date) : null
  const total = cours.nb_questions ?? 0
  const faites = cours.nb_tentees ?? 0
  const progression = total > 0 ? faites / total : 0

  return (
    <div className="flex flex-col gap-space-20">
      <div className="flex flex-col gap-space-8">
        <Link
          href="/reviser"
          className="flex min-h-[48px] w-fit items-center gap-space-4 text-label-md text-reviz-muted"
        >
          <Icon name="arrow_back" size={20} />
          {fr.reviser.titre}
        </Link>

        <div className="flex flex-wrap items-center gap-space-8">
          {cours.is_demo ? (
            <Chip tone="jaune" icon="auto_awesome">
              {fr.reviser.exemple}
            </Chip>
          ) : null}
          {cours.exam_date ? (
            <Chip tone="orange" icon="hourglass_top">
              {jours === null ? fr.cours.examenPasse : fr.cours.jMoins(jours)}
            </Chip>
          ) : null}
        </div>

        <h1 className="text-headline-xl text-reviz-ink">{cours.title}</h1>
        {cours.subject_name ? (
          <span className="flex items-center gap-space-4 text-label-md text-reviz-muted">
            <Icon name="school" size={18} />
            {cours.subject_name}
          </span>
        ) : null}
      </div>

      {/* Progression et session ------------------------------------------- */}
      <Card>
        <div className="flex items-center gap-space-20">
          <CircularProgress value={progression} size={88}>
            <span className="text-headline-md text-reviz-ink">
              {Math.round(progression * 100)}%
            </span>
          </CircularProgress>
          <div className="flex flex-1 flex-col gap-space-4">
            <span className="text-label-lg text-reviz-ink">
              {fr.cours.progression(faites, total)}
            </span>
            <span className="text-label-sm text-reviz-muted">
              {fr.reviser.decompte(
                cours.nb_chapitres ?? 0,
                total,
                cours.nb_fiches ?? 0,
              )}
            </span>
          </div>
        </div>

        {total > 0 ? (
          <Link href={`/cours/${id}/session`} className="block">
            <Button icon="bolt">{fr.cours.reviser}</Button>
          </Link>
        ) : (
          <Button icon="bolt" disabled>
            {fr.cours.reviser}
          </Button>
        )}
      </Card>

      <OngletsCours
        courseId={id}
        chapitres={vueChapitres}
        probables={probables}
        fiches={fiches}
      />
    </div>
  )
}
