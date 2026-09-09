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
    titre: 'Bienvenue sur Reviz',
    sousTitre:
      'Connecte-toi pour retrouver tes cours, tes QCM et tes corrections.',

    avecGoogle: 'Continuer avec Google',
    ou: 'ou',

    labelEmail: 'Ton email',
    aideEmail: 'On t’envoie un code à 6 chiffres. Pas de mot de passe à retenir.',
    envoyerCode: 'Recevoir le code',

    titreCode: 'Le code',
    // %s est remplacé par l'adresse email.
    sousTitreCode: 'On vient d’envoyer 6 chiffres à %s.',
    changerEmail: 'Ce n’est pas mon email',
    valider: 'Valider',
    renvoyer: 'Renvoyer le code',
    // %s est remplacé par le nombre de secondes.
    renvoyerDans: 'Nouveau code dans %s s',

    erreurs: {
      emailInvalide: 'Cette adresse ne ressemble pas à un email.',
      codeIncomplet: 'Il manque des chiffres.',
      codeInvalide: 'Ce code ne marche pas. Vérifie, ou demandes-en un nouveau.',
      codeExpire: 'Ce code a expiré. Demandes-en un nouveau.',
      tropDeTentatives: 'Trop d’essais. Patiente une minute avant de réessayer.',
      googleAnnule: 'Connexion Google annulée.',
      envoiImpossible:
        'On n’a pas pu envoyer le code. Vérifie ta connexion et réessaie.',
      inconnue: 'Quelque chose a coincé de notre côté. Réessaie.',
    },
  },

  inscription: {
    titre: 'On fait connaissance',
    sousTitre:
      'Ces informations servent à te proposer les bons cours et à te situer dans ta faculté.',
    labelPrenom: 'Ton prénom',
    labelUniversite: 'Ton université',
    labelFiliere: 'Ta filière',
    labelAnnee: 'Ton année',
    /** L1, L2… puis M1, M2 au-delà de la licence. */
    annee: (n: number) => (n <= 3 ? `L${n}` : `M${n - 3}`),
    labelParrain: 'Code parrain (facultatif)',
    aideParrain: 'Si un camarade t’a donné son code, il touche une commission.',
    terminer: 'Terminer mon inscription',
  },

  // Le numéro reste demandé à l'inscription, mais facultatif : il ne sert
  // qu'aux notifications WhatsApp (CLAUDE.md, règle métier 3).
  telephone: {
    label: 'Numéro WhatsApp (facultatif)',
    aide: 'Pour recevoir tes rappels de révision. Tu peux l’ajouter plus tard.',
    pays: 'Pays',
    erreurLongueur: 'Ce numéro ne ressemble pas à un numéro %s.',
    dejaUtilise: 'Ce numéro est déjà lié à un autre compte.',
  },
} as const

export type Fr = typeof fr

/** Remplace les `%s` d'un gabarit, dans l'ordre. */
export function t(gabarit: string, ...valeurs: (string | number)[]): string {
  let i = 0
  return gabarit.replace(/%s/g, () => String(valeurs[i++] ?? ''))
}
