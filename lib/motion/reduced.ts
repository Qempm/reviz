'use client'

import { useEffect, useState } from 'react'

/**
 * Faut-il réduire les animations ?
 *
 * Deux sources : la préférence système, et un réglage propre à l'application.
 * Sur un Android d'entrée de gamme, l'étudiant doit pouvoir couper les
 * animations même si son système ne le demande pas — c'est le sens du réglage
 * local, qui l'emporte quand il est posé.
 */

export const CLE_REGLAGE = 'reviz.animations-reduites'

function lireReglageLocal(): boolean | null {
  try {
    const v = localStorage.getItem(CLE_REGLAGE)
    return v === null ? null : v === '1'
  } catch {
    // Navigation privée ou stockage bloqué : on s'en remet au système.
    return null
  }
}

export function ecrireReglageLocal(reduites: boolean): void {
  try {
    localStorage.setItem(CLE_REGLAGE, reduites ? '1' : '0')
    window.dispatchEvent(new Event('reviz:animations'))
  } catch {
    // Sans stockage, le réglage ne survit pas au rechargement. Tant pis.
  }
}

export function useAnimationsReduites(): boolean {
  // Vrai par défaut le temps de l'hydratation : mieux vaut une première image
  // sobre qu'une animation qui démarre puis s'annule.
  const [reduites, setReduites] = useState(true)

  useEffect(() => {
    const media = window.matchMedia('(prefers-reduced-motion: reduce)')

    const calculer = () => {
      const local = lireReglageLocal()
      setReduites(local ?? media.matches)
    }

    calculer()
    media.addEventListener('change', calculer)
    window.addEventListener('reviz:animations', calculer)

    return () => {
      media.removeEventListener('change', calculer)
      window.removeEventListener('reviz:animations', calculer)
    }
  }, [])

  return reduites
}
