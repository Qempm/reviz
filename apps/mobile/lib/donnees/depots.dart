// Accès aux données.
//
// Deux canaux, et la règle qui les sépare (docs/API.md § 1) : toute lecture
// que la RLS sait filtrer passe en direct par PostgREST, toute écriture qui
// exige un privilège passe par une route Next.js. Les quatre vues sont en
// `security_invoker`, donc consommables telles quelles.

import 'api.dart';
import 'modeles.dart';
import 'supabase.dart';

/// Petite aide : PostgREST renvoie des `Map<String, dynamic>` déjà typées,
/// mais les fabriques qui peuvent refuser une ligne renvoient `null`.
List<T> _garder<T>(
  List<dynamic> lignes,
  T? Function(Map<String, dynamic>) fabrique,
) {
  final gardees = <T>[];
  for (final l in lignes) {
    if (l is! Map) continue;
    final objet = fabrique(Map<String, dynamic>.from(l));
    if (objet != null) gardees.add(objet);
  }
  return gardees;
}

// ---------------------------------------------------------------- Profil

class DepotProfil {
  const DepotProfil();

  /// Le profil de l'utilisateur connecté, ou `null` s'il n'a pas encore
  /// terminé son inscription.
  Future<Profil?> mien() async {
    final id = supabase.auth.currentUser?.id;
    if (id == null) return null;

    final ligne = await supabase
        .from('profiles')
        .select(
          'id, first_name, xp_total, current_streak, last_validated_on, '
          'faculty_id, referral_code, universities(name), faculties(name)',
        )
        .eq('id', id)
        .maybeSingle();

    if (ligne == null) return null;
    return Profil.depuis(ligne);
  }

  Future<List<Universite>> universites() async {
    final lignes = await supabase.from('universities').select('id, name').order('name');
    return _garder(lignes, Universite.depuis);
  }

  Future<List<Faculte>> facultes(String universiteId) async {
    final lignes = await supabase
        .from('faculties')
        .select('id, name, university_id')
        .eq('university_id', universiteId)
        .order('name');
    return _garder(lignes, Faculte.depuis);
  }

  /// Création du profil — par la route, pas en direct.
  ///
  /// Le code parrain désigne un profil dont la RLS ne laisse rien lire : la
  /// recherche exige le rôle de service. Et depuis la phase 0, les colonnes
  /// privilégiées de `profiles` sont verrouillées par trigger, donc une
  /// insertion cliente ne pourrait de toute façon plus rien s'octroyer.
  Future<Reponse<String>> creer({
    required ApiReviz api,
    required String prenom,
    required String universiteId,
    required String faculteId,
    required int annee,
    String? codeParrain,
  }) {
    return api.poster<String>(
      '/api/profil',
      corps: {
        'prenom': prenom,
        'universiteId': universiteId,
        'faculteId': faculteId,
        'annee': annee,
        if (codeParrain != null && codeParrain.isNotEmpty)
          'codeParrain': codeParrain,
      },
      depuis: (data) => data['id'] as String,
    );
  }
}

// --------------------------------------------------------------- Accueil

class DonneesAccueil {
  const DonneesAccueil({
    required this.profil,
    required this.semaine,
    required this.objectif,
    required this.matieres,
  });

  final Profil profil;
  final List<JourSerie> semaine;
  final int objectif;
  final List<StatMatiere> matieres;

  JourSerie? get aujourdhui {
    for (final j in semaine) {
      if (j.aujourdhui) return j;
    }
    return null;
  }
}

class DepotAccueil {
  const DepotAccueil();

  /// Tout ce que le tableau de bord affiche, en une salve.
  ///
  /// `Future.wait` et non quatre attentes en file : l'étudiant est sur une
  /// connexion instable, et quatre allers-retours en série se voient.
  Future<DonneesAccueil?> charger() async {
    final profil = await const DepotProfil().mien();
    if (profil == null) return null;

    // Les constructeurs de requête de supabase_flutter sont des `Future` par
    // `Thenable`, mais pas des `Future` au sens du type : on les enveloppe
    // explicitement pour que `Future.wait` les accepte.
    final resultats = await Future.wait<dynamic>([
      Future<dynamic>.value(supabase.rpc('streak_week')),
      Future<dynamic>.value(supabase.rpc('daily_goal')),
      Future<dynamic>.value(
        supabase
            .from('subject_stats')
            .select(
              'subject_id, subject_name, questions_answered, average_score, '
              'is_weak',
            )
            .order('questions_answered', ascending: false)
            .limit(4),
      ),
    ]);

    return DonneesAccueil(
      profil: profil,
      semaine: _garder(resultats[0] as List? ?? const [], JourSerie.depuis),
      objectif: (resultats[1] as num?)?.toInt() ?? 10,
      matieres: _garder(resultats[2] as List? ?? const [], StatMatiere.depuis),
    );
  }
}

// ----------------------------------------------------------------- Cours

class DepotCours {
  const DepotCours();

  /// Les cours visibles, démonstration épinglée en tête.
  ///
  /// La RLS filtre : mes cours, ceux partagés dans ma faculté, et les
  /// démonstrations. Aucun filtre à écrire ici.
  Future<List<ApercuCours>> liste() async {
    final lignes = await supabase
        .from('course_overview')
        .select(
          'id, title, status, is_demo, subject_name, exam_date, '
          'nb_chapitres, nb_questions, nb_fiches, nb_tentees, created_at',
        )
        .order('is_demo', ascending: false)
        .order('created_at', ascending: false);

    return _garder(lignes, ApercuCours.depuis);
  }

  Future<ApercuCours?> un(String id) async {
    final ligne = await supabase
        .from('course_overview')
        .select(
          'id, title, status, is_demo, subject_name, exam_date, '
          'nb_chapitres, nb_questions, nb_fiches, nb_tentees',
        )
        .eq('id', id)
        .maybeSingle();

    if (ligne == null) return null;
    return ApercuCours.depuis(ligne);
  }

  Future<List<ApercuChapitre>> chapitres(String coursId) async {
    final lignes = await supabase
        .from('chapter_stats')
        .select(
          'id, index, title, nb_questions, nb_fiches, nb_tentees, taux, '
          'is_weak',
        )
        .eq('course_id', coursId)
        .order('index');

    return _garder(lignes, ApercuChapitre.depuis);
  }

  /// Les questions d'une session : QCM seulement, les plus probables d'abord.
  ///
  /// L'énumération `question_probability` est déclarée (high, medium, low),
  /// donc l'ordre croissant de Postgres est déjà celui de la promesse produit
  /// — « les questions qui vont probablement tomber ».
  ///
  /// Dix par session, comme `public.daily_goal()` : une session finie doit
  /// pouvoir valider la journée, sinon la série reste hors d'atteinte de qui
  /// révise une fois par jour.
  Future<List<QuestionQcm>> questionsDeSession(
    String coursId, {
    int combien = 10,
  }) async {
    final lignes = await supabase
        .from('questions')
        .select(
          'id, statement, options, answer, explanation, probability, '
          'chapters!inner(course_id)',
        )
        .eq('chapters.course_id', coursId)
        .eq('type', 'mcq')
        .order('probability')
        .limit(combien);

    return _garder(lignes, QuestionQcm.depuis);
  }

  /// Fin de session — par la route : le serveur recorrige depuis
  /// `questions.answer` avant d'écrire, et attribue les XP avec le rôle de
  /// service.
  Future<Reponse<ResultatSession>> terminerSession({
    required ApiReviz api,
    required String coursId,
    required List<({String questionId, String? choix})> reponses,
  }) {
    return api.poster<ResultatSession>(
      '/api/session/terminer',
      corps: {
        'courseId': coursId,
        'reponses': [
          for (final r in reponses)
            {'questionId': r.questionId, 'choix': r.choix},
        ],
      },
      depuis: ResultatSession.depuis,
    );
  }
}
