import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

// Jetons du design system Reviz — troisième version, 3 octobre 2026.
//
// L'identité vient de la charte de marque (tableau Miro « Reviz — brand
// guide v1.0 ») et des maquettes validées par le propriétaire le 3 octobre
// (`docs/DESIGN.md` § 11 ter, qui prime sur les sections précédentes) :
//
//  * un **fond crème** `#FCEFD0`, chaud, sur lequel les cartes blanches se
//    posent — il remplace le gris clair « façon Apple » du 29 septembre ;
//  * le **jaune** `#FFC400` de la marque, l'**encre** `#101818` (un noir
//    légèrement bleuté, celui du pelage du panthéreau), l'**orange flamme**
//    `#F4793B` pour l'urgence ;
//  * des coins plus ronds (20 px dominant, 24 px cartes) et des ombres
//    teintées d'encre plutôt que de noir pur ;
//  * et toujours **aucun vert** : une bonne réponse se fête en jaune.
//
// Les noms des jetons n'ont pas changé : plus de deux cents usages dans
// trente fichiers basculent d'un coup, sans qu'on les touche.

abstract final class Couleurs {
  /// Fond de l'application : le crème de la charte. Les cartes blanches s'en
  /// détachent sans bordure.
  static const fond = Color(0xFFFCEFD0);

  /// Cartes.
  static const carte = Color(0xFFFFFFFF);

  /// Jaune de marque : CTA, progression, podium n° 1, série, pilule de
  /// navigation. Le seul aplat franc de l'interface.
  static const jaune = Color(0xFFFFC400);

  /// Sélection de QCM, bonne réponse.
  static const jauneDoux = Color(0xFFFFEDB0);

  /// Texte sur un fond jaune : l'encre.
  static const surJaune = Color(0xFF101818);

  /// Urgence, compte à rebours : l'orange flamme de la charte. Comme fond ou
  /// comme icône ; un **texte** orange prend [orangeProfond], plus lisible.
  static const orange = Color(0xFFF4793B);

  /// Podium n° 3, fond d'urgence.
  static const orangeDoux = Color(0xFFFDE3D3);

  /// Podium n° 2, badges.
  static const bleu = Color(0xFFBCCDEB);
  static const bleuDoux = Color(0xFFE3ECFF);

  /// Texte principal : l'encre de la charte.
  static const encre = Color(0xFF101818);

  /// Texte secondaire : un gris tiré vers l'encre, 7,4:1 sur le crème.
  static const attenue = Color(0xFF4A4F4C);

  /// Mauvaise réponse, erreur. Contraste AA sur le blanc (4,9:1).
  static const danger = Color(0xFFD92D20);
  static const dangerDoux = Color(0xFFFEE4E2);
  static const surDangerDoux = Color(0xFFB42318);

  /// Séparateurs et contours de champs : un sable, pas un gris froid, pour
  /// rester dans la famille du crème.
  static const bordure = Color(0xFFE5D3A6);

  /// Texte d'emphase secondaire — liens, valeurs mises en avant.
  static const texteAccent = Color(0xFF263030);

  /// Surfaces intermédiaires, toutes tirées du crème : le remplissage d'un
  /// champ, la piste d'une jauge, la surface la plus marquée.
  static const surfaceBasse = Color(0xFFFFF8E8);
  static const surfaceConteneur = Color(0xFFF7E7C0);
  static const surfaceHaute = Color(0xFFEADBB4);

  /// Teintes profondes. Les avatars s'en servent comme fonds et encres ;
  /// [orangeProfond] est aussi l'orange des petits textes d'urgence.
  static const jauneProfond = Color(0xFFD9A400);
  static const orangeProfond = Color(0xFFC9531F);
  static const pecheProfond = Color(0xFF802900);

  /// Les six divisions des ligues, de Bronze à Diamant — le blason de
  /// l'écran Ligue et de la carte d'accueil. Toujours aucun vert ; le rubis
  /// tire sur le rose pour ne pas se lire comme une erreur.
  static const divisions = [
    Color(0xFFB0703C), // Bronze
    Color(0xFF8E8E96), // Argent
    Color(0xFFFFC400), // Or
    Color(0xFF4F7BD9), // Saphir
    Color(0xFFE0457B), // Rubis
    Color(0xFF6FA8EE), // Diamant
  ];
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

/// Rayons, servis en **coins continus** (`formeContinue`) par les
/// composants : la courbe accélère doucement au lieu de partir d'un quart de
/// cercle posé sur une droite. C'est la différence qu'on sent sans savoir la
/// nommer entre une icône iOS et un rectangle arrondi quelconque.
abstract final class Rayons {
  static const petit = 8.0;
  static const moyen = 14.0;

  /// Rayon **dominant** : boutons, champs, options de QCM.
  static const normal = 20.0;

  /// Cartes.
  static const carte = 24.0;

  /// Carte héros.
  static const heros = 28.0;

  /// Feuilles modales.
  static const feuille = 32.0;
}

abstract final class Mesures {
  static const hauteurEnTete = 64.0;
  static const hauteurNav = 80.0;

  /// Hauteur du CTA principal.
  static const hauteurCta = 54.0;

  /// Largeur maximale de la colonne de contenu.
  static const largeurApp = 440.0;

  /// Plancher d'une zone tactile.
  static const zoneTactile = 48.0;
}

/// Ombres : **toujours en deux couches**, teintées de l'encre `#101818`.
///
/// Une ombre unique paraît posée ; deux — une courte et nette au contact, une
/// longue et diffuse autour — donnent l'impression d'un objet qui flotte
/// légèrement au-dessus du fond. La charte fixe l'encre à 10 % au plus :
/// c'est la somme des couches qui atteint ce plafond, pas chacune.
abstract final class Ombres {
  static const carte = [
    BoxShadow(color: Color(0x0A101818), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x14101818), blurRadius: 24, offset: Offset(0, 10)),
  ];

  static const cartePetite = [
    BoxShadow(color: Color(0x0A101818), blurRadius: 1, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0F101818), blurRadius: 12, offset: Offset(0, 4)),
  ];

  /// Ce qui flotte au-dessus du contenu : barre de navigation, feuilles.
  static const flottante = [
    BoxShadow(color: Color(0x0A101818), blurRadius: 1, offset: Offset(0, 0)),
    BoxShadow(color: Color(0x1A101818), blurRadius: 30, offset: Offset(0, -2)),
  ];

  /// Le halo d'un bouton jaune : une ombre **teintée** plutôt que grise.
  /// Une ombre grise sous du jaune le salit ; une ombre jaune le fait briller.
  ///
  /// L'étalement **négatif** de la couche diffuse est ce qui compte : sans
  /// lui, le halo débordait sous le bouton comme une bande pâle, et on
  /// retrouvait l'arête qu'on venait de supprimer. Resserré, il reste une
  /// lueur sous l'objet.
  static const lueurJaune = [
    BoxShadow(color: Color(0x33D9A400), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(
      color: Color(0x59FFB800),
      blurRadius: 20,
      spreadRadius: -6,
      offset: Offset(0, 10),
    ),
  ];

  /// La même, bouton enfoncé : le halo se resserre, l'objet se rapproche du
  /// fond.
  static const lueurJauneEnfoncee = [
    BoxShadow(color: Color(0x33D9A400), blurRadius: 1, offset: Offset(0, 1)),
    BoxShadow(
      color: Color(0x40FFB800),
      blurRadius: 10,
      spreadRadius: -4,
      offset: Offset(0, 4),
    ),
  ];
}

/// Une forme à coins continus, pour `ShapeDecoration` et les découpes.
RoundedSuperellipseBorder formeContinue(double rayon, {BorderSide? bord}) =>
    RoundedSuperellipseBorder(
      borderRadius: BorderRadius.all(Radius.circular(rayon)),
      side: bord ?? BorderSide.none,
    );

/// Durées et courbes.
// 150 à 300 ms. Au-delà, une transition devient une attente, et l'étudiant
// qui révise à minuit avant un contrôle n'a pas de temps à donner à nos
// jolies choses.
abstract final class Mouvement {
  /// Le retour immédiat d'un appui : assez bref pour ne jamais retarder le
  /// geste, assez long pour être vu.
  static const appui = Duration(milliseconds: 120);

  static const doux = Duration(milliseconds: 220);

  /// Entrées d'écran, révélations.
  static const ample = Duration(milliseconds: 360);

  /// Décalage entre deux éléments d'une liste qui entrent l'un après l'autre.
  static const cascade = Duration(milliseconds: 45);

  static const courbeDouce = Cubic(0.22, 1, 0.36, 1);

  /// Ressort du web : raideur 420, amortissement 32, masse 0,7.
  static const ressort = SpringDescription(mass: 0.7, stiffness: 420, damping: 32);

  /// Ressort « vif » : amortissement réduit d'un quart sous le critique
  /// (ζ ≈ 0,75), donc un **léger dépassement** avant de se poser. C'est ce
  /// qui fait qu'un objet semble avoir une masse plutôt que glisser sur un
  /// rail — la différence entre une interface qui répond et une qui s'anime.
  static const ressortVif = SpringDescription(
    mass: 1,
    stiffness: 380,
    damping: 29,
  );

  /// Durée de la glisse de la pilule de navigation. Le ressort vif est posé
  /// à ~1 % en 0,3 s ; 380 ms lui laissent le temps de finir sans traîner.
  static const glisse = Duration(milliseconds: 380);

  /// La courbe de la glisse, tirée du ressort vif.
  static const courbeGlisse = CourbeRessort(ressortVif, glisse);
}

/// Une courbe tirée d'un ressort physique.
///
/// Les animations implicites de Flutter (`AnimatedPositioned`,
/// `AnimatedAlign`…) veulent une `Curve`, pas une simulation. Celle-ci rejoue
/// une `SpringSimulation` sur la durée de l'animation : on garde la commodité
/// des widgets implicites, et on gagne le dépassement et le retour d'un vrai
/// ressort — ce qu'aucune `Cubic` ne sait faire, puisqu'elle ne dépasse
/// jamais sa cible deux fois.
class CourbeRessort extends Curve {
  const CourbeRessort(this.ressort, this.duree);

  final SpringDescription ressort;

  /// La durée de l'animation qui utilisera la courbe : c'est elle qui relie
  /// le temps normalisé `t` au temps physique de la simulation.
  final Duration duree;

  /// Une simulation n'atteint jamais tout à fait 1 ; `Curve.transform`
  /// renvoie déjà 0 et 1 exacts aux bornes, donc la pilule se pose au pixel
  /// près sans rien ajouter ici.
  @override
  double transformInternal(double t) {
    final secondes = duree.inMicroseconds / Duration.microsecondsPerSecond;
    return SpringSimulation(ressort, 0, 1, 0).x(t * secondes);
  }
}
