import 'package:flutter/widgets.dart';
import 'jetons.dart';

// Échelle typographique de Reviz.
//
// Les douze niveaux de `tailwind.config.ts`, à l'identique : taille,
// interligne, interlettrage et graisse. Les majuscules sont réservées au seul
// niveau `caption`.
//
// La police est un fichier **variable**. `fontVariations` fixe l'axe `wght`
// explicitement, en plus de `fontWeight` : le second suffit à Flutter pour
// nos propres styles, mais le premier garantit le même rendu si un widget
// tiers recompose le style.

const _famille = 'Nunito Sans';

TextStyle _style({
  required double taille,
  required double interligne,
  required int graisse,
  double? interlettrage,
  Color? couleur,
}) {
  return TextStyle(
    fontFamily: _famille,
    fontSize: taille,
    // Flutter attend un multiplicateur, le web une valeur absolue.
    height: interligne / taille,
    letterSpacing: interlettrage == null ? null : taille * interlettrage,
    fontWeight: FontWeight.values[graisse ~/ 100 - 1],
    fontVariations: [FontVariation('wght', graisse.toDouble())],
    color: couleur ?? Couleurs.encre,
  );
}

abstract final class Typo {
  /// Chiffres héros, 44 px. Sur mobile, préférer [displayHerosMobile].
  static final displayHeros = _style(
    taille: 44,
    interligne: 48,
    graisse: 800,
    interlettrage: -0.02,
  );

  static final displayHerosMobile = _style(
    taille: 38,
    interligne: 42,
    graisse: 800,
    interlettrage: -0.02,
  );

  static final headlineXl = _style(
    taille: 28,
    interligne: 34,
    graisse: 800,
    interlettrage: -0.015,
  );

  static final headlineLg = _style(
    taille: 22,
    interligne: 28,
    graisse: 800,
    interlettrage: -0.01,
  );

  static final headlineMd = _style(taille: 18, interligne: 24, graisse: 800);

  static final headlineSm = _style(taille: 16, interligne: 22, graisse: 700);

  static final bodyLg = _style(taille: 16, interligne: 24, graisse: 500);

  static final bodyMd = _style(taille: 15, interligne: 22, graisse: 500);

  static final labelLg = _style(taille: 16, interligne: 20, graisse: 700);

  static final labelMd = _style(taille: 14, interligne: 18, graisse: 700);

  static final labelSm = _style(taille: 13, interligne: 16, graisse: 600);

  /// Le seul niveau en majuscules, +0.04em.
  static final caption = _style(
    taille: 11,
    interligne: 14,
    graisse: 700,
    interlettrage: 0.04,
  );
}
