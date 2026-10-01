import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../donnees/supabase.dart';
import '../etat/fournisseurs.dart';
import '../metier/notifications.dart';
import '../routage.dart';

/// Le lien entre les notifications et la navigation, monté une fois à la
/// racine (`main.dart`, au-dessus du routeur).
///
///  - Toucher un rappel ou un push ouvre l'écran qu'il annonce — y compris
///    quand c'est lui qui a lancé l'application.
///  - Connecté, le téléphone s'inscrit au push (s'il a la permission).
///  - Au retour au premier plan, le centre de notifications se relit : la
///    pastille de la cloche dit vrai sans attendre un rafraîchissement.
class EcouteNotifications extends ConsumerStatefulWidget {
  const EcouteNotifications({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<EcouteNotifications> createState() =>
      _EcouteNotificationsState();
}

class _EcouteNotificationsState extends ConsumerState<EcouteNotifications> {
  AppLifecycleListener? _cycle;

  @override
  void initState() {
    super.initState();
    final rappels = ref.read(serviceRappelsProvider);
    final push = ref.read(servicePushProvider);

    rappels.auToucher = _ouvrir;
    push.brancher(auRecu: _relire, auToucher: _ouvrir);

    _cycle = AppLifecycleListener(
      onResume: () {
        if (supabase.auth.currentUser == null) return;
        _relire();
        // La permission a pu être accordée dans les réglages du téléphone.
        push.activer();
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final lien = await rappels.demarrer();
      if (lien != null) _ouvrir(lien);
      if (supabase.auth.currentUser != null) await push.activer();
    });
  }

  @override
  void dispose() {
    _cycle?.dispose();
    super.dispose();
  }

  void _relire() {
    if (!mounted) return;
    ref.invalidate(notificationsProvider);
    // Un push « cours prêt » ou « paiement confirmé » change aussi ce que
    // montrent l'accueil et la liste des cours.
    ref.invalidate(coursProvider);
    ref.invalidate(accueilProvider);
  }

  void _ouvrir(String lien) {
    if (!mounted) return;
    final chemin = cheminDe(lien);
    final routeur = ref.read(routeurProvider);
    // L'accueil est la racine : on y retourne, on ne l'empile pas.
    if (chemin == Chemins.accueil) {
      routeur.go(chemin);
    } else {
      routeur.push(chemin);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Une connexion (ou une reconnexion) inscrit le téléphone au push.
    ref.listen(authProvider, (_, etat) {
      if (etat.value?.session != null) {
        ref.read(servicePushProvider).activer();
        ref.invalidate(notificationsProvider);
      }
    });
    return widget.child;
  }
}
