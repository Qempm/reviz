'use client'

import { useVersionCheck } from '@/lib/hooks/useVersionCheck'
import { Button, Icon } from '@/components/ui'

/**
 * Composant de verification de version.
 *
 * Affiche une notification ou redirige vers l'ecran update-required.
 * Seul affiche une notification pour les updates facultatives.
 */
export function VersionCheck() {
  const { status, versionInfo } = useVersionCheck()

  // Mise a jour requise : redirection handlee cote serveur ou middleware
  if (status === 'update-required') {
    return null // Middleware redirige avant le rendu
  }

  // Mise a jour disponible : notification discretionnelle
  if (status === 'update-available' && versionInfo) {
    return (
      <div className="fixed bottom-24 left-space-20 right-space-20 z-40 flex gap-space-12 rounded-xl bg-reviz-yellow px-space-16 py-space-12 shadow-card">
        <Icon name="system_update" size={20} className="text-reviz-on-yellow flex-shrink-0" />
        <div className="flex-1">
          <p className="text-label-md text-reviz-on-yellow font-600">Nouvelle version disponible</p>
          <p className="text-label-sm text-reviz-on-yellow opacity-90">{versionInfo.releaseNotes}</p>
        </div>
        <a
          href={versionInfo.updateUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="flex-shrink-0"
        >
          <Button variant="primary" fullWidth={false}>
            Mettre a jour
          </Button>
        </a>
      </div>
    )
  }

  return null
}
