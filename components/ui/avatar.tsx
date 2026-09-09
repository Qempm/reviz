'use client'

import { useState } from 'react'
import { cn } from '@/lib/utils'

export type AvatarProps = {
  /** Clé de `profiles.avatar_key`, par exemple `07`. */
  avatarKey?: string | null
  /** Sert d'initiale quand aucun avatar n'est choisi. */
  nom?: string | null
  size?: number
  /** Anneau coloré autour, pour le podium et le classement. */
  ring?: 'jaune' | 'bleu' | 'peche' | 'aucun'
}

/**
 * Avatar d'étudiant.
 *
 * Les 24 illustrations vivent dans `public/avatars/`. Tant qu'elles ne sont
 * pas livrées, on affiche l'initiale sur fond neutre — jamais une image
 * cassée.
 */
export function Avatar({ avatarKey, nom, size = 40, ring = 'aucun' }: AvatarProps) {
  const [absente, setAbsente] = useState(false)

  const anneaux = {
    jaune: 'bg-reviz-yellow p-1',
    bleu: 'bg-reviz-blue p-1',
    peche: 'bg-reviz-orange-soft p-1',
    aucun: '',
  }

  const initiale = (nom ?? '?').trim().slice(0, 1).toUpperCase() || '?'
  const montrerImage = Boolean(avatarKey) && !absente

  return (
    <span
      className={cn('inline-flex shrink-0 items-center justify-center rounded-full', anneaux[ring])}
      style={{ width: size, height: size }}
    >
      {montrerImage ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          src={`/avatars/${avatarKey}.png`}
          alt=""
          className="h-full w-full rounded-full object-cover"
          onError={() => setAbsente(true)}
        />
      ) : (
        <span className="flex h-full w-full items-center justify-center rounded-full bg-surface-container text-label-md text-reviz-muted">
          {initiale}
        </span>
      )}
    </span>
  )
}
