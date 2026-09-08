import { cn } from '@/lib/utils'

export type ProgressBarProps = {
  /** Progression entre 0 et 1. */
  value: number
  label?: string
}

/**
 * Barre de progression : 10 px en pilule, remplissage plat (docs/DESIGN.md § 7).
 * Le dégradé décrit par la prose de Stitch n'a jamais été produit dans ses
 * écrans — on s'en tient au remplissage uni.
 */
export function ProgressBar({ value, label }: ProgressBarProps) {
  const pct = Math.round(Math.min(1, Math.max(0, value)) * 100)

  return (
    <div className="flex flex-col gap-space-4">
      {label ? (
        <div className="flex items-center justify-between">
          <span className="text-label-sm text-reviz-muted">{label}</span>
          <span className="text-label-sm text-reviz-ink">{pct} %</span>
        </div>
      ) : null}
      <div
        role="progressbar"
        aria-valuenow={pct}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-label={label}
        className="h-2.5 w-full overflow-hidden rounded-full bg-surface-container"
      >
        <div
          className="h-full rounded-full bg-reviz-yellow transition-all"
          style={{ width: `${pct}%` }}
        />
      </div>
    </div>
  )
}

export type SegmentState = 'correct' | 'wrong' | 'upcoming'

/**
 * Progression segmentée d'une session de QCM : une case par question.
 * Conforme à l'arbitrage sur les couleurs — le juste est en jaune, le faux
 * en rouge d'erreur, sans vert (docs/DESIGN.md § 11).
 */
export function SegmentedProgressBar({ segments }: { segments: SegmentState[] }) {
  return (
    <div className="flex h-3 w-full gap-space-4 overflow-hidden rounded-full bg-surface-container-high p-[2px] shadow-inner">
      {segments.map((state, i) => (
        <div
          key={i}
          className={cn(
            'h-2.5 flex-1 rounded-full',
            state === 'correct' && 'bg-reviz-yellow',
            state === 'wrong' && 'bg-reviz-danger',
            state === 'upcoming' && 'bg-surface-container',
          )}
        />
      ))}
    </div>
  )
}
