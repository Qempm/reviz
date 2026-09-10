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
    aideEmail: 'On t’envoie un lien de connexion. Pas de mot de passe à retenir.',
    envoyerLien: 'Recevoir le lien',

    lienEnvoye: 'Regarde tes mails',
    // %s est remplacé par l'adresse.
    lienEnvoyeDetail: 'On vient d’envoyer un lien de connexion à %s.',
    lienAstuce:
      'Le lien n’est valable qu’une fois, et pour un moment seulement. Si tu ne vois rien, regarde dans les indésirables.',
    renvoyerLien: 'Renvoyer le lien',
    // %s est remplacé par le nombre de secondes.
    renvoyerDans: 'Nouveau lien dans %s s',
    changerEmail: 'Ce n’est pas mon email',

    // Réservé à l'étape « code à six chiffres », prête mais non branchée :
    // elle attend que le gabarit d'email porte {{ .Token }}.
    titreCode: 'Le code',
    sousTitreCode: 'On vient d’envoyer 6 chiffres à %s.',
    valider: 'Valider',
    renvoyer: 'Renvoyer le code',

    erreurs: {
      emailInvalide: 'Cette adresse ne ressemble pas à un email.',
      codeIncomplet: 'Il manque des chiffres.',
      codeInvalide: 'Ce code ne marche pas. Vérifie, ou demandes-en un nouveau.',
      codeExpire: 'Ce lien a expiré. Demandes-en un nouveau.',
      tropDeTentatives: 'Trop d’essais. Patiente une minute avant de réessayer.',
      googleAnnule: 'Connexion Google annulée.',
      envoiImpossible:
        'On n’a pas pu envoyer le lien. Vérifie ta connexion et réessaie.',
      inconnue: 'Quelque chose a coincé de notre côté. Réessaie.',
    },
  },

  tableauDeBord: {
    salutation: (prenom: string) => `Bonjour ${prenom}`.trim(),
    sousTitre: 'Prêt à réviser aujourd’hui ?',
    serieRompue:
      'Ta série s’est arrêtée. Une session aujourd’hui suffit à en relancer une.',
    serieEnJeu: (reste: number) =>
      reste <= 1
        ? 'Encore une question et ta série tient un jour de plus.'
        : `Encore ${reste} questions et ta série tient un jour de plus.`,
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
    activerDecouverte: 'Activer gratuitement',
    decouverteUtilisee: 'Découverte déjà utilisée',
    activationImpossible: 'L’activation n’a pas abouti. Réessaie dans un instant.',
    paiementBientot: 'Paiement Mobile Money bientôt disponible',
    sansReconduction:
      'Aucun prélèvement automatique. À la fin de la période, l’accès s’arrête, tout simplement.',
  },

  reviser: {
    titre: 'Réviser',
    sousTitre: 'Tes cours, tes QCM et tes fiches, au même endroit.',
    aucunCours: 'Aucun cours déposé',
    aucunCoursDetail:
      'Envoie un PDF, un Word ou des photos de ton cours. Reviz s’occupe du reste.',
    ajouterCours: 'Ajouter un cours',

    exemple: 'Exemple',
    enTraitement: 'En préparation',
    examenLe: (date: string) => `Examen le ${dateCourte(date)}`,
    decompte: (chapitres: number, questions: number, fiches: number) =>
      [
        chapitres <= 1 ? `${chapitres} chapitre` : `${chapitres} chapitres`,
        questions <= 1 ? `${questions} question` : `${questions} questions`,
        fiches <= 1 ? `${fiches} fiche` : `${fiches} fiches`,
      ].join(' · '),
    mesMatieres: 'Ma maîtrise',
    maitrise: (pct: number) => `${pct} % de maîtrise`,
    surQuestions: (n: number) =>
      n <= 1 ? `sur ${n} question` : `sur ${n} questions`,
    aRevoir: 'À revoir',
    seulementDemo:
      'Ce cours est là pour te montrer le principe. Dépose le tien pour de vrai.',
  },

  cours: {
    // Trois états de `courses.status` : en préparation, prêt, échoué.
    traitementTitre: 'Ton cours est en préparation',
    traitementDetail:
      'Reviz lit ton document, le découpe en chapitres et en tire des questions.',
    traitementAstuce:
      'Tu peux fermer l’application : on te prévient dès que c’est prêt.',
    // Messages qui défilent pendant l'attente. L'étudiant doit sentir qu'il
    // se passe quelque chose, sans qu'on lui mente sur une progression
    // qu'on ne mesure pas.
    traitementEtapes: [
      'Lecture de ton document…',
      'Découpage en chapitres…',
      'Repérage des notions importantes…',
      'Rédaction des questions…',
      'Préparation des fiches…',
    ],
    traitementLong:
      'C’est plus long que d’habitude. Reviens dans quelques minutes, ton cours continue d’être préparé.',
    actualiser: 'Actualiser',
    echecTitre: 'On n’a pas réussi à lire ce cours',
    echecDetail:
      'Le document est peut-être trop flou ou protégé. Réessaie avec un autre fichier.',

    progression: (faites: number, total: number) =>
      total === 0
        ? 'Aucune question pour l’instant'
        : `${faites} question${faites <= 1 ? '' : 's'} sur ${total}`,
    reviser: 'Lancer une session',
    chapitres: 'Les chapitres',
    voirFiches: (n: number) => (n <= 1 ? 'Voir la fiche' : `Voir les ${n} fiches`),
    decompteChapitre: (questions: number, fiches: number) =>
      `${questions} question${questions <= 1 ? '' : 's'} · ${fiches} fiche${fiches <= 1 ? '' : 's'}`,
    ongletProbables: 'Qui va tomber',
    ongletChapitres: 'Chapitres',
    ongletFiches: 'Fiches',
    ongletFaibles: 'À revoir',
    probableHaute: 'Très probable',
    probableMoyenne: 'Possible',
    probableBasse: 'Peu probable',
    aucuneProbable: 'Aucune question probable',
    aucuneProbableDetail:
      'Les questions arrivent quand la préparation du cours est finie.',
    aucunFaible: 'Rien à revoir pour l’instant',
    aucunFaibleDetail:
      'Fais une session : les notions que tu rates apparaîtront ici.',
    voirLeChapitre: 'Ouvrir le chapitre',
    aucunChapitre: 'Aucun chapitre',
    aucunChapitreDetail: 'Ce cours n’a pas encore été découpé.',
    jMoins: (j: number) =>
      j === 0 ? 'Examen aujourd’hui' : j === 1 ? 'Examen demain' : `J−${j}`,
    examenPasse: 'Examen passé',
  },

  depot: {
    titre: 'Ajouter un cours',
    sousTitre:
      'Un PDF, un Word ou des photos. Reviz le découpe en chapitres et en tire des QCM.',
    labelFichier: 'Choisis ton cours',
    aideFichier: 'PDF, Word ou images. 25 Mo au maximum.',
    labelTitre: 'Titre du cours',
    aideTitre: 'Celui que tu reconnaîtras dans la liste.',
    labelMatiere: 'La matière',
    labelExamen: 'Date de l’examen (facultatif)',
    aideExamen: 'Pour afficher le compte à rebours et prioriser les questions.',
    envoyer: 'Envoyer mon cours',
    envoi: 'Envoi en cours…',
    // %s est remplacé par le pourcentage.
    progression: (pct: number) => `Envoi ${pct} %`,

    // Refus d'accès : la raison doit être dite, pas juste le refus.
    aucunAcces: 'Il te faut un pack pour ajouter un cours',
    aucunAccesDetail:
      'Le pack Découverte est gratuit : une matière pendant trois jours.',
    accesExpire: 'Ton pack est arrivé à terme',
    accesExpireDetail:
      'Tes cours restent consultables. Réactive pour en ajouter un nouveau.',
    plafondMatieres: (n: number) =>
      `Ton pack couvre ${n <= 1 ? 'une matière' : `${n} matières`}`,
    plafondMatieresDetail:
      'Prends un pack plus large pour ajouter une matière de plus.',
    voirLesPacks: 'Voir les packs',

    erreurs: {
      fichierManquant: 'Choisis d’abord un fichier.',
      matiereManquante: 'Choisis la matière du cours.',
      titreManquant: 'Donne un titre à ton cours.',
      dejaDepose: 'Tu as déjà déposé ce document.',
      envoiImpossible: 'L’envoi a échoué. Vérifie ta connexion et réessaie.',
      inconnue: 'Quelque chose a coincé de notre côté. Réessaie.',
    },
  },

  session: {
    titre: 'Session',
    quitter: 'Quitter',
    quitterConfirmation:
      'Tes réponses ne seront pas enregistrées si tu sors maintenant.',
    // Position dans la session.
    question: (i: number, total: number) => `Question ${i} sur ${total}`,
    probable: 'Souvent posée',
    valider: 'Valider',
    suivante: 'Question suivante',
    voirResultat: 'Voir mon résultat',
    juste: 'C’est juste',
    faux: 'Ce n’est pas ça',
    bonneReponse: 'La bonne réponse',
    aucuneQuestion: 'Aucune question à réviser',
    aucuneQuestionDetail:
      'Ce cours n’a pas encore de QCM. Reviens quand la préparation est finie.',

    resultatTitre: 'Session terminée',
    score: (bonnes: number, total: number) => `${bonnes} / ${total}`,
    precision: (pct: number) => `${pct} % de réussite`,
    xpGagnes: (n: number) => `+${n} XP`,
    detailXp: {
      correct_answer: 'Bonnes réponses',
      quiz_completed: 'Session terminée',
      daily_goal: 'Objectif du jour',
      streak_bonus: 'Bonus de série',
      course_added: 'Cours ajouté',
      correction_done: 'Correction faite',
      referral: 'Parrainage',
      adjustment: 'Ajustement',
    },
    objectifAtteint: 'Objectif du jour atteint',
    serie: (j: number) => (j <= 1 ? 'Série lancée' : `${j} jours de série`),
    refaire: 'Refaire une session',
    refaireRatees: 'Revoir mes erreurs',
    retourCours: 'Retour au cours',
    partager: 'Partager sur WhatsApp',
    partageTexte: (bonnes: number, total: number, cours: string) =>
      `J’ai fait ${bonnes}/${total} en ${cours} sur Reviz 📚`,
    // Le score n'a pas été enregistré : on le dit, sans dramatiser.
    echecEnregistrement:
      'On n’a pas pu enregistrer cette session. Ton score s’affiche quand même.',
  },

  chapitre: {
    // %s est remplacé par le numéro.
    numero: (n: number) => `Chapitre ${n}`,
    contenu: 'Le cours',
    fiches: 'Les fiches du chapitre',
    questions: (n: number) =>
      n <= 1 ? `${n} question` : `${n} questions`,
    aucunTexte: 'Ce chapitre n’a pas encore de contenu.',
    reviser: 'Réviser ce chapitre',
  },

  fiches: {
    titre: 'Les fiches',
    sousTitre: 'Touche une fiche pour voir la réponse.',
    aucune: 'Aucune fiche',
    aucuneDetail: 'Les fiches arrivent en même temps que les questions.',
    // Position dans le paquet, pour le lecteur d'écran.
    position: (i: number, total: number) => `Fiche ${i} sur ${total}`,
    recto: 'Question',
    verso: 'Réponse',
    retourner: 'Retourner',
    precedente: 'Précédente',
    suivante: 'Suivante',
    terminee: 'Tu as vu toutes les fiches',
    recommencer: 'Recommencer',
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

} as const

export type Fr = typeof fr

/**
 * Date courte à la française — « 12 janv. ».
 *
 * `courses.exam_date` est une date nue (`YYYY-MM-DD`) : la passer à `new Date()`
 * la lit en UTC, ce qui décale d'un jour à l'ouest de Greenwich. On découpe
 * donc la chaîne au lieu de laisser le fuseau s'en mêler.
 */
export function dateCourte(iso: string): string {
  const [a, m, j] = iso.slice(0, 10).split('-').map(Number)
  if (!a || !m || !j) return iso
  return new Date(a, m - 1, j).toLocaleDateString('fr-FR', {
    day: 'numeric',
    month: 'short',
  })
}

/** Remplace les `%s` d'un gabarit, dans l'ordre. */
export function t(gabarit: string, ...valeurs: (string | number)[]): string {
  let i = 0
  return gabarit.replace(/%s/g, () => String(valeurs[i++] ?? ''))
}
