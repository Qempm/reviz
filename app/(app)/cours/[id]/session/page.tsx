import Link from 'next/link'
import { notFound, redirect } from 'next/navigation'
import { Button, Card, EmptyState, Icon } from '@/components/ui'
import { SessionQcm, type QuestionSession } from '@/components/reviz/session-qcm'
import { createClient } from '@/lib/supabase/server'
import { fr } from '@/lib/i18n/fr'

/**
 * Écrans D6 et D7 — session de QCM.
 *
 * Dix questions par session, comme l'objectif du jour
 * (`public.daily_goal()`) : une session finie doit pouvoir valider la journée,
 * sinon la série reste hors d'atteinte de celui qui révise une fois par jour.
 */
const PAR_SESSION = 10

export default async function PageSession({
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
    .from('courses')
    .select('id, title, status')
    .eq('id', id)
    .maybeSingle()

  if (!cours) notFound()

  // Les plus probables d'abord : c'est la promesse du produit — « les
  // questions qui vont probablement tomber ». L'énumération est déclarée
  // (high, medium, low), donc l'ordre croissant de Postgres est déjà le bon.
  //
  // Seuls les QCM : une question ouverte demande une correction par l'IA,
  // qui viendra avec les clés (lot 9).
  const { data: brutes } = await supabase
    .from('questions')
    .select('id, statement, options, answer, explanation, probability, chapters!inner(course_id)')
    .eq('chapters.course_id', id)
    .eq('type', 'mcq')
    .order('probability')
    .limit(PAR_SESSION)

  const questions: QuestionSession[] = []
  const reponses: Record<string, string> = {}

  for (const q of brutes ?? []) {
    // `options` est du jsonb : la contrainte `questions_options_coherentes`
    // garantit un tableau pour un QCM, mais le type généré reste `Json`.
    const options = Array.isArray(q.options)
      ? q.options.filter((o): o is string => typeof o === 'string')
      : []

    // Un QCM sans propositions, ou dont la réponse n'est pas parmi elles,
    // serait insoluble : on l'écarte plutôt que de l'afficher.
    if (options.length < 2 || !options.includes(q.answer)) continue

    questions.push({
      id: q.id,
      statement: q.statement,
      options,
      explanation: q.explanation,
      probability: q.probability,
    })
    // La réponse attendue part vers le client, pour que le retour soit
    // immédiat et que la session survive à une coupure réseau. Ce n'est pas
    // un secret : l'explication l'énonce de toute façon, et c'est le serveur
    // qui recorrige avant d'écrire quoi que ce soit.
    reponses[q.id] = q.answer
  }

  if (questions.length === 0) {
    return (
      <div className="flex flex-col gap-space-20">
        <Retour id={id} titre={cours.title} />
        <Card>
          <EmptyState
            icon="quiz"
            title={fr.session.aucuneQuestion}
            description={fr.session.aucuneQuestionDetail}
            action={
              <Link href={`/cours/${id}`}>
                <Button variant="secondary" icon="arrow_back">
                  {fr.session.retourCours}
                </Button>
              </Link>
            }
          />
        </Card>
      </div>
    )
  }

  return (
    <div className="flex flex-col gap-space-16">
      <Retour id={id} titre={cours.title} />
      <SessionQcm
        courseId={id}
        titre={cours.title}
        questions={questions}
        reponses={reponses}
      />
    </div>
  )
}

function Retour({ id, titre }: { id: string; titre: string | null }) {
  return (
    <Link
      href={`/cours/${id}`}
      className="flex min-h-[48px] w-fit items-center gap-space-4 text-label-md text-reviz-muted"
    >
      <Icon name="close" size={20} />
      {titre}
    </Link>
  )
}
