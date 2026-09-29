import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Barre de progression : 10 px en pilule, remplissage plat.
///
/// **Elle se remplit**, au lieu d'apparaître déjà pleine : à l'arrivée sur
/// l'écran elle part de zéro, et quand la valeur change elle glisse jusqu'à
/// la nouvelle. Une progression qu'on voit avancer se lit comme un progrès ;
/// une barre figée, comme un chiffre.
class BarreProgression extends StatelessWidget {
  const BarreProgression({super.key, required this.valeur, this.libelle});

  /// Entre 0 et 1.
  final double valeur;
  final String? libelle;

  @override
  Widget build(BuildContext context) {
    final pct = (valeur.clamp(0.0, 1.0) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (libelle != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  libelle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                ),
              ),
              const SizedBox(width: Espaces.x8),
              Text('$pct %', style: Typo.labelSm),
            ],
          ),
          const SizedBox(height: Espaces.x4),
        ],
        Semantics(
          value: '$pct %',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 10,
              color: Couleurs.surfaceConteneur,
              child: _Remplissage(
                valeur: valeur.clamp(0.0, 1.0),
                construire: (v) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: v,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: Couleurs.jaune,
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// État d'un segment de session.
///
/// Conforme à l'arbitrage de palette : le juste est en **jaune**, le faux en
/// rouge d'erreur. Aucun vert.
enum EtatSegment { juste, faux, aVenir }

/// Progression segmentée d'une session : une case par question.
class BarreSegmentee extends StatelessWidget {
  const BarreSegmentee({super.key, required this.segments});

  final List<EtatSegment> segments;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 12,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Couleurs.surfaceHaute,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0) const SizedBox(width: Espaces.x4),
            Expanded(
              // Un segment qui change d'état glisse vers sa couleur : on voit
              // la réponse s'inscrire dans la barre.
              child: AnimatedContainer(
                duration: Mouvement.doux,
                curve: Mouvement.courbeDouce,
                decoration: BoxDecoration(
                  color: switch (segments[i]) {
                    EtatSegment.juste => Couleurs.jaune,
                    EtatSegment.faux => Couleurs.danger,
                    EtatSegment.aVenir => Couleurs.surfaceConteneur,
                  },
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Jauge circulaire, pour le taux de maîtrise d'une matière.
///
/// Dessinée au `Canvas` plutôt qu'en dégradé conique : celui-ci s'anime mal et
/// rend des bords crénelés sur les navigateurs Android anciens — la raison
/// vaut aussi pour le rendu natif.
class JaugeCirculaire extends StatelessWidget {
  const JaugeCirculaire({
    super.key,
    required this.valeur,
    this.taille = 72,
    this.epaisseur = 8,
    this.centre,
  });

  final double valeur;
  final double taille;
  final double epaisseur;
  final Widget? centre;

  @override
  Widget build(BuildContext context) {
    final pct = valeur.clamp(0.0, 1.0);

    return Semantics(
      value: '${(pct * 100).round()} %',
      child: SizedBox(
        width: taille,
        height: taille,
        child: _Remplissage(
          valeur: pct,
          construire: (v) => CustomPaint(
            painter: _PeintreJauge(valeur: v, epaisseur: epaisseur),
            child: Center(child: centre),
          ),
        ),
      ),
    );
  }
}

class _PeintreJauge extends CustomPainter {
  _PeintreJauge({required this.valeur, required this.epaisseur});

  final double valeur;
  final double epaisseur;

  @override
  void paint(Canvas canvas, Size size) {
    final rayon = (size.width - epaisseur) / 2;
    final centre = Offset(size.width / 2, size.height / 2);

    final fond = Paint()
      ..color = Couleurs.surfaceConteneur
      ..style = PaintingStyle.stroke
      ..strokeWidth = epaisseur;

    final trait = Paint()
      ..color = Couleurs.jaune
      ..style = PaintingStyle.stroke
      ..strokeWidth = epaisseur
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(centre, rayon, fond);

    if (valeur > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: rayon),
        // Départ à midi, comme la version web qui applique une rotation
        // de -90°.
        -math.pi / 2,
        2 * math.pi * valeur,
        false,
        trait,
      );
    }
  }

  @override
  bool shouldRepaint(_PeintreJauge ancien) =>
      ancien.valeur != valeur || ancien.epaisseur != epaisseur;
}


/// Anime une valeur de progression, de zéro à l'arrivée puis d'une valeur à
/// l'autre. Mis en commun pour que la barre et la jauge bougent pareil.
///
/// Respecte le mouvement réduit : la valeur est alors posée d'emblée.
class _Remplissage extends StatelessWidget {
  const _Remplissage({required this.valeur, required this.construire});

  final double valeur;
  final Widget Function(double) construire;

  @override
  Widget build(BuildContext context) {
    final reduit = MediaQuery.disableAnimationsOf(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: valeur),
      duration: reduit ? Duration.zero : const Duration(milliseconds: 700),
      curve: Mouvement.courbeDouce,
      builder: (_, v, _) => construire(v),
    );
  }
}
