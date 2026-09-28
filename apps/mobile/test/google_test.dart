import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInExceptionCode;
import 'package:reviz/metier/google.dart';

/// Tests de la connexion Google.
///
/// Deux choses seulement sont vérifiables sans appareil, et ce sont les deux
/// qui cassent en silence :
///
///  1. **Le nonce.** Google reçoit l'empreinte, Supabase reçoit le brut.
///     Inverser les deux donne un refus dont le message ne dit rien, et la
///     relecture ne voit pas l'inversion — les deux chaînes se ressemblent
///     à l'appel.
///  2. **La traduction des échecs.** Sans elle, une empreinte SHA-1 non
///     déclarée sort en `PlatformException(sign_in_failed, ..., 10)` : un
///     étudiant croit avoir mal fait, et le développeur cherche ailleurs.
void main() {
  group('nonce', () {
    test('fait la longueur annoncée, en alphanumérique', () {
      final n = nonceAleatoire();
      expect(n, hasLength(longueurNonce));
      expect(n, matches(RegExp(r'^[A-Za-z0-9]+$')));
    });

    test('change d’une tentative à l’autre', () {
      // Un nonce constant ne lie plus le jeton à une tentative : il ne sert
      // alors plus à rien.
      final tirages = {for (var i = 0; i < 50; i++) nonceAleatoire()};
      expect(tirages.length, 50);
    });

    test('se laisse fixer pour un test', () {
      expect(nonceAleatoire(Random(7)), nonceAleatoire(Random(7)));
    });

    test('l’empreinte est un SHA-256 hexadécimal, et n’est pas le brut', () {
      const brut = 'abcABC123';
      final empreinte = empreinteNonce(brut);

      expect(empreinte, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(empreinte, isNot(brut));

      // Valeur de référence, pour qu'un changement d'algorithme se voie :
      // c'est bien le SHA-256 de « abcABC123 ».
      expect(
        empreinte,
        '5e24fa8f026b69a8e26fc7ce8f918cf63b8202ceede7544e7356ea7b0e337ce0',
      );
    });

    test('la même entrée donne la même empreinte', () {
      expect(empreinteNonce('reviz'), empreinteNonce('reviz'));
      expect(empreinteNonce('reviz'), isNot(empreinteNonce('reviZ')));
    });
  });

  group('motifs d’échec', () {
    test('une annulation ne s’affiche pas', () {
      final motif = motifEchecGoogle(GoogleSignInExceptionCode.canceled);
      expect(motif, MotifEchecGoogle.annule);
      expect(motifSilencieux(motif), isTrue);
    });

    test('une erreur de configuration est la nôtre, et se distingue', () {
      // C'est l'échec le plus probable au premier essai : client OAuth
      // Android absent, ou empreinte SHA-1 non déclarée.
      expect(
        motifEchecGoogle(GoogleSignInExceptionCode.clientConfigurationError),
        MotifEchecGoogle.configuration,
      );
    });

    test('un appareil sans services Google renvoie à l’e-mail', () {
      expect(
        motifEchecGoogle(GoogleSignInExceptionCode.providerConfigurationError),
        MotifEchecGoogle.indisponible,
      );
    });

    test('une coupure invite à réessayer', () {
      for (final code in [
        GoogleSignInExceptionCode.interrupted,
        GoogleSignInExceptionCode.uiUnavailable,
      ]) {
        expect(motifEchecGoogle(code), MotifEchecGoogle.interrompu);
      }
    });

    test('tous les codes du greffon ont un motif', () {
      // Le `switch` est exhaustif, donc ceci ne peut pas échouer sans qu'une
      // version du greffon ait ajouté un code : c'est précisément ce qu'on
      // veut apprendre par un test rouge et non par un plantage sur le
      // téléphone d'un étudiant.
      for (final code in GoogleSignInExceptionCode.values) {
        expect(motifEchecGoogle(code), isA<MotifEchecGoogle>());
      }
    });

    test('seule l’annulation est silencieuse', () {
      for (final motif in MotifEchecGoogle.values) {
        expect(
          motifSilencieux(motif),
          motif == MotifEchecGoogle.annule,
          reason: 'motif $motif',
        );
      }
    });
  });
}
