import Link from 'next/link'
import { redirect } from 'next/navigation'
import { Button, Card, Chip, CircularProgress, EmptyState, Icon } from '@/components/ui'
import { createClient } from '@/lib/supabase/server'
import { fr } from '@/lib/i18n/fr'

/**
 * Écran D3 — Mes cours.
 *
 * Les cours de démonstration sont épinglés en tête : un étudiant qui vient
 * de s'inscrire n'a rien déposé, et un écran vide ne lui apprend pas ce que
 * l'application sait faire.
 */
export default async function Reviser() {
  const supabase = await createClient()

  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) redirect('/connexion')

  // La RLS filtre : mes cours, ceux partagés dans ma faculté, et les
  // démonstrations. Aucun filtre à écrire ici.
  const { data: cours } = await supabase
    .from('course_overview')
    .select(
      'id, title, status, is_demo, subject_name, exam_date, nb_chapitres, nb_questions, nb_fiches, nb_tentees',
    )
    .order('is_demo', { ascending: false })
    .order('created_at', { ascending: false })

  // La vue `course_overview` type toutes ses colonnes en nullable, comme
  // toute vue Postgres : on écarte les lignes sans identifiant plutôt que
  // d'affirmer un type que la base ne garantit pas.
  const liste = (cours ?? []).filter((c) => c.id !== null)
  const miens = liste.filter((c) => !c.is_demo)

  return (
    <div className="flex flex-col gap-space-20">
      <header className="flex flex-col gap-space-4">
        <h1 className="text-headline-xl text-reviz-ink">{fr.reviser.titre}</h1>
        <p className="text-body-md text-reviz-muted">{fr.reviser.sousTitre}</p>
      </header>

      <Link href="/reviser/ajouter" className="block">
        <Button icon="add">{fr.reviser.ajouterCours}</Button>
      </Link>

      {liste.length === 0 ? (
        <Card>
          <EmptyState
            icon="upload_file"
            title={fr.reviser.aucunCours}
            description={fr.reviser.aucunCoursDetail}
          />
        </Card>
      ) : (
        <div className="flex flex-col gap-space-12">
          {liste.map((c) => (
            <CarteCours key={c.id} cours={c} />
          ))}
        </div>
      )}

      {miens.length === 0 && liste.length > 0 ? (
        <p className="pb-space-16 text-center text-label-sm text-reviz-muted">
          {fr.reviser.seulementDemo}
        </p>
      ) : null}
    </div>
  )
}

type Cours = {
  id: string | null
  title: string | null
  status: string | null
  is_demo: boolean | null
  subject_name: string | null
  exam_date: string | null
  nb_chapitres: number | null
  nb_questions: number | null
  nb_fiches: number | null
  nb_tentees: number | null
}

function CarteCours({ cours }: { cours: Cours }) {
  const total = cours.nb_questions ?? 0
  const faites = cours.nb_tentees ?? 0
  const progression = total > 0 ? faites / total : 0
  const pret = cours.status === 'ready'

  return (
    <Link href={`/cours/${cours.id}`} className="block">
      <Card>
        <div className="flex items-start justify-between gap-space-16">
          <div className="flex flex-1 flex-col gap-space-8">
            <div className="flex flex-wrap items-center gap-space-8">
              {cours.is_demo ? (
                <Chip tone="jaune" icon="auto_awesome">
                  {fr.reviser.exemple}
                </Chip>
              ) : null}
              {!pret ? (
                <Chip tone="orange" icon="hourglass_top">
                  {fr.reviser.enTraitement}
                </Chip>
              ) : null}
              {cours.exam_date ? (
                <Chip tone="orange" icon="event">
                  {fr.reviser.examenLe(cours.exam_date)}
                </Chip>
              ) : null}
            </div>

            <span className="text-headline-md text-reviz-ink">{cours.title}</span>

            {cours.subject_name ? (
              <span className="flex items-center gap-space-4 text-label-sm text-reviz-muted">
                <Icon name="school" size={16} />
                {cours.subject_name}
              </span>
            ) : null}

            <span className="text-label-sm text-reviz-muted">
              {fr.reviser.decompte(
                cours.nb_chapitres ?? 0,
                total,
                cours.nb_fiches ?? 0,
              )}
            </span>
          </div>

          {pret && total > 0 ? (
            <CircularProgress value={progression} size={64}>
              <span className="text-label-md text-reviz-ink">
                {Math.round(progression * 100)}%
              </span>
            </CircularProgress>
          ) : (
            <Icon name="chevron_right" size={24} className="text-reviz-muted" />
          )}
        </div>
      </Card>
    </Link>
  )
}
