import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Aucun `.order()` sans sens de tri explicite.
///
/// En Dart, `order(colonne)` trie par défaut en ordre **décroissant** —
/// l'inverse du client JavaScript. Le 30 septembre 2026, cela faisait
/// commencer le chemin d'un cours par son dernier chapitre (le seul ouvert),
/// lister les écoles de Z à A et mélanger les fiches. Chaque tri doit donc
/// dire `ascending: true` ou `ascending: false`.
void main() {
  test('chaque .order() dit son sens de tri', () {
    final implicite = RegExp(r"\.order\(\s*'[^']+'\s*\)");
    final fautifs = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lignes = f.readAsLinesSync();
      for (var i = 0; i < lignes.length; i++) {
        final ligne = lignes[i];
        if (ligne.trimLeft().startsWith('//')) continue;
        if (implicite.hasMatch(ligne)) fautifs.add('${f.path}:${i + 1}');
      }
    }
    expect(fautifs, isEmpty, reason: 'Tri sans sens explicite : $fautifs');
  });
}
