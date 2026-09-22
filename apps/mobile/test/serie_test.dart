import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/metier/serie.dart';

/// Port de `lib/xp/serie.test.ts` — 17 tests.

/// Mercredi 10 septembre 2026, 14 h UTC.
final maintenant = DateTime.utc(2026, 9, 10, 14);

void main() {
  group('jourUtc et veille', () {
    test('donne le jour en UTC', () {
      expect(jourUtc(maintenant), '2026-09-10');
    });

    test('reste en UTC juste après minuit à Cotonou', () {
      // 00 h 30 au Bénin (UTC+1) est 23 h 30 la veille en UTC. La base compte
      // ainsi, l'affichage doit compter pareil.
      expect(jourUtc(DateTime.utc(2026, 9, 10, 23, 30)), '2026-09-10');
      expect(jourUtc(DateTime.utc(2026, 9, 11, 0, 30)), '2026-09-11');
    });

    test('recule d’un jour, y compris en changeant de mois', () {
      expect(veille('2026-09-10'), '2026-09-09');
      expect(veille('2026-09-01'), '2026-08-31');
      expect(veille('2026-01-01'), '2025-12-31');
    });

    test('recule correctement au 1er mars d’une année bissextile', () {
      expect(veille('2028-03-01'), '2028-02-29');
    });
  });

  group('etatSerie', () {
    test('affiche zéro quand rien n’a jamais été validé', () {
      expect(
        etatSerie(current: 0, lastValidatedOn: null, maintenant: maintenant),
        const EtatSerie(
          jours: 0,
          rompue: true,
          valideAujourdhui: false,
          enJeu: false,
        ),
      );
    });

    test('rompt la série quand le dernier jour validé est trop ancien', () {
      // Le cas que personne ne traitait côté web : la base garde 5, l'écran
      // affichait 5, alors que la série est morte depuis une semaine.
      final etat = etatSerie(
        current: 5,
        lastValidatedOn: '2026-09-03',
        maintenant: maintenant,
      );

      expect(etat.rompue, isTrue);
      expect(etat.jours, 0);
    });

    test('garde la série quand aujourd’hui est validé', () {
      expect(
        etatSerie(
          current: 6,
          lastValidatedOn: '2026-09-10',
          maintenant: maintenant,
        ),
        const EtatSerie(
          jours: 6,
          rompue: false,
          valideAujourdhui: true,
          enJeu: false,
        ),
      );
    });

    test('met la série en jeu quand seule la veille est validée', () {
      expect(
        etatSerie(
          current: 3,
          lastValidatedOn: '2026-09-09',
          maintenant: maintenant,
        ),
        const EtatSerie(
          jours: 3,
          rompue: false,
          valideAujourdhui: false,
          enJeu: true,
        ),
      );
    });

    test('accepte un horodatage complet et n’en garde que la date', () {
      // Postgres renvoie une date nue, mais un `timestamptz` mal typé
      // arriverait avec son heure : la comparaison ne doit pas échouer pour un
      // « T00:00:00+00:00 » de trop.
      final etat = etatSerie(
        current: 2,
        lastValidatedOn: '2026-09-10T00:00:00+00:00',
        maintenant: maintenant,
      );

      expect(etat.valideAujourdhui, isTrue);
    });

    test('ne fait pas confiance à un compteur négatif', () {
      final etat = etatSerie(
        current: -4,
        lastValidatedOn: '2026-09-10',
        maintenant: maintenant,
      );

      expect(etat.jours, 0);
    });

    test('tient au passage d’un mois', () {
      expect(
        etatSerie(
          current: 9,
          lastValidatedOn: '2026-08-31',
          maintenant: DateTime.utc(2026, 9, 1, 8),
        ),
        const EtatSerie(
          jours: 9,
          rompue: false,
          valideAujourdhui: false,
          enJeu: true,
        ),
      );
    });
  });

  group('progressionDuJour', () {
    test('rend une fraction', () {
      expect(progressionDuJour(3, 10), closeTo(0.3, 1e-9));
    });

    test('borne à 1 : trente questions ne remplissent pas la barre trois fois', () {
      expect(progressionDuJour(30, 10), 1);
    });

    test('ne descend pas sous zéro', () {
      expect(progressionDuJour(-5, 10), 0);
    });

    test('ne divise pas par zéro si l’objectif est retiré', () {
      expect(progressionDuJour(0, 0), 1);
    });
  });

  group('resteAvantObjectif', () {
    test('compte les questions manquantes', () {
      expect(resteAvantObjectif(4, 10), 6);
    });

    test('vaut zéro une fois l’objectif dépassé', () {
      expect(resteAvantObjectif(12, 10), 0);
    });
  });
}
