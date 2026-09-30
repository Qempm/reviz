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

import '../metier/maitrise.dart';

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
    this.avatar,
    this.statutVerification = 'none',
    this.anneeEtude,
    this.telephone,
    this.meilleureSerie = 0,
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
  final String? avatar;

  /// `none` | `pending` | `verified` | `rejected`, tel quel.
  ///
  /// Gardé en texte brut plutôt qu'en énumération : c'est le serveur qui en
  /// décide, et un statut inconnu doit s'afficher comme « non vérifié » sans
  /// faire échouer la lecture du profil.
  final String statutVerification;
  final int? anneeEtude;

  /// Au format E.164, facultatif et non vérifié : il sert aux notifications
  /// WhatsApp, et à pré-remplir le numéro de paiement.
  final String? telephone;

  /// La plus longue série tenue. « Meilleure série » affichait la série en
  /// cours, qui retombe à zéro au premier jour manqué.
  final int meilleureSerie;

  bool get verifie => statutVerification == 'verified';
  bool get verificationEnCours => statutVerification == 'pending';

  /// Carte refusée : illisible, périmée, ou déjà rattachée à un autre compte.
  /// L'étudiant peut en redéposer une — c'est le seul état qui le permette
  /// après un premier essai.
  bool get verificationRefusee => statutVerification == 'rejected';

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
    avatar: l['avatar_key'] as String?,
    statutVerification: l['verification_status'] as String? ?? 'none',
    anneeEtude: (l['study_year'] as num?)?.toInt(),
    telephone: l['phone'] as String?,
    meilleureSerie: (l['longest_streak'] as num?)?.toInt() ?? 0,
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
    // La vue expose `chapter_id` ; `id` reste lu pour une ligne de `chapters`.
    final id = (l['chapter_id'] ?? l['id']) as String?;
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
    this.chapitreId,
  });

  final String id;
  final String enonce;
  final List<String> options;
  final String reponse;
  final String? explication;
  final String probabilite;
  final String? chapitreId;

  /// La même question, propositions dans un autre ordre.
  QuestionQcm avecOptions(List<String> autres) => QuestionQcm(
    id: id,
    enonce: enonce,
    options: autres,
    reponse: reponse,
    explication: explication,
    probabilite: probabilite,
    chapitreId: chapitreId,
  );

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
      chapitreId: l['chapter_id'] as String?,
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
  const Faculte({
    required this.id,
    required this.nom,
    required this.universiteId,
  });
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

/// Une fiche de révision.
class Fiche {
  const Fiche({
    required this.id,
    required this.recto,
    required this.verso,
    required this.chapitre,
  });

  final String id;
  final String recto;
  final String verso;
  final String? chapitre;

  static Fiche? depuis(Map<String, dynamic> l) {
    final id = l['id'] as String?;
    final recto = l['front'] as String?;
    final verso = l['back'] as String?;
    if (id == null || recto == null || verso == null) return null;
    return Fiche(
      id: id,
      recto: recto,
      verso: verso,
      chapitre: (l['chapters'] as Map?)?['title'] as String?,
    );
  }
}

/// Un pack de la boutique.
class PackBoutique {
  const PackBoutique({
    required this.code,
    required this.libelle,
    required this.description,
    required this.prixFcfa,
    required this.dureeJours,
    required this.correctionsIncluses,
    required this.plafondMatieres,
  });

  final String code;
  final String libelle;
  final String? description;
  final int prixFcfa;
  final int dureeJours;
  final int correctionsIncluses;

  /// `null` vaut illimité.
  final int? plafondMatieres;

  bool get gratuit => prixFcfa == 0;

  static PackBoutique? depuis(Map<String, dynamic> l) {
    final code = l['code'] as String?;
    final libelle = l['label'] as String?;
    if (code == null || libelle == null) return null;
    return PackBoutique(
      code: code,
      libelle: libelle,
      description: l['description'] as String?,
      prixFcfa: (l['price_fcfa'] as num?)?.toInt() ?? 0,
      dureeJours: (l['duration_days'] as num?)?.toInt() ?? 0,
      correctionsIncluses: (l['corrections_included'] as num?)?.toInt() ?? 0,
      plafondMatieres: (l['subjects_limit'] as num?)?.toInt(),
    );
  }
}

/// Une ligne d'abonnement, telle que la base la rend.
class LigneAbonnement {
  const LigneAbonnement({
    required this.code,
    required this.debut,
    required this.fin,
    required this.correctionsRestantes,
    required this.plafondMatieres,
  });

  final String code;
  final DateTime debut;
  final DateTime fin;
  final int correctionsRestantes;
  final int? plafondMatieres;

  static LigneAbonnement? depuis(Map<String, dynamic> l) {
    final code = l['pack_code'] as String?;
    final debut = l['starts_at'] as String?;
    final fin = l['ends_at'] as String?;
    if (code == null || debut == null || fin == null) return null;
    return LigneAbonnement(
      code: code,
      debut: DateTime.parse(debut),
      fin: DateTime.parse(fin),
      correctionsRestantes: (l['corrections_left'] as num?)?.toInt() ?? 0,
      plafondMatieres: ((l['packs'] as Map?)?['subjects_limit'] as num?)
          ?.toInt(),
    );
  }
}

/// Une ligne du classement de la faculté.
///
/// Aucun identifiant : « c'est toi » se lit sur [estMoi]. C'est la fonction
/// SQL qui en décide, pas le client.
class LigneClassement {
  const LigneClassement({
    required this.rang,
    required this.prenom,
    required this.avatar,
    required this.xp,
    required this.estMoi,
  });

  final int rang;
  final String? prenom;
  final String? avatar;
  final int xp;
  final bool estMoi;

  static LigneClassement? depuis(Map<String, dynamic> l) {
    final rang = (l['rang'] as num?)?.toInt();
    if (rang == null) return null;
    return LigneClassement(
      rang: rang,
      prenom: l['prenom'] as String?,
      avatar: l['avatar_key'] as String?,
      xp: (l['xp_total'] as num?)?.toInt() ?? 0,
      estMoi: l['est_moi'] as bool? ?? false,
    );
  }
}

/// Ce que l'écran des gains affiche.
class DonneesGains {
  const DonneesGains({
    required this.soldeFcfa,
    required this.codeParrain,
    required this.filleuls,
    required this.filleulsPayants,
  });

  final int soldeFcfa;
  final String? codeParrain;
  final int filleuls;

  /// Un filleul ne compte que s'il a payé au moins une fois (règle 2).
  final int filleulsPayants;
}

// ------------------------------------------------------- Correction de copie

/// Un nombre tel qu'on l'écrit en français : virgule décimale, et pas de
/// décimale quand il n'y en a pas — « 13,5 » et « 20 », jamais « 13.5 » ni
/// « 20,0 ».
String nombreFr(double v) =>
    v.toStringAsFixed(v % 1 == 0 ? 0 : 1).replaceAll('.', ',');

/// Une ligne du barème.
class LigneBareme {
  const LigneBareme({
    required this.critere,
    required this.points,
    required this.maximum,
    required this.commentaire,
  });

  final String critere;
  final double points;
  final double maximum;
  final String? commentaire;

  /// Part obtenue, entre 0 et 1, pour la barre de progression.
  double get part => maximum <= 0 ? 0 : (points / maximum).clamp(0.0, 1.0);

  static LigneBareme? depuis(Map<String, dynamic> l) {
    final critere = l['criterion'] as String?;
    final maximum = (l['maxPoints'] as num?)?.toDouble();
    if (critere == null || maximum == null || maximum <= 0) return null;

    return LigneBareme(
      critere: critere,
      points: (l['points'] as num?)?.toDouble() ?? 0,
      maximum: maximum,
      commentaire: l['comment'] as String?,
    );
  }
}

/// Le retour rédigé, en trois parties.
class RetourCorrection {
  const RetourCorrection({
    required this.resume,
    required this.pointsForts,
    required this.aTravailler,
    this.chapitres = const [],
    this.notions = const [],
  });

  final String? resume;
  final List<String> pointsForts;
  final List<String> aTravailler;

  /// Les chapitres de son cours à revoir d'après la copie : `(id, titre)`.
  final List<(String, String)> chapitres;

  /// Les notions manquées ou confondues.
  final List<String> notions;

  static List<String> _liste(dynamic valeur) {
    if (valeur is! List) return const [];
    return valeur
        .whereType<String>()
        .where((t) => t.trim().isNotEmpty)
        .toList();
  }

  static RetourCorrection depuis(Map<String, dynamic> l) => RetourCorrection(
    resume: l['summary'] as String?,
    pointsForts: _liste(l['strengths']),
    aTravailler: _liste(l['improvements']),
    chapitres: [
      for (final c in (l['chapitres'] as List?) ?? const [])
        if (c is Map && c['id'] is String)
          (c['id'] as String, c['titre'] as String? ?? ''),
    ],
    notions: _liste(l['notions']),
  );
}

/// Une correction, telle que la base la rend.
///
/// `rubric` et `feedback` sont du `jsonb` : on les décode défensivement — une
/// ligne de barème malformée est ignorée, elle ne fait pas échouer la lecture
/// de toute la correction.
class Correction {
  const Correction({
    required this.id,
    required this.statut,
    required this.note,
    required this.bareme,
    required this.lignes,
    required this.retour,
    required this.modele,
    required this.creeLe,
    required this.motifIllisible,
    this.coursId,
  });

  final String id;

  /// Le cours rattaché, s'il y en a un : c'est lui qu'on révise ensuite.
  final String? coursId;

  /// `pending` | `processing` | `ready` | `failed`, tel quel.
  final String statut;
  final double? note;
  final double? bareme;
  final List<LigneBareme> lignes;
  final RetourCorrection? retour;
  final String? modele;
  final DateTime? creeLe;

  /// Renseigné quand le modèle a déclaré la copie illisible : ce n'est pas une
  /// panne, l'étudiant n'a qu'à reprendre la photo.
  final String? motifIllisible;

  bool get enAttente => statut == 'pending' || statut == 'processing';
  bool get prete => statut == 'ready';
  bool get echouee => statut == 'failed';
  bool get illisible => motifIllisible != null;

  /// Taux obtenu, entre 0 et 1.
  double get taux {
    final n = note;
    final b = bareme;
    if (n == null || b == null || b <= 0) return 0;
    return (n / b).clamp(0.0, 1.0);
  }

  static Correction? depuis(Map<String, dynamic> l) {
    final id = l['id'] as String?;
    if (id == null) return null;

    final brutRetour = l['feedback'];
    final retour = brutRetour is Map
        ? Map<String, dynamic>.from(brutRetour)
        : null;

    final lignes = <LigneBareme>[];
    final brutBareme = l['rubric'];
    if (brutBareme is List) {
      for (final ligne in brutBareme) {
        if (ligne is! Map) continue;
        final lue = LigneBareme.depuis(Map<String, dynamic>.from(ligne));
        if (lue != null) lignes.add(lue);
      }
    }

    final creeLe = l['created_at'] as String?;

    return Correction(
      id: id,
      coursId: l['course_id'] as String?,
      statut: l['status'] as String? ?? 'pending',
      note: (l['grade'] as num?)?.toDouble(),
      bareme: (l['max_grade'] as num?)?.toDouble(),
      lignes: lignes,
      // Le retour du serveur porte `summary` quand la copie a été corrigée,
      // et `motif` quand elle ne l'a pas été.
      retour: retour != null && retour['summary'] != null
          ? RetourCorrection.depuis(retour)
          : null,
      modele: l['model_used'] as String?,
      creeLe: creeLe == null ? null : DateTime.tryParse(creeLe),
      // Parenthèses nécessaires : sans elles, l'analyseur lit `as String`
      // puis prend le `?` de `String?` pour un second opérateur ternaire.
      motifIllisible: retour?['illisible'] == true
          ? (retour?['motif'] as String?)
          : null,
    );
  }
}

/// Un fichier prêt à partir : ce que la route de préparation attend, et ce
/// qu'il faudra téléverser ensuite.
class FichierAEnvoyer {
  const FichierAEnvoyer({
    required this.champ,
    required this.octets,
    required this.typeMime,
  });

  /// `copie` (la première page), `page` (les suivantes) ou `sujet`.
  final String champ;
  final List<int> octets;
  final String typeMime;

  Map<String, dynamic> get description => {
    'mime': typeMime,
    'taille': octets.length,
  };
}

/// Ce que la préparation rend : l'identifiant réservé et les URL d'envoi.
class DepotPrepare {
  const DepotPrepare({required this.correctionId, required this.envois});

  final String correctionId;

  /// Une entrée par fichier, dans l'ordre : la copie, puis le sujet.
  final List<({String champ, String url})> envois;

  static DepotPrepare depuis(Map<String, dynamic> l) {
    final brut = l['envois'];
    final envois = <({String champ, String url})>[];

    if (brut is List) {
      for (final e in brut) {
        if (e is! Map) continue;
        final champ = e['champ'] as String?;
        final url = e['url'] as String?;
        if (champ != null && url != null) {
          envois.add((champ: champ, url: url));
        }
      }
    }

    return DepotPrepare(
      correctionId: l['correctionId'] as String,
      envois: envois,
    );
  }
}

// ------------------------------------------------------- Dépôt d'un cours

/// Une matière de la faculté, pour le choix au dépôt.
class Matiere {
  const Matiere({required this.id, required this.nom});

  final String id;
  final String nom;

  static Matiere? depuis(Map<String, dynamic> l) {
    final id = l['id'] as String?;
    final nom = l['name'] as String?;
    if (id == null || nom == null) return null;
    return Matiere(id: id, nom: nom);
  }
}

/// Un document choisi, en mémoire, prêt à partir.
class DocumentChoisi {
  const DocumentChoisi({
    required this.nom,
    required this.octets,
    required this.typeMime,
  });

  final String nom;
  final List<int> octets;
  final String typeMime;

  int get kilos => (octets.length / 1024).round();

  /// Le nom du fichier sans son extension : un titre par défaut convenable,
  /// que l'étudiant n'a plus qu'à corriger.
  String get titreSuggere {
    final sansExtension = nom.contains('.')
        ? nom.substring(0, nom.lastIndexOf('.'))
        : nom;
    // Les gestionnaires de fichiers rendent volontiers
    // « cours_droit-const_L1 » : on rend cela lisible.
    final propre = sansExtension
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return propre.isEmpty ? nom : propre;
  }
}

/// Ce que la préparation du dépôt rend.
class DepotCoursPrepare {
  const DepotCoursPrepare({required this.coursId, required this.urlEnvoi});

  final String coursId;
  final String urlEnvoi;

  static DepotCoursPrepare depuis(Map<String, dynamic> l) => DepotCoursPrepare(
    coursId: l['courseId'] as String,
    urlEnvoi: l['uploadUrl'] as String,
  );
}

/// Ce que rend `/api/carte/preparer`.
class CartePreparee {
  const CartePreparee({required this.chemin, required this.urlEnvoi});

  /// Le chemin dans le seau `cartes`, à renvoyer à la confirmation.
  final String chemin;
  final String urlEnvoi;

  static CartePreparee depuis(Map<String, dynamic> l) => CartePreparee(
    chemin: l['chemin'] as String,
    urlEnvoi: l['uploadUrl'] as String,
  );
}

/// Un chapitre sur le chemin du cours : ce qu'on en montre, et où en est
/// l'étudiant (`metier/maitrise.dart`).
class ChapitreDuChemin {
  const ChapitreDuChemin({required this.chapitre, required this.maitrise});

  final ApercuChapitre chapitre;
  final Maitrise maitrise;
}

/// La ligue de la semaine, telle que la rend `ma_ligue()`.
class DonneesLigue {
  const DonneesLigue({
    required this.division,
    required this.fin,
    required this.membres,
    this.derniere,
  });

  final int division;

  /// Lundi suivant, 00:00 UTC.
  final DateTime fin;

  /// Le groupe de la semaine ; vide tant que l'étudiant n'a rien gagné.
  final List<LigneClassement> membres;

  /// L'issue de la dernière semaine close, s'il y en a une.
  final BilanLigue? derniere;

  /// Le bilan, seulement s'il porte sur la semaine qui vient de finir : celui
  /// d'il y a un mois n'a plus rien à annoncer.
  BilanLigue? get bilanRecent {
    final d = derniere;
    final lundi = DateTime.tryParse(d?.semaine ?? '');
    if (d == null || lundi == null) return null;
    final precedent = fin.toUtc().subtract(const Duration(days: 14));
    final memeJour =
        lundi.year == precedent.year &&
        lundi.month == precedent.month &&
        lundi.day == precedent.day;
    return memeJour ? d : null;
  }

  LigneClassement? get moi {
    for (final m in membres) {
      if (m.estMoi) return m;
    }
    return null;
  }

  static DonneesLigue depuis(Map<String, dynamic> l) {
    final derniere = l['derniere'];
    return DonneesLigue(
      division: (l['division'] as num?)?.toInt() ?? 1,
      fin:
          DateTime.tryParse(l['fin'] as String? ?? '') ??
          DateTime.now().add(const Duration(days: 7)),
      membres: [
        for (final m in (l['membres'] as List?) ?? const [])
          if (m is Map)
            LigneClassement(
              rang: (m['rang'] as num?)?.toInt() ?? 0,
              prenom: m['prenom'] as String?,
              avatar: m['avatar'] as String?,
              xp: (m['xp'] as num?)?.toInt() ?? 0,
              estMoi: m['moi'] as bool? ?? false,
            ),
      ],
      derniere: derniere is Map
          ? BilanLigue.depuis(Map<String, dynamic>.from(derniere))
          : null,
    );
  }
}

/// L'issue d'une semaine close.
class BilanLigue {
  const BilanLigue({
    required this.semaine,
    required this.rang,
    required this.issue,
    required this.division,
  });

  /// Le lundi de la semaine, `AAAA-MM-JJ`.
  final String semaine;
  final int rang;

  /// `monte`, `reste` ou `descend`.
  final String issue;

  /// La division **pendant** cette semaine.
  final int division;

  static BilanLigue depuis(Map<String, dynamic> l) => BilanLigue(
    semaine: l['semaine'] as String? ?? '',
    rang: (l['rang'] as num?)?.toInt() ?? 0,
    issue: l['issue'] as String? ?? 'reste',
    division: (l['division'] as num?)?.toInt() ?? 1,
  );
}
