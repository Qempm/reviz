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
    voirTout: 'Tout voir',
    bientot: 'Bientôt disponible',
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

  tableauDeBord: {
    salutation: (prenom: string) => `Bonjour ${prenom}`.trim(),
    sousTitre: 'Prêt à réviser aujourd’hui ?',
    streakVide: 'Réponds à 10 questions aujourd’hui pour lancer ta série.',
    mesMatieres: 'Mes matières',
    pointFaible: 'À revoir',
    questionsFaites: (n: number) =>
      n <= 1 ? `${n} question répondue` : `${n} questions répondues`,
    aucuneMatiere: 'Aucune matière pour l’instant',
    aucuneMatiereDetail:
      'Ajoute ton premier cours et Reviz en tire des QCM et des fiches.',
    ajouterCours: 'Ajouter un cours',
  },

  boutique: {
    titre: 'Les packs',
    sousTitre: 'Tu paies une fois, pour une durée précise. Rien ne se renouvelle.',
    recommande: 'Conseillé',
    gratuit: 'Gratuit',
    duree: (j: number) => (j <= 1 ? `${j} jour d’accès` : `${j} jours d’accès`),
    corrections: (n: number) =>
      n === 0
        ? 'Aucune correction incluse'
        : n <= 1
          ? `${n} correction de copie`
          : `${n} corrections de copie`,
    matieres: (n: number | null) =>
      n === null
        ? 'Toutes tes matières'
        : n <= 1
          ? `${n} matière`
          : `${n} matières`,
    choisir: 'Choisir ce pack',
    accesActif: (j: number) =>
      j <= 1 ? 'Ton accès finit aujourd’hui' : `Accès actif encore ${j} jours`,
    correctionsRestantes: (n: number) =>
      n === 0
        ? 'Plus de correction disponible'
        : n <= 1
          ? `${n} correction restante`
          : `${n} corrections restantes`,
    accesExpire: 'Ton pack est arrivé à terme',
    accesExpireDetail:
      'Tes cours et ton historique restent consultables. Réactive pour générer de nouveau.',
    sansReconduction:
      'Aucun prélèvement automatique. À la fin de la période, l’accès s’arrête, tout simplement.',
  },

  reviser: {
    titre: 'Réviser',
    aucunCours: 'Aucun cours déposé',
    aucunCoursDetail:
      'Envoie un PDF, un Word ou des photos de ton cours. Reviz s’occupe du reste.',
    ajouterCours: 'Ajouter un cours',
  },

  corriger: {
    titre: 'Corriger',
    aucuneCorrection: 'Aucune copie corrigée',
    aucuneCorrectionDetail:
      'Photographie ta copie et son sujet, tu reçois une note et un barème détaillé.',
    deposer: 'Déposer une copie',
  },

  gains: {
    titre: 'Mes gains',
    solde: 'Solde disponible',
    retraitPossible: 'Tu peux demander un retrait.',
    resteAvantRetrait: (n: number) =>
      `Encore ${n.toLocaleString('fr-FR')} F avant de pouvoir retirer.`,
    tonCode: 'Ton code parrain',
    aideCode:
      'Partage-le : tu touches 25 % de chaque paiement de tes filleuls pendant 12 mois.',
    aucunFilleul: 'Aucun filleul pour l’instant',
    aucunFilleulDetail:
      'Un filleul compte dès qu’il est vérifié et qu’il a payé une première fois.',
    filleulsPayants: (n: number) =>
      n <= 1 ? `${n} filleul actif` : `${n} filleuls actifs`,
  },

  profil: {
    titre: 'Mon profil',
    sansTelephone: 'Aucun numéro renseigné',
    verifie: 'Compte vérifié',
    verifieDetail: 'Ta carte étudiante a été validée.',
    nonVerifie: 'Compte non vérifié',
    nonVerifieDetail:
      'Ajoute ta carte étudiante pour débloquer le parrainage et les cours partagés.',
    voirLesPacks: 'Les packs et mon accès',
    deconnexion: 'Me déconnecter',
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
