import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// États d'une option de QCM.
///
/// Toujours **pas de vert de succès** : la bonne réponse se célèbre en jaune,
/// la mauvaise en rouge d'erreur. Ce qui a changé le 29 septembre 2026, c'est
/// le relief : l'arête tactile pleine est remplacée par un **anneau** de
/// sélection fin — la sélection d'iOS —, et le passage d'un état à l'autre
/// s'anime au lieu de sauter.
enum EtatOption { repos, choisie, juste, fausse }

/// Option de QCM, une par ligne et pleine largeur.
class OptionQcm extends StatefulWidget {
  const OptionQcm({
    super.key,
    required this.lettre,
    required this.libelle,
    this.etat = EtatOption.repos,
    this.onTap,
  });

  /// Lettre affichée dans la pastille : A, B, C, D.
  final String lettre;
  final String libelle;
  final EtatOption etat;
  final VoidCallback? onTap;

  @override
  State<OptionQcm> createState() => _OptionQcmState();
}

class _OptionQcmState extends State<OptionQcm>
    with SingleTickerProviderStateMixin {
  bool _enfonce = false;

  /// La secousse d'une mauvaise réponse : trois allers-retours qui
  /// s'amortissent, en 420 ms. Le geste « non » de la tête — on comprend
  /// avant d'avoir lu la couleur.
  late final AnimationController _secousse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(OptionQcm ancien) {
    super.didUpdateWidget(ancien);

    final devientFausse =
        widget.etat == EtatOption.fausse && ancien.etat != EtatOption.fausse;

    if (devientFausse && !MediaQuery.disableAnimationsOf(context)) {
      HapticFeedback.mediumImpact();
      _secousse.forward(from: 0);
    } else if (widget.etat == EtatOption.juste &&
        ancien.etat != EtatOption.juste) {
      HapticFeedback.lightImpact();
    }
  }

  @override
  void dispose() {
    _secousse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final etat = widget.etat;
    final reduit = MediaQuery.disableAnimationsOf(context);

    final (fond, anneau, pastille, surPastille, texte) = switch (etat) {
      EtatOption.repos => (
        Couleurs.carte,
        null,
        Couleurs.surfaceConteneur,
        Couleurs.attenue,
        Couleurs.encre,
      ),
      EtatOption.choisie => (
        Couleurs.jauneDoux,
        Couleurs.jaune,
        Couleurs.jaune,
        Couleurs.surJaune,
        Couleurs.encre,
      ),
      EtatOption.juste => (
        Couleurs.jauneDoux,
        Couleurs.jaune,
        Couleurs.jaune,
        Couleurs.surJaune,
        Couleurs.encre,
      ),
      EtatOption.fausse => (
        Couleurs.dangerDoux,
        Couleurs.danger,
        Couleurs.danger,
        Colors.white,
        Couleurs.surDangerDoux,
      ),
    };

    final icone = switch (etat) {
      EtatOption.juste => Icons.check_rounded,
      EtatOption.fausse => Icons.close_rounded,
      _ => null,
    };

    final actif = widget.onTap != null;

    return AnimatedBuilder(
      animation: _secousse,
      builder: (context, enfant) {
        final t = _secousse.value;
        // Une sinusoïde qui s'éteint : 3 oscillations, amplitude 7 px → 0.
        final dx = math.sin(t * math.pi * 6) * 7 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: enfant);
      },
      child: Semantics(
        button: actif,
        selected: etat == EtatOption.choisie,
        child: GestureDetector(
          onTapDown: actif ? (_) => setState(() => _enfonce = true) : null,
          onTapUp: actif ? (_) => setState(() => _enfonce = false) : null,
          onTapCancel: actif ? () => setState(() => _enfonce = false) : null,
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _enfonce && !reduit ? 0.98 : 1,
            duration: _enfonce ? Mouvement.appui : Mouvement.glisse,
            curve: _enfonce ? Curves.easeOut : Mouvement.courbeGlisse,
            child: AnimatedContainer(
              duration: Mouvement.doux,
              curve: Mouvement.courbeDouce,
              constraints: const BoxConstraints(minHeight: Mesures.zoneTactile),
              padding: const EdgeInsets.all(Espaces.x16),
              decoration: ShapeDecoration(
                color: fond,
                shape: formeContinue(
                  Rayons.normal,
                  // Un anneau fin, à l'intérieur, plutôt qu'une ombre : la
                  // sélection se lit sans que l'option change de hauteur.
                  bord: BorderSide(
                    color: anneau ?? Colors.transparent,
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
                shadows: anneau == null ? Ombres.cartePetite : const [],
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: Mouvement.doux,
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: pastille,
                      shape: BoxShape.circle,
                    ),
                    child: AnimatedSwitcher(
                      duration: Mouvement.doux,
                      transitionBuilder: (enfant, animation) => ScaleTransition(
                        scale: animation,
                        child: enfant,
                      ),
                      child: icone != null
                          ? Icon(
                              icone,
                              key: ValueKey(icone),
                              size: 20,
                              color: surPastille,
                            )
                          : Text(
                              widget.lettre,
                              key: ValueKey(widget.lettre),
                              style: Typo.labelMd.copyWith(color: surPastille),
                            ),
                    ),
                  ),
                  const SizedBox(width: Espaces.x12),
                  Expanded(
                    child: Text(
                      widget.libelle,
                      style: Typo.bodyLg.copyWith(color: texte),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
