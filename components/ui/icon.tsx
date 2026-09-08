import { cn } from '@/lib/utils'

export type IconProps = {
  /** Nom du glyphe Material Symbols, par exemple `local_fire_department`. */
  name: string
  /** Taille en pixels. Les écrans Stitch utilisent 16, 18, 20, 22, 24 et 64. */
  size?: number
  /** Glyphe plein plutôt qu'au trait. */
  filled?: boolean
  className?: string
}

/**
 * Icône Material Symbols Outlined, le jeu employé par les maquettes
 * (docs/DESIGN.md § 3). La feuille de style est chargée dans app/layout.tsx.
 */
export function Icon({ name, size = 20, filled = false, className }: IconProps) {
  return (
    <span
      aria-hidden="true"
      className={cn('material-symbols-outlined leading-none', className)}
      style={{
        fontSize: `${size}px`,
        ...(filled ? { fontVariationSettings: "'FILL' 1" } : {}),
      }}
    >
      {name}
    </span>
  )
}
