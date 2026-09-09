import { cn } from '@/lib/utils'

export type SkeletonProps = {
  /** Classes de dimension, par exemple `h-cta w-full`. */
  className?: string
}

/**
 * Bloc de chargement.
 *
 * Reprend la forme de ce qu'il remplace plutôt qu'un rond tournant : sur une
 * connexion instable, voir la page se dessiner rassure davantage qu'un
 * indicateur qui ne dit rien de ce qui arrive.
 */
export function Skeleton({ className }: SkeletonProps) {
  return (
    <div
      aria-hidden="true"
      className={cn('animate-pulse rounded-xl bg-surface-container', className)}
    />
  )
}
