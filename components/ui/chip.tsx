import type { ReactNode } from 'react'
import { cn } from '@/lib/utils'
import { Icon } from './icon'

export type ChipTone = 'neutre' | 'jaune' | 'orange' | 'bleu' | 'danger'

export type ChipProps = {
  children: ReactNode
  tone?: ChipTone
  icon?: string
  /** Rend la pilule actionnable, avec l'arête tactile. */
  onClick?: () => void
  selected?: boolean
}

/** Pilule d'information ou de filtre. Toujours `rounded-full`. */
export function Chip({ children, tone = 'neutre', icon, onClick, selected }: ChipProps) {
  const tons: Record<ChipTone, string> = {
    neutre: 'bg-surface-container text-reviz-muted',
    jaune: 'bg-reviz-yellow text-reviz-on-yellow',
    orange: 'bg-reviz-orange-soft text-on-secondary-fixed',
    bleu: 'bg-reviz-blue text-on-tertiary-container',
    danger: 'bg-reviz-danger-soft text-reviz-on-danger-soft',
  }

  const classes = cn(
    'inline-flex items-center gap-space-4 rounded-full px-space-8 py-space-4 text-caption',
    selected ? 'bg-reviz-yellow text-reviz-on-yellow shadow-tactile-sm' : tons[tone],
    onClick && 'min-h-[48px] px-space-12 text-label-sm transition-all active:translate-y-[1px]',
  )

  const contenu = (
    <>
      {icon ? <Icon name={icon} size={14} /> : null}
      {children}
    </>
  )

  if (!onClick) return <span className={classes}>{contenu}</span>

  return (
    <button type="button" onClick={onClick} aria-pressed={selected} className={classes}>
      {contenu}
    </button>
  )
}
