import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/metier/otp.dart';

/// Port de `lib/auth/otp.test.ts`, plus **un test que le TypeScript n'avait
/// pas** et qui aurait attrapé sa regex cassée.
void main() {
  group('extraction du code collé', () {
    test('prend six chiffres nus', () {
      expect(extraireCode('123456'), '123456');
    });

    test('trouve le code au milieu d’une phrase du mail', () {
      // Ce que l'étudiant sélectionne vraiment dans son application de mail.
      expect(extraireCode('Ton code Reviz : 123456'), '123456');
      expect(
        extraireCode('Ton code Reviz : 123456\nIl expire dans une heure.'),
        '123456',
      );
      expect(extraireCode('  123456  '), '123456');
    });

    test('ignore les autres nombres autour du code', () {
      expect(extraireCode('Code 654321 valable jusqu’à 18h'), '654321');
    });

    test('ignore un nombre qui PRÉCÈDE le code', () {
      // Le cas que la version TypeScript rate : sa regex `/d{6}/` cherchait
      // six lettres « d », donc tout passait par le repli qui recolle les
      // chiffres — et « 2026 » venait se coller devant le code.
      expect(extraireCode('Reviz 2026 : ton code 654321'), '654321');
      expect(extraireCode('Le 12 mars, code 987654'), '987654');
    });

    test('recolle les chiffres quand ils sont espacés ou séparés', () {
      expect(extraireCode('1 2 3 4 5 6'), '123456');
      expect(extraireCode('123-456'), '123456');
    });

    test('tronque au-delà de la longueur demandée', () {
      expect(extraireCode('12345678901234'), '123456');
    });

    test('rend une chaîne vide quand il n’y a rien à prendre', () {
      expect(extraireCode('aucun chiffre ici'), '');
      expect(extraireCode(''), '');
    });

    test('accepte un code partiel en cours de frappe', () {
      expect(extraireCode('123'), '123');
    });

    test('rend un code de huit chiffres, la longueur réelle du projet', () {
      // Vérifié sur la base : Supabase émet huit chiffres ici. Une règle
      // calée sur six tronquerait et ferait refuser un code valide.
      expect(
        extraireCode('Ton code Reviz : 30910681', longueur: longueurCodeMax),
        '30910681',
      );
      expect(
        extraireCode('Reviz 2026 : code 30910681', longueur: longueurCodeMax),
        '30910681',
      );
    });

    test('ne recolle pas une heure au code', () {
      // La plus longue suite l'emporte : « 18 h » ne doit pas venir se coller
      // derrière le code, ce que faisait le repli du TypeScript.
      expect(
        extraireCode('Code 654321 valable jusqu’à 18h', longueur: longueurCodeMax),
        '654321',
      );
    });

    test('respecte une longueur différente', () {
      expect(extraireCode('Code : 1234', longueur: 4), '1234');
    });
  });
}
