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
import '../metier/rappels.dart';

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

final animationsReduitesProvider = NotifierProvider<AnimationsReduites, bool>(
  AnimationsReduites.new,
);

/// Clés des réglages de rappels. Sur l'appareil, comme les rappels eux-mêmes :
/// ils sont programmés par ce téléphone, pour ce téléphone.
const String cleRappelSerie = 'reviz.rappel-serie';
const String cleRappelHeure = 'reviz.rappel-serie-heure';
const String cleRappelExamens = 'reviz.rappel-examens';
const String cleRappelFinPack = 'reviz.rappel-fin-pack';

/// Les rappels que l'étudiant veut, et l'heure du rappel du soir.
///
/// Même motif que [AnimationsReduites] : valeurs par défaut tout de suite,
/// réglage lu ensuite, écrit à chaque changement. `rappelsProvider` le
/// regarde et reprogramme le téléphone dès qu'il change.
class ReglagesRappels extends Notifier<OptionsRappels> {
  @override
  OptionsRappels build() {
    _relire();
    return const OptionsRappels();
  }

  Future<void> _relire() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lu = OptionsRappels(
        serie: prefs.getBool(cleRappelSerie) ?? true,
        heureSerie: (prefs.getInt(cleRappelHeure) ?? heureSerieParDefaut).clamp(
          heureSerieMin,
          heureSerieMax,
        ),
        examens: prefs.getBool(cleRappelExamens) ?? true,
        finPack: prefs.getBool(cleRappelFinPack) ?? true,
      );
      if (lu != state) state = lu;
    } catch (_) {
      // Pas de greffon (test), ou fournisseur jeté pendant la lecture.
    }
  }

  Future<void> changer(OptionsRappels nouvelles) async {
    state = nouvelles;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(cleRappelSerie, nouvelles.serie);
      await prefs.setInt(cleRappelHeure, nouvelles.heureSerie);
      await prefs.setBool(cleRappelExamens, nouvelles.examens);
      await prefs.setBool(cleRappelFinPack, nouvelles.finPack);
    } catch (_) {
      // Le choix tient pour la session.
    }
  }
}

final reglagesRappelsProvider =
    NotifierProvider<ReglagesRappels, OptionsRappels>(ReglagesRappels.new);
