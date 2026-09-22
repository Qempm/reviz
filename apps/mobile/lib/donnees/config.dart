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

  static bool get estConfiguree =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Ce qui manque, pour un message d'erreur qui se lit.
  static List<String> get manquantes => [
    if (supabaseUrl.isEmpty) 'SUPABASE_URL',
    if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
  ];
}
