import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/i18n/fr.dart';
import 'package:reviz/metier/ligues.dart';

/// Mêmes cas que le scénario SQL de `cloturer_ligues()`.
void main() {
  IssueLigue issue(int rang, int membres, int division, [int xp = 100]) =>
      issueDuRang(rang: rang, membres: membres, division: division, xp: xp);

  test('groupe plein de division 3 : 7 montent, 5 descendent', () {
    final issues = [for (var r = 1; r <= 20; r++) issue(r, 20, 3)];
    expect(issues.where((i) => i == IssueLigue.monte).length, 7);
    expect(issues.where((i) => i == IssueLigue.descend).length, 5);
    expect(issue(15, 20, 3), IssueLigue.reste);
    expect(issue(16, 20, 3), IssueLigue.descend);
  });

  test('en Bronze on ne descend pas, en Diamant on ne monte pas', () {
    expect(issue(30, 30, 1), IssueLigue.reste);
    expect(issue(1, 30, 6), IssueLigue.reste);
    expect(issue(30, 30, 6), IssueLigue.descend);
  });

  test('petit groupe : la montée l’emporte', () {
    expect([
      for (var r = 1; r <= 5; r++) issue(r, 5, 3),
    ], everyElement(IssueLigue.monte));
    expect(issue(8, 10, 3), IssueLigue.descend);
  });

  test('sans XP, pas de montée', () {
    expect(issue(1, 3, 2, 0), IssueLigue.reste);
  });

  test('chaque division a un nom', () {
    for (var d = 1; d <= divisionMax; d++) {
      expect(Fr.ligue.division(d), isNotEmpty);
    }
  });
}
