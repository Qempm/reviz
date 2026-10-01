// Les rappels, programmés sur le téléphone.
//
// Aucun serveur : un rappel local ne coûte ni data ni envoi, et part même
// hors ligne. La règle (quand, quoi) est dans `metier/rappels.dart` ; ici, on
// programme ce qu'elle rend, en remplaçant les rappels précédents.
//
// Chaque appel au greffon est protégé : un test de widget n'a pas le greffon,
// un téléphone peut refuser les notifications — rien de cela ne doit casser
// un écran.

library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../i18n/fr.dart';
import '../metier/rappels.dart';
import '../theme/jetons.dart';

const String clePermissionRappelsDemandee = 'reviz.permission-rappels-demandee';

class ServiceRappels {
  ServiceRappels();

  final _greffon = FlutterLocalNotificationsPlugin();
  Future<bool>? _initialisation;

  Future<bool> _pret() => _initialisation ??= () async {
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
      );
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }();

  /// Demande la permission (Android 13, iOS), **une seule fois** : après une
  /// première série réussie, quand le rappel a du sens pour l'étudiant, et
  /// non à l'ouverture de l'application.
  Future<void> demanderPermissionUneFois() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(clePermissionRappelsDemandee) ?? false) return;
      await prefs.setBool(clePermissionRappelsDemandee, true);
      if (!await _pret()) return;
      await _greffon
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await _greffon
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {}
  }

  /// Remplace tous les rappels programmés par ceux-ci.
  Future<void> programmer(List<Rappel> rappels) async {
    if (!await _pret()) return;
    try {
      await _greffon.cancelAll();
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          'rappels',
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
        );
      }
    } catch (_) {}
  }
}
