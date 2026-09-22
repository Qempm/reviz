/// Textes d'interface.
///
/// Port de `lib/i18n/fr.ts`, **section par section, au fur et à mesure des
/// écrans**. Ce n'est pas de la paresse : le dépôt web compte déjà huit
/// composants que seul son kitchen-sink consomme et une couche IA de
/// 979 lignes que personne n'appelle. Porter quatre cents lignes de chaînes
/// qu'aucun écran n'affiche encore créerait la même dette, et elles
/// divergeraient en silence.
///
/// Ce qui est ici est ce que la galerie et le socle utilisent réellement.
library;

abstract final class Fr {
  static const commun = _Commun();
  static const session = _Session();
  static const reviser = _Reviser();
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

class _Session {
  const _Session();

  final String valider = 'Valider';
  final String suivante = 'Question suivante';
  final String voirResultat = 'Voir mon résultat';
  final String juste = 'C’est juste';
  final String faux = 'Ce n’est pas ça';
  final String bonneReponse = 'La bonne réponse';
  final String probable = 'Souvent posée';

  /// Position dans la session.
  String question(int i, int total) => 'Question $i sur $total';

  String score(int bonnes, int total) => '$bonnes / $total';
  String precision(int pct) => '$pct % de réussite';
  String xpGagnes(int n) => '+$n XP';
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

  String decompte(int chapitres, int questions, int fiches) => [
    chapitres <= 1 ? '$chapitres chapitre' : '$chapitres chapitres',
    questions <= 1 ? '$questions question' : '$questions questions',
    fiches <= 1 ? '$fiches fiche' : '$fiches fiches',
  ].join(' · ');
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

  /// Configuration absente au build — une erreur de développeur, pas
  /// d'étudiant, mais qui doit se lire quand elle arrive.
  String configurationManquante(List<String> variables) =>
      'Configuration incomplète : ${variables.join(', ')}. '
      'Voir apps/mobile/lib/donnees/config.dart.';
}
