import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/metier/selection.dart';

QuestionAChoisir<String> q(
  String id, {
  String ch = 'c1',
  String p = 'medium',
}) => QuestionAChoisir(valeur: id, id: id, chapitreId: ch, probabilite: p);

DerniereReponse juste(int jour) =>
    DerniereReponse(juste: true, le: DateTime(2026, 9, jour));
DerniereReponse faux(int jour) =>
    DerniereReponse(juste: false, le: DateTime(2026, 9, jour));

void main() {
  test('trois sessions de suite ne montrent pas les mêmes questions', () {
    // Le défaut d'origine : dix questions, toujours les mêmes.
    final banque = [for (var i = 0; i < 30; i++) q('q$i')];
    final historique = <String, DerniereReponse>{};
    final vues = <String>{};

    for (var s = 0; s < 3; s++) {
      final choix = choisirQuestions(
        questions: banque,
        historique: historique,
        hasard: Random(s),
      );
      expect(choix, hasLength(10));
      // Aucune question déjà vue tant qu'il en reste d'inédites.
      expect(vues.intersection(choix.toSet()), isEmpty, reason: 'session $s');
      vues.addAll(choix);
      for (final id in choix) {
        historique[id] = juste(10 + s);
      }
    }
    expect(vues, hasLength(30));
  });

  test('ramène les questions ratées avant celles déjà justes', () {
    final banque = [for (var i = 0; i < 12; i++) q('q$i')];
    final historique = {
      for (var i = 0; i < 12; i++) 'q$i': i < 3 ? faux(5) : juste(5),
    };
    final choix = choisirQuestions(
      questions: banque,
      historique: historique,
      combien: 3,
      hasard: Random(1),
    );
    expect(choix.toSet(), {'q0', 'q1', 'q2'});
  });

  test('parmi les justes, revoit d’abord les plus anciennes', () {
    final banque = [q('vieille'), q('recente'), q('moyenne')];
    final historique = {
      'vieille': juste(1),
      'moyenne': juste(10),
      'recente': juste(20),
    };
    final choix = choisirQuestions(
      questions: banque,
      historique: historique,
      combien: 1,
      hasard: Random(1),
    );
    expect(choix, ['vieille']);
  });

  test('fait passer les chapitres faibles avant les autres', () {
    final banque = [
      q('f1', ch: 'faible'),
      q('f2', ch: 'faible'),
      q('f3', ch: 'faible'),
      q('s1', ch: 'solide'),
      q('s2', ch: 'solide'),
    ];
    final historique = {
      'f1': faux(3),
      'f2': faux(3),
      'f3': juste(3),
      's1': juste(1),
      's2': juste(1),
    };
    // f1, f2 ratées d'abord ; puis f3, juste mais d'un chapitre faible,
    // avant s1 et s2 pourtant plus anciennes.
    final choix = choisirQuestions(
      questions: banque,
      historique: historique,
      combien: 3,
      hasard: Random(2),
    );
    expect(choix.toSet(), {'f1', 'f2', 'f3'});
  });

  test('« souvent posée » passe devant à priorité égale', () {
    final banque = [q('rare', p: 'low'), q('probable', p: 'high')];
    final choix = choisirQuestions(
      questions: banque,
      historique: const {},
      combien: 1,
      hasard: Random(3),
    );
    expect(choix, ['probable']);
  });

  test('le mode erreurs ne garde que les questions ratées', () {
    final banque = [q('a'), q('b'), q('c'), q('d')];
    final historique = {'a': faux(1), 'b': juste(1), 'c': faux(2)};
    final choix = choisirQuestions(
      questions: banque,
      historique: historique,
      mode: ModeSession.erreurs,
      hasard: Random(4),
    );
    expect(choix.toSet(), {'a', 'c'});
  });

  test('le mode erreurs est vide quand rien n’a été raté', () {
    final choix = choisirQuestions(
      questions: [q('a')],
      historique: {'a': juste(1)},
      mode: ModeSession.erreurs,
    );
    expect(choix, isEmpty);
  });

  test('mélange les propositions sans en perdre', () {
    final options = ['A', 'B', 'C', 'D'];
    final ordres = {
      for (var s = 0; s < 20; s++) melanger(options, Random(s)).join(),
    };
    expect(ordres.length, greaterThan(1));
    for (final o in ordres) {
      expect(o.split('')..sort(), options);
    }
  });
}
