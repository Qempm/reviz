/// Le choix des questions d'une session.
///
/// Avant : `order('probability').limit(10)` — les dix mêmes questions à
/// chaque session, dans le même ordre, et la plupart des questions d'un
/// cours jamais montrées. Au deuxième passage, l'étudiant n'apprenait plus
/// rien ; c'est exactement ce que ChatGPT fait aussi bien.
///
/// Maintenant, dans cet ordre de priorité :
///  1. les questions **jamais vues** ;
///  2. celles **ratées** à la dernière réponse ;
///  3. celles des **chapitres faibles** ;
///  4. les autres, **les plus anciennement revues d'abord** — le principe de
///     la répétition espacée, sans rien stocker de plus que les réponses.
/// À priorité égale, « souvent posée » passe devant, puis le hasard.
///
/// Fonction pure : l'historique arrive en paramètre, le hasard aussi, pour
/// que les tests soient reproductibles.
library;

import 'dart:math';

enum ModeSession {
  /// Le mélange ci-dessus.
  normal,

  /// Seulement les questions ratées à la dernière réponse.
  erreurs,
}

/// La dernière réponse de l'étudiant à une question.
class DerniereReponse {
  const DerniereReponse({required this.juste, required this.le});

  final bool juste;
  final DateTime le;
}

/// Ce que la sélection a besoin de savoir d'une question.
class QuestionAChoisir<T> {
  const QuestionAChoisir({
    required this.valeur,
    required this.id,
    required this.chapitreId,
    required this.probabilite,
  });

  final T valeur;
  final String id;
  final String? chapitreId;

  /// `high`, `medium` ou `low`.
  final String probabilite;
}

int _rangProbabilite(String p) => switch (p) {
  'high' => 0,
  'medium' => 1,
  _ => 2,
};

/// Les chapitres faibles : au moins deux questions déjà répondues, et moins
/// de la moitié justes à la dernière réponse.
Set<String> chapitresFaibles<T>(
  List<QuestionAChoisir<T>> questions,
  Map<String, DerniereReponse> historique,
) {
  final tentees = <String, int>{};
  final justes = <String, int>{};
  for (final q in questions) {
    final ch = q.chapitreId;
    final r = historique[q.id];
    if (ch == null || r == null) continue;
    tentees[ch] = (tentees[ch] ?? 0) + 1;
    if (r.juste) justes[ch] = (justes[ch] ?? 0) + 1;
  }
  return {
    for (final e in tentees.entries)
      if (e.value >= 2 && (justes[e.key] ?? 0) * 2 < e.value) e.key,
  };
}

List<T> choisirQuestions<T>({
  required List<QuestionAChoisir<T>> questions,
  required Map<String, DerniereReponse> historique,
  ModeSession mode = ModeSession.normal,
  int combien = 10,
  Random? hasard,
}) {
  final alea = hasard ?? Random();

  var candidates = questions;
  if (mode == ModeSession.erreurs) {
    candidates = [
      for (final q in questions)
        if (historique[q.id]?.juste == false) q,
    ];
  }

  final faibles = chapitresFaibles(questions, historique);

  int priorite(QuestionAChoisir<T> q) {
    final r = historique[q.id];
    if (r == null) return 0;
    if (!r.juste) return 1;
    if (faibles.contains(q.chapitreId)) return 2;
    return 3;
  }

  // Un tirage par question, fixé avant le tri : un comparateur qui tirerait
  // au sort à chaque comparaison serait incohérent.
  final tirage = {for (final q in candidates) q.id: alea.nextDouble()};

  final triees = [...candidates]
    ..sort((a, b) {
      final pa = priorite(a);
      final pb = priorite(b);
      if (pa != pb) return pa.compareTo(pb);

      // Parmi les questions déjà justes : la plus anciennement revue d'abord.
      if (pa == 3) {
        final la = historique[a.id]!.le;
        final lb = historique[b.id]!.le;
        final c = la.compareTo(lb);
        if (c != 0) return c;
      }

      final prob = _rangProbabilite(
        a.probabilite,
      ).compareTo(_rangProbabilite(b.probabilite));
      if (prob != 0) return prob;
      return tirage[a.id]!.compareTo(tirage[b.id]!);
    });

  final retenues = triees.take(combien).map((q) => q.valeur).toList();
  // L'ordre d'affichage, lui, est mélangé : sinon la session commencerait
  // toujours par la même catégorie.
  retenues.shuffle(alea);
  return retenues;
}

/// Les propositions d'une question, dans un ordre nouveau à chaque fois : la
/// bonne réponse ne doit pas se retenir par sa position.
List<String> melanger(List<String> options, Random hasard) =>
    [...options]..shuffle(hasard);
