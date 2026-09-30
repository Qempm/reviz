import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/donnees/depots.dart';
import 'package:reviz/donnees/modeles.dart';

/// La liste des chapitres de tous les cours a été cassée depuis le portage :
/// l'application demandait une colonne `id` à la vue `chapter_stats`, qui
/// n'en a pas. Aucun test ne pouvait le voir — les écrans reçoivent des
/// données factices. Ce test lit la définition SQL de la vue et vérifie que
/// chaque colonne demandée y existe.
void main() {
  /// Les colonnes d'une vue, lues dans la migration qui la crée : les alias
  /// (`… as nom`) et les colonnes nues (`ch.nom`) du `select` final.
  Set<String> colonnesDeLaVue(String fichier, String vue) {
    final sql = File('../../supabase/migrations/$fichier').readAsStringSync();
    final debut = sql.indexOf('create view public.$vue');
    expect(debut, isNot(-1), reason: 'vue $vue introuvable dans $fichier');
    final corps = sql.substring(debut);
    // Le `select` final, celui qui suit la CTE, jusqu'au `from` de premier
    // niveau.
    final select = corps.substring(corps.indexOf('\nselect\n'));
    final fin = select.indexOf('\nfrom ');
    final liste = select.substring(0, fin);

    final noms = <String>{};
    for (final m in RegExp(r'\bas\s+([a-z_]+)').allMatches(liste)) {
      noms.add(m.group(1)!);
    }
    for (final m in RegExp(r'^\s*[a-z]+\.([a-z_]+),?\s*$', multiLine: true)
        .allMatches(liste)) {
      noms.add(m.group(1)!);
    }
    return noms;
  }

  test('les colonnes lues dans chapter_stats existent dans la vue', () {
    final vue = colonnesDeLaVue(
      '20260910120100_vue_chapitres.sql',
      'chapter_stats',
    );
    final demandees = DepotCours.colonnesChapitres
        .split(',')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty);

    for (final colonne in demandees) {
      expect(vue, contains(colonne), reason: 'chapter_stats.$colonne');
    }
    // La cause du défaut, nommément.
    expect(vue, isNot(contains('id')));
  });

  test('un chapitre de la vue se lit par chapter_id', () {
    final ch = ApercuChapitre.depuis({
      'chapter_id': 'ch1',
      'index': 2,
      'title': 'Les jointures',
      'nb_questions': 4,
      'nb_fiches': 4,
      'nb_tentees': 0,
      'taux': null,
      'is_weak': false,
    });
    expect(ch, isNotNull);
    expect(ch!.id, 'ch1');
    expect(ch.nbQuestions, 4);
  });
}
