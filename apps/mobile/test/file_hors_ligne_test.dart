import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/donnees/api.dart';
import 'package:reviz/donnees/file_hors_ligne.dart';
import 'package:reviz/metier/identifiant.dart';
import 'package:shared_preferences/shared_preferences.dart';

SessionEnAttente _serie(String id, {DateTime? le, int essais = 0}) =>
    SessionEnAttente(
      sessionId: id,
      coursId: 'c1',
      reponses: const [
        (questionId: 'q1', choix: 'A'),
        (questionId: 'q2', choix: null),
      ],
      le: le ?? DateTime(2026, 9, 30, 10),
      essais: essais,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final maintenant = DateTime(2026, 9, 30, 12);

  group('deciderEnvoi', () {
    test('un succès part', () {
      expect(
        deciderEnvoi(const Reponse.succes(1), _serie('s1'), maintenant),
        IssueEnvoi.envoyee,
      );
    });

    test('pas de réseau ou session expirée : on garde sans compter', () {
      expect(
        deciderEnvoi(
          const Reponse.echec('x', motif: 'reseau'),
          _serie('s1', essais: 4),
          maintenant,
        ),
        IssueEnvoi.garder,
      );
      expect(
        deciderEnvoi(
          const ReponseEchec('x', statut: 401),
          _serie('s1', essais: 4),
          maintenant,
        ),
        IssueEnvoi.garder,
      );
    });

    test('un refus répété finit par être abandonné', () {
      expect(
        deciderEnvoi(
          const ReponseEchec('x', statut: 400),
          _serie('s1'),
          maintenant,
        ),
        IssueEnvoi.garder,
      );
      expect(
        deciderEnvoi(
          const ReponseEchec('x', statut: 400),
          _serie('s1', essais: essaisMax - 1),
          maintenant,
        ),
        IssueEnvoi.abandonner,
      );
    });

    test('une série trop vieille est abandonnée', () {
      expect(
        deciderEnvoi(
          const Reponse.echec('x', motif: 'reseau'),
          _serie('s1', le: maintenant.subtract(const Duration(days: 15))),
          maintenant,
        ),
        IssueEnvoi.abandonner,
      );
    });
  });

  group('FileHorsLigne', () {
    test('garde, relit, et ne double pas une même série', () async {
      final file = FileHorsLigne();
      expect(await file.ajouter(_serie('s1')), isTrue);
      expect(await file.ajouter(_serie('s1')), isTrue);
      expect(await file.ajouter(_serie('s2')), isTrue);
      final lues = await file.lire();
      expect(lues.map((s) => s.sessionId), ['s1', 's2']);
      expect(lues.first.reponses.last.choix, isNull);
    });

    test('renvoie tout quand le réseau est là', () async {
      final file = FileHorsLigne();
      await file.ajouter(_serie('s1'));
      await file.ajouter(_serie('s2'));
      final envoyees = <String>[];
      final parties = await file.envoyer((s) async {
        envoyees.add(s.sessionId);
        return const Reponse.succes(true);
      }, maintenant: () => maintenant);
      expect(parties, 2);
      expect(envoyees, ['s1', 's2']);
      expect(await file.lire(), isEmpty);
    });

    test('s’arrête à la première coupure et garde la suite', () async {
      final file = FileHorsLigne();
      await file.ajouter(_serie('s1'));
      await file.ajouter(_serie('s2'));
      var appels = 0;
      final parties = await file.envoyer((s) async {
        appels++;
        return const Reponse.echec('x', motif: 'reseau');
      }, maintenant: () => maintenant);
      expect(parties, 0);
      expect(appels, 1);
      final restantes = await file.lire();
      expect(restantes.map((s) => s.sessionId), ['s1', 's2']);
      expect(restantes.first.essais, 0);
    });

    test('compte les refus, puis abandonne', () async {
      final file = FileHorsLigne();
      await file.ajouter(_serie('s1', essais: essaisMax - 2));
      Future<Reponse<Object?>> refus(SessionEnAttente _) async =>
          const ReponseEchec('x', statut: 400);
      await file.envoyer(refus, maintenant: () => maintenant);
      expect((await file.lire()).single.essais, essaisMax - 1);
      await file.envoyer(refus, maintenant: () => maintenant);
      expect(await file.lire(), isEmpty);
    });
  });

  test('identifiantAleatoire : un UUID v4 valide, jamais deux fois le même', () {
    final motif = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    final vus = <String>{};
    for (var i = 0; i < 200; i++) {
      final id = identifiantAleatoire();
      expect(id, matches(motif));
      vus.add(id);
    }
    expect(vus.length, 200);
  });
}
