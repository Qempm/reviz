// Réglages locaux, propres à l'appareil.
//
// Rien de ce qui est ici ne part sur le serveur : ce sont des préférences
// d'affichage, pas des données de compte. `shared_preferences` suffit, et son
// absence ne doit jamais casser un écran — d'où le `try` autour de chaque
// accès (un test de widget n'a pas le greffon, une plateforme non prévue non
// plus).

library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clé du réglage « réduire les animations ».
///
/// Même nom que côté web (`reviz.animations-reduites`), pour qu'un étudiant
/// qui passe du site à l'application retrouve son choix documenté au même
/// endroit. Les deux stockages sont distincts : c'est un nom commun, pas une
/// synchronisation.
const String cleAnimationsReduites = 'reviz.animations-reduites';

/// Réduire les animations.
///
/// S'ajoute à `MediaQuery.disableAnimations`, qui porte la préférence
/// système : un étudiant peut vouloir moins de mouvement dans Reviz sans
/// l'avoir demandé pour tout son téléphone.
class AnimationsReduites extends Notifier<bool> {
  @override
  bool build() {
    // Lecture différée : construire un fournisseur ne peut pas attendre un
    // aller-retour disque. La valeur par défaut est « animations normales »,
    // et le réglage s'applique dès qu'il est lu.
    _relire();
    return false;
  }

  Future<void> _relire() async {
    final lu = await _lire();
    if (lu != null && lu != state) {
      try {
        state = lu;
      } catch (_) {
        // Le fournisseur a été jeté entre-temps (écran quitté pendant la
        // lecture). Il n'y a rien à faire, et surtout rien à signaler.
      }
    }
  }

  Future<void> basculer() async {
    final nouvelle = !state;
    state = nouvelle;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(cleAnimationsReduites, nouvelle);
    } catch (_) {
      // Le choix tient pour la session mais ne survivra pas au redémarrage.
      // Mieux que de refuser le réglage.
    }
  }

  static Future<bool?> _lire() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(cleAnimationsReduites);
    } catch (_) {
      return null;
    }
  }
}

final animationsReduitesProvider =
    NotifierProvider<AnimationsReduites, bool>(AnimationsReduites.new);
