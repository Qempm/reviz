import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/metier/examen.dart';

void main() {
  // Tard le soir : l'heure où l'étudiant révise, et celle où une soustraction
  // de millisecondes arrondirait « demain » à zéro jour.
  final soir = DateTime(2026, 9, 29, 23, 40);

  test('compte en jours de calendrier, pas en heures', () {
    expect(joursAvant('2026-09-30', maintenant: soir), 1);
    expect(joursAvant('2026-10-04', maintenant: soir), 5);
  });

  test('aujourd’hui vaut zéro, hier ne vaut rien', () {
    expect(joursAvant('2026-09-29', maintenant: soir), 0);
    expect(joursAvant('2026-09-28', maintenant: soir), isNull);
  });

  test('lit une date complète comme une date seule', () {
    expect(joursAvant('2026-10-01T00:00:00+00:00', maintenant: soir), 2);
  });

  test('ne plante pas sur une date illisible', () {
    expect(joursAvant('bientôt', maintenant: soir), isNull);
    expect(joursAvant('2026-xx-01', maintenant: soir), isNull);
  });
}
