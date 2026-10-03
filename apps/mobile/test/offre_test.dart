import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/metier/offre.dart';

/// Les mêmes cas que `lib/metier/offre.test.ts` : la boutique et le site
/// doivent dire la même chose du même pack.
void main() {
  const packs = <PackOffre>[
    (code: 'controle', prixFcfa: 500, jours: 7),
    (code: 'partiel', prixFcfa: 1500, jours: 30),
    (code: 'rattrapage', prixFcfa: 2000, jours: 30),
    (code: 'semestre', prixFcfa: 3500, jours: 120),
  ];

  group('prix par jour', () {
    test('exact quand la division tombe juste', () {
      expect(prixParJour(1500, 30), '50 F par jour');
    });

    test('approché sinon, et dit approché', () {
      expect(prixParJour(500, 7), '≈ 71 F par jour');
      expect(prixParJour(3500, 120), '≈ 29 F par jour');
    });

    test('le moins cher par jour est le semestre', () {
      expect(meilleurPrixParJour(packs), 'semestre');
    });

    test('un pack gratuit ne compte pas', () {
      expect(
        meilleurPrixParJour(const [(code: 'decouverte', prixFcfa: 0, jours: 3)]),
        isNull,
      );
    });
  });

  group('durées et contenus', () {
    test('mois, semaine, jours', () {
      expect(dureeLisible(30), '1 mois');
      expect(dureeLisible(120), '4 mois');
      expect(dureeLisible(7), '1 semaine');
      expect(dureeLisible(3), '3 jours');
    });

    test('matières et corrections', () {
      expect(matieresLisibles(null), 'Toutes tes matières');
      expect(matieresLisibles(1), '1 matière');
      expect(correctionsLisibles(10), '10 corrections');
    });
  });

  group('conseil', () {
    test('le pack conseillé est le partiel', () {
      expect(packConseille, 'partiel');
      expect(choixInitial(packs), 'partiel');
    });

    test('sans partiel, le premier payant', () {
      expect(choixInitial(packs.where((p) => p.code != 'partiel')), 'controle');
    });

    test('la phrase de conseil', () {
      expect(
        phraseConseil(
          code: 'partiel',
          libelle: 'Partiel',
          jours: 30,
          matieres: 5,
          corrections: 10,
        ),
        'Pour tes partiels, prends le pack Partiel : 1 mois, 5 matières, '
        '10 corrections.',
      );
    });

    test('un pack inconnu garde son nom', () {
      expect(objectifDe('ete', 'Été').bouton, 'Été');
    });
  });
}
