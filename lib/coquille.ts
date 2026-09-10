'use client'

import { useEffect, useState } from 'react'

/**
 * Tourne-t-on dans la coquille Android ?
 *
 * `MainActivity` ajoute « Reviz/<version> » à l'agent utilisateur. Le côté
 * serveur a `estCoquille()` dans app/(auth)/actions.ts ; celui-ci sert aux
 * écrans, là où le parcours doit changer de forme.
 *
 * Ce que cela change, concrètement : dans l'APK, un lien de connexion reçu
 * par mail s'ouvre dans le navigateur et la session s'y installe, pas dans
 * l'application. Les six chiffres, eux, se saisissent sur place.
 *
 * Faux pendant l'hydratation : le serveur ne peut pas rendre deux HTML
 * différents pour la même route sans risquer une discordance, et se tromper
 * dans ce sens n'ôte rien — l'étape du code reste atteignable.
 */
export function useCoquille(): boolean {
  const [coquille, setCoquille] = useState(false)

  useEffect(() => {
    setCoquille(navigator.userAgent.includes('Reviz/'))
  }, [])

  return coquille
}
