/// Modèles de données, construits depuis les lignes PostgREST.
///
/// Écrits à la main plutôt que générés : le schéma est stable, les vues sont
/// peu nombreuses, et une passe de codegen pour une douzaine de classes
/// coûterait plus qu'elle ne rapporte.
///
/// **Toutes les colonnes de vue sont nullables**, comme toute vue Postgres :
/// les fabriques écartent donc les lignes sans identifiant plutôt que
/// d'affirmer un type que la base ne garantit pas — la même prudence que côté
/// web.
library;

/// Le profil de l'étudiant connecté.
class Profil {
  const Profil({
    required this.id,
    required this.prenom,
    required this.xpTotal,
    required this.serieCourante,
    required this.dernierJourValide,
    required this.faculteId,
    required this.universiteNom,
    required this.faculteNom,
    required this.codeParrain,
  });

  final String id;
  final String? prenom;
  final int xpTotal;
  final int serieCourante;
  final String? dernierJourValide;
  final String? faculteId;
  final String? universiteNom;
  final String? faculteNom;
  final String? codeParrain;

  static Profil depuis(Map<String, dynamic> l) => Profil(
    id: l['id'] as String,
    prenom: l['first_name'] as String?,
    xpTotal: (l['xp_total'] as num?)?.toInt() ?? 0,
    serieCourante: (l['current_streak'] as num?)?.toInt() ?? 0,
    dernierJourValide: l['last_validated_on'] as String?,
    faculteId: l['faculty_id'] as String?,
    universiteNom: (l['universities'] as Map?)?['name'] as String?,
    faculteNom: (l['faculties'] as Map?)?['name'] as String?,
    codeParrain: l['referral_code'] as String?,
  );
}

/// Un jour de la carte des sept jours, tel que le renvoie `streak_week()`.
class JourSerie {
  const JourSerie({
    required this.jourSemaine,
    required this.questions,
    required this.xp,
    required this.valide,
    required this.aujourdhui,
  });

  /// 1 = lundi, 7 = dimanche (isodow).
  final int jourSemaine;
  final int questions;
  final int xp;
  final bool valide;
  final bool aujourdhui;

  static JourSerie depuis(Map<String, dynamic> l) => JourSerie(
    jourSemaine: (l['weekday'] as num).toInt(),
    questions: (l['questions_answered'] as num?)?.toInt() ?? 0,
    xp: (l['xp_earned'] as num?)?.toInt() ?? 0,
    valide: l['is_validated'] as bool? ?? false,
    aujourdhui: l['is_today'] as bool? ?? false,
  );
}

/// Une matière et sa maîtrise, depuis la vue `subject_stats`.
class StatMatiere {
  const StatMatiere({
    required this.matiereId,
    required this.matiereNom,
    required this.questionsFaites,
    required this.scoreMoyen,
    required this.aRevoir,
  });

  final String matiereId;
  final String? matiereNom;
  final int questionsFaites;

  /// Entre 0 et 1.
  final double scoreMoyen;
  final bool aRevoir;

  static StatMatiere? depuis(Map<String, dynamic> l) {
    final id = l['subject_id'] as String?;
    if (id == null) return null;
    return StatMatiere(
      matiereId: id,
      matiereNom: l['subject_name'] as String?,
      questionsFaites: (l['questions_answered'] as num?)?.toInt() ?? 0,
      scoreMoyen: (l['average_score'] as num?)?.toDouble() ?? 0,
      aRevoir: l['is_weak'] as bool? ?? false,
    );
  }
}

/// Un cours avec ses décomptes, depuis la vue `course_overview`.
class ApercuCours {
  const ApercuCours({
    required this.id,
    required this.titre,
    required this.statut,
    required this.demo,
    required this.matiereNom,
    required this.dateExamen,
    required this.nbChapitres,
    required this.nbQuestions,
    required this.nbFiches,
    required this.nbTentees,
  });

  final String id;
  final String? titre;
  final String? statut;
  final bool demo;
  final String? matiereNom;
  final String? dateExamen;
  final int nbChapitres;
  final int nbQuestions;
  final int nbFiches;
  final int nbTentees;

  bool get pret => statut == 'ready';
  bool get echoue => statut == 'failed';

  double get progression => nbQuestions == 0 ? 0 : nbTentees / nbQuestions;

  static ApercuCours? depuis(Map<String, dynamic> l) {
    final id = l['id'] as String?;
    if (id == null) return null;
    return ApercuCours(
      id: id,
      titre: l['title'] as String?,
      statut: l['status'] as String?,
      demo: l['is_demo'] as bool? ?? false,
      matiereNom: l['subject_name'] as String?,
      dateExamen: l['exam_date'] as String?,
      nbChapitres: (l['nb_chapitres'] as num?)?.toInt() ?? 0,
      nbQuestions: (l['nb_questions'] as num?)?.toInt() ?? 0,
      nbFiches: (l['nb_fiches'] as num?)?.toInt() ?? 0,
      nbTentees: (l['nb_tentees'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Un chapitre et sa maîtrise, depuis la vue `chapter_stats`.
class ApercuChapitre {
  const ApercuChapitre({
    required this.id,
    required this.index,
    required this.titre,
    required this.nbQuestions,
    required this.nbFiches,
    required this.nbTentees,
    required this.taux,
    required this.aRevoir,
  });

  final String id;
  final int index;
  final String? titre;
  final int nbQuestions;
  final int nbFiches;
  final int nbTentees;

  /// `null` si rien n'a encore été tenté.
  final double? taux;
  final bool aRevoir;

  static ApercuChapitre? depuis(Map<String, dynamic> l) {
    final id = l['id'] as String?;
    if (id == null) return null;
    return ApercuChapitre(
      id: id,
      index: (l['index'] as num?)?.toInt() ?? 0,
      titre: l['title'] as String?,
      nbQuestions: (l['nb_questions'] as num?)?.toInt() ?? 0,
      nbFiches: (l['nb_fiches'] as num?)?.toInt() ?? 0,
      nbTentees: (l['nb_tentees'] as num?)?.toInt() ?? 0,
      taux: (l['taux'] as num?)?.toDouble(),
      aRevoir: l['is_weak'] as bool? ?? false,
    );
  }
}

/// Une question de QCM, avec sa réponse attendue.
///
/// La réponse attendue descend jusqu'au client, **volontairement** : c'est ce
/// qui rend le verdict immédiat et permet à une session de survivre à une
/// coupure. Ce n'est pas un secret — l'explication l'énonce de toute façon —
/// et c'est le serveur qui recorrige avant d'écrire quoi que ce soit.
class QuestionQcm {
  const QuestionQcm({
    required this.id,
    required this.enonce,
    required this.options,
    required this.reponse,
    required this.explication,
    required this.probabilite,
  });

  final String id;
  final String enonce;
  final List<String> options;
  final String reponse;
  final String? explication;
  final String probabilite;

  bool get souventPosee => probabilite == 'high';

  /// `null` si la question est inutilisable : moins de deux propositions, ou
  /// une réponse absente des propositions. Mieux vaut l'écarter que
  /// l'afficher insoluble.
  static QuestionQcm? depuis(Map<String, dynamic> l) {
    final id = l['id'] as String?;
    final enonce = l['statement'] as String?;
    final reponse = l['answer'] as String?;
    if (id == null || enonce == null || reponse == null) return null;

    final brutes = l['options'];
    final options = brutes is List
        ? brutes.whereType<String>().toList()
        : const <String>[];

    if (options.length < 2 || !options.contains(reponse)) return null;

    return QuestionQcm(
      id: id,
      enonce: enonce,
      options: options,
      reponse: reponse,
      explication: l['explanation'] as String?,
      probabilite: (l['probability'] as String?) ?? 'medium',
    );
  }
}

/// Une université, pour l'inscription.
class Universite {
  const Universite({required this.id, required this.nom});
  final String id;
  final String nom;

  static Universite? depuis(Map<String, dynamic> l) {
    final id = l['id'] as String?;
    final nom = l['name'] as String?;
    if (id == null || nom == null) return null;
    return Universite(id: id, nom: nom);
  }
}

/// Une filière.
class Faculte {
  const Faculte({required this.id, required this.nom, required this.universiteId});
  final String id;
  final String nom;
  final String universiteId;

  static Faculte? depuis(Map<String, dynamic> l) {
    final id = l['id'] as String?;
    final nom = l['name'] as String?;
    final uni = l['university_id'] as String?;
    if (id == null || nom == null || uni == null) return null;
    return Faculte(id: id, nom: nom, universiteId: uni);
  }
}

/// Un gain d'XP renvoyé par `/api/session/terminer`.
class GainSession {
  const GainSession({required this.motif, required this.montant});
  final String motif;
  final int montant;

  static GainSession depuis(Map<String, dynamic> l) => GainSession(
    motif: (l['reason'] as String?) ?? 'adjustment',
    montant: (l['amount'] as num?)?.toInt() ?? 0,
  );
}

/// Résultat d'une session, tel que le renvoie la route.
class ResultatSession {
  const ResultatSession({
    required this.bonnes,
    required this.total,
    required this.xp,
    required this.gains,
    required this.objectifAtteint,
    required this.serie,
  });

  final int bonnes;
  final int total;
  final int xp;
  final List<GainSession> gains;
  final bool objectifAtteint;
  final int serie;

  int get pourcentage => total == 0 ? 0 : (bonnes / total * 100).round();

  static ResultatSession depuis(Map<String, dynamic> l) => ResultatSession(
    bonnes: (l['bonnes'] as num?)?.toInt() ?? 0,
    total: (l['total'] as num?)?.toInt() ?? 0,
    xp: (l['xp'] as num?)?.toInt() ?? 0,
    gains: ((l['gains'] as List?) ?? const [])
        .whereType<Map>()
        .map((g) => GainSession.depuis(Map<String, dynamic>.from(g)))
        .toList(),
    objectifAtteint: l['objectifAtteint'] as bool? ?? false,
    serie: (l['serie'] as num?)?.toInt() ?? 0,
  );
}
