import type { ReactNode } from 'react'
import { Icon } from './icon'

export type EmptyStateProps = {
  /** Glyphe Material Symbols illustrant l'absence de contenu. */
  icon?: string
  title: string
  description?: string
  action?: ReactNode
}

/**
 * État vide : aucune matière, aucune correction, aucun filleul.
 * Toujours accompagné d'une porte de sortie — un seul CTA par écran.
 */
export function EmptyState({
  icon = 'inbox',
  title,
  description,
  action,
}: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center gap-space-16 px-space-24 py-space-32 text-center">
      <span className="flex h-16 w-16 items-center justify-center rounded-full bg-surface-container text-reviz-muted">
        <Icon name={icon} size={32} />
      </span>
      <div className="flex flex-col gap-space-4">
        <h2 className="text-headline-md text-reviz-ink">{title}</h2>
        {description ? (
          <p className="max-w-[280px] text-body-md text-reviz-muted">
            {description}
          </p>
        ) : null}
      </div>
      {action}
    </div>
  )
}
