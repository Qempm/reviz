import type { HTMLAttributes, ReactNode } from 'react'
import { cn } from '@/lib/utils'

export type CardProps = {
  /** `sm` pour les encarts internes : rayon 12 px et 12 px de gouttière. */
  size?: 'default' | 'sm'
  children?: ReactNode
} & Omit<HTMLAttributes<HTMLDivElement>, 'className'>

/**
 * Carte blanche du design system (docs/DESIGN.md § 7).
 * Sans bordure : la séparation d'avec le fond vient de l'ombre douce.
 */
export function Card({ size = 'default', children, ...rest }: CardProps) {
  return (
    <div
      className={cn(
        'flex flex-col bg-reviz-card',
        size === 'default'
          ? 'rounded-card p-space-20 gap-space-16 shadow-card'
          : 'rounded-xl p-space-12 gap-space-8 shadow-card-sm',
      )}
      {...rest}
    >
      {children}
    </div>
  )
}
