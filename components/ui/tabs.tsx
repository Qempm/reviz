'use client'

import { useId, useRef, type ReactNode } from 'react'
import { cn } from '@/lib/utils'
import { Icon } from './icon'

export type Onglet = {
  id: string
  label: string
  icon?: string
  /** Compteur affiché entre parenthèses, comme « Chapitres (6) ». */
  compteur?: number
}

export type TabsProps = {
  onglets: Onglet[]
  actif: string
  onChange: (id: string) => void
  children?: ReactNode
}

/**
 * Onglets défilants horizontalement.
 *
 * Quatre onglets ne tiennent pas sur 375 px avec leurs libellés : la barre
 * défile plutôt que de tronquer. Le repère actif est un soulignement jaune,
 * pas un fond plein — un fond plein entrerait en concurrence avec les
 * pilules de la navigation basse.
 */
export function Tabs({ onglets, actif, onChange, children }: TabsProps) {
  const baseId = useId()
  const barre = useRef<HTMLDivElement>(null)

  return (
    <div className="flex flex-col gap-space-16">
      <div
        ref={barre}
        role="tablist"
        // Marges négatives : la barre déborde jusqu'aux bords de l'écran pour
        // que le défilement se sente, le contenu reste dans la gouttière.
        className="-mx-screen-margin-mobile flex gap-space-4 overflow-x-auto px-screen-margin-mobile"
      >
        {onglets.map((o) => {
          const estActif = o.id === actif
          return (
            <button
              key={o.id}
              type="button"
              role="tab"
              id={`${baseId}-${o.id}`}
              aria-selected={estActif}
              aria-controls={`${baseId}-${o.id}-panneau`}
              onClick={(e) => {
                onChange(o.id)
                e.currentTarget.scrollIntoView({
                  behavior: 'smooth',
                  block: 'nearest',
                  inline: 'center',
                })
              }}
              className={cn(
                'flex min-h-[48px] shrink-0 items-center gap-space-4 border-b-2 px-space-12 pb-space-8 text-label-md transition-colors',
                estActif
                  ? 'border-reviz-yellow text-reviz-ink'
                  : 'border-transparent text-reviz-muted',
              )}
            >
              {o.icon ? <Icon name={o.icon} size={18} filled={estActif} /> : null}
              {o.label}
              {typeof o.compteur === 'number' ? (
                <span className="text-caption text-reviz-muted">({o.compteur})</span>
              ) : null}
            </button>
          )
        })}
      </div>

      <div
        role="tabpanel"
        id={`${baseId}-${actif}-panneau`}
        aria-labelledby={`${baseId}-${actif}`}
      >
        {children}
      </div>
    </div>
  )
}
