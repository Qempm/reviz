// Les douze avatars : un animal, un fond, une encre.
//
// **Les images sont arrivées**, et les clés n'ont pas bougé — c'est ce que
// promettait le commentaire précédent, qui disait « le jour où les PNG
// arrivent, `ton-03` désigne un fichier au lieu d'une couleur, sans migration
// ni écran à réécrire ». Aucune ligne de base n'a été touchée.
//
// Ce que porte chaque fichier est un **pochoir** : une silhouette opaque sur
// du transparent, les yeux évidés. Aucune couleur dedans. Le fond et l'encre
// restent ici, et l'écran teinte la forme à l'affichage (`BlendMode.srcIn`).
// Trois raisons :
//
//  * aucune couleur n'est dupliquée entre Dart et des pixels, donc aucune ne
//    peut diverger ;
//  * un fond sombre reçoit la même forme en crème, sans second jeu d'images ;
//  * les douze fichiers pèsent 74 ko en tout, ce qui compte pour un APK déjà
//    lourd et un public au forfait data limité.
//
// Les animaux plutôt que des visages, et c'est un choix : générer douze
// visages « divers » finit en stéréotypes, alors qu'une silhouette d'animal
// n'a pas ce problème, se reconnaît à 40 px dans une ligne de classement, et
// va avec le panthéreau de la mascotte.
//
// L'initiale reste le repli, pour une clé inconnue ou une image manquante.
//
// Aucune couleur n'est inventée ici : les douze combinaisons viennent toutes
// de `theme/jetons.dart`, et la palette reste strictement chaude, sans vert
// (docs/DESIGN.md § 11).
//
// La même liste de clés existe côté serveur dans `lib/profil/avatars.ts`, où
// elle sert de liste blanche : `avatar_key` est un `text` libre, et la route
// acceptait auparavant n'importe quelle chaîne de cent caractères. Les
// couleurs, elles, ne concernent que l'écran.

library;

import 'package:flutter/painting.dart' show Color;
import '../theme/jetons.dart';

/// Un avatar : une clé stable, un animal, un fond, une encre.
class Avatar {
  const Avatar({
    required this.cle,
    required this.animal,
    required this.fond,
    required this.encre,
  });

  final String cle;

  /// Le nom de l'animal, en français.
  ///
  /// Sert d'étiquette d'accessibilité et de libellé dans l'écran de choix :
  /// un lecteur d'écran doit annoncer « avatar panthère », pas « image ».
  final String animal;

  final Color fond;
  final Color encre;

  /// Le pochoir, produit par `scripts/avatars.mjs`.
  String get pochoir => 'assets/avatars/$cle.png';
}

/// Celui qu'on montre à qui n'a rien choisi.
///
/// Et non un rond gris : un compte neuf a déjà une tête, ce qui rend le
/// classement lisible avant le premier passage par l'écran des avatars.
///
/// Extrait en constante nommée plutôt qu'écrit `avatars[1]` : indexer une
/// liste n'est pas une expression constante en Dart — même contrainte que
/// `paysParDefaut` dans `metier/telephone.dart`.
const Avatar avatarParDefaut = Avatar(
  cle: 'ton-02',
  animal: 'éléphant',
  fond: Couleurs.jauneDoux,
  encre: Couleurs.texteAccent,
);

/// Les douze, dans l'ordre d'affichage — le même que la grille découpée par
/// `scripts/avatars.mjs`.
const List<Avatar> avatars = [
  // `encre` et non `surJaune` : `#785A00` sur le jaune convenait à une
  // lettre, pas à une silhouette pleine, qui ressortait terne. L'aperçu du
  // script l'a montré.
  Avatar(
    cle: 'ton-01',
    animal: 'panthère',
    fond: Couleurs.jaune,
    encre: Couleurs.encre,
  ),
  avatarParDefaut,
  Avatar(
    cle: 'ton-03',
    animal: 'perroquet',
    fond: Couleurs.orange,
    encre: Couleurs.carte,
  ),
  Avatar(
    cle: 'ton-04',
    animal: 'tortue',
    fond: Couleurs.orangeDoux,
    encre: Couleurs.pecheProfond,
  ),
  Avatar(
    cle: 'ton-05',
    animal: 'singe',
    fond: Couleurs.bleu,
    encre: Couleurs.encre,
  ),
  Avatar(
    cle: 'ton-06',
    animal: 'gazelle',
    fond: Couleurs.bleuDoux,
    encre: Couleurs.texteAccent,
  ),
  Avatar(
    cle: 'ton-07',
    animal: 'coq',
    fond: Couleurs.jauneProfond,
    encre: Couleurs.carte,
  ),
  Avatar(
    cle: 'ton-08',
    animal: 'poisson',
    fond: Couleurs.orangeProfond,
    encre: Couleurs.carte,
  ),
  Avatar(
    cle: 'ton-09',
    animal: 'lion',
    fond: Couleurs.dangerDoux,
    encre: Couleurs.surDangerDoux,
  ),
  Avatar(
    cle: 'ton-10',
    animal: 'escargot',
    fond: Couleurs.bordure,
    encre: Couleurs.encre,
  ),
  Avatar(
    cle: 'ton-11',
    animal: 'papillon',
    fond: Couleurs.surfaceHaute,
    encre: Couleurs.attenue,
  ),
  Avatar(
    cle: 'ton-12',
    animal: 'hibou',
    fond: Couleurs.texteAccent,
    encre: Couleurs.carte,
  ),
];

/// L'avatar d'une clé, ou celui par défaut.
///
/// Tolérant par nécessité : la colonne est un `text` libre, et des comptes
/// créés avant la liste blanche peuvent porter n'importe quoi — dont les clés
/// descriptives de l'ancien écran web, du genre
/// `avatar-1-garcon-sourire`. Une clé inconnue ne doit pas casser un
/// classement, elle doit retomber sur une tête.
Avatar avatarDe(String? cle) {
  if (cle == null) return avatarParDefaut;

  for (final a in avatars) {
    if (a.cle == cle) return a;
  }

  return avatarParDefaut;
}

/// L'initiale à dessiner.
///
/// Par rune et non par `substring(0, 1)` : un prénom commençant par un
/// caractère hors du plan de base se couperait en deux moitiés de paire.
String initialeDe(String? prenom) {
  final p = (prenom ?? '').trim();
  if (p.isEmpty) return '?';
  return String.fromCharCode(p.runes.first).toUpperCase();
}
