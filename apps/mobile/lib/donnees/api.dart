import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import 'config.dart';
import 'supabase.dart';

/// Client HTTP des routes REST de Next.js.
///
/// Un intercepteur pose le jeton Supabase sur chaque requête. Côté serveur,
/// `authentifier()` le lit et valide sa signature auprès du serveur
/// d'authentification — avant la phase 1, rien ne lisait cet en-tête et toute
/// requête d'ici aurait reçu 401 (docs/API.md § 2).
///
/// Sur 401, on rafraîchit **une fois** et on rejoue : un jeton Supabase vit
/// une heure, et l'étudiant qui reprend son application le lendemain matin ne
/// doit pas voir un écran d'erreur avant de pouvoir continuer.
class ApiReviz {
  ApiReviz({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = Config.apiBase
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 30)
      // On lit le corps d'erreur nous-mêmes : les routes renvoient
      // `{ ok: false, error }` avec un statut parlant.
      ..validateStatus = (_) => true;

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final jeton = jetonAcces;
          if (jeton != null) {
            options.headers['Authorization'] = 'Bearer $jeton';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;

  /// Appelle une route et déplie l'enveloppe `{ ok, data | error }`.
  Future<Reponse<T>> poster<T>(
    String chemin, {
    Object? corps,
    T Function(Map<String, dynamic>)? depuis,
  }) async {
    Future<Response<dynamic>> envoyer() =>
        _dio.post<dynamic>(chemin, data: corps);

    var reponse = await envoyer();

    // Une seule reprise, et seulement sur 401 : au-delà, c'est que la session
    // est réellement perdue.
    if (reponse.statusCode == 401) {
      try {
        await supabase.auth.refreshSession();
        reponse = await envoyer();
      } on AuthException {
        return const Reponse.echec('Ta session a expiré. Reconnecte-toi.');
      }
    }

    final donnees = reponse.data;
    if (donnees is! Map) {
      return const Reponse.echec(
        'Réponse inattendue du serveur. Réessaie dans un instant.',
      );
    }

    final carte = Map<String, dynamic>.from(donnees);

    if (carte['ok'] == true) {
      final utile = carte['data'];
      if (depuis == null) return Reponse.succes(utile as T);
      return Reponse.succes(depuis(Map<String, dynamic>.from(utile as Map)));
    }

    return Reponse.echec(
      (carte['error'] as String?) ??
          'Quelque chose a coincé de notre côté. Réessaie.',
      motif: carte['motif'] as String?,
      statut: reponse.statusCode,
    );
  }
}

/// Résultat d'un appel : le message d'erreur est déjà en français, prêt à
/// afficher, et `motif` sert quand l'écran doit réagir selon la cause.
sealed class Reponse<T> {
  const Reponse();

  const factory Reponse.succes(T data) = ReponseSucces<T>;
  const factory Reponse.echec(String erreur, {String? motif, int? statut}) =
      ReponseEchec<T>;
}

class ReponseSucces<T> extends Reponse<T> {
  const ReponseSucces(this.data);
  final T data;
}

class ReponseEchec<T> extends Reponse<T> {
  const ReponseEchec(this.erreur, {this.motif, this.statut});
  final String erreur;
  final String? motif;
  final int? statut;
}
