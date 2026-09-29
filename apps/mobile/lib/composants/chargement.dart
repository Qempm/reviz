import 'package:flutter/material.dart';
import '../i18n/fr.dart';
import '../theme/typographie.dart';
import '../theme/jetons.dart';
import 'mascotte.dart';

/// Ce qu'on voit pendant qu'un écran charge.
///
/// **Page entière** (`Chargement.liste()`) : le panthéreau lit, avec
/// « Un instant… ». Le propriétaire a voulu la mascotte sur chaque page de
/// chargement ; les silhouettes grises qu'il y avait avant sont parties.
///
/// **Morceau de page** (`Chargement.bloc()`) — une liste de matières dans un
/// formulaire, un historique sous une carte : une silhouette traversée d'un
/// reflet. Un panthéreau dans une case de 56 px serait illisible, et la page
/// autour, elle, est déjà là.
///
/// En mouvement réduit, rien ne bouge.
class Chargement extends StatefulWidget {
  /// Une page entière qui charge : le panthéreau lit.
  const Chargement.liste({super.key}) : hauteur = null;

  /// Un seul bloc, là où un morceau de page charge dans une page déjà là
  /// (une liste de matières dans un formulaire, un historique).
  const Chargement.bloc({super.key, this.hauteur = 56});

  final double? hauteur;

  @override
  State<Chargement> createState() => _ChargementState();
}

class _ChargementState extends State<Chargement>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reflet = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.hauteur == null || MediaQuery.disableAnimationsOf(context)) {
      _reflet.stop();
      _reflet.value = 0.5;
    } else if (!_reflet.isAnimating) {
      _reflet.repeat();
    }
  }

  @override
  void dispose() {
    _reflet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hauteur = widget.hauteur;

    if (hauteur == null) {
      return Semantics(
        label: Fr.commun.chargement,
        liveRegion: true,
        child: ExcludeSemantics(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Mascotte(etat: EtatMascotte.reflexion, taille: 132),
                const SizedBox(height: Espaces.x12),
                Text(
                  Fr.commun.chargement,
                  style: Typo.labelMd.copyWith(color: Couleurs.attenue),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final silhouettes = _Bloc(hauteur: hauteur, rayon: Rayons.normal);

    return Semantics(
      label: Fr.commun.chargement,
      liveRegion: true,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _reflet,
          builder: (context, enfant) => ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bornes) => LinearGradient(
              colors: const [
                Couleurs.surfaceHaute,
                Couleurs.surfaceBasse,
                Couleurs.surfaceHaute,
              ],
              stops: const [0.35, 0.5, 0.65],
              transform: _Glisse(_reflet.value),
            ).createShader(bornes),
            child: enfant,
          ),
          child: silhouettes,
        ),
      ),
    );
  }
}

/// Fait passer le reflet de la gauche, hors cadre, à la droite, hors cadre.
class _Glisse extends GradientTransform {
  const _Glisse(this.t);

  final double t;

  @override
  Matrix4? transform(Rect bornes, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bornes.width * (2 * t - 1), 0, 0);
}

class _Bloc extends StatelessWidget {
  const _Bloc({required this.hauteur, required this.rayon});

  final double hauteur;
  final double rayon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: hauteur,
      decoration: ShapeDecoration(
        // La teinte réelle vient du `ShaderMask`, qui peint par-dessus : ce
        // blanc ne sert qu'à donner une forme opaque à recouvrir.
        color: Couleurs.carte,
        shape: formeContinue(rayon),
      ),
    );
  }
}
