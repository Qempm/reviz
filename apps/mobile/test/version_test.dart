import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/metier/version.dart';

/// Tests de la vérification de version.
///
/// Le premier groupe existe surtout pour une raison : la version web comparait
/// deux champs **du même fichier distant**, si bien que « mise à jour
/// exigée » ne pouvait jamais se déclencher. Ici la version locale est un
/// paramètre, et un test vérifie explicitement qu'elle décide.
void main() {
  group('comparaison de versions', () {
    test('ordonne les numéros, pas les chaînes', () {
      // « 10 » vient après « 9 », ce qu'une comparaison de chaînes rate.
      expect(comparerVersions('1.9.0', '1.10.0'), lessThan(0));
      expect(comparerVersions('2.0.0', '1.9.9'), greaterThan(0));
      expect(comparerVersions('1.2.3', '1.2.3'), 0);
    });

    test('ignore le numéro de compilation', () {
      // `pubspec.yaml` porte « 2.0.0+2 » ; le `+2` est le versionCode
      // d'Android, pas une version.
      expect(comparerVersions('2.0.0+2', '2.0.0'), 0);
      expect(comparerVersions('2.0.0+7', '2.0.1'), lessThan(0));
    });

    test('ignore un suffixe de pré-publication', () {
      expect(comparerVersions('2.0.0-beta', '2.0.0'), 0);
    });

    test('complète les segments absents par zéro', () {
      expect(comparerVersions('2', '2.0.0'), 0);
      expect(comparerVersions('2.1', '2.0.9'), greaterThan(0));
    });

    test('ne se casse pas sur une chaîne illisible', () {
      // Une valeur mal formée dans /version.json ne doit pas bloquer une
      // application qui marche : elle vaut zéro et l'on continue.
      expect(comparerVersions('', '0.0.0'), 0);
      expect(comparerVersions('bientôt', '0.0.0'), 0);
      expect(comparerVersions('1.x.3', '1.0.3'), 0);
    });
  });

  group('exigence de mise à jour', () {
    const seuils = VersionDistante(minimum: '2.0.0', derniere: '2.3.0');

    test('exige la mise à jour en dessous du minimum', () {
      expect(
        etatVersion(locale: '1.9.9', distante: seuils),
        ExigenceVersion.exigee,
      );
    });

    test('la conseille entre le minimum et la dernière', () {
      expect(
        etatVersion(locale: '2.0.0', distante: seuils),
        ExigenceVersion.conseillee,
      );
      expect(
        etatVersion(locale: '2.2.9', distante: seuils),
        ExigenceVersion.conseillee,
      );
    });

    test('ne demande rien à jour, ni au-delà', () {
      expect(
        etatVersion(locale: '2.3.0', distante: seuils),
        ExigenceVersion.aJour,
      );
      // Une version de développement en avance sur la publication.
      expect(
        etatVersion(locale: '2.4.0', distante: seuils),
        ExigenceVersion.aJour,
      );
    });

    test('la version locale décide, pas les deux champs distants', () {
      // Le défaut de la version web : `version` et `minimumVersion` du même
      // fichier valaient tous deux « 1.0.0 », donc la comparaison était
      // toujours fausse et `update-required` inatteignable. Ici, deux
      // versions locales différentes en face des **mêmes** seuils donnent
      // deux réponses différentes — c'est la preuve que la locale compte.
      const identiques = VersionDistante(minimum: '1.0.0', derniere: '1.0.0');

      expect(
        etatVersion(locale: '1.0.0', distante: identiques),
        ExigenceVersion.aJour,
      );
      expect(
        etatVersion(locale: '0.9.0', distante: identiques),
        ExigenceVersion.exigee,
      );
    });

    test('la maintenance passe avant tout', () {
      // Un étudiant déjà à jour ne doit pas être invité à télécharger une
      // version qu'il a.
      const coupure = VersionDistante(
        minimum: '1.0.0',
        derniere: '2.0.0',
        maintenance: true,
      );

      expect(
        etatVersion(locale: '2.0.0', distante: coupure),
        ExigenceVersion.maintenance,
      );
      expect(
        etatVersion(locale: '0.1.0', distante: coupure),
        ExigenceVersion.maintenance,
      );
    });
  });

  group('lecture de /version.json', () {
    test('lit le fichier tel qu’il est publié aujourd’hui', () {
      final lue = VersionDistante.depuis({
        'version': '1.0.0',
        'minimumVersion': '1.0.0',
        'latestVersion': '1.0.0',
        'buildDate': '2026-09-10',
        'releaseNotes': 'Version initiale du MVP.',
        'updateUrl': 'https://reviz-eight.vercel.app/app',
        'critical': false,
        'maintenance': false,
      });

      expect(lue, isNotNull);
      expect(lue!.minimum, '1.0.0');
      expect(lue.derniere, '1.0.0');
      expect(lue.lien, 'https://reviz-eight.vercel.app/app');
      expect(lue.maintenance, isFalse);
    });

    test('retombe sur « version » quand « latestVersion » manque', () {
      final lue = VersionDistante.depuis({
        'version': '2.1.0',
        'minimumVersion': '2.0.0',
      });
      expect(lue?.derniere, '2.1.0');
    });

    test('refuse un fichier sans minimum', () {
      // Sans seuil, on ne sait rien : mieux vaut ne rien dire que bloquer.
      expect(VersionDistante.depuis({'version': '2.0.0'}), isNull);
    });
  });
}
