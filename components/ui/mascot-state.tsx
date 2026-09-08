'use client'

import { useState } from 'react'
import { cn } from '@/lib/utils'
import { Icon } from './icon'

/** Les cinq moments où la mascotte apparaît (CLAUDE.md, section Design system). */
export type MascotMood =
  | 'accueil'
  | 'reussite'
  | 'echec'
  | 'chargement'
  | 'pack-expire'

export type MascotStateProps = {
  mood: MascotMood
  title?: string
  description?: string
  size?: number
  children?: React.ReactNode
}

/**
 * Illustration de mascotte.
 *
 * Les visuels attendus dans `public/mascotte/` n'existent pas encore : Stitch
 * n'a livré aucun asset local, ses écrans pointaient vers des images générées
 * (docs/DESIGN.md § 9). En leur absence, on affiche une pastille de repli
 * plutôt qu'une image cassée, pour que le kitchen-sink reste lisible.
 */
const MOODS: Record<
  MascotMood,
  { icon: string; ring: string; tint: string; defaut: string }
> = {
  accueil: {
    icon: 'waving_hand',
    ring: 'bg-reviz-yellow-soft',
    tint: 'text-primary',
    defaut: 'Content de te revoir',
  },
  reussite: {
    icon: 'celebration',
    ring: 'bg-reviz-yellow',
    tint: 'text-reviz-on-yellow',
    defaut: 'Bien joué !',
  },
  echec: {
    icon: 'sentiment_dissatisfied',
    ring: 'bg-reviz-danger-soft',
    tint: 'text-reviz-on-danger-soft',
    defaut: 'Ce n’est pas grave',
  },
  chargement: {
    icon: 'hourglass_top',
    ring: 'bg-reviz-blue-soft',
    tint: 'text-tertiary',
    defaut: 'Un instant…',
  },
  'pack-expire': {
    icon: 'lock_clock',
    ring: 'bg-reviz-orange-soft',
    tint: 'text-on-secondary-fixed',
    defaut: 'Ton pack est arrivé à terme',
  },
}

export function MascotState({
  mood,
  title,
  description,
  size = 120,
  children,
}: MascotStateProps) {
  const [imageManquante, setImageManquante] = useState(false)
  const m = MOODS[mood]

  return (
    <div className="flex flex-col items-center gap-space-16 text-center">
      {imageManquante ? (
        <span
          className={cn(
            'flex items-center justify-center rounded-full',
            m.ring,
            m.tint,
            mood === 'chargement' && 'animate-pulse',
          )}
          style={{ width: size, height: size }}
        >
          <Icon name={m.icon} size={Math.round(size * 0.45)} filled />
        </span>
      ) : (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          src={`/mascotte/${mood}.png`}
          alt=""
          width={size}
          height={size}
          className="object-contain"
          onError={() => setImageManquante(true)}
        />
      )}

      <div className="flex flex-col gap-space-4">
        <h2 className="text-headline-md text-reviz-ink">{title ?? m.defaut}</h2>
        {description ? (
          <p className="max-w-[280px] text-body-md text-reviz-muted">
            {description}
          </p>
        ) : null}
      </div>

      {children}
    </div>
  )
}
