'use client'

import { useEffect, useState } from 'react'

export type CountdownProps = {
  /** Échéance. */
  jusqua: Date
  /** Rendu du temps restant. */
  children: (restant: { jours: number; heures: number; minutes: number; secondes: number; passe: boolean }) => React.ReactNode
}

function calculer(jusqua: Date, maintenant: number) {
  const delta = jusqua.getTime() - maintenant
  const passe = delta <= 0
  const s = Math.max(0, Math.floor(delta / 1000))
  return {
    jours: Math.floor(s / 86400),
    heures: Math.floor((s % 86400) / 3600),
    minutes: Math.floor((s % 3600) / 60),
    secondes: s % 60,
    passe,
  }
}

/**
 * Compte à rebours.
 *
 * Ne bat à la seconde que s'il reste moins d'une heure : au-delà, un
 * `setInterval` par seconde réveillerait le processeur pour rien, ce qui se
 * paie en batterie sur un téléphone d'entrée de gamme.
 */
export function Countdown({ jusqua, children }: CountdownProps) {
  const [maintenant, setMaintenant] = useState(() => Date.now())

  useEffect(() => {
    const restant = jusqua.getTime() - Date.now()
    if (restant <= 0) return

    const pas = restant < 3_600_000 ? 1000 : 60_000
    const id = setInterval(() => setMaintenant(Date.now()), pas)
    return () => clearInterval(id)
  }, [jusqua])

  return <>{children(calculer(jusqua, maintenant))}</>
}
