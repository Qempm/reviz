// Les notifications push (Firebase Cloud Messaging).
//
// Le serveur pousse ce que les déclencheurs SQL ont écrit dans
// `notifications` (`lib/notifications/envoyer.ts`) ; ici, on enregistre le
// jeton du téléphone, on affiche un push reçu application ouverte, et on
// ouvre le bon écran quand l'étudiant en touche un.
//
// **Facultatif.** Le projet Firebase arrive par `--dart-define`
// (`Config.firebase…`, posés par `npm run apk` et `codemagic.yaml`). Sans
// eux, le push est simplement absent, et tout le reste — rappels, centre de
// notifications — marche.
//
// **Sur le web, le Web Push** (5 octobre 2026) : sur iPhone sans compte
// Apple, Reviz est l'app web installée, qui reçoit les notifications par le
// Web Push standard, sans Firebase (`push_navigateur.dart`, `sw.js`). Le jeton
// est alors l'adresse de l'abonnement du navigateur.

library;

import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../metier/notifications.dart';
import '../metier/plateforme.dart';
import 'api.dart';
import 'config.dart';
import 'depots.dart';
import 'push_navigateur.dart';
import 'rappels.dart';

class ServicePush {
  ServicePush({required this.depot, required this.api, required this.rappels});

  final DepotNotifications depot;
  final ApiReviz api;
  final ServiceRappels rappels;

  Future<bool>? _initialisation;
  final _abonnements = <StreamSubscription<dynamic>>[];
  String? _jeton;

  /// Le service worker n'est écouté qu'une fois (web).
  bool _ecouteNavigateur = false;

  void Function() _auRecu = _rien;
  void Function(String lien) _auToucher = _rienAvec;
  static void _rien() {}
  static void _rienAvec(String _) {}

  /// Ce que la racine de l'application veut faire d'un push reçu (relire le
  /// centre) et d'un push touché (ouvrir l'écran). Posé une fois.
  void brancher({
    required void Function() auRecu,
    required void Function(String lien) auToucher,
  }) {
    _auRecu = auRecu;
    _auToucher = auToucher;
  }

  /// Firebase est-il configuré sur ce téléphone ?
  Future<bool> disponible() => _initialisation ??= () async {
    // Le web : le Web Push, si le navigateur le permet (sur iPhone, dans
    // l'app installée seulement).
    if (kIsWeb) {
      final etat = etatPushNavigateur();
      return etat != EtatPushNavigateur.nonSupporte &&
          etat != EtatPushNavigateur.aInstaller;
    }
    final options = optionsFirebase();
    if (!pushDisponible || options == null) return false;
    try {
      await Firebase.initializeApp(options: options);
      return true;
    } catch (e) {
      debugPrint('[push] Firebase absent : $e');
      return false;
    }
  }();

  /// Après la connexion : enregistre le téléphone et écoute les push.
  ///
  /// Ne demande pas la permission : elle se demande après la première série
  /// réussie, ou depuis les réglages (`demanderPermission`). Sans elle, rien
  /// n'est enregistré, et un nouvel appel le fera une fois accordée.
  Future<void> activer() async {
    if (kIsWeb) return _activerNavigateur();
    if (!await disponible()) return;
    try {
      final messagerie = FirebaseMessaging.instance;
      final reglages = await messagerie.getNotificationSettings();
      final autorise =
          reglages.authorizationStatus == AuthorizationStatus.authorized ||
          reglages.authorizationStatus == AuthorizationStatus.provisional;
      if (!autorise) return;

      await _enregistrer(await messagerie.getToken());

      if (_abonnements.isEmpty) {
        _abonnements
          ..add(messagerie.onTokenRefresh.listen(_enregistrer))
          // Application ouverte : ni Android ni iOS n'affichent le push
          // d'eux-mêmes. On le montre, et le centre se relit.
          ..add(
            FirebaseMessaging.onMessage.listen((m) {
              final n = m.notification;
              if (n != null) {
                rappels.afficher(
                  titre: n.title ?? '',
                  corps: n.body ?? '',
                  lien: cheminDe(m.data['lien'] as String?),
                );
              }
              _auRecu();
            }),
          )
          ..add(
            FirebaseMessaging.onMessageOpenedApp.listen((m) {
              _auRecu();
              _auToucher(cheminDe(m.data['lien'] as String?));
            }),
          );

        // L'application a été **lancée** par un push touché.
        final initial = await messagerie.getInitialMessage();
        if (initial != null) {
          _auRecu();
          _auToucher(cheminDe(initial.data['lien'] as String?));
        }
      }
    } catch (e) {
      debugPrint('[push] activation impossible : $e');
    }
  }

  /// La permission des notifications, pour les rappels **et** le push.
  ///
  /// Sur Android, c'est une seule permission ; sur iOS, Firebase doit aussi
  /// la demander pour inscrire le téléphone auprès d'APNs. Puis le jeton est
  /// enregistré. Rend `true` si les notifications sont autorisées.
  Future<bool> demanderPermission() async {
    if (kIsWeb) {
      // Rien d'attendu avant la demande : Safari refuse celle qui ne suit
      // pas immédiatement un toucher.
      final reponse = await demanderPushNavigateur();
      await _activerNavigateur();
      return reponse == 'granted';
    }
    final locale = await rappels.demanderPermission();
    if (!await disponible()) return locale;
    try {
      final r = await FirebaseMessaging.instance.requestPermission();
      await activer();
      return r.authorizationStatus == AuthorizationStatus.authorized ||
          r.authorizationStatus == AuthorizationStatus.provisional ||
          locale;
    } catch (_) {
      return locale;
    }
  }

  /// Après la première série réussie : la demande, **une seule fois** — un
  /// refus ne doit pas revenir à chaque série.
  Future<void> demanderPermissionUneFois() async {
    // Sur le web, la demande exige un toucher : elle se fait depuis le
    // bouton des réglages ou de l'accueil, jamais d'office.
    if (kIsWeb) return;
    if (await rappels.permissionDejaDemandee()) return;
    await rappels.noterPermissionDemandee();
    await demanderPermission();
  }

  Future<void> _enregistrer(String? jeton) async {
    if (jeton == null || jeton.isEmpty) return;
    _jeton = jeton;
    await depot.enregistrerAppareil(
      api,
      token: jeton,
      plateforme: defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android',
    );
  }

  /// À la déconnexion : ce téléphone ne doit plus rien recevoir pour ce
  /// compte. On oublie le jeton côté serveur **avant** de couper la session
  /// (la route exige d'être connecté), puis côté Firebase.
  /// Le Web Push, une fois l'autorisation donnée : abonne le navigateur avec
  /// notre clé publique, enregistre l'abonnement, et écoute le service worker.
  Future<void> _activerNavigateur() async {
    if (etatPushNavigateur() != EtatPushNavigateur.accorde) return;
    try {
      if (!_ecouteNavigateur) {
        _ecouteNavigateur = true;
        ecouterPushNavigateur((brut) {
          final m = jsonDecode(brut);
          if (m is! Map) return;
          _auRecu();
          if (m['evenement'] == 'ouvrir') {
            _auToucher(cheminDe(m['lien'] as String?));
          }
        });
      }
      final cle = await depot.cleVapid(api);
      if (cle == null) return;
      final brut = await abonnerPushNavigateur(cle);
      if (brut == null) return;
      final abonnement = jsonDecode(brut);
      if (abonnement is! Map) return;
      final adresse = abonnement['endpoint'];
      final cles = abonnement['keys'];
      if (adresse is! String || cles is! Map) return;
      _jeton = adresse;
      await depot.enregistrerAppareil(
        api,
        token: adresse,
        plateforme: 'web',
        abonnement: {'p256dh': '${cles['p256dh']}', 'auth': '${cles['auth']}'},
      );
    } catch (e) {
      debugPrint('[push] Web Push impossible : $e');
    }
  }

  Future<void> desactiver() async {
    for (final a in _abonnements) {
      await a.cancel();
    }
    _abonnements.clear();
    if (kIsWeb) {
      final adresse = await desabonnerPushNavigateur();
      if (adresse != null) await depot.oublierAppareil(api, adresse);
      return;
    }
    if (!await disponible()) return;
    try {
      final jeton = _jeton ?? await FirebaseMessaging.instance.getToken();
      if (jeton != null) await depot.oublierAppareil(api, jeton);
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    _jeton = null;
  }
}

/// Les options Firebase de ce téléphone, ou `null` s'il en manque une.
FirebaseOptions? optionsFirebase() {
  final ios = defaultTargetPlatform == TargetPlatform.iOS;
  final apiKey = ios ? Config.firebaseIosApiKey : Config.firebaseAndroidApiKey;
  final appId = ios ? Config.firebaseIosAppId : Config.firebaseAndroidAppId;
  if (apiKey.isEmpty ||
      appId.isEmpty ||
      Config.firebaseProjectId.isEmpty ||
      Config.firebaseSenderId.isEmpty) {
    return null;
  }
  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: Config.firebaseSenderId,
    projectId: Config.firebaseProjectId,
    iosBundleId: ios ? 'com.reviz.app' : null,
  );
}
