import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

// Jetons du design system Reviz — deuxième version, 29 septembre 2026.
//
// La première version, figée depuis les maquettes Stitch, donnait à
// l'application un air de **vieux papier** : fond blanc cassé chaud, texte
// secondaire brun, arêtes pleines sous chaque bouton. Le propriétaire l'a
// jugée amateur, et il a tranché (voir `docs/DESIGN.md` § 11, arbitrage du
// 29 septembre) :
//
//  * des **neutres clairs, façon Apple** — fond gris très clair, cartes
//    blanches pures, texte presque noir, secondaire gris moyen. On reprend la
//    géométrie et le rendu, pas la texture ;
//  * **fin de l'arête tactile** — du relief doux, des ombres en couches, et un
//    bouton qui se contracte sous le doigt ;
//  * le **jaune reste la marque**, l'orange l'urgence, le rouge l'erreur ;
//  * et toujours **aucun vert** : une bonne réponse se fête en jaune.
//
// Les noms des jetons n'ont presque pas changé, et c'est voulu : plus de deux
// cents usages dans trente fichiers basculent d'un coup, sans qu'on les
// touche. Seuls ont été renommés ceux dont le nom aurait menti — `cream`
// n'est plus crème — ou qui disparaissent avec l'arête tactile.

abstract final class Couleurs {
  /// Fond de l'application. Le gris très clair des listes groupées d'iOS : les
  /// cartes blanches s'en détachent sans bordure.
  static const fond = Color(0xFFF5F5F7);

  /// Cartes.
  static const carte = Color(0xFFFFFFFF);

  /// Jaune de marque : CTA, progression, podium n° 1, série, pilule de
  /// navigation. Le seul aplat franc de l'interface.
  static const jaune = Color(0xFFFFC300);

  /// Sélection de QCM, bonne réponse. Plus clair et plus net que l'ancien
  /// `#FFDF9A`, qui tirait vers le beige.
  static const jauneDoux = Color(0xFFFFEDB0);

  /// Texte sur un fond jaune : **noir**, et non plus brun. Un brun sur jaune
  /// était le premier signe de l'effet « vieux papier ».
  static const surJaune = Color(0xFF1D1D1F);

  /// Urgence, compte à rebours.
  static const orange = Color(0xFFFE6A2B);

  /// Podium n° 3, fond d'urgence.
  static const orangeDoux = Color(0xFFFFE2D5);

  /// Podium n° 2, badges.
  static const bleu = Color(0xFFBCCDEB);
  static const bleuDoux = Color(0xFFE3ECFF);

  /// Texte principal.
  static const encre = Color(0xFF1D1D1F);

  /// Texte secondaire : un gris **neutre**. L'ancienne règle « jamais de gris
  /// froid » est levée par l'arbitrage du 29 septembre — c'était elle qui
  /// imposait le brun.
  static const attenue = Color(0xFF6E6E73);

  /// Mauvaise réponse, erreur. Plus vif que l'ancien `#BA1A1A`, sans tomber
  /// sous le contraste AA sur du blanc (4,9:1).
  static const danger = Color(0xFFD92D20);
  static const dangerDoux = Color(0xFFFEE4E2);
  static const surDangerDoux = Color(0xFFB42318);

  /// Séparateurs et contours de champs.
  static const bordure = Color(0xFFD1D1D6);

  /// Texte d'emphase secondaire — liens, valeurs mises en avant. L'ancien
  /// `#785A00` était un brun : c'est ce jeton qui colorait « Tout voir ».
  static const texteAccent = Color(0xFF2C2C2E);

  /// Surfaces intermédiaires : le fond groupé, le remplissage d'un champ ou
  /// d'une piste de progression, la surface la plus marquée.
  static const surfaceBasse = Color(0xFFF2F2F7);
  static const surfaceConteneur = Color(0xFFEBEBF0);
  static const surfaceHaute = Color(0xFFE5E5EA);

  /// Teintes profondes, anciennement les « arêtes tactiles ». L'arête a
  /// disparu, mais ces trois couleurs restent : les avatars s'en servent
  /// comme fonds et encres.
  static const jauneProfond = Color(0xFFD9A400);
  static const orangeProfond = Color(0xFFD94E15);
  static const pecheProfond = Color(0xFF802900);
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
  static const petit = 6.0;
  static const moyen = 10.0;

  /// Rayon **dominant** : boutons, champs, options de QCM.
  static const normal = 14.0;

  /// Cartes.
  static const carte = 22.0;

  /// Carte héros.
  static const heros = 28.0;

  /// Feuilles modales.
  static const feuille = 28.0;
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

/// Ombres : **toujours en deux couches**.
///
/// Une ombre unique paraît posée ; deux — une courte et nette au contact, une
/// longue et diffuse autour — donnent l'impression d'un objet qui flotte
/// légèrement au-dessus du fond. Les opacités sont basses exprès : c'est la
/// somme qui se voit, pas chaque couche.
abstract final class Ombres {
  static const carte = [
    BoxShadow(color: Color(0x08000000), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0D000000), blurRadius: 24, offset: Offset(0, 8)),
  ];

  static const cartePetite = [
    BoxShadow(color: Color(0x08000000), blurRadius: 1, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  /// Ce qui flotte au-dessus du contenu : barre de navigation, feuilles.
  static const flottante = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 1, offset: Offset(0, 0)),
    BoxShadow(color: Color(0x14000000), blurRadius: 30, offset: Offset(0, -2)),
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
