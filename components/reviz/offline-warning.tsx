'use client'

import { useOnline } from '@/lib/hooks/useOnline'
import { Icon } from '@/components/ui'

/**
 * Barre d'avertissement hors ligne.
 *
 * Affiche une notification en haut de page quand l'utilisateur n'a pas de connexion.
 * Les donnees locales continuent a fonctionner (PWA).
 */
export function OfflineWarning() {
  const isOnline = useOnline()

  if (isOnline) return null

  return (
    <div className="sticky top-0 z-50 flex items-center gap-space-8 bg-reviz-orange px-space-16 py-space-8">
      <Icon name="cloud_off" size={18} className="text-reviz-on-yellow flex-shrink-0" />
      <span className="text-label-sm text-reviz-on-yellow">
        Vous etes hors ligne. Les donnees locales sont disponibles.
      </span>
    </div>
  )
}
