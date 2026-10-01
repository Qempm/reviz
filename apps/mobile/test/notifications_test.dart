import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/metier/notifications.dart';

/// Les mêmes cas que `lib/metier/notifications.test.ts` : le centre de
/// notifications et le push disent exactement la même chose.
void main() {
  final cas =
      (jsonDecode(
                File(
                  '../../lib/metier/notifications.cas.json',
                ).readAsStringSync(),
              )
              as List)
          .cast<Map<String, dynamic>>();

  test('chaque cas partagé avec le serveur se rend mot pour mot', () {
    expect(cas, isNotEmpty);
    for (final c in cas) {
      final kind = c['kind'] as String;
      final t = texteDe(kind, Map<String, dynamic>.from(c['data'] as Map));
      expect(t.titre, c['titre'], reason: kind);
      expect(t.corps, c['corps'], reason: kind);
      expect(lienDe(kind, c['reference'] as String?), c['lien'], reason: kind);
    }
  });

  test('chaque sorte connue a un cas', () {
    for (final kind in categories.keys) {
      expect(cas.any((c) => c['kind'] == kind), isTrue, reason: kind);
    }
  });

  test('une ligne de la base se lit, une sorte inconnue est ignorée', () {
    final n = NotificationReviz.depuis({
      'id': 'n1',
      'kind': 'cours_pret',
      'reference_id': 'c1',
      'data': {'titre': 'Droit'},
      'read_at': null,
      'created_at': '2026-10-01T12:00:00Z',
    })!;
    expect(n.lue, isFalse);
    expect(n.lien, '/cours/c1');
    expect(n.categorie, CategorieNotification.cours);
    expect(n.marqueeLue().lue, isTrue);

    expect(
      NotificationReviz.depuis({'id': 'n2', 'kind': 'nouveau_truc'}),
      isNull,
    );
  });

  test('un lien inconnu ou forgé mène à l’accueil', () {
    expect(cheminDe('/cours/abc-123'), '/cours/abc-123');
    expect(cheminDe('/ligue'), '/ligue');
    expect(cheminDe('https://ailleurs.example'), '/');
    expect(cheminDe('/cours/../admin'), '/');
    expect(cheminDe('/profil/supprimer-compte'), '/');
    expect(cheminDe(null), '/');
  });

  test('les nombres s’écrivent à la française', () {
    expect(nombreLisible(27.5), '27,5');
    expect(nombreLisible(40), '40');
    expect(nombreLisible(4250), '4 250');
  });
}
