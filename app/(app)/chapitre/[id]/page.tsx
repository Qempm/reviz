import Link from 'next/link'
import { notFound, redirect } from 'next/navigation'
import { Button, Card, Chip, EmptyState, Icon, ProgressBar } from '@/components/ui'
import { PaquetFiches, type Fiche } from '@/components/reviz/paquet-fiches'
import { createClient } from '@/lib/supabase/server'
import { fr } from '@/lib/i18n/fr'

/**
 * Écran D5 — fiche de révision d'un chapitre.
 *
 * Le texte du chapitre est celui extrait du document, tel quel : c'est la
 * source des questions, et un étudiant qui doute d'une réponse doit pouvoir
 * remonter au passage plutôt qu'à sa mémoire du cours.
 */
export default async function PageChapitre({
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

  const [{ data: chapitre }, { data: stats }, { data: cartes }] =
    await Promise.all([
      supabase
        .from('chapters')
        .select('id, index, title, text, course_id, courses(title)')
        .eq('id', id)
        .maybeSingle(),
      supabase
        .from('chapter_stats')
        .select('nb_questions, nb_fiches, nb_tentees, taux, is_weak')
        .eq('chapter_id', id)
        .maybeSingle(),
      supabase
        .from('flashcards')
        .select('id, front, back')
        .eq('chapter_id', id)
        .order('id'),
    ])

  // La politique de `chapters` délègue à `can_read_course()` : un chapitre
  // qu'on n'a pas le droit de lire ne remonte simplement pas.
  if (!chapitre) notFound()

  const fiches: Fiche[] = (cartes ?? []).map((f) => ({
    id: f.id,
    front: f.front,
    back: f.back,
    chapitre: null,
  }))

  const taux = stats?.taux === null || stats?.taux === undefined ? null : Number(stats.taux)
  const nbQuestions = stats?.nb_questions ?? 0

  return (
    <div className="flex flex-col gap-space-20">
      <div className="flex flex-col gap-space-8">
        <Link
          href={`/cours/${chapitre.course_id}`}
          className="flex min-h-[48px] w-fit items-center gap-space-4 text-label-md text-reviz-muted"
        >
          <Icon name="arrow_back" size={20} />
          {chapitre.courses?.title ?? fr.reviser.titre}
        </Link>

        <div className="flex flex-wrap items-center gap-space-8">
          <Chip tone="jaune" icon="bookmark">
            {fr.chapitre.numero(chapitre.index)}
          </Chip>
          {stats?.is_weak ? (
            <Chip tone="danger" icon="priority_high">
              {fr.reviser.aRevoir}
            </Chip>
          ) : null}
        </div>

        <h1 className="text-headline-xl text-reviz-ink">{chapitre.title}</h1>
        <span className="text-label-sm text-reviz-muted">
          {fr.chapitre.questions(nbQuestions)}
        </span>
      </div>

      {taux !== null ? (
        <Card size="sm">
          <ProgressBar
            value={taux}
            label={fr.reviser.maitrise(Math.round(taux * 100))}
          />
          <span className="text-label-sm text-reviz-muted">
            {fr.reviser.surQuestions(stats?.nb_tentees ?? 0)}
          </span>
        </Card>
      ) : null}

      {/* Le cours -------------------------------------------------------- */}
      <section className="flex flex-col gap-space-12">
        <h2 className="text-headline-lg text-reviz-ink">{fr.chapitre.contenu}</h2>
        {chapitre.text.trim() === '' ? (
          <Card>
            <EmptyState icon="article" title={fr.chapitre.aucunTexte} />
          </Card>
        ) : (
          <Card>
            {/* `whitespace-pre-line` : le découpage garde les sauts de ligne
                du document, qui portent sa structure. Les rendre en un seul
                paragraphe rendrait un plan illisible. */}
            <p className="whitespace-pre-line text-body-lg text-reviz-ink">
              {chapitre.text}
            </p>
          </Card>
        )}
      </section>

      {/* Les fiches ------------------------------------------------------ */}
      {fiches.length > 0 ? (
        <section className="flex flex-col gap-space-12">
          <h2 className="text-headline-lg text-reviz-ink">{fr.chapitre.fiches}</h2>
          <PaquetFiches fiches={fiches} />
        </section>
      ) : null}

      {nbQuestions > 0 ? (
        <Link href={`/cours/${chapitre.course_id}/session`} className="block pb-space-16">
          <Button icon="bolt">{fr.chapitre.reviser}</Button>
        </Link>
      ) : null}
    </div>
  )
}
