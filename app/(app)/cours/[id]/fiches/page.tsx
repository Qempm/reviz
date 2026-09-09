import Link from 'next/link'
import { notFound, redirect } from 'next/navigation'
import { Card, EmptyState, Icon } from '@/components/ui'
import { PaquetFiches, type Fiche } from '@/components/reviz/paquet-fiches'
import { createClient } from '@/lib/supabase/server'
import { fr } from '@/lib/i18n/fr'

/**
 * Écran D5 — les fiches d'un cours.
 *
 * Le paquet entier est chargé d'un coup : quelques dizaines de fiches pèsent
 * moins qu'un aller-retour réseau par fiche, et l'étudiant qui révise dans un
 * amphi sans réseau peut finir son paquet.
 */
export default async function PageFiches({
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

  const [{ data: cours }, { data: lignes }] = await Promise.all([
    supabase.from('courses').select('id, title').eq('id', id).maybeSingle(),
    supabase
      .from('flashcards')
      .select('id, front, back, chapters!inner(index, title, course_id)')
      .eq('chapters.course_id', id)
      .order('id'),
  ])

  if (!cours) notFound()

  const fiches: Fiche[] = (lignes ?? []).map((l) => ({
    id: l.id,
    front: l.front,
    back: l.back,
    chapitre: l.chapters?.title ?? null,
  }))

  return (
    <div className="flex flex-col gap-space-20">
      <div className="flex flex-col gap-space-4">
        <Link
          href={`/cours/${id}`}
          className="flex min-h-[48px] w-fit items-center gap-space-4 text-label-md text-reviz-muted"
        >
          <Icon name="arrow_back" size={20} />
          {cours.title}
        </Link>
        <h1 className="text-headline-xl text-reviz-ink">{fr.fiches.titre}</h1>
      </div>

      {fiches.length === 0 ? (
        <Card>
          <EmptyState
            icon="style"
            title={fr.fiches.aucune}
            description={fr.fiches.aucuneDetail}
          />
        </Card>
      ) : (
        <PaquetFiches fiches={fiches} />
      )}
    </div>
  )
}
