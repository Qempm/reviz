import 'package:flutter/widgets.dart';
import 'jetons.dart';

// Échelle typographique de Reviz — identité du 3 octobre 2026.
//
// Deux familles, et une règle simple pour choisir :
//
//  * **Fredoka** pour ce qui se lit d'un coup d'œil — titres, chiffres
//    héros, montants. Ronde comme le panthéreau, elle donne la voix de la
//    marque. Elle n'existe qu'en une graisse (600, l'ancienne Fredoka One) :
//    on ne la grossit pas, on l'agrandit ;
//  * **Inter** pour tout ce qui se lit vraiment — corps, labels, boutons.
//    Fichier variable : `fontVariations` fixe l'axe `wght` en plus de
//    `fontWeight`, pour le même rendu si un widget tiers recompose le style.
//
// Fredoka n'a pas de chiffres tabulaires. Un compteur qui défile garde donc
// Inter (`Typo.chiffres`), sinon sa largeur tremblerait à chaque chiffre.
// Les majuscules sont réservées au seul niveau `caption`.

const familleTitres = 'Fredoka';
const familleTexte = 'Inter';

TextStyle _titre({
  required double taille,
  required double interligne,
  double? interlettrage,
}) {
  return TextStyle(
    fontFamily: familleTitres,
    fontSize: taille,
    // Flutter attend un multiplicateur, le web une valeur absolue.
    height: interligne / taille,
    letterSpacing: interlettrage == null ? null : taille * interlettrage,
    fontWeight: FontWeight.w600,
    color: Couleurs.encre,
  );
}

TextStyle _texte({
  required double taille,
  required double interligne,
  required int graisse,
  double? interlettrage,
}) {
  return TextStyle(
    fontFamily: familleTexte,
    fontSize: taille,
    height: interligne / taille,
    letterSpacing: interlettrage == null ? null : taille * interlettrage,
    fontWeight: FontWeight.values[graisse ~/ 100 - 1],
    fontVariations: [FontVariation('wght', graisse.toDouble())],
    color: Couleurs.encre,
  );
}

abstract final class Typo {
  /// Chiffres héros, 44 px. Sur mobile, préférer [displayHerosMobile].
  static final displayHeros = _titre(
    taille: 44,
    interligne: 48,
    interlettrage: -0.01,
  );

  static final displayHerosMobile = _titre(
    taille: 38,
    interligne: 42,
    interlettrage: -0.01,
  );

  static final headlineXl = _titre(taille: 28, interligne: 34);

  static final headlineLg = _titre(taille: 22, interligne: 28);

  static final headlineMd = _titre(taille: 19, interligne: 24);

  static final headlineSm = _titre(taille: 17, interligne: 22);

  static final bodyLg = _texte(taille: 16, interligne: 24, graisse: 400);

  static final bodyMd = _texte(taille: 15, interligne: 22, graisse: 400);

  static final labelLg = _texte(taille: 16, interligne: 20, graisse: 600);

  static final labelMd = _texte(taille: 14, interligne: 18, graisse: 600);

  static final labelSm = _texte(taille: 13, interligne: 16, graisse: 500);

  /// Le seul niveau en majuscules, +0.04em.
  static final caption = _texte(
    taille: 11,
    interligne: 14,
    graisse: 700,
    interlettrage: 0.04,
  );

  /// Un compteur qui change sous les yeux : Inter, chiffres tabulaires, en
  /// graisse forte. À appliquer par-dessus un style Fredoka avec
  /// `style.merge(Typo.chiffres)`.
  static final chiffres = TextStyle(
    fontFamily: familleTexte,
    fontWeight: FontWeight.w700,
    fontVariations: const [FontVariation('wght', 700)],
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
