// Les notifications affichées par le téléphone : les rappels, programmés
// ici, et les push reçus application ouverte.
//
// Aucun serveur pour les rappels : un rappel local ne coûte ni data ni envoi,
// et part même hors ligne. La règle (quand, quoi) est dans
// `metier/rappels.dart` ; ici, on programme ce qu'elle rend, en remplaçant
// les rappels précédents.
//
// Deux canaux Android, que l'étudiant peut régler séparément dans les
// paramètres du téléphone : `rappels` (série, examens, fin de pack) et
// `evenements` (cours prêt, copie corrigée, paiement… — le push).
//
// Chaque appel au greffon est protégé : un test de widget n'a pas le greffon,
// un téléphone peut refuser les notifications — rien de cela ne doit casser
// un écran.

library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../i18n/fr.dart';
import '../metier/plateforme.dart';
import '../metier/rappels.dart';
import '../theme/jetons.dart';

const String clePermissionRappelsDemandee = 'reviz.permission-rappels-demandee';

const String canalRappels = 'rappels';
const String canalEvenements = 'evenements';

class ServiceRappels {
  ServiceRappels();

  // Paresseux : dans un navigateur, le greffon n'existe pas, et on ne le
  // construit même pas (`rappelsDisponibles`).
  late final _greffon = FlutterLocalNotificationsPlugin();
  Future<bool>? _initialisation;

  /// Appelé quand l'étudiant touche une notification, avec son lien
  /// (`/cours/…`). Posé par la racine de l'application, qui a le routeur.
  void Function(String lien)? auToucher;

  Future<bool> _pret() => _initialisation ??= () async {
    if (!rappelsDisponibles) return false;
    try {
      final ok = await _greffon.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // iOS demanderait la permission dès l'initialisation : on la garde
          // pour après la première série, comme sur Android.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (reponse) {
          final lien = reponse.payload;
          if (lien != null && lien.isNotEmpty) auToucher?.call(lien);
        },
      );
      // Le canal des push existe avant le premier push : sans lui, Android
      // range un push reçu en arrière-plan dans « Divers ».
      await _greffon
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            AndroidNotificationChannel(
              canalEvenements,
              Fr.notifications.canalNom,
              description: Fr.notifications.canalDescription,
              importance: Importance.high,
            ),
          );
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }();

  /// Prépare le greffon au démarrage, et rend le lien de la notification qui
  /// a **lancé** l'application, s'il y en a une (démarrage à froid).
  Future<String?> demarrer() async {
    if (!await _pret()) return null;
    try {
      final details = await _greffon.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        final lien = details!.notificationResponse?.payload;
        if (lien != null && lien.isNotEmpty) return lien;
      }
    } catch (_) {}
    return null;
  }

  /// Demande la permission (Android 13, iOS), **une seule fois** : après une
  /// première série réussie, quand le rappel a du sens pour l'étudiant, et
  /// non à l'ouverture de l'application.
  Future<void> demanderPermissionUneFois() async {
    if (!rappelsDisponibles || await permissionDejaDemandee()) return;
    await noterPermissionDemandee();
    await demanderPermission();
  }

  Future<bool> permissionDejaDemandee() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(clePermissionRappelsDemandee) ?? false;
    } catch (_) {
      return true;
    }
  }

  Future<void> noterPermissionDemandee() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(clePermissionRappelsDemandee, true);
    } catch (_) {}
  }

  /// Demande la permission maintenant — le bouton des réglages. Rend
  /// `true` si les notifications sont autorisées ensuite.
  Future<bool> demanderPermission() async {
    if (!await _pret()) return false;
    try {
      final android = await _greffon
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      final ios = await _greffon
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return android ?? ios ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Les notifications sont-elles autorisées sur ce téléphone ? `null` si on
  /// ne peut pas le savoir (web, test).
  Future<bool?> autorisees() async {
    if (!await _pret()) return null;
    try {
      final android = _greffon
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) return await android.areNotificationsEnabled();
      final ios = _greffon
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) return (await ios.checkPermissions())?.isEnabled;
    } catch (_) {}
    return null;
  }

  /// Remplace tous les rappels programmés par ceux-ci.
  ///
  /// N'annule que les **rappels** (identifiants 1 à 99) : un push affiché
  /// application ouverte ne doit pas disparaître parce que l'accueil s'est
  /// rafraîchi.
  Future<void> programmer(List<Rappel> rappels) async {
    if (!await _pret()) return;
    try {
      await _annulerRappels();
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          canalRappels,
          Fr.rappels.canalNom,
          channelDescription: Fr.rappels.canalDescription,
          color: Couleurs.jaune,
        ),
        iOS: const DarwinNotificationDetails(),
      );
      for (final r in rappels) {
        await _greffon.zonedSchedule(
          id: r.id,
          // En UTC depuis l'heure locale du téléphone : l'instant est exact,
          // et l'Afrique de l'Ouest n'a pas d'heure d'été à suivre.
          scheduledDate: tz.TZDateTime.from(r.quand.toUtc(), tz.UTC),
          notificationDetails: details,
          // À quelques minutes près : pas de permission d'alarme exacte à
          // demander, et la batterie s'en porte mieux.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: r.titre,
          body: r.texte,
          payload: r.lien,
        );
      }
    } catch (_) {}
  }

  Future<void> _annulerRappels() async {
    final attente = await _greffon.pendingNotificationRequests();
    for (final p in attente) {
      if (p.id <= idRappelMax) await _greffon.cancel(id: p.id);
    }
  }

  /// Affiche un push reçu pendant que l'application est ouverte — Android
  /// et iOS ne l'affichent pas d'eux-mêmes dans ce cas.
  Future<void> afficher({
    required String titre,
    required String corps,
    required String lien,
  }) async {
    if (!await _pret()) return;
    try {
      await _greffon.show(
        // Au-delà des rappels, et différent à chaque push.
        id: idRappelMax + 1 + (DateTime.now().millisecondsSinceEpoch % 100000),
        title: titre,
        body: corps,
        payload: lien,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            canalEvenements,
            Fr.notifications.canalNom,
            channelDescription: Fr.notifications.canalDescription,
            importance: Importance.high,
            priority: Priority.high,
            color: Couleurs.jaune,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('[rappels] affichage impossible : $e');
    }
  }

  /// Tout annuler : déconnexion, suppression du compte. Les rappels d'un
  /// compte ne doivent pas sonner sur le téléphone d'un autre.
  Future<void> toutAnnuler() async {
    if (!await _pret()) return;
    try {
      await _greffon.cancelAll();
    } catch (_) {}
  }
}
