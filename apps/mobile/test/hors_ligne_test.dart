import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/donnees/cache.dart';
import 'package:reviz/donnees/depots.dart';
import 'package:reviz/metier/selection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Les vrais dépôts, face à un serveur muet : le téléphone sans réseau, ou
/// la 3G qui accepte la connexion et ne répond plus. C'était le chargement
/// sans fin. Avec la copie d'un passage précédent, tout doit se lire.
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
  late ServerSocket muet;
  late _Memoire disque;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    // `flutter_test` remplace le réseau par une réponse 400 immédiate : on
    // rend le vrai, pour que les requêtes atteignent le serveur muet et y
    // restent suspendues, comme sur le téléphone.
    HttpOverrides.global = null;
    // Accepte les connexions et ne répond jamais.
    muet = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    muet.listen((_) {});
    await Supabase.initialize(
      url: 'http://127.0.0.1:${muet.port}',
      publishableKey: 'cle-de-test',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
    );
  });

  tearDownAll(() => muet.close());

  setUp(() {
    disque = _Memoire();
    CacheLectures.instance = CacheLectures(
      stockage: disque,
      enLigne: () async => true,
      compte: () => 'awa',
      delaiAvecCopie: const Duration(milliseconds: 200),
      delaiSansCopie: const Duration(milliseconds: 400),
    );
  });

  /// Une copie telle que la laisse un passage en ligne.
  void copie(String cle, Object? valeur) {
    disque.fichiers['awa/$cle'] = jsonEncode({
      'le': DateTime.now().toIso8601String(),
      'v': valeur,
    });
  }

  Map<String, dynamic> question(String id, String chapitre) => {
    'id': id,
    'statement': 'Question $id ?',
    'options': ['A', 'B', 'C', 'D'],
    'answer': 'A',
    'explanation': 'Parce que A.',
    'probability': 'high',
    'chapter_id': chapitre,
    'chapters': {'course_id': 'c1'},
  };

  test('une série se lance hors ligne, depuis la copie du cours', () async {
    copie('questions/c1', [
      for (var i = 0; i < 12; i++) question('q$i', i < 6 ? 'ch1' : 'ch2'),
    ]);
    copie('tentatives/c1', [
      {
        'question_id': 'q0',
        'is_correct': false,
        'answered_at': '2026-10-01T10:00:00Z',
      },
    ]);

    final serie = await const DepotCours().questionsDeSession('c1');
    expect(serie, hasLength(10));

    // Une série de chapitre filtre la même copie.
    final duChapitre = await const DepotCours().questionsDeSession(
      'c1',
      chapitreId: 'ch2',
    );
    expect(duChapitre, hasLength(6));
    expect(duChapitre.every((q) => q.chapitreId == 'ch2'), isTrue);

    // Le mode « erreurs » se sert de l'historique gardé.
    final erreurs = await const DepotCours().questionsDeSession(
      'c1',
      mode: ModeSession.erreurs,
    );
    expect(erreurs.map((q) => q.id), contains('q0'));
  });

  test('le chemin d’un cours s’affiche hors ligne', () async {
    copie('chapitres/c1', [
      {
        'chapter_id': 'ch1',
        'index': 0,
        'title': 'Introduction',
        'nb_questions': 6,
        'nb_fiches': 4,
        'nb_tentees': 1,
        'taux': 0.0,
        'is_weak': false,
      },
    ]);
    copie('qcm/c1', [
      {'id': 'q0', 'chapter_id': 'ch1', 'chapters': {'course_id': 'c1'}},
    ]);
    copie('tentatives/c1', const []);

    final chemin = await const DepotCours().chemin('c1');
    expect(chemin, hasLength(1));
    expect(chemin.first.chapitre.titre, 'Introduction');
  });

  test('les fiches et la liste des cours aussi', () async {
    copie('fiches/c1', [
      {
        'id': 'f1',
        'front': 'Recto',
        'back': 'Verso',
        'chapters': {'title': 'Intro', 'index': 0, 'course_id': 'c1'},
      },
    ]);
    copie('cours', [
      {
        'id': 'c1',
        'title': 'Droit constitutionnel',
        'status': 'ready',
        'is_demo': false,
        'nb_chapitres': 1,
        'nb_questions': 12,
        'nb_fiches': 1,
        'nb_tentees': 1,
      },
    ]);

    expect(await const DepotFiches().duCours('c1'), hasLength(1));
    final cours = await const DepotCours().liste();
    expect(cours.single.titre, 'Droit constitutionnel');
  });

  test('sans copie, la page échoue vite au lieu de charger sans fin', () async {
    final debut = DateTime.now();
    await expectLater(
      const DepotCours().questionsDeSession('jamais-ouvert'),
      throwsA(isA<TimeoutException>()),
    );
    expect(DateTime.now().difference(debut).inSeconds, lessThan(3));
  });
}
