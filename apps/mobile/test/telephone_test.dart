import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/metier/telephone.dart';

/// Port de `lib/auth/phone.test.ts` — 14 tests.

final bj = paysParDefaut;
final ci = paysParCode('CI')!;
final sn = paysParCode('SN')!;

void main() {
  group('normalisation des numéros', () {
    test('accepte les formes réellement tapées par un étudiant béninois', () {
      // Toutes ces saisies désignent le même numéro.
      const saisies = [
        '97123456',
        '97 12 34 56',
        '97-12-34-56',
        '97.12.34.56',
        ' 97 12 34 56 ',
        '+22997123456',
        '+229 97 12 34 56',
        '22997123456',
        '0022997123456',
      ];

      for (final saisie in saisies) {
        final r = normaliserTelephone(saisie, bj);
        expect(r, isA<NumeroNormalise>(), reason: 'échec sur « $saisie »');
        expect((r as NumeroNormalise).e164, '+22997123456');
      }
    });

    test('retire le zéro initial hérité des habitudes françaises', () {
      final r = normaliserTelephone('097123456', bj);
      expect(r, isA<NumeroNormalise>());
      expect((r as NumeroNormalise).e164, '+22997123456');
    });

    test('ne retire pas un zéro qui fait partie du numéro', () {
      // En Côte d'Ivoire les numéros à 10 chiffres commencent par 0.
      final r = normaliserTelephone('0712345678', ci);
      expect(r, isA<NumeroNormalise>());
      expect((r as NumeroNormalise).e164, '+2250712345678');
    });

    test('reconnaît l’indicatif même si un autre pays est sélectionné', () {
      // L'étudiant a collé un numéro sénégalais alors que le Bénin est choisi.
      final r = normaliserTelephone('+221771234567', bj);
      expect(r, isA<NumeroNormalise>());
      final n = r as NumeroNormalise;
      expect(n.pays.code, 'SN');
      expect(n.e164, '+221771234567');
    });

    test('refuse une longueur invalide', () {
      for (final saisie in ['9712', '971234567890123']) {
        final r = normaliserTelephone(saisie, bj);
        expect(r, isA<NumeroRefuse>(), reason: saisie);
        expect((r as NumeroRefuse).raison, RaisonRefusNumero.longueur);
      }
    });

    test('refuse une saisie vide ou sans chiffre', () {
      for (final saisie in ['', '   ', 'abc', '+++']) {
        final r = normaliserTelephone(saisie, bj);
        expect(r, isA<NumeroRefuse>(), reason: saisie);
        expect((r as NumeroRefuse).raison, RaisonRefusNumero.vide);
      }
    });

    test('couvre les cinq pays visés', () {
      const exemples = {
        'BJ': '97123456',
        'TG': '90123456',
        'CI': '0712345678',
        'SN': '771234567',
        'BF': '70123456',
      };

      for (final p in pays) {
        final r = normaliserTelephone(exemples[p.code]!, p);
        expect(r, isA<NumeroNormalise>(), reason: 'échec pour ${p.code}');
        expect((r as NumeroNormalise).e164.startsWith('+${p.indicatif}'), isTrue);
      }
    });

    test('produit toujours du E.164 : un plus, puis des chiffres', () {
      final r = normaliserTelephone('97 12 34 56', bj);
      expect(r, isA<NumeroNormalise>());
      expect(
        (r as NumeroNormalise).e164,
        matches(RegExp(r'^\+[1-9]\d{7,14}$')),
      );
    });

    test('l’exemple affiché de chaque pays est lui-même valide', () {
      // Un exemple d'aide à la saisie que le validateur refuserait serait le
      // plus sûr moyen de faire douter l'étudiant.
      for (final p in pays) {
        final r = normaliserTelephone(p.exemple, p);
        expect(
          r,
          isA<NumeroNormalise>(),
          reason: 'exemple invalide pour ${p.nom} : ${p.exemple}',
        );
      }
    });
  });

  group('affichage', () {
    test('groupe selon l’usage de chaque pays', () {
      expect(formaterNational('97123456', bj), '97 12 34 56');
      expect(formaterNational('0712345678', ci), '07 12 34 56 78');
      expect(formaterNational('771234567', sn), '77 123 45 67');
    });

    test('formate exactement comme l’exemple affiché, pour les cinq pays', () {
      // Le garde-fou qui compte : si le formateur et l'aide à la saisie
      // divergent, l'étudiant croit s'être trompé.
      for (final p in pays) {
        final r = normaliserTelephone(p.exemple, p);
        expect(r, isA<NumeroNormalise>());
        expect(
          formaterNational((r as NumeroNormalise).national, p),
          p.exemple,
          reason: 'divergence pour ${p.nom}',
        );
      }
    });

    test('formate un numéro en cours de frappe sans le déformer', () {
      expect(formaterNational('9', bj), '9');
      expect(formaterNational('971', bj), '97 1');
      expect(formaterNational('77123', sn), '77 123');
    });

    test('masque le milieu du numéro', () {
      expect(masquerTelephone('+22997123456'), '+229 97 •••• 56');
    });

    test('laisse intact un numéro non reconnu', () {
      expect(masquerTelephone('+33612345678'), '+33612345678');
    });
  });
}
