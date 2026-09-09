'use client'

import { useCallback, useEffect, useState } from 'react'
import { Button, Icon, SegmentedProgressBar } from '@/components/ui'
import { useAnimationsReduites } from '@/lib/motion/reduced'
import { fr } from '@/lib/i18n/fr'

export type Fiche = {
  id: string
  front: string
  back: string
  chapitre: string | null
}

/**
 * Paquet de fiches retournables.
 *
 * Une fiche à l'écran, comme une question de QCM : sur 375 px, deux fiches
 * côte à côte seraient illisibles, et une liste déroulante ferait perdre
 * l'effort de rappel qui fait tout l'intérêt de la fiche.
 *
 * Le retournement est en CSS et non en Motion : une rotation d'axe Y est
 * exactement ce qu'une transition sait faire, et importer Motion ici pesait
 * 48 ko sur un écran que l'étudiant ouvre en révision, souvent en 3G.
 */
export function PaquetFiches({ fiches }: { fiches: Fiche[] }) {
  const [index, setIndex] = useState(0)
  const [retournee, setRetournee] = useState(false)
  const [vues, setVues] = useState<Set<number>>(() => new Set([0]))
  const reduites = useAnimationsReduites()

  const fiche = fiches[index]

  const aller = useCallback(
    (delta: number) => {
      setIndex((i) => {
        const suivant = Math.min(fiches.length - 1, Math.max(0, i + delta))
        if (suivant !== i) {
          setRetournee(false)
          setVues((v) => new Set(v).add(suivant))
        }
        return suivant
      })
    },
    [fiches.length],
  )

  // Flèches et barre d'espace : l'app tourne aussi dans un navigateur de
  // bureau, et réviser au clavier y est nettement plus rapide.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'ArrowRight') aller(1)
      else if (e.key === 'ArrowLeft') aller(-1)
      else if (e.key === ' ' || e.key === 'Enter') {
        e.preventDefault()
        setRetournee((r) => !r)
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [aller])

  if (!fiche) return null

  const derniere = index === fiches.length - 1
  const toutesVues = vues.size === fiches.length

  return (
    <div className="flex flex-col gap-space-16">
      <div className="flex flex-col gap-space-8">
        <SegmentedProgressBar
          segments={fiches.map((_, i) => (vues.has(i) ? 'correct' : 'upcoming'))}
        />
        <span className="text-center text-label-sm text-reviz-muted">
          {fr.fiches.position(index + 1, fiches.length)}
        </span>
      </div>

      {/* La carte ------------------------------------------------------- */}
      <button
        type="button"
        onClick={() => setRetournee((r) => !r)}
        aria-pressed={retournee}
        aria-label={fr.fiches.retourner}
        className="relative block w-full text-left [perspective:1200px]"
        style={{ minHeight: 300 }}
      >
        <span
          className="relative block w-full"
          style={{
            minHeight: 300,
            transformStyle: 'preserve-3d',
            transform: retournee ? 'rotateY(180deg)' : 'rotateY(0deg)',
            // Le réglage local prime : `prefers-reduced-motion` ne le connaît
            // pas, et c'est lui qui sert sur un téléphone poussif.
            transition: reduites
              ? 'none'
              : 'transform 420ms cubic-bezier(0.22, 1, 0.36, 1)',
          }}
        >
          <Face
            cache={retournee}
            etiquette={fr.fiches.recto}
            texte={fiche.front}
            chapitre={fiche.chapitre}
            ton="recto"
          />
          <Face
            cache={!retournee}
            etiquette={fr.fiches.verso}
            texte={fiche.back}
            chapitre={fiche.chapitre}
            ton="verso"
            verso
          />
        </span>
      </button>

      <p className="text-center text-label-sm text-reviz-muted">
        {toutesVues && derniere ? fr.fiches.terminee : fr.fiches.sousTitre}
      </p>

      {/* Navigation ------------------------------------------------------ */}
      <div className="flex items-center gap-space-12">
        <Button
          variant="secondary"
          icon="chevron_left"
          disabled={index === 0}
          onClick={() => aller(-1)}
        >
          {fr.fiches.precedente}
        </Button>
        {derniere ? (
          <Button
            icon="restart_alt"
            onClick={() => {
              setIndex(0)
              setRetournee(false)
            }}
          >
            {fr.fiches.recommencer}
          </Button>
        ) : (
          <Button icon="chevron_right" onClick={() => aller(1)}>
            {fr.fiches.suivante}
          </Button>
        )}
      </div>
    </div>
  )
}

function Face({
  cache,
  etiquette,
  texte,
  chapitre,
  ton,
  verso,
}: {
  cache: boolean
  etiquette: string
  texte: string
  chapitre: string | null
  ton: 'recto' | 'verso'
  verso?: boolean
}) {
  return (
    <span
      className={[
        'flex min-h-[300px] w-full flex-col justify-center gap-space-12 rounded-card p-space-24 text-center shadow-card',
        verso ? 'absolute inset-0' : '',
        ton === 'recto'
          ? 'bg-reviz-card'
          : 'bg-reviz-yellow-soft text-reviz-on-yellow',
      ].join(' ')}
      // `backface-visibility` seul suffirait, mais Chrome sur Android ancien
      // laisse parfois filtrer la face arrière : on la cache aussi à la
      // lecture d'écran et au pointeur.
      aria-hidden={cache}
      style={{
        backfaceVisibility: 'hidden',
        WebkitBackfaceVisibility: 'hidden',
        transform: verso ? 'rotateY(180deg)' : undefined,
      }}
    >
      <span className="text-caption text-reviz-muted">{etiquette}</span>
      <span className="text-headline-md">{texte}</span>
      {chapitre ? (
        <span className="flex items-center justify-center gap-space-4 text-label-sm text-reviz-muted">
          <Icon name="bookmark" size={16} />
          {chapitre}
        </span>
      ) : null}
    </span>
  )
}
