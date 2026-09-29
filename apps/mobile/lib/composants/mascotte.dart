import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../i18n/fr.dart';
import '../theme/jetons.dart';

/// Les humeurs du panthéreau, une par situation.
///
/// Chaque état est un dessin distinct (`assets/mascotte/<nom>.webp`), tiré de
/// la même référence dans Flow pour que ce soit toujours le même personnage.
enum EtatMascotte {
  /// Accueil : il fait signe.
  salut,

  /// Réussite : il saute, les deux pattes en l'air.
  bravo,

  /// Échec : un pouce levé, « on recommence ».
  courage,

  /// N° 1, sans-faute, record : couronne sur la tête.
  champion,

  /// Attente longue (lecture d'une copie, d'un cours) : il lit.
  reflexion,

  /// Pack arrivé à terme : il dort sous un croissant de lune.
  dodo,

  /// Rien à afficher encore : il cherche à la loupe.
  curieux;

  String get chemin => 'assets/mascotte/$name.webp';

  String get description => switch (this) {
    salut => Fr.mascotte.salut,
    bravo => Fr.mascotte.bravo,
    courage => Fr.mascotte.courage,
    champion => Fr.mascotte.champion,
    reflexion => Fr.mascotte.reflexion,
    dodo => Fr.mascotte.dodo,
    curieux => Fr.mascotte.curieux,
  };
}

/// Le panthéreau Reviz.
///
/// Il **entre** en surgissant (échelle sur un ressort à léger dépassement),
/// puis **respire** : un gonflement de 3 % toutes les 2,4 s, le pied posé
/// pour que ce soit le corps qui monte et pas l'image qui flotte.
///
/// La respiration s'arrête d'elle-même après quelques cycles, sauf en
/// `reflexion` qui accompagne une attente et ne doit pas se figer avant
/// elle (`enBoucle` force l'un ou l'autre). Une animation sans fin ailleurs empêcherait `pumpAndSettle` de
/// jamais conclure dans les tests d'écran — et, sur un vieux téléphone,
/// redessinerait l'écran pour rien pendant que l'étudiant lit.
///
/// En mouvement réduit, il est posé d'emblée et ne bouge pas.
class Mascotte extends StatefulWidget {
  const Mascotte({
    super.key,
    required this.etat,
    this.taille = 120,
    this.enBoucle,
  });

  final EtatMascotte etat;

  /// Côté du carré, en pixels logiques. Le dessin est carré.
  final double taille;

  /// Respire sans fin ? Par défaut, seulement en `reflexion`.
  final bool? enBoucle;

  bool get _respireSansFin => enBoucle ?? etat == EtatMascotte.reflexion;

  @override
  State<Mascotte> createState() => _MascotteState();
}

class _MascotteState extends State<Mascotte> with TickerProviderStateMixin {
  static const _respiration = Duration(milliseconds: 2400);
  static const _cyclesHorsAttente = 3;

  late final AnimationController _entree = AnimationController(
    vsync: this,
    duration: Mouvement.ample + const Duration(milliseconds: 180),
  );

  late final Animation<double> _echelle = CurvedAnimation(
    parent: _entree,
    curve: const CourbeRessort(
      // Moins amorti que `ressortVif` : on veut voir le rebond.
      SpringDescription(mass: 1, stiffness: 260, damping: 14),
      Duration(milliseconds: 540),
    ),
  );

  late final AnimationController _souffle = AnimationController(
    vsync: this,
    duration: _respiration,
  );

  bool _demarre = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_demarre) return;
    _demarre = true;

    if (MediaQuery.disableAnimationsOf(context)) {
      _entree.value = 1;
      return;
    }

    _entree.forward().whenComplete(_respirer);
  }

  void _respirer() {
    if (!mounted) return;
    if (widget._respireSansFin) {
      _souffle.repeat();
    } else {
      _souffle
          .repeat(count: _cyclesHorsAttente)
          .whenComplete(() => _souffle.value = 0);
    }
  }

  @override
  void didUpdateWidget(covariant Mascotte ancien) {
    super.didUpdateWidget(ancien);
    // Un écran de chargement qui devient un écran de résultat garde le même
    // widget : la respiration sans fin ne doit pas le suivre.
    if (ancien._respireSansFin &&
        !widget._respireSansFin &&
        _souffle.isAnimating) {
      _souffle.stop();
      _souffle.value = 0;
    }
  }

  @override
  void dispose() {
    _entree.dispose();
    _souffle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.taille;
    final ratio = MediaQuery.devicePixelRatioOf(context);

    final dessin = Image.asset(
      widget.etat.chemin,
      width: t,
      height: t,
      // Décodé à la taille affichée : un WebP de 512 px décodé en entier pour
      // une vignette de 96 px coûte cinq fois la mémoire nécessaire.
      cacheWidth: (t * ratio).round(),
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      gaplessPlayback: true,
      // Un asset manquant ne doit jamais casser un écran de résultat.
      errorBuilder: (_, _, _) => SizedBox.square(dimension: t),
    );

    return Semantics(
      container: true,
      image: true,
      label: widget.etat.description,
      child: SizedBox.square(
        dimension: t,
        child: AnimatedBuilder(
          animation: Listenable.merge([_entree, _souffle]),
          builder: (context, enfant) {
            final souffle = math.sin(_souffle.value * 2 * math.pi);
            return Opacity(
              opacity: _entree.value.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.6 + 0.4 * _echelle.value,
                alignment: Alignment.bottomCenter,
                child: Transform.scale(
                  scaleX: 1 - 0.012 * souffle,
                  scaleY: 1 + 0.03 * souffle,
                  alignment: Alignment.bottomCenter,
                  child: enfant,
                ),
              ),
            );
          },
          child: AnimatedSwitcher(
            duration: Mouvement.doux,
            child: KeyedSubtree(key: ValueKey(widget.etat), child: dessin),
          ),
        ),
      ),
    );
  }
}
