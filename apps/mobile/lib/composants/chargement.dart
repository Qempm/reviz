import 'package:flutter/material.dart';
import '../i18n/fr.dart';
import '../theme/jetons.dart';

/// Ce qu'on voit pendant qu'un écran charge.
///
/// Des **silhouettes** à la forme du contenu, et non une roue au milieu d'un
/// écran vide : la page se dessine avant d'arriver, et l'arrivée des données
/// ne fait plus sauter la mise en page. Un reflet les traverse pour dire que
/// quelque chose se passe ; en mouvement réduit, elles restent immobiles.
///
/// Pour une attente **longue** — une copie qu'on corrige, une carte qu'on
/// lit —, c'est le panthéreau en `reflexion` qu'on montre, pas ce composant :
/// une silhouette qui reste trente secondes ressemble à une panne.
class Chargement extends StatefulWidget {
  /// Un titre et trois cartes : la forme de presque tous les onglets.
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
    if (MediaQuery.disableAnimationsOf(context)) {
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

    final silhouettes = hauteur != null
        ? _Bloc(hauteur: hauteur, rayon: Rayons.normal)
        : ListView(
            // Une silhouette ne se fait pas défiler : elle n'a rien à montrer
            // plus bas.
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: Espaces.ecran,
              vertical: Espaces.x16,
            ),
            children: const [
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.55,
                child: _Bloc(hauteur: 30, rayon: Rayons.moyen),
              ),
              SizedBox(height: Espaces.x8),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.8,
                child: _Bloc(hauteur: 16, rayon: Rayons.petit),
              ),
              SizedBox(height: Espaces.x24),
              _Bloc(hauteur: 148, rayon: Rayons.heros),
              SizedBox(height: Espaces.x12),
              _Bloc(hauteur: 96, rayon: Rayons.carte),
              SizedBox(height: Espaces.x12),
              _Bloc(hauteur: 96, rayon: Rayons.carte),
            ],
          );

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
