import Link from 'next/link'
import { notFound, redirect } from 'next/navigation'
import {
  Button,
  Card,
  Chip,
  CircularProgress,
  EmptyState,
  Icon,
  MascotState,
} from '@/components/ui'
import { createClient } from '@/lib/supabase/server'
import { fr } from '@/lib/i18n/fr'

/**
 * Écran D4 — Page cours.
 *
 * Trois états selon `courses.status` : en traitement, prêt, échoué. Un cours
 * qui vient d'être déposé n'a ni chapitre ni question : montrer une page vide
 * laisserait croire à une panne.
 */
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

  const [{ data: cours }, { data: chapitres }] = await Promise.all([
    supabase
      .from('course_overview')
      .select(
        'id, title, status, is_demo, subject_name, exam_date, page_count, nb_chapitres, nb_questions, nb_fiches, nb_tentees',
      )
      .eq('id', id)
      .maybeSingle(),
    supabase
      .from('chapters')
      .select('id, index, title, questions(count), flashcards(count)')
      .eq('course_id', id)
      .order('index'),
  ])

  // La RLS renvoie simplement rien si le cours n'est pas lisible : on ne
  // distingue pas « inexistant » de « pas à toi », ce qui évite de révéler
  // l'existence du cours d'un autre.
  if (!cours) notFound()

  const jours = cours.exam_date ? joursAvant(cours.exam_date) : null
  const total = cours.nb_questions ?? 0
  const faites = cours.nb_tentees ?? 0
  const progression = total > 0 ? faites / total : 0

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

  if (cours.status !== 'ready') {
    return (
      <div className="flex flex-1 flex-col items-center justify-center gap-space-24">
        <MascotState
          mood="chargement"
          title={fr.cours.traitementTitre}
          description={fr.cours.traitementDetail}
        />
        <Card size="sm">
          <p className="text-label-sm text-reviz-muted">{fr.cours.traitementAstuce}</p>
        </Card>
      </div>
    )
  }

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

      {/* Progression ------------------------------------------------------- */}
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

        <Button icon="bolt" disabled>
          {fr.cours.reviser}
        </Button>
        <p className="text-center text-label-sm text-reviz-muted">
          {fr.commun.bientot}
        </p>
      </Card>

      {/* Chapitres --------------------------------------------------------- */}
      <section className="flex flex-col gap-space-12">
        <div className="flex items-baseline justify-between">
          <h2 className="text-headline-lg text-reviz-ink">{fr.cours.chapitres}</h2>
          {(cours.nb_fiches ?? 0) > 0 ? (
            <Link
              href={`/cours/${id}/fiches`}
              className="text-label-md text-primary"
            >
              {fr.cours.voirFiches(cours.nb_fiches ?? 0)}
            </Link>
          ) : null}
        </div>

        {chapitres && chapitres.length > 0 ? (
          <div className="flex flex-col gap-space-8">
            {chapitres.map((ch) => {
              const nbQ = (ch.questions as unknown as { count: number }[])[0]?.count ?? 0
              const nbF = (ch.flashcards as unknown as { count: number }[])[0]?.count ?? 0

              return (
                <Card key={ch.id} size="sm">
                  <div className="flex items-center gap-space-12">
                    <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-reviz-yellow-soft text-label-lg text-primary">
                      {ch.index}
                    </span>
                    <span className="flex flex-1 flex-col">
                      <span className="text-label-lg text-reviz-ink">{ch.title}</span>
                      <span className="text-label-sm text-reviz-muted">
                        {fr.cours.decompteChapitre(nbQ, nbF)}
                      </span>
                    </span>
                  </div>
                </Card>
              )
            })}
          </div>
        ) : (
          <Card>
            <EmptyState
              icon="menu_book"
              title={fr.cours.aucunChapitre}
              description={fr.cours.aucunChapitreDetail}
            />
          </Card>
        )}
      </section>
    </div>
  )
}
