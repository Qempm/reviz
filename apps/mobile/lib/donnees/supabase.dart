import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';

/// Client Supabase de l'application.
///
/// Les **lectures** passent par lui, en direct : la RLS filtre, et les quatre
/// vues (`subject_stats`, `chapter_stats`, `course_overview`,
/// `active_subscriptions`) sont en `security_invoker`, donc consommables tel
/// quel. Les écritures privilégiées passent par `api.dart` (voir docs/API.md).
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: Config.supabaseUrl,
    // `publishableKey` remplace `anonKey`, déprécié : c'est la même valeur,
    // renommée par Supabase pour dire ce qu'elle est — publique.
    publishableKey: Config.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      // PKCE : le flux standard pour un client public.
      authFlowType: AuthFlowType.pkce,
    ),
  );
}

SupabaseClient get supabase => Supabase.instance.client;

/// Session courante, ou `null`.
Session? get session => supabase.auth.currentSession;

/// Jeton d'accès à poser dans l'en-tête `Authorization` des appels à Next.js.
String? get jetonAcces => session?.accessToken;
