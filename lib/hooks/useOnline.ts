'use client'

import { useEffect, useState } from 'react'

/**
 * Hook pour detecter l'etat online/offline de l'utilisateur.
 *
 * Utilise l'API navigator.onLine et les evenements online/offline.
 * Utile pour afficher des avertissements et adapter le comportement.
 */
export function useOnline(): boolean {
  const [isOnline, setIsOnline] = useState(true)

  useEffect(() => {
    // Initialise l'etat depuis navigator.onLine
    setIsOnline(navigator.onLine)

    // Ecoute les changements d'etat
    const handleOnline = () => setIsOnline(true)
    const handleOffline = () => setIsOnline(false)

    window.addEventListener('online', handleOnline)
    window.addEventListener('offline', handleOffline)

    return () => {
      window.removeEventListener('online', handleOnline)
      window.removeEventListener('offline', handleOffline)
    }
  }, [])

  return isOnline
}
