'use client'

import { useState } from 'react'
import Link from 'next/link'
import { Card, Chip, EmptyState, Icon, ProgressBar, Tabs } from '@/components/ui'
import { PaquetFiches, type Fiche } from '@/components/reviz/paquet-fiches'
import { fr } from '@/lib/i18n/fr'

export type ChapitreVue = {
  id: string
  index: number
  titre: string
  nbQuestions: number
  nbFiches: number
  nbTentees: number
  nbJustes: number
  taux: number | null
  faible: boolean
}

export type QuestionProbable = {
  id: string
  statement: string
  answer: string
  explanation: string | null
  probability: 'high' | 'medium' | 'low'
  chapitre: string | null
}

/**
 * Écran D4 — le contenu d'un cours en quatre onglets.
 *
 * Tout est chargé par le composant serveur et rendu ici : changer d'onglet
 * ne coûte aucun aller-retour. Sur une connexion instable, un onglet qui
 * déclenche une requête est un onglet qui reste vide.
 */
export function OngletsCours({
  courseId,
  chapitres,
  probables,
  fiches,
}: {
  courseId: string
  chapitres: ChapitreVue[]
  probables: QuestionProbable[]
  fiches: Fiche[]
}) {
  const [actif, setActif] = useState('probables')
  const faibles = chapitres.filter((c) => c.faible)

  return (
    <Tabs
      actif={actif}
      onChange={setActif}
      onglets={[
        {
          id: 'probables',
          label: fr.cours.ongletProbables,
          icon: 'local_fire_department',
          compteur: probables.length,
        },
        {
          id: 'chapitres',
          label: fr.cours.ongletChapitres,
          icon: 'menu_book',
          compteur: chapitres.length,
        },
        {
          id: 'fiches',
          label: fr.cours.ongletFiches,
          icon: 'style',
          compteur: fiches.length,
        },
        {
          id: 'faibles',
          label: fr.cours.ongletFaibles,
          icon: 'priority_high',
          compteur: faibles.length,
        },
      ]}
    >
      {actif === 'probables' ? <Probables questions={probables} /> : null}
      {actif === 'chapitres' ? <Chapitres chapitres={chapitres} /> : null}
      {actif === 'fiches' ? <Fiches courseId={courseId} fiches={fiches} /> : null}
      {actif === 'faibles' ? <Faibles chapitres={faibles} /> : null}
    </Tabs>
  )
}

/** « Les questions qui vont probablement tomber » — la promesse du produit. */
function Probables({ questions }: { questions: QuestionProbable[] }) {
  const [ouverte, setOuverte] = useState<string | null>(null)

  if (questions.length === 0) {
    return (
      <Card>
        <EmptyState
          icon="local_fire_department"
          title={fr.cours.aucuneProbable}
          description={fr.cours.aucuneProbableDetail}
        />
      </Card>
    )
  }

  return (
    <div className="flex flex-col gap-space-8">
      {questions.map((q) => {
        const estOuverte = ouverte === q.id

        return (
          <Card key={q.id} size="sm">
            <button
              type="button"
              onClick={() => setOuverte(estOuverte ? null : q.id)}
              aria-expanded={estOuverte}
              className="flex min-h-[48px] w-full items-start gap-space-8 text-left"
            >
              <span className="flex flex-1 flex-col gap-space-8">
                <span className="flex flex-wrap items-center gap-space-4">
                  <Chip
                    tone={q.probability === 'high' ? 'orange' : 'neutre'}
                    icon={
                      q.probability === 'high' ? 'local_fire_department' : 'help'
                    }
                  >
                    {q.probability === 'high'
                      ? fr.cours.probableHaute
                      : q.probability === 'medium'
                        ? fr.cours.probableMoyenne
                        : fr.cours.probableBasse}
                  </Chip>
                  {q.chapitre ? (
                    <span className="text-caption text-reviz-muted">
                      {q.chapitre}
                    </span>
                  ) : null}
                </span>
                <span className="text-label-lg text-reviz-ink">{q.statement}</span>
              </span>

              <Icon
                name={estOuverte ? 'expand_less' : 'expand_more'}
                size={24}
                className="shrink-0 text-reviz-muted"
              />
            </button>

            {estOuverte ? (
              <div className="flex animate-apparition flex-col gap-space-4 border-t border-reviz-border pt-space-8">
                <span className="text-label-sm text-reviz-muted">
                  {fr.session.bonneReponse}
                </span>
                <span className="text-label-md text-reviz-ink">{q.answer}</span>
                {q.explanation ? (
                  <p className="text-body-md text-reviz-muted">{q.explanation}</p>
                ) : null}
              </div>
            ) : null}
          </Card>
        )
      })}
    </div>
  )
}

function Chapitres({ chapitres }: { chapitres: ChapitreVue[] }) {
  if (chapitres.length === 0) {
    return (
      <Card>
        <EmptyState
          icon="menu_book"
          title={fr.cours.aucunChapitre}
          description={fr.cours.aucunChapitreDetail}
        />
      </Card>
    )
  }

  return (
    <div className="flex flex-col gap-space-8">
      {chapitres.map((c) => (
        <Link key={c.id} href={`/chapitre/${c.id}`} className="block">
          <Card size="sm">
            <div className="flex items-center gap-space-12">
              <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-reviz-yellow-soft text-label-lg text-primary">
                {c.index}
              </span>
              <span className="flex min-w-0 flex-1 flex-col gap-space-4">
                <span className="truncate text-label-lg text-reviz-ink">
                  {c.titre}
                </span>
                <span className="text-label-sm text-reviz-muted">
                  {fr.cours.decompteChapitre(c.nbQuestions, c.nbFiches)}
                </span>
              </span>
              <Icon name="chevron_right" size={24} className="text-reviz-muted" />
            </div>

            {/* Un chapitre jamais ouvert n'a pas de taux : il n'affiche pas
                une barre à zéro, qui se lirait comme un échec. */}
            {c.taux !== null ? (
              <ProgressBar
                value={c.taux}
                label={fr.reviser.maitrise(Math.round(c.taux * 100))}
              />
            ) : null}
          </Card>
        </Link>
      ))}
    </div>
  )
}

function Fiches({ courseId, fiches }: { courseId: string; fiches: Fiche[] }) {
  if (fiches.length === 0) {
    return (
      <Card>
        <EmptyState
          icon="style"
          title={fr.fiches.aucune}
          description={fr.fiches.aucuneDetail}
        />
      </Card>
    )
  }

  return (
    <div className="flex flex-col gap-space-12">
      <PaquetFiches fiches={fiches} />
      <Link
        href={`/cours/${courseId}/fiches`}
        className="flex min-h-[48px] items-center justify-center gap-space-4 text-label-md text-reviz-muted"
      >
        <Icon name="open_in_full" size={18} />
        {fr.fiches.titre}
      </Link>
    </div>
  )
}

function Faibles({ chapitres }: { chapitres: ChapitreVue[] }) {
  if (chapitres.length === 0) {
    return (
      <Card>
        <EmptyState
          icon="task_alt"
          title={fr.cours.aucunFaible}
          description={fr.cours.aucunFaibleDetail}
        />
      </Card>
    )
  }

  return (
    <div className="flex flex-col gap-space-8">
      {chapitres.map((c) => (
        <Link key={c.id} href={`/chapitre/${c.id}`} className="block">
          <Card size="sm">
            <div className="flex items-center gap-space-12">
              <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-reviz-danger-soft text-reviz-on-danger-soft">
                <Icon name="priority_high" size={20} />
              </span>
              <span className="flex min-w-0 flex-1 flex-col gap-space-2">
                <span className="truncate text-label-lg text-reviz-ink">
                  {c.titre}
                </span>
                <span className="text-label-sm text-reviz-muted">
                  {fr.reviser.maitrise(Math.round((c.taux ?? 0) * 100))}{' '}
                  {fr.reviser.surQuestions(c.nbTentees)}
                </span>
              </span>
              <Icon name="chevron_right" size={24} className="text-reviz-muted" />
            </div>
          </Card>
        </Link>
      ))}
    </div>
  )
}
