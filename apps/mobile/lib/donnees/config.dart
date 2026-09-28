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
///   --dart-define=API_BASE=https://reviz-eight.vercel.app
/// ```
///
/// `npm run apk` les passe depuis `.env.local` et refuse de compiler s'il en
/// manque une : un APK sans configuration démarre sur un bandeau rouge, et un
/// fichier partagé par WhatsApp ne se reprend pas.
abstract final class Config {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Racine des routes REST de Next.js.
  static const apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://reviz-eight.vercel.app',
  );

  /// Client OAuth **Web** de Google, exigé par `signInWithIdToken` même sur
  /// Android : c'est l'audience du jeton d'identité que Supabase vérifie.
  static const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  /// Numéro WhatsApp du support, au format international sans `+` ni espace
  /// (ex. `22990000000`). Facultatif : sans lui, l'écran d'aide ne propose
  /// pas de contact plutôt que d'ouvrir un numéro qui ne répond pas.
  static const contactWhatsapp = String.fromEnvironment('CONTACT_WHATSAPP');

  static bool get estConfiguree =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Ce qui manque, pour un message d'erreur qui se lit.
  static List<String> get manquantes => [
    if (supabaseUrl.isEmpty) 'SUPABASE_URL',
    if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
  ];
}
