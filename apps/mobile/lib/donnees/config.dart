import 'package:flutter/foundation.dart';

/// Configuration d'exécution, injectée au build.
///
/// Rien n'est codé en dur ici, et surtout **aucune clé de service** : le
/// client mobile ne connaît que l'URL du projet et la clé anonyme, qui est
/// publique par construction et dont la RLS fait toute la sécurité. La clé de
/// service et les clés des fournisseurs IA restent côté Next.js.
///
/// Passer les valeurs au build :
///
/// ```
/// flutter build apk \
///   --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=... \
///   --dart-define=API_BASE=https://revizapp.fun
/// ```
///
/// `npm run apk` les passe depuis `.env.local` et refuse de compiler s'il en
/// manque une : un APK sans configuration démarre sur un bandeau rouge, et un
/// fichier partagé par WhatsApp ne se reprend pas.
abstract final class Config {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const _apiBaseCompilee = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://revizapp.fun',
  );

  /// Racine des routes REST de Next.js.
  ///
  /// Dans le navigateur, quand la page est servie par Next.js sous `/web`,
  /// c'est l'origine de la page elle-même : même domaine, donc pas de CORS,
  /// et une prévisualisation Vercel parle à son propre serveur plutôt qu'à
  /// la production. Partout ailleurs, la valeur compilée.
  static String get apiBase {
    if (kIsWeb && Uri.base.path.startsWith('/web')) return Uri.base.origin;
    return _apiBaseCompilee;
  }

  /// Client OAuth **Web** de Google, exigé par `signInWithIdToken` même sur
  /// Android : c'est l'audience du jeton d'identité que Supabase vérifie.
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  /// Numéro WhatsApp du support, au format international sans `+` ni espace
  /// (ex. `22990000000`). Facultatif : sans lui, l'écran d'aide ne propose
  /// pas de contact plutôt que d'ouvrir un numéro qui ne répond pas.
  static const contactWhatsapp = String.fromEnvironment('CONTACT_WHATSAPP');

  /// Le projet Firebase, pour le push. Facultatif : sans ces valeurs, le
  /// push est simplement absent (`donnees/push.dart`), le reste marche.
  ///
  /// Passées au build plutôt que par `google-services.json` /
  /// `GoogleService-Info.plist` : un fichier de configuration iOS doit être
  /// inscrit dans le projet Xcode, ce qui ne se fait pas sans Mac. Rien de
  /// secret ici — ce sont les identifiants publics du projet, embarqués
  /// dans toute application Firebase. La clé qui **envoie** les push reste
  /// sur le serveur (`FIREBASE_SERVICE_ACCOUNT`).
  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const firebaseSenderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const firebaseAndroidApiKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
  );
  static const firebaseAndroidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const firebaseIosApiKey = String.fromEnvironment(
    'FIREBASE_IOS_API_KEY',
  );
  static const firebaseIosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');

  static bool get estConfiguree =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Ce qui manque, pour un message d'erreur qui se lit.
  static List<String> get manquantes => [
    if (supabaseUrl.isEmpty) 'SUPABASE_URL',
    if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
  ];
}
