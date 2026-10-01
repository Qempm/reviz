import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/i18n/fr.dart';
import 'package:reviz/metier/rappels.dart';

List<Rappel> _planifier({
  required DateTime maintenant,
  int serie = 4,
  bool journeeFaite = false,
  List<ExamenAVenir> examens = const [],
  DateTime? finPack,
  OptionsRappels options = const OptionsRappels(),
}) => planifierRappels(
  maintenant: maintenant,
  serie: serie,
  journeeFaite: journeeFaite,
  examens: examens,
  finPack: finPack,
  titreSerie: Fr.rappels.serieTitre,
  texteSerie: Fr.rappels.serieTexte,
  titreExamen: Fr.rappels.examenTitre,
  texteExamen: Fr.rappels.examenTexte,
  titrePack: Fr.rappels.packTitre,
  textePack: Fr.rappels.packTexte,
  options: options,
);

void main() {
  test('série à faire : ce soir à 20 h', () {
    final r = _planifier(maintenant: DateTime(2026, 9, 30, 14));
    final serie = r.firstWhere((x) => x.id == idSerie);
    expect(serie.quand, DateTime(2026, 9, 30, 20));
    expect(serie.titre, contains('4 jours'));
  });

  test('journée faite, ou déjà passé 20 h : demain soir', () {
    expect(
      _planifier(
        maintenant: DateTime(2026, 9, 30, 14),
        journeeFaite: true,
      ).firstWhere((x) => x.id == idSerie).quand,
      DateTime(2026, 10, 1, 20),
    );
    expect(
      _planifier(
        maintenant: DateTime(2026, 9, 30, 21),
      ).firstWhere((x) => x.id == idSerie).quand,
      DateTime(2026, 10, 1, 20),
    );
  });

  test('examen : J-3 et J-1 à 18 h, seulement dans le futur', () {
    final r = _planifier(
      maintenant: DateTime(2026, 9, 30, 19),
      examens: [
        (coursId: 'c1', titre: 'Droit civil', jour: DateTime(2026, 10, 3)),
        (coursId: null, titre: 'Passé', jour: DateTime(2026, 9, 20)),
      ],
    );
    final examens = r.where((x) => x.id >= idPremierExamen).toList();
    // J-3 = 30/09 18 h est déjà passé à 19 h : seul J-1 reste.
    expect(examens.map((x) => x.quand), [DateTime(2026, 10, 2, 18)]);
    expect(examens.single.titre, contains('Droit civil'));
    expect(examens.single.titre, contains('demain'));
  });

  test('pack : la veille de la fin à 10 h', () {
    final r = _planifier(
      maintenant: DateTime(2026, 9, 30, 8),
      finPack: DateTime(2026, 10, 5, 23, 59),
    );
    expect(
      r.firstWhere((x) => x.id == idPackFin).quand,
      DateTime(2026, 10, 4, 10),
    );
  });

  test('identifiants uniques', () {
    final r = _planifier(
      maintenant: DateTime(2026, 9, 1),
      examens: [
        for (var i = 1; i <= 5; i++)
          (coursId: null, titre: 'E$i', jour: DateTime(2026, 10, i * 3)),
      ],
      finPack: DateTime(2026, 11, 1),
    );
    expect(r.map((x) => x.id).toSet().length, r.length);
  });

  test('sans série, le rappel en lance une', () {
    final r = _planifier(maintenant: DateTime(2026, 9, 30, 9), serie: 0);
    expect(r.first.titre, isNot(contains('0 jour')));
  });

  test('l’heure du rappel du soir est celle choisie', () {
    final r = _planifier(
      maintenant: DateTime(2026, 9, 30, 14),
      options: const OptionsRappels(heureSerie: 18),
    );
    expect(
      r.firstWhere((x) => x.id == idSerie).quand,
      DateTime(2026, 9, 30, 18),
    );

    // Passé 18 h : demain à 18 h, et non ce soir à 20 h.
    final tard = _planifier(
      maintenant: DateTime(2026, 9, 30, 19),
      options: const OptionsRappels(heureSerie: 18),
    );
    expect(
      tard.firstWhere((x) => x.id == idSerie).quand,
      DateTime(2026, 10, 1, 18),
    );
  });

  test('une heure hors de 6 h – 23 h est ramenée dans la plage', () {
    final r = _planifier(
      maintenant: DateTime(2026, 9, 30, 1),
      options: const OptionsRappels(heureSerie: 3),
    );
    expect(r.firstWhere((x) => x.id == idSerie).quand.hour, heureSerieMin);
  });

  test('chaque rappel se coupe seul', () {
    List<Rappel> avec(OptionsRappels o) => _planifier(
      maintenant: DateTime(2026, 9, 1, 9),
      examens: [(coursId: 'c1', titre: 'Droit', jour: DateTime(2026, 9, 10))],
      finPack: DateTime(2026, 9, 20),
      options: o,
    );
    final tout = avec(const OptionsRappels());
    expect(
      tout.map((r) => r.id),
      containsAll([idSerie, idPackFin, idPremierExamen]),
    );

    expect(
      avec(const OptionsRappels(serie: false)).any((r) => r.id == idSerie),
      isFalse,
    );
    expect(
      avec(
        const OptionsRappels(examens: false),
      ).any((r) => r.id >= idPremierExamen),
      isFalse,
    );
    expect(
      avec(const OptionsRappels(finPack: false)).any((r) => r.id == idPackFin),
      isFalse,
    );
  });

  test('chaque rappel mène à son écran', () {
    final r = _planifier(
      maintenant: DateTime(2026, 9, 1, 9),
      examens: [(coursId: 'c1', titre: 'Droit', jour: DateTime(2026, 9, 10))],
      finPack: DateTime(2026, 9, 20),
    );
    expect(r.firstWhere((x) => x.id == idSerie).lien, '/');
    expect(r.firstWhere((x) => x.id == idPremierExamen).lien, '/cours/c1');
    expect(r.firstWhere((x) => x.id == idPackFin).lien, '/boutique');
    expect(r.every((x) => x.id <= idRappelMax), isTrue);
  });
}
