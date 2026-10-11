import type { ErreurTuteur } from './tuteur-serveur'

/**
 * Les refus du tuteur, en phrases et en statuts HTTP. Partagés par les deux
 * routes, pour que l'écran reçoive toujours le même `motif` et la même phrase.
 */
export const MESSAGES_TUTEUR: Record<ErreurTuteur, string> = {
  invalide: 'Ta réponse n’a pas pu partir. Réessaie.',
  'essai-utilise': 'Tu as déjà utilisé ton essai gratuit : le tuteur fait partie des packs.',
  'plafond-du-jour': 'Tu as fait 20 vérifications aujourd’hui. Reviens demain.',
  introuvable: 'On ne retrouve pas ce chapitre.',
  terminee: 'Cette vérification est terminée.',
  'ia-indisponible': 'Le tuteur est indisponible pour l’instant. Réessaie dans un moment.',
  serveur: 'Un souci de notre côté. Réessaie dans un instant.',
}

export function statutTuteur(erreur: ErreurTuteur): number {
  switch (erreur) {
    case 'invalide':
      return 400
    case 'essai-utilise':
      return 402
    case 'plafond-du-jour':
      return 429
    case 'introuvable':
      return 404
    case 'terminee':
      return 409
    case 'ia-indisponible':
      return 503
    default:
      return 500
  }
}

export function refusTuteur(erreur: ErreurTuteur): Response {
  return Response.json(
    { ok: false, error: MESSAGES_TUTEUR[erreur], motif: erreur },
    { status: statutTuteur(erreur) },
  )
}
