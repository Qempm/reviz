import 'package:flutter/material.dart';

// Jetons du design system Reviz.
//
// Transposés de `tailwind.config.ts`, lui-même figé depuis les écrans Stitch
// réellement générés (`docs/DESIGN.md`). **Aucune valeur n'est réinventée
// ici** : si un écart apparaît, c'est `docs/DESIGN.md` qui fait foi.
//
// Deux arbitrages du 8 septembre 2026 doivent survivre au portage :
//
//  * le fond est un blanc cassé **chaud** (`#fcf9f8`), pas un crème ;
//  * **la palette n'a aucun vert.** Une bonne réponse se célèbre en jaune,
//    une mauvaise en rouge d'erreur. Ne pas introduire `#22C55E` ni
//    `#EF4444`.

abstract final class Couleurs {
  /// Fond de l'application.
  static const cream = Color(0xFFFCF9F8);

  /// Cartes.
  static const carte = Color(0xFFFFFFFF);

  /// Jaune d'accent : CTA, progression, podium n° 1, série.
  static const jaune = Color(0xFFFFC300);

  /// Sélection de QCM, bonne réponse.
  static const jauneDoux = Color(0xFFFFDF9A);

  /// Texte sur un fond jaune.
  static const surJaune = Color(0xFF6D5200);

  /// Urgence, compte à rebours.
  static const orange = Color(0xFFFE6A2B);

  /// Podium n° 3.
  static const orangeDoux = Color(0xFFFFDBCF);

  /// Podium n° 2, badges.
  static const bleu = Color(0xFFBCCDEB);
  static const bleuDoux = Color(0xFFD4E3FF);

  /// Texte principal.
  static const encre = Color(0xFF1C1B1B);

  /// Texte secondaire — brun chaud, **jamais un gris froid**.
  static const attenue = Color(0xFF4F4632);

  /// Mauvaise réponse.
  static const danger = Color(0xFFBA1A1A);
  static const dangerDoux = Color(0xFFFFDAD6);
  static const surDangerDoux = Color(0xFF93000A);

  static const bordure = Color(0xFFD3C5AB);

  /// ⚠️ `primary` du jeu Material 3 conservé côté web : il sert **au texte**,
  /// jamais à un fond de CTA. Le jaune, lui, est `primary-container`.
  /// Confondre les deux donne un CTA brun.
  static const texteAccent = Color(0xFF785A00);

  /// Surfaces intermédiaires, reprises des rôles Material 3 de Stitch.
  static const surfaceBasse = Color(0xFFF6F3F2);
  static const surfaceConteneur = Color(0xFFF0EDED);
  static const surfaceHaute = Color(0xFFEAE7E7);

  /// Arêtes tactiles : la couleur de l'ombre pleine sous un élément
  /// actionnable.
  static const areteJaune = Color(0xFFD9A400);
  static const areteOrange = Color(0xFFD94E15);
  static const areteNeutre = Color(0xFFD3C5AB);
  static const aretePeche = Color(0xFF802900);
  static const areteDanger = Color(0xFF93000A);
}

/// Espacements. Les noms reprennent l'échelle du web (`space-4` → 4 px) pour
// qu'une valeur se retrouve d'un dépôt à l'autre sans conversion mentale.
abstract final class Espaces {
  static const x2 = 2.0;
  static const x4 = 4.0;
  static const x8 = 8.0;
  static const x12 = 12.0;
  static const x16 = 16.0;
  static const x20 = 20.0;
  static const x24 = 24.0;
  static const x32 = 32.0;
  static const x40 = 40.0;
  static const x48 = 48.0;

  /// Marge latérale d'écran sur mobile.
  static const ecran = 16.0;
}

abstract final class Rayons {
  static const petit = 4.0;
  static const moyen = 8.0;

  /// Rayon **dominant** du design system.
  static const normal = 12.0;

  /// Grandes cartes.
  static const carte = 20.0;

  /// Carte héros.
  static const heros = 24.0;

  /// Feuilles modales.
  static const feuille = 28.0;
}

abstract final class Mesures {
  static const hauteurEnTete = 64.0;
  static const hauteurNav = 80.0;

  /// Hauteur du CTA principal.
  static const hauteurCta = 56.0;

  /// Largeur maximale de la colonne de contenu.
  static const largeurApp = 440.0;

  /// Plancher d'une zone tactile.
  static const zoneTactile = 48.0;
}

/// Ombres.
abstract final class Ombres {
  /// Ombre douce des cartes : la séparation d'avec le fond ne vient pas d'une
  /// bordure.
  static const carte = [
    BoxShadow(
      color: Color(0x0F1A1A1A),
      blurRadius: 20,
      offset: Offset(0, 4),
    ),
  ];

  static const cartePetite = [
    BoxShadow(
      color: Color(0x0A1A1A1A),
      blurRadius: 10,
      offset: Offset(0, 2),
    ),
  ];

  /// Signature tactile : ombre **pleine, sans flou**, sous un élément
  /// actionnable. C'est ce qui donne le relief « bouton qu'on enfonce ».
  static List<BoxShadow> tactile(Color arete) => [
    BoxShadow(color: arete, offset: const Offset(0, 4)),
  ];

  /// La même, à l'appui : l'élément descend de 2 px et l'ombre se réduit
  /// d'autant, donc la hauteur totale ne change pas.
  static List<BoxShadow> tactileEnfoncee(Color arete) => [
    BoxShadow(color: arete, offset: const Offset(0, 2)),
  ];
}

/// Durées et courbes.
// 150 à 300 ms. Au-delà, une transition devient une attente, et l'étudiant
// qui révise à minuit avant un contrôle n'a pas de temps à donner à nos
// jolies choses.
abstract final class Mouvement {
  static const doux = Duration(milliseconds: 220);
  static const courbeDouce = Cubic(0.22, 1, 0.36, 1);

  /// Ressort du web : raideur 420, amortissement 32, masse 0,7.
  static const ressort = SpringDescription(mass: 0.7, stiffness: 420, damping: 32);
}
