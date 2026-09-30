// Les séries finies sans réseau, gardées sur le téléphone.
//
// L'étudiant révise dans le bus, dans un amphi sans couverture, avec un
// forfait épuisé : avant, une série finie hors ligne était perdue — dix
// réponses, la série du jour, les XP. Elle est maintenant gardée ici, et
// renvoyée dès que le réseau revient (`_Transversal`, dans `main.dart`).
//
// Chaque série porte un identifiant tiré au départ : le serveur reconnaît un
// renvoi et ne compte rien deux fois (`lib/metier/session.ts`).

library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

const String cleSessionsEnAttente = 'reviz.sessions-en-attente';

/// Au-delà, une série refusée pour une autre raison que le réseau est
/// abandonnée : elle ne passera jamais, et la garder la renverrait sans fin.
const int essaisMax = 5;

/// Une série trop vieille ne compte plus pour la série du jour ni pour la
/// ligue de la semaine : on la laisse partir.
const Duration ageMax = Duration(days: 14);

class SessionEnAttente {
  const SessionEnAttente({
    required this.sessionId,
    required this.coursId,
    required this.reponses,
    required this.le,
    this.essais = 0,
  });

  final String sessionId;
  final String coursId;
  final List<({String questionId, String? choix})> reponses;
  final DateTime le;
  final int essais;

  SessionEnAttente avecUnEssaiDePlus() => SessionEnAttente(
    sessionId: sessionId,
    coursId: coursId,
    reponses: reponses,
    le: le,
    essais: essais + 1,
  );

  Map<String, dynamic> versJson() => {
    'sessionId': sessionId,
    'coursId': coursId,
    'reponses': [
      for (final r in reponses) {'q': r.questionId, 'c': r.choix},
    ],
    'le': le.toIso8601String(),
    'essais': essais,
  };

  static SessionEnAttente? depuis(Object? brut) {
    if (brut is! Map) return null;
    final id = brut['sessionId'];
    final cours = brut['coursId'];
    final le = DateTime.tryParse(brut['le'] as String? ?? '');
    if (id is! String || cours is! String || le == null) return null;
    return SessionEnAttente(
      sessionId: id,
      coursId: cours,
      le: le,
      essais: (brut['essais'] as num?)?.toInt() ?? 0,
      reponses: [
        for (final r in (brut['reponses'] as List?) ?? const [])
          if (r is Map && r['q'] is String)
            (questionId: r['q'] as String, choix: r['c'] as String?),
      ],
    );
  }
}

enum IssueEnvoi { envoyee, garder, abandonner }

/// Pas de réseau, ou une session à renouveler (401) : ce n'est pas la série
/// qui est en cause, on réessaiera sans compter.
bool _passager(ReponseEchec<Object?> e) =>
    e.motif == 'reseau' || e.statut == 401;

/// Que faire d'une série après une tentative d'envoi.
IssueEnvoi deciderEnvoi(
  Reponse<Object?> reponse,
  SessionEnAttente s,
  DateTime maintenant,
) {
  if (reponse is ReponseSucces) return IssueEnvoi.envoyee;
  if (maintenant.difference(s.le) > ageMax) return IssueEnvoi.abandonner;
  if (_passager(reponse as ReponseEchec<Object?>)) return IssueEnvoi.garder;
  return s.essais + 1 >= essaisMax ? IssueEnvoi.abandonner : IssueEnvoi.garder;
}

class FileHorsLigne {
  FileHorsLigne();

  bool _enCours = false;

  Future<List<SessionEnAttente>> lire() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final brut = prefs.getString(cleSessionsEnAttente);
      if (brut == null) return [];
      final liste = jsonDecode(brut);
      if (liste is! List) return [];
      return [for (final e in liste) ?SessionEnAttente.depuis(e)];
    } catch (_) {
      return [];
    }
  }

  Future<bool> _ecrire(List<SessionEnAttente> sessions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.setString(
        cleSessionsEnAttente,
        jsonEncode([for (final s in sessions) s.versJson()]),
      );
    } catch (_) {
      return false;
    }
  }

  /// Garde une série ; `false` si le téléphone n'a pas pu l'écrire.
  Future<bool> ajouter(SessionEnAttente s) async {
    final sessions = await lire();
    sessions.removeWhere((e) => e.sessionId == s.sessionId);
    return _ecrire([...sessions, s]);
  }

  /// Renvoie ce qui attend, dans l'ordre. S'arrête au premier échec de
  /// réseau : inutile d'essayer les suivantes. Rend le nombre de séries
  /// parties.
  Future<int> envoyer(
    Future<Reponse<Object?>> Function(SessionEnAttente s) envoi, {
    DateTime Function() maintenant = DateTime.now,
  }) async {
    if (_enCours) return 0;
    _enCours = true;
    try {
      final sessions = await lire();
      if (sessions.isEmpty) return 0;
      final restantes = <SessionEnAttente>[];
      var parties = 0;
      var coupe = false;
      for (final s in sessions) {
        if (coupe) {
          restantes.add(s);
          continue;
        }
        final reponse = await envoi(s);
        switch (deciderEnvoi(reponse, s, maintenant())) {
          case IssueEnvoi.envoyee:
            parties++;
          case IssueEnvoi.abandonner:
            break;
          case IssueEnvoi.garder:
            final reseau =
                reponse is ReponseEchec<Object?> && _passager(reponse);
            restantes.add(reseau ? s : s.avecUnEssaiDePlus());
            if (reseau) coupe = true;
        }
      }
      await _ecrire(restantes);
      return parties;
    } finally {
      _enCours = false;
    }
  }
}
