/// Textes d'interface.
///
/// Port de `lib/i18n/fr.ts`, **section par section, au fur et à mesure des
/// écrans**. Ce n'est pas de la paresse : le dépôt web compte déjà huit
/// composants que seul son kitchen-sink consomme et une couche IA de
/// 979 lignes que personne n'appelle. Porter quatre cents lignes de chaînes
/// qu'aucun écran n'affiche encore créerait la même dette, et elles
/// divergeraient en silence.
library;

abstract final class Fr {
  static const commun = _Commun();
  static const connexion = _Connexion();
  static const inscription = _Inscription();
  static const tableauDeBord = _TableauDeBord();
  static const reviser = _Reviser();
  static const cours = _Cours();
  static const session = _Session();
  static const erreurs = _Erreurs();
}

class _Commun {
  const _Commun();

  final String continuer = 'Continuer';
  final String annuler = 'Annuler';
  final String reessayer = 'Réessayer';
  final String chargement = 'Un instant…';
  final String retour = 'Retour';
  final String voirTout = 'Tout voir';
  final String bientot = 'Bientôt disponible';
}

class _Connexion {
  const _Connexion();

  final String titre = 'Bienvenue sur Reviz';
  final String sousTitre =
      'Connecte-toi pour retrouver tes cours, tes QCM et tes corrections.';

  final String avecGoogle = 'Continuer avec Google';
  final String googleIndisponible =
      'La connexion Google n’est pas configurée dans cette version.';
  final String ou = 'ou';

  final String labelEmail = 'Ton email';
  final String aideEmail =
      'On t’envoie un code par mail. Pas de mot de passe à retenir.';
  final String recevoirCode = 'Recevoir mon code';

  final String titreCode = 'Le code';
  String sousTitreCode(String email) => 'On vient d’envoyer un code à $email.';
  final String codeAstuce =
      'Recopie ici les chiffres du mail. Si tu ne vois rien, regarde dans les '
      'indésirables.';
  final String valider = 'Valider';
  final String renvoyer = 'Renvoyer le code';
  String renvoyerDans(int s) => 'Nouveau code dans $s s';
  final String changerEmail = 'Ce n’est pas mon email';

  final String emailInvalide = 'Cette adresse ne ressemble pas à un email.';
  final String codeIncomplet = 'Il manque des chiffres du code.';
  final String codeInvalide =
      'Ce code ne marche pas. Vérifie, ou demandes-en un nouveau.';
  final String envoiImpossible =
      'On n’a pas pu envoyer le code. Vérifie ta connexion et réessaie.';
}

class _Inscription {
  const _Inscription();

  final String titre = 'On fait connaissance';
  final String sousTitre =
      'Ces informations servent à te proposer les bons cours et à te situer '
      'dans ta faculté.';
  final String labelPrenom = 'Ton prénom';
  final String labelUniversite = 'Ton université';
  final String labelFiliere = 'Ta filière';
  final String labelAnnee = 'Ton année';

  /// L1, L2… puis M1, M2 au-delà de la licence.
  String annee(int n) => n <= 3 ? 'L$n' : 'M${n - 3}';

  final String labelParrain = 'Code parrain (facultatif)';
  final String aideParrain =
      'Si un camarade t’a donné son code, il touche une commission.';
  final String terminer = 'Terminer mon inscription';
  final String choisirUniversite = 'Choisis ton université';
  final String choisirFiliere = 'Choisis ta filière';
}

class _TableauDeBord {
  const _TableauDeBord();

  String salutation(String prenom) => 'Bonjour $prenom'.trim();
  final String sousTitre = 'Prêt à réviser aujourd’hui ?';
  final String mesMatieres = 'Mes matières';
  final String pointFaible = 'À revoir';

  String questionsFaites(int n) =>
      n <= 1 ? '$n question répondue' : '$n questions répondues';

  final String aucuneMatiere = 'Aucune matière pour l’instant';
  final String aucuneMatiereDetail =
      'Ajoute ton premier cours et Reviz en tire des QCM et des fiches.';
  final String ajouterCours = 'Ajouter un cours';

  final String serieRompue =
      'Ta série s’est arrêtée. Une session aujourd’hui suffit à en relancer '
      'une.';

  String serieEnJeu(int reste) => reste <= 1
      ? 'Encore une question et ta série tient un jour de plus.'
      : 'Encore $reste questions et ta série tient un jour de plus.';

  String flamme(int jours) =>
      jours > 1 ? '$jours jours de flamme !' : '$jours jour de flamme !';
  final String lanceTaSerie = 'Lance ta série';
  String xpAujourdhui(int n) => '+$n XP aujourd’hui';
  String objectifDuJour(int faites, int but) =>
      '$faites / $but questions aujourd’hui';
}

class _Reviser {
  const _Reviser();

  final String titre = 'Réviser';
  final String sousTitre = 'Tes cours, tes QCM et tes fiches, au même endroit.';
  final String aucunCours = 'Aucun cours déposé';
  final String aucunCoursDetail =
      'Envoie un PDF, un Word ou des photos de ton cours. Reviz s’occupe du '
      'reste.';
  final String ajouterCours = 'Ajouter un cours';
  final String exemple = 'Exemple';
  final String enTraitement = 'En préparation';
  final String seulementDemo =
      'Ce cours est là pour te montrer le principe. Dépose le tien pour de '
      'vrai.';

  String decompte(int chapitres, int questions, int fiches) => [
    chapitres <= 1 ? '$chapitres chapitre' : '$chapitres chapitres',
    questions <= 1 ? '$questions question' : '$questions questions',
    fiches <= 1 ? '$fiches fiche' : '$fiches fiches',
  ].join(' · ');
}

class _Cours {
  const _Cours();

  final String traitementTitre = 'Ton cours est en préparation';
  final String traitementDetail =
      'Reviz lit ton document, le découpe en chapitres et en tire des '
      'questions.';
  final String traitementAstuce =
      'Tu peux fermer l’application : on te prévient dès que c’est prêt.';
  final String echecTitre = 'On n’a pas réussi à lire ce cours';
  final String echecDetail =
      'Le document est peut-être trop flou ou protégé. Réessaie avec un autre '
      'fichier.';

  String progression(int faites, int total) => total == 0
      ? 'Aucune question pour l’instant'
      : '$faites question${faites <= 1 ? '' : 's'} sur $total';

  final String reviser = 'Lancer une session';
  final String chapitres = 'Les chapitres';
  final String aucunChapitre = 'Aucun chapitre';
  final String aucunChapitreDetail = 'Ce cours n’a pas encore été découpé.';

  String decompteChapitre(int questions, int fiches) =>
      '$questions question${questions <= 1 ? '' : 's'} · '
      '$fiches fiche${fiches <= 1 ? '' : 's'}';

  String jMoins(int j) => j == 0
      ? 'Examen aujourd’hui'
      : j == 1
      ? 'Examen demain'
      : 'J−$j';
  final String examenPasse = 'Examen passé';
}

class _Session {
  const _Session();

  final String valider = 'Valider';
  final String suivante = 'Question suivante';
  final String voirResultat = 'Voir mon résultat';
  final String juste = 'C’est juste';
  final String faux = 'Ce n’est pas ça';
  final String bonneReponse = 'La bonne réponse';
  final String probable = 'Souvent posée';

  String question(int i, int total) => 'Question $i sur $total';

  final String aucuneQuestion = 'Aucune question à réviser';
  final String aucuneQuestionDetail =
      'Ce cours n’a pas encore de QCM. Reviens quand la préparation est '
      'finie.';

  final String resultatTitre = 'Session terminée';
  String score(int bonnes, int total) => '$bonnes / $total';
  String precision(int pct) => '$pct % de réussite';
  String xpGagnes(int n) => '+$n XP';
  final String objectifAtteint = 'Objectif du jour atteint';
  String serie(int j) => j <= 1 ? 'Série lancée' : '$j jours de série';
  final String refaire = 'Refaire une session';
  final String retourCours = 'Retour au cours';

  final String echecEnregistrement =
      'On n’a pas pu enregistrer cette session. Ton score s’affiche quand '
      'même.';

  /// Libellés des motifs de `xp_events.reason`.
  final Map<String, String> detailXp = const {
    'correct_answer': 'Bonnes réponses',
    'quiz_completed': 'Session terminée',
    'daily_goal': 'Objectif du jour',
    'streak_bonus': 'Bonus de série',
    'course_added': 'Cours ajouté',
    'correction_done': 'Correction faite',
    'referral': 'Parrainage',
    'adjustment': 'Ajustement',
  };
}

/// Messages d'erreur destinés à l'étudiant.
///
/// Les routes REST renvoient déjà leur message en français : ceux-ci ne
/// servent qu'aux pannes que le client constate lui-même.
class _Erreurs {
  const _Erreurs();

  final String horsLigne =
      'Pas de connexion. Tes cours déjà chargés restent consultables.';
  final String sessionExpiree = 'Ta session a expiré. Reconnecte-toi.';
  final String inconnue = 'Quelque chose a coincé de notre côté. Réessaie.';
  final String chargementImpossible =
      'On n’a pas pu charger cette page. Réessaie.';

  /// Configuration absente au build — une erreur de développeur, pas
  /// d'étudiant, mais qui doit se lire quand elle arrive.
  String configurationManquante(List<String> variables) =>
      'Configuration incomplète : ${variables.join(', ')}. '
      'Voir apps/mobile/lib/donnees/config.dart.';
}
