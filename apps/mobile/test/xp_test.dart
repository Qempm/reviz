import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/metier/xp.dart';

/// Port de `lib/xp/attribution.test.ts` — 11 tests.
///
/// Deux cas du TypeScript n'existent pas ici : `NaN` et une entrée
/// non entière, que le type `int` de Dart rend impossibles par construction.
/// Ils sont remplacés par les bornes négatives, qui restent atteignables.
void main() {
  group('bonusSerie', () {
    test('ne récompense pas une série de un jour', () {
      // Le premier jour n'est pas une série : c'est un jour.
      expect(bonusSerie(0), 0);
      expect(bonusSerie(1), 0);
    });

    test('donne 5 points par jour', () {
      expect(bonusSerie(2), 10);
      expect(bonusSerie(7), 35);
    });

    test('plafonne, pour que le classement ne se fige pas', () {
      expect(bonusSerie(10), bonusSerieMax);
      expect(bonusSerie(180), bonusSerieMax);
    });

    test('ignore une série négative', () {
      expect(bonusSerie(-3), 0);
    });
  });

  group('gainsDeSession', () {
    test('agrège les bonnes réponses en une seule ligne', () {
      final gains = gainsDeSession(
        bonnes: 7,
        total: 10,
        objectifAtteint: false,
      );

      expect(gains, [
        GainXp(MotifXp.correctAnswer, 7 * bareme[MotifXp.correctAnswer]!),
        GainXp(MotifXp.quizCompleted, bareme[MotifXp.quizCompleted]!),
      ]);
    });

    test('ne donne rien pour une session sans réponse', () {
      // Ouvrir puis quitter l'écran ne doit rien rapporter.
      expect(
        gainsDeSession(bonnes: 0, total: 0, objectifAtteint: false),
        isEmpty,
      );
    });

    test('récompense une session entièrement fausse pour l’avoir finie', () {
      expect(gainsDeSession(bonnes: 0, total: 10, objectifAtteint: false), [
        GainXp(MotifXp.quizCompleted, bareme[MotifXp.quizCompleted]!),
      ]);
    });

    test('ajoute objectif du jour et bonus de série', () {
      final gains = gainsDeSession(
        bonnes: 8,
        total: 10,
        objectifAtteint: true,
        serie: 4,
      );

      expect(gains.map((g) => g.motif).toList(), [
        MotifXp.correctAnswer,
        MotifXp.quizCompleted,
        MotifXp.dailyGoal,
        MotifXp.streakBonus,
      ]);
      expect(totalGains(gains), 80 + 20 + 30 + 20);
    });

    test('n’ajoute pas de bonus de série au premier jour validé', () {
      final gains = gainsDeSession(
        bonnes: 10,
        total: 10,
        objectifAtteint: true,
        serie: 1,
      );

      expect(gains.map((g) => g.motif), isNot(contains(MotifXp.streakBonus)));
    });

    test('ne compte pas de bonus quand l’objectif n’est pas atteint', () {
      final gains = gainsDeSession(
        bonnes: 2,
        total: 3,
        objectifAtteint: false,
        serie: 30,
      );

      final motifs = gains.map((g) => g.motif);
      expect(motifs, isNot(contains(MotifXp.dailyGoal)));
      expect(motifs, isNot(contains(MotifXp.streakBonus)));
    });

    test('borne une entrée négative plutôt que de retirer des points', () {
      final gains = gainsDeSession(
        bonnes: -5,
        total: 3,
        objectifAtteint: false,
      );

      expect(gains.map((g) => g.motif), isNot(contains(MotifXp.correctAnswer)));
      expect(totalGains(gains), bareme[MotifXp.quizCompleted]);
    });
  });

  group('correspondance avec l’énumération Postgres', () {
    test('chaque motif se relit depuis sa valeur SQL', () {
      // Le barème part vers `xp_events.reason` : un écart de nom ferait
      // échouer l'insertion à l'exécution, pas à la compilation.
      for (final m in MotifXp.values) {
        expect(MotifXp.depuisSql(m.sql), m);
      }
      expect(MotifXp.depuisSql('inconnu'), isNull);
    });
  });
}
