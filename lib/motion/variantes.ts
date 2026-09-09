import type { Variants, Transition } from 'motion/react'

/**
 * Variantes d'animation partagées.
 *
 * Un seul vocabulaire pour toute l'application : sans cela, chaque écran
 * inventerait ses propres durées et le résultat paraîtrait décousu.
 *
 * Les durées sont courtes — 150 à 300 ms. Au-delà, une transition devient une
 * attente, et l'étudiant qui révise à minuit avant un contrôle n'a pas de
 * temps à donner à nos jolies choses.
 */

export const RESSORT: Transition = {
  type: 'spring',
  stiffness: 420,
  damping: 32,
  mass: 0.7,
}

export const DOUX: Transition = { duration: 0.22, ease: [0.22, 1, 0.36, 1] }

/** Apparition simple, pour un bloc qui entre dans la page. */
export const apparition: Variants = {
  cache: { opacity: 0, y: 12 },
  visible: { opacity: 1, y: 0, transition: DOUX },
  sortie: { opacity: 0, y: -8, transition: { duration: 0.15 } },
}

/** Liste dont les enfants entrent l'un après l'autre. */
export const cascade: Variants = {
  cache: {},
  visible: { transition: { staggerChildren: 0.06, delayChildren: 0.04 } },
}

/** Élément d'une liste en cascade. */
export const elementCascade: Variants = {
  cache: { opacity: 0, y: 16 },
  visible: { opacity: 1, y: 0, transition: RESSORT },
}

/** Question de QCM : entre par la droite, sort par la gauche. */
export const carteQuestion: Variants = {
  cache: (versLaDroite: boolean) => ({
    opacity: 0,
    x: versLaDroite ? 48 : -48,
  }),
  visible: { opacity: 1, x: 0, transition: RESSORT },
  sortie: (versLaDroite: boolean) => ({
    opacity: 0,
    x: versLaDroite ? -48 : 48,
    transition: { duration: 0.16 },
  }),
}

/** Feuille modale qui monte du bas. */
export const feuille: Variants = {
  cache: { y: '100%' },
  visible: { y: 0, transition: RESSORT },
  sortie: { y: '100%', transition: { duration: 0.2 } },
}

/** Compteur ou badge qui apparaît en rebondissant. */
export const rebond: Variants = {
  cache: { scale: 0.6, opacity: 0 },
  visible: { scale: 1, opacity: 1, transition: { ...RESSORT, stiffness: 520 } },
}

/** Variantes neutralisées, servies quand les animations sont réduites. */
export const IMMOBILE: Variants = {
  cache: { opacity: 1 },
  visible: { opacity: 1 },
  sortie: { opacity: 1 },
}
