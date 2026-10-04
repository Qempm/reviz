import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/donnees/cache.dart';

/// Le hors-ligne : ce qui a été lu une fois se relit sans réseau, et rien ne
/// charge sans fin.
class _Memoire implements StockageLectures {
  final Map<String, String> fichiers = {};

  @override
  Future<String?> lire(String cle) async => fichiers[cle];

  @override
  Future<void> ecrire(String cle, String valeur) async =>
      fichiers[cle] = valeur;

  @override
  Future<void> effacer() async => fichiers.clear();
}

void main() {
  late _Memoire disque;
  late bool enLigne;
  late String compte;

  CacheLectures cache({Duration avecCopie = const Duration(seconds: 1)}) =>
      CacheLectures(
        stockage: disque,
        enLigne: () async => enLigne,
        compte: () => compte,
        delaiAvecCopie: avecCopie,
        delaiSansCopie: const Duration(milliseconds: 300),
      );

  /// Laisse l'écriture sur disque se faire (elle part sans être attendue).
  Future<void> ecrite() => Future<void>.delayed(Duration.zero);

  setUp(() {
    disque = _Memoire();
    enLigne = true;
    compte = 'awa';
  });

  test('en ligne : lit le réseau et garde la réponse', () async {
    final c = cache();
    final lu = await c.lire('cours', () async => [
      {'id': 'c1'},
    ]);
    await ecrite();

    expect(lu, [
      {'id': 'c1'},
    ]);
    expect(c.derniere, Provenance.reseau);
    expect(disque.fichiers, hasLength(1));
  });

  test('sans aucune interface réseau : sert la copie sans appeler', () async {
    await cache().lire('cours', () async => [
      {'id': 'c1'},
    ]);
    await ecrite();

    enLigne = false;
    var appele = false;
    // Un nouveau cache relit le disque : c'est le redémarrage hors ligne.
    final c = cache();
    final lu = await c.lire('cours', () async {
      appele = true;
      return const [];
    });

    expect(appele, isFalse);
    expect(lu, [
      {'id': 'c1'},
    ]);
    expect(c.derniere, Provenance.copie);
  });

  test('un réseau qui échoue : la copie prend le relais', () async {
    await cache().lire('questions/c1', () async => [
      {'id': 'q1'},
    ]);
    await ecrite();

    final lu = await cache().lire(
      'questions/c1',
      () async => throw Exception('SocketException'),
    );
    expect(lu, [
      {'id': 'q1'},
    ]);
  });

  test(
    'un réseau qui ne répond jamais : la copie, au bout du délai',
    () async {
      await cache().lire('profil', () async => {'first_name': 'Awa'});
      await ecrite();

      // C'est le chargement sans fin d'avant : la requête attend un jeton
      // qui ne vient pas.
      final jamais = Completer<Object?>();
      final lu = await cache(
        avecCopie: const Duration(milliseconds: 50),
      ).lire('profil', () => jamais.future);
      expect(lu, {'first_name': 'Awa'});
    },
  );

  test('sans copie, un réseau muet finit en erreur, pas en attente', () async {
    final jamais = Completer<Object?>();
    await expectLater(
      cache().lire('ligue', () => jamais.future),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('sans copie, l’échec du réseau remonte', () async {
    await expectLater(
      cache().lire('ligue', () async => throw Exception('hors ligne')),
      throwsException,
    );
  });

  test('une réponse vide se garde aussi (un profil absent reste absent)', () {
    return () async {
      await cache().lire('cours/x', () async => null);
      await ecrite();
      enLigne = false;
      expect(await cache().lire('cours/x', () async => {'id': 'x'}), isNull);
    }();
  });

  test('chaque compte a ses copies', () async {
    await cache().lire('cours', () async => [
      {'id': 'cours-awa'},
    ]);
    await ecrite();

    compte = 'koffi';
    enLigne = false;
    await expectLater(
      cache().lire('cours', () async => throw Exception('hors ligne')),
      throwsException,
    );
  });

  test('effacer ne laisse rien sur le téléphone', () async {
    final c = cache();
    await c.lire('cours', () async => const []);
    await ecrite();
    await c.effacer();
    expect(disque.fichiers, isEmpty);
  });

  test('la date de la copie est connue', () async {
    final c = cache();
    expect(await c.datee('questions/c1'), isNull);
    await c.lire('questions/c1', () async => const []);
    await ecrite();
    final le = await c.datee('questions/c1');
    expect(le, isNotNull);
    expect(DateTime.now().difference(le!).inMinutes, 0);
  });
}
