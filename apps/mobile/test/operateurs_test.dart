import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/metier/operateurs.dart';

/// Mêmes cas que `lib/metier/operateurs.test.ts` : les deux tables doivent
/// dire la même chose, ou l'écran proposerait ce que le serveur refuse.
void main() {
  test('propose les trois réseaux du Bénin', () {
    expect(operateursDuPays('BJ').map((o) => o.code), [
      'mtn',
      'moov',
      'celtiis',
    ]);
  });

  test('ne propose que ce qui se paie sans quitter l’application', () {
    expect(operateursDuPays('CI').map((o) => o.code), ['mtn']);
    expect(operateursDuPays('SN').map((o) => o.code), ['free']);
    expect(operateursDuPays('TG').map((o) => o.code), ['moov', 'togocel']);
  });

  test('ne propose rien au Burkina', () {
    expect(operateursDuPays('BF'), isEmpty);
    expect(operateursDuPays('XX'), isEmpty);
  });

  test('ignore la casse du code pays', () {
    expect(operateursDuPays('bj'), operateursDuPays('BJ'));
  });
}
