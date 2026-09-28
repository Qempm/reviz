// Y a-t-il du réseau ?
//
// `connectivity_plus` était dans `pubspec.yaml` sans un seul import, comme
// `useOnline` côté web l'était sans un seul montage.
//
// **Ce que ce fichier sait, et ce qu'il ne sait pas.** Le greffon rapporte
// l'état des *interfaces* — wifi associé, données mobiles actives —, pas la
// présence réelle d'Internet. Un wifi d'hôtel derrière un portail captif, ou
// un forfait data épuisé, se présentent ici comme une connexion. C'est
// suffisant pour ce qu'on en fait : signaler l'absence évidente de réseau.
// Ce n'est pas suffisant pour décider qu'un appel va réussir — c'est pourquoi
// chaque écran garde son propre état d'erreur et son bouton « Réessayer ».

library;

import 'package:connectivity_plus/connectivity_plus.dart';

class DepotReseau {
  const DepotReseau();

  /// Vrai dès qu'une interface est disponible.
  static bool _connecte(List<ConnectivityResult> etats) =>
      etats.any((e) => e != ConnectivityResult.none);

  Future<bool> maintenant() async {
    try {
      return _connecte(await Connectivity().checkConnectivity());
    } catch (_) {
      // Pas de greffon — banc de test, plateforme non prévue. On se déclare
      // connecté : afficher un bandeau « hors ligne » à tort serait pire que
      // de ne rien afficher.
      return true;
    }
  }

  /// Les changements d'état, pour que le bandeau apparaisse et disparaisse
  /// tout seul.
  Stream<bool> flux() {
    try {
      return Connectivity().onConnectivityChanged.map(_connecte);
    } catch (_) {
      return const Stream<bool>.empty();
    }
  }
}
