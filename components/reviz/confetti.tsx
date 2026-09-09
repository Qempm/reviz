'use client'

import { useEffect, useRef } from 'react'
import { useAnimationsReduites } from '@/lib/motion/reduced'

/**
 * Confettis de célébration.
 *
 * `canvas-confetti` n'est chargé qu'au moment où l'on célèbre, par un
 * `import()` : son poids ne pèse jamais sur le bundle d'une route, et un
 * étudiant qui ne finit pas de session ne le télécharge jamais.
 *
 * Palette strictement chaude, conformément à l'arbitrage de
 * docs/DESIGN.md § 11 : la réussite se fête en jaune et orange, jamais en
 * vert.
 */

const COULEURS = ['#ffc300', '#ffdf9a', '#fe6a2b', '#ffdbcf', '#f8be00']

export type ConfettiProps = {
  /** Passe à vrai pour déclencher. Repasser à faux permet de rejouer. */
  actif: boolean
  /** Intensité : `discret` pour un bon résultat, `franc` pour un sans-faute. */
  intensite?: 'discret' | 'franc'
}

export function Confetti({ actif, intensite = 'discret' }: ConfettiProps) {
  const reduites = useAnimationsReduites()
  const dejaJoue = useRef(false)

  useEffect(() => {
    if (!actif) {
      dejaJoue.current = false
      return
    }
    // Une seule salve par activation.
    if (dejaJoue.current || reduites) return
    dejaJoue.current = true

    let annule = false

    void (async () => {
      try {
        const { default: confetti } = await import('canvas-confetti')
        if (annule) return

        const commun = {
          colors: COULEURS,
          disableForReducedMotion: true,
          // Part du bas de l'écran : sur mobile, le regard est sur le score,
          // pas sur le haut de la page.
          origin: { y: 0.75 },
        }

        if (intensite === 'franc') {
          confetti({ ...commun, particleCount: 90, spread: 78, startVelocity: 42 })
          setTimeout(
            () => !annule && confetti({ ...commun, particleCount: 55, spread: 100, decay: 0.92 }),
            180,
          )
        } else {
          confetti({ ...commun, particleCount: 45, spread: 62, startVelocity: 34 })
        }
      } catch {
        // Le paquet n'a pas pu être chargé : l'écran de résultat reste
        // parfaitement lisible sans confettis. Rien à signaler à l'étudiant.
      }
    })()

    return () => {
      annule = true
    }
  }, [actif, intensite, reduites])

  return null
}
