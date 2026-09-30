import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/i18n/fr.dart';
import 'package:reviz/metier/niveaux.dart';

void main() {
  test('les paliers s’allongent', () {
    expect(seuilNiveau(1), 0);
    expect(seuilNiveau(2), 150);
    expect(seuilNiveau(3), 350);
    expect(seuilNiveau(5), 900);
    expect(seuilNiveau(10), 3150);
    for (var n = 2; n < 60; n++) {
      expect(
        seuilNiveau(n + 1) - seuilNiveau(n),
        greaterThan(seuilNiveau(n) - seuilNiveau(n - 1)),
      );
    }
  });

  test('le niveau et l’avancée dans le niveau', () {
    expect(niveauDepuisXp(0).numero, 1);
    expect(niveauDepuisXp(149).numero, 1);
    expect(niveauDepuisXp(150).numero, 2);
    final n = niveauDepuisXp(250);
    expect(n.numero, 2);
    expect(n.progression, closeTo(0.5, 1e-9));
    expect(n.xpRestants, 100);
  });

  test('une XP négative (ajustement) reste au niveau 1', () {
    expect(niveauDepuisXp(-40).numero, 1);
    expect(niveauDepuisXp(-40).progression, 0);
  });

  test('chaque niveau a un nom', () {
    for (var n = 1; n <= 80; n++) {
      expect(Fr.niveaux.nom(n), isNotEmpty);
    }
    expect(Fr.niveaux.nom(1), isNot(Fr.niveaux.nom(40)));
  });
}
