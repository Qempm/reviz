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
  ApiReviz({Dio? dio, Dio? dioStockage})
    : _dio = dio ?? Dio(),
      _stockage = dioStockage ?? Dio() {
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

    // Client séparé pour le stockage, **sans l'intercepteur ci-dessus**.
    //
    // Une URL signée porte déjà son propre jeton, dans sa query. Y ajouter le
    // JWT Supabase l'enverrait à une autre origine que la nôtre pour rien :
    // une fuite gratuite. Le délai d'envoi est long, parce qu'une photo de
    // copie sur une 3G béninoise prend son temps.
    _stockage.options
      ..connectTimeout = const Duration(seconds: 20)
      ..sendTimeout = const Duration(minutes: 3)
      ..receiveTimeout = const Duration(seconds: 30)
      ..validateStatus = (_) => true;
  }

  final Dio _dio;
  final Dio _stockage;

  /// Appelle une route et déplie l'enveloppe `{ ok, data | error }`.
  Future<Reponse<T>> poster<T>(
    String chemin, {
    Object? corps,
    T Function(Map<String, dynamic>)? depuis,
  }) {
    return _appeler(() => _dio.post<dynamic>(chemin, data: corps), depuis);
  }

  /// Lit une route. Même enveloppe, même rejeu sur 401.
  Future<Reponse<T>> obtenir<T>(
    String chemin, {
    T Function(Map<String, dynamic>)? depuis,
  }) {
    return _appeler(() => _dio.get<dynamic>(chemin), depuis);
  }

  /// Met à jour une ressource. Même enveloppe, même rejeu sur 401.
  ///
  /// Le verbe compte : `/api/profile/avatar` répond en `PUT`, et la faire
  /// répondre en `POST` pour économiser une méthode ici aurait été
  /// l'arranger dans le mauvais sens.
  Future<Reponse<T>> mettreAJour<T>(
    String chemin, {
    Object? corps,
    T Function(Map<String, dynamic>)? depuis,
  }) {
    return _appeler(() => _dio.put<dynamic>(chemin, data: corps), depuis);
  }

  /// Supprime une ressource (`DELETE`, avec un corps). Même enveloppe.
  Future<Reponse<T>> supprimer<T>(
    String chemin, {
    Object? corps,
    T Function(Map<String, dynamic>)? depuis,
  }) {
    return _appeler(() => _dio.delete<dynamic>(chemin, data: corps), depuis);
  }

  /// Envoie un fichier vers une URL signée, par un `PUT` direct.
  ///
  /// Ni enveloppe ni jeton : c'est le stockage Supabase qui répond, et l'URL
  /// signée est l'autorisation. Rend `null` si tout va bien, un message
  /// affichable sinon.
  Future<String?> televerser({
    required String url,
    required List<int> octets,
    required String typeMime,
    void Function(int envoyes, int total)? progression,
  }) async {
    try {
      final reponse = await _stockage.put<dynamic>(
        url,
        data: Stream.fromIterable([octets]),
        options: Options(
          headers: {
            Headers.contentTypeHeader: typeMime,
            Headers.contentLengthHeader: octets.length,
          },
        ),
        onSendProgress: progression,
      );

      final code = reponse.statusCode ?? 0;
      if (code >= 200 && code < 300) return null;

      return 'L’envoi a échoué (code $code). Réessaie.';
    } on DioException catch (e) {
      // Coupure, délai dépassé : le message doit rester lisible pour un
      // étudiant, pas reprendre la trace de Dio.
      return e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.connectionTimeout
          ? 'L’envoi prend trop de temps. Vérifie ta connexion et réessaie.'
          : 'L’envoi a été interrompu. Réessaie.';
    }
  }

  /// Le corps commun : rejeu unique sur 401, puis dépliage de l'enveloppe.
  ///
  /// Une coupure réseau devient un échec lisible au lieu d'une exception :
  /// sur une 3G qui décroche, c'est le cas ordinaire, pas l'exception.
  Future<Reponse<T>> _appeler<T>(
    Future<Response<dynamic>> Function() envoyer,
    T Function(Map<String, dynamic>)? depuis,
  ) async {
    try {
      return await _appelerSansFilet(envoyer, depuis);
    } on DioException {
      return const Reponse.echec(
        'Pas de connexion pour l’instant. Vérifie ton réseau et réessaie.',
        motif: 'reseau',
      );
    }
  }

  Future<Reponse<T>> _appelerSansFilet<T>(
    Future<Response<dynamic>> Function() envoyer,
    T Function(Map<String, dynamic>)? depuis,
  ) async {
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
        'Quelque chose a coincé. Réessaie dans un instant.',
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
