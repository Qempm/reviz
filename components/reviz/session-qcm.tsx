'use client'

import { useState, useTransition } from 'react'
import Link from 'next/link'
import {
  Button,
  Card,
  Chip,
  Icon,
  MascotState,
  QuizOption,
  SegmentedProgressBar,
} from '@/components/ui'
import type { QuizOptionState, SegmentState } from '@/components/ui'
import { Confetti } from '@/components/reviz/confetti'
import { fr } from '@/lib/i18n/fr'
import {
  enregistrerSession,
  type ResultatEnregistrement,
} from '@/app/(app)/cours/[id]/session/actions'

export type QuestionSession = {
  id: string
  statement: string
  options: string[]
  explanation: string | null
  probability: 'high' | 'medium' | 'low'
}

const LETTRES = ['A', 'B', 'C', 'D', 'E', 'F']

/**
 * Session de QCM : une question par écran (docs/DESIGN.md § 7).
 *
 * La correction affichée ici est locale, pour être immédiate ; celle qui
 * compte est refaite par le serveur à l'enregistrement, depuis
 * `questions.answer`. Ce n'est pas une redondance inutile : le client ne
 * remonte que son choix, jamais son verdict.
 */
export function SessionQcm({
  courseId,
  titre,
  questions,
  reponses: bonnesReponses,
}: {
  courseId: string
  titre: string | null
  questions: QuestionSession[]
  /** Réponse attendue par question, pour le retour immédiat. */
  reponses: Record<string, string>
}) {
  const [index, setIndex] = useState(0)
  const [choix, setChoix] = useState<string | null>(null)
  const [corrige, setCorrige] = useState(false)
  const [donnees, setDonnees] = useState<
    { questionId: string; choix: string | null }[]
  >([])
  const [etats, setEtats] = useState<SegmentState[]>(() =>
    questions.map(() => 'upcoming'),
  )
  const [resultat, setResultat] = useState<ResultatEnregistrement | null>(null)
  const [enCours, demarrer] = useTransition()

  const question = questions[index]
  const derniere = index === questions.length - 1

  function valider() {
    if (choix === null || corrige) return

    const juste = choix === bonnesReponses[question.id]
    setCorrige(true)
    setEtats((e) => {
      const suivant = [...e]
      suivant[index] = juste ? 'correct' : 'wrong'
      return suivant
    })
    setDonnees((d) => [...d, { questionId: question.id, choix }])
  }

  function suivant() {
    if (!derniere) {
      setIndex((i) => i + 1)
      setChoix(null)
      setCorrige(false)
      return
    }

    demarrer(async () => {
      const r = await enregistrerSession({ courseId, reponses: donnees })
      setResultat(r)
    })
  }

  if (resultat) {
    return (
      <Resultat
        resultat={resultat}
        etats={etats}
        courseId={courseId}
        titre={titre}
        total={questions.length}
      />
    )
  }

  const attendue = bonnesReponses[question.id]
  const juste = corrige && choix === attendue

  const etatOption = (option: string): QuizOptionState => {
    if (!corrige) return choix === option ? 'selected' : 'idle'
    if (option === attendue) return 'correct'
    if (option === choix) return 'wrong'
    return 'idle'
  }

  return (
    <div className="flex flex-col gap-space-16">
      <div className="flex flex-col gap-space-8">
        <SegmentedProgressBar
          segments={etats.map((e, i) => (i === index && !corrige ? 'upcoming' : e))}
        />
        <div className="flex items-center justify-between gap-space-8">
          <span className="text-label-sm text-reviz-muted">
            {fr.session.question(index + 1, questions.length)}
          </span>
          {question.probability === 'high' ? (
            <Chip tone="orange" icon="local_fire_department">
              {fr.session.probable}
            </Chip>
          ) : null}
        </div>
      </div>

      <Card>
        <h1 className="text-headline-md text-reviz-ink">{question.statement}</h1>
      </Card>

      <div className="flex flex-col gap-space-8">
        {question.options.map((option, i) => (
          <QuizOption
            key={option}
            letter={LETTRES[i] ?? '?'}
            label={option}
            state={etatOption(option)}
            disabled={corrige}
            onSelect={() => setChoix(option)}
          />
        ))}
      </div>

      {/* Retour immédiat — écran D7, intégré à la session ---------------- */}
      {corrige ? (
        <Card size="sm">
          <span
            className={
              juste
                ? 'flex items-center gap-space-8 text-label-lg text-primary'
                : 'flex items-center gap-space-8 text-label-lg text-reviz-on-danger-soft'
            }
          >
            <Icon name={juste ? 'check_circle' : 'cancel'} size={20} />
            {juste ? fr.session.juste : fr.session.faux}
          </span>

          {!juste ? (
            <span className="text-label-md text-reviz-ink">
              {fr.session.bonneReponse} : {attendue}
            </span>
          ) : null}

          {question.explanation ? (
            <p className="text-body-md text-reviz-muted">{question.explanation}</p>
          ) : null}
        </Card>
      ) : null}

      {corrige ? (
        <Button
          icon={derniere ? 'flag' : 'arrow_forward'}
          onClick={suivant}
          disabled={enCours}
        >
          {enCours
            ? fr.commun.chargement
            : derniere
              ? fr.session.voirResultat
              : fr.session.suivante}
        </Button>
      ) : (
        <Button icon="check" onClick={valider} disabled={choix === null}>
          {fr.session.valider}
        </Button>
      )}
    </div>
  )
}

/** Écran D8 — résultat de session. */
function Resultat({
  resultat,
  etats,
  courseId,
  titre,
  total,
}: {
  resultat: ResultatEnregistrement
  etats: SegmentState[]
  courseId: string
  titre: string | null
  total: number
}) {
  // La session s'est déroulée, seul l'enregistrement a échoué : on montre le
  // score compté localement plutôt qu'un écran d'erreur qui effacerait
  // l'effort de l'étudiant.
  const bonnes = resultat.ok
    ? resultat.bonnes
    : etats.filter((e) => e === 'correct').length
  const pct = total > 0 ? Math.round((bonnes / total) * 100) : 0
  const sansFaute = total > 0 && bonnes === total

  const partage = encodeURIComponent(
    fr.session.partageTexte(bonnes, total, titre ?? 'mon cours'),
  )

  return (
    <div className="flex flex-col gap-space-20">
      <Confetti actif={pct >= 60} intensite={sansFaute ? 'franc' : 'discret'} />

      <MascotState
        mood={pct >= 60 ? 'reussite' : 'echec'}
        title={fr.session.resultatTitre}
      />

      <Card>
        <span className="text-center text-display-hero-mobile text-reviz-ink">
          {fr.session.score(bonnes, total)}
        </span>
        <span className="text-center text-label-md text-reviz-muted">
          {fr.session.precision(pct)}
        </span>
        <SegmentedProgressBar segments={etats} />
      </Card>

      {resultat.ok ? (
        <Card>
          <div className="flex items-baseline justify-between gap-space-8">
            <span className="text-label-lg text-reviz-ink">
              {fr.session.xpGagnes(resultat.xp)}
            </span>
            {resultat.objectifAtteint ? (
              <Chip tone="jaune" icon="local_fire_department">
                {fr.session.serie(resultat.serie)}
              </Chip>
            ) : null}
          </div>

          <div className="flex flex-col gap-space-4">
            {resultat.gains.map((g) => (
              <div
                key={g.reason}
                className="flex items-baseline justify-between gap-space-8"
              >
                <span className="text-label-sm text-reviz-muted">
                  {fr.session.detailXp[g.reason]}
                </span>
                <span className="text-label-sm text-reviz-ink">+{g.amount}</span>
              </div>
            ))}
          </div>
        </Card>
      ) : (
        <Card size="sm">
          <p className="text-label-sm text-reviz-muted">
            {fr.session.echecEnregistrement}
          </p>
        </Card>
      )}

      <div className="flex flex-col gap-space-8">
        <Link href={`/cours/${courseId}/session`} className="block">
          <Button icon="restart_alt">{fr.session.refaire}</Button>
        </Link>

        <a
          href={`https://wa.me/?text=${partage}`}
          target="_blank"
          rel="noreferrer"
          className="block"
        >
          <Button variant="secondary" icon="share">
            {fr.session.partager}
          </Button>
        </a>

        <Link
          href={`/cours/${courseId}`}
          className="flex min-h-[48px] items-center justify-center text-label-md text-reviz-muted"
        >
          {fr.session.retourCours}
        </Link>
      </div>
    </div>
  )
}
