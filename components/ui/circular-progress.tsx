import { cn } from '@/lib/utils'

export type CircularProgressProps = {
  /** Progression entre 0 et 1. */
  value: number
  size?: number
  /** Épaisseur du trait. */
  epaisseur?: number
  /** Contenu au centre, typiquement un pourcentage. */
  children?: React.ReactNode
  className?: string
}

/**
 * Jauge circulaire, pour le taux de maîtrise d'une matière.
 *
 * En SVG et non en `conic-gradient` : le dégradé conique s'anime mal et rend
 * des bords crénelés sur les navigateurs Android anciens.
 */
export function CircularProgress({
  value,
  size = 72,
  epaisseur = 8,
  children,
  className,
}: CircularProgressProps) {
  const pct = Math.min(1, Math.max(0, value))
  const rayon = (size - epaisseur) / 2
  const circonference = 2 * Math.PI * rayon

  return (
    <span
      className={cn('relative inline-flex items-center justify-center', className)}
      style={{ width: size, height: size }}
      role="img"
      aria-label={`${Math.round(pct * 100)} %`}
    >
      <svg width={size} height={size} className="-rotate-90">
        <circle
          cx={size / 2}
          cy={size / 2}
          r={rayon}
          fill="none"
          strokeWidth={epaisseur}
          className="stroke-surface-container"
        />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={rayon}
          fill="none"
          strokeWidth={epaisseur}
          strokeLinecap="round"
          strokeDasharray={circonference}
          strokeDashoffset={circonference * (1 - pct)}
          className="stroke-reviz-yellow transition-[stroke-dashoffset] duration-500"
        />
      </svg>
      <span className="absolute inset-0 flex items-center justify-center">{children}</span>
    </span>
  )
}
