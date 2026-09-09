/**
 * Tous les textes d'interface. Rien d'écrit en dur dans les composants.
 * Ton : tutoiement, phrases courtes (CLAUDE.md, section Design system).
 */
export const fr = {
  commun: {
    continuer: 'Continuer',
    annuler: 'Annuler',
    reessayer: 'Réessayer',
    chargement: 'Un instant…',
    retour: 'Retour',
  },

  connexion: {
    titreTelephone: 'Ton numéro',
    sousTitreTelephone:
      'On t’envoie un code par WhatsApp. Pas de mot de passe à retenir.',
    labelTelephone: 'Numéro de téléphone',
    pays: 'Pays',
    envoyerCode: 'Recevoir le code',

    titreCode: 'Le code',
    // %s est remplacé par le numéro masqué.
    sousTitreCode: 'On vient d’envoyer 6 chiffres au %s.',
    changerNumero: 'Ce n’est pas mon numéro',
    valider: 'Valider',
    renvoyer: 'Renvoyer le code',
    // %s est remplacé par le nombre de secondes.
    renvoyerDans: 'Nouveau code dans %s s',

    erreurs: {
      vide: 'Entre ton numéro pour continuer.',
      longueur: 'Ce numéro ne ressemble pas à un numéro %s.',
      pays_inconnu: 'On ne reconnaît pas cet indicatif.',
      codeIncomplet: 'Il manque des chiffres.',
      codeInvalide: 'Ce code ne marche pas. Vérifie, ou demandes-en un nouveau.',
      codeExpire: 'Ce code a expiré. Demandes-en un nouveau.',
      tropDeTentatives: 'Trop d’essais. Patiente une minute avant de réessayer.',
      envoiImpossible:
        'On n’a pas pu envoyer le code. Vérifie ta connexion et réessaie.',
      inconnue: 'Quelque chose a coincé de notre côté. Réessaie.',
    },
  },
} as const

export type Fr = typeof fr

/** Remplace les `%s` d'un gabarit, dans l'ordre. */
export function t(gabarit: string, ...valeurs: (string | number)[]): string {
  let i = 0
  return gabarit.replace(/%s/g, () => String(valeurs[i++] ?? ''))
}
