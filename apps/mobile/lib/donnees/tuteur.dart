import 'api.dart';
import '../metier/tuteur.dart';

/// Le tuteur de maîtrise, côté réseau : deux routes, aucune copie gardée.
///
/// Le tuteur exige le réseau — c'est un modèle qui répond. Ses appels ne
/// passent donc pas par `lu()` : une copie hors ligne d'une question déjà
/// posée n'aurait pas de sens.
///
/// Un tour peut prendre une vingtaine de secondes quand un fournisseur
/// bascule sur le suivant : le délai de réception passe à 60 s pour ces deux
/// appels, au lieu des 30 s par défaut.

/// Le jugement d'une réponse.
class EvaluationTuteur {
  const EvaluationTuteur({required this.niveau, required this.retour});

  final NiveauReponse niveau;
  final String retour;

  factory EvaluationTuteur.depuis(Map<String, dynamic> j) => EvaluationTuteur(
    niveau: NiveauReponse.depuis(j['niveau'] as String? ?? 'faux'),
    retour: j['retour'] as String? ?? '',
  );
}

/// La suite : une question, ou le bilan.
sealed class SuiteTuteur {
  const SuiteTuteur();

  factory SuiteTuteur.depuis(Map<String, dynamic> j) {
    if (j['type'] == 'fin') {
      return FinTuteur(
        maitrise: j['verdict'] == 'maitrise',
        score: (j['score'] as num?)?.toInt() ?? 0,
        bilan: j['bilan'] as String? ?? '',
        aRevoir: [
          for (final n in (j['aRevoir'] as List? ?? const [])) n.toString(),
        ],
      );
    }
    return QuestionTuteur(
      texte: j['texte'] as String? ?? '',
      numero: (j['numero'] as num?)?.toInt() ?? 1,
      total: (j['total'] as num?)?.toInt() ?? questionsParSession,
    );
  }
}

class QuestionTuteur extends SuiteTuteur {
  const QuestionTuteur({
    required this.texte,
    required this.numero,
    required this.total,
  });

  final String texte;
  final int numero;
  final int total;
}

class FinTuteur extends SuiteTuteur {
  const FinTuteur({
    required this.maitrise,
    required this.score,
    required this.bilan,
    required this.aRevoir,
  });

  final bool maitrise;
  final int score;
  final String bilan;
  final List<String> aRevoir;
}

class DemarrageTuteur {
  const DemarrageTuteur({
    required this.sessionId,
    required this.essai,
    required this.question,
  });

  final String sessionId;

  /// La session gratuite d'un étudiant sans pack.
  final bool essai;
  final QuestionTuteur question;

  factory DemarrageTuteur.depuis(Map<String, dynamic> j) {
    final suite = SuiteTuteur.depuis(
      Map<String, dynamic>.from(j['suite'] as Map),
    );
    return DemarrageTuteur(
      sessionId: j['sessionId'] as String,
      essai: j['essai'] == true,
      question: suite is QuestionTuteur
          ? suite
          : const QuestionTuteur(texte: '', numero: 1, total: 3),
    );
  }
}

class TourTuteur {
  const TourTuteur({required this.evaluation, required this.suite});

  final EvaluationTuteur evaluation;
  final SuiteTuteur suite;

  factory TourTuteur.depuis(Map<String, dynamic> j) => TourTuteur(
    evaluation: EvaluationTuteur.depuis(
      Map<String, dynamic>.from(j['evaluation'] as Map),
    ),
    suite: SuiteTuteur.depuis(Map<String, dynamic>.from(j['suite'] as Map)),
  );
}

/// Ce que l'écran demande au tuteur. Une interface, pour que les tests
/// branchent une fausse source sans réseau.
abstract interface class SourceTuteur {
  Future<Reponse<DemarrageTuteur>> demarrer({
    required String coursId,
    required String chapitreId,
  });

  Future<Reponse<TourTuteur>> repondre({
    required String sessionId,
    required String reponse,
  });
}

class DepotTuteur implements SourceTuteur {
  const DepotTuteur(this.api);

  final ApiReviz api;

  static const _delai = Duration(seconds: 60);

  @override
  Future<Reponse<DemarrageTuteur>> demarrer({
    required String coursId,
    required String chapitreId,
  }) => api.poster<DemarrageTuteur>(
    '/api/tuteur/demarrer',
    corps: {'courseId': coursId, 'chapterId': chapitreId},
    depuis: DemarrageTuteur.depuis,
    delai: _delai,
  );

  @override
  Future<Reponse<TourTuteur>> repondre({
    required String sessionId,
    required String reponse,
  }) => api.poster<TourTuteur>(
    '/api/tuteur/repondre',
    corps: {'sessionId': sessionId, 'reponse': reponse},
    depuis: TourTuteur.depuis,
    delai: _delai,
  );
}
