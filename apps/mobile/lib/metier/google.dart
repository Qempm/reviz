// Connexion Google : le nonce, et ce qu'on dit quand ça échoue.
//
// Deux règles pures, séparées de l'appel au greffon pour être testables.
//
// **Le nonce n'est pas décoratif, et son sens se perd facilement.** Google
// reçoit l'**empreinte** du nonce et la place dans le jeton d'identité ;
// Supabase reçoit le nonce **brut** et compare son empreinte à celle du jeton
// (`gotrue`, `signInWithIdToken` : « If the ID token contains a `nonce` claim,
// then [nonce] must be provided to compare its hash with the value in the ID
// token »). Envoyer le brut à Google ou l'empreinte à Supabase produit dans
// les deux cas un refus — et un refus dont le message ne dit pas pourquoi.
// C'est exactement le genre d'inversion qu'un test attrape et qu'une relecture
// laisse passer.

library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInExceptionCode;

/// Caractères du nonce. Alphanumériques seulement : il traverse une URL et un
/// jeton, autant qu'aucun encodage ne s'en mêle.
const _alphabet =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

/// 32 caractères pris dans 62 : largement assez pour qu'un nonce ne se rejoue
/// pas.
const longueurNonce = 32;

/// Un nonce à usage unique.
///
/// `Random.secure()` et non `Random()` : c'est la seule chose qui lie le jeton
/// d'identité à **cette** tentative de connexion, donc elle doit être
/// imprévisible. Le paramètre n'existe que pour les tests.
String nonceAleatoire([Random? hasard]) {
  final tirage = hasard ?? Random.secure();
  return List.generate(
    longueurNonce,
    (_) => _alphabet[tirage.nextInt(_alphabet.length)],
  ).join();
}

/// Ce que Google reçoit : l'empreinte SHA-256, en hexadécimal.
String empreinteNonce(String brut) =>
    sha256.convert(utf8.encode(brut)).toString();

/// Pourquoi la connexion Google n'a pas abouti.
///
/// Les codes du greffon sont regroupés par **ce que l'étudiant peut y faire**,
/// et non par leur cause technique : « reprends » n'est pas « ce n'est pas toi,
/// c'est nous ».
enum MotifEchecGoogle {
  /// L'étudiant a fermé la feuille de choix de compte. Ce n'est pas un échec,
  /// et il ne faut donc rien afficher.
  annule,

  /// **Notre faute.** Client OAuth Android absent, empreinte SHA-1 non
  /// déclarée, mauvais identifiant de client web. C'est l'échec le plus
  /// probable au premier essai, et le message doit le dire au lieu de laisser
  /// croire à l'étudiant qu'il a mal fait.
  configuration,

  /// Supabase a refusé le jeton : fournisseur Google désactivé côté projet,
  /// ou audience qui ne correspond pas à l'identifiant client web déclaré.
  refuseParSupabase,

  /// Coupure, activité détruite, écran indisponible. Réessayer a un sens.
  interrompu,

  /// Pas de services Google exploitables sur l'appareil. Fréquent sur les
  /// Android d'entrée de gamme sans Play Services : la connexion par code
  /// e-mail reste la voie, et le message doit y renvoyer.
  indisponible,

  /// Le compte demandé n'est pas celui qui est connecté sur l'appareil.
  autreCompte,

  inconnu,
}

/// Traduit un code du greffon en motif.
MotifEchecGoogle motifEchecGoogle(GoogleSignInExceptionCode code) =>
    switch (code) {
      GoogleSignInExceptionCode.canceled => MotifEchecGoogle.annule,
      GoogleSignInExceptionCode.clientConfigurationError =>
        MotifEchecGoogle.configuration,
      // « The underlying auth SDK is unavailable or misconfigured » : sur
      // Android, c'est d'abord l'absence de Play Services.
      GoogleSignInExceptionCode.providerConfigurationError =>
        MotifEchecGoogle.indisponible,
      GoogleSignInExceptionCode.interrupted ||
      GoogleSignInExceptionCode.uiUnavailable => MotifEchecGoogle.interrompu,
      GoogleSignInExceptionCode.userMismatch => MotifEchecGoogle.autreCompte,
      GoogleSignInExceptionCode.unknownError => MotifEchecGoogle.inconnu,
    };

/// Un motif qu'il ne faut **pas** afficher : l'étudiant a choisi de renoncer.
bool motifSilencieux(MotifEchecGoogle motif) =>
    motif == MotifEchecGoogle.annule;
