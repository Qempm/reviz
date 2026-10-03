// Les douze avatars : un animal en peluche 3D, posé sur un fond de couleur.
//
// **Identité du 3 octobre 2026** : les pochoirs 2D, teintés à l'écran, sont
// devenus douze bustes en peluche 3D, de la même famille que le panthéreau —
// générés un par un dans Flow, détourés et centrés par `scripts/avatars.mjs`
// (WebP de 288 px, 15 à 21 ko pièce). Le léopard a remplacé la panthère, qui
// aurait doublé la mascotte.
//
// **Les clés n'ont pas bougé**, comme lors du passage des couleurs aux
// pochoirs : `ton-03` désigne toujours le même animal, aucune ligne de base
// ni route n'est touchée.
//
// Chaque buste se pose dans un disque de la couleur `fond` de sa clé. `encre`
// ne sert plus qu'au repli — l'initiale, pour une image manquante.
//
// Les animaux plutôt que des visages, et c'est un choix : générer douze
// visages « divers » finit en stéréotypes, alors qu'un animal n'a pas ce
// problème, se reconnaît à 36 px dans une ligne de classement, et va avec le
// panthéreau de la mascotte.
//
// Aucune couleur n'est inventée ici : les douze fonds viennent tous de
// `theme/jetons.dart`, sans vert (docs/DESIGN.md § 11).
//
// La même liste de clés existe côté serveur dans `lib/profil/avatars.ts`, où
// elle sert de liste blanche : `avatar_key` est un `text` libre.

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
  /// un lecteur d'écran doit annoncer « avatar léopard », pas « image ».
  final String animal;

  final Color fond;

  /// La couleur de l'initiale, quand l'image manque.
  final Color encre;

  /// Le buste 3D, produit par `scripts/avatars.mjs`.
  String get image => 'assets/avatars/$cle.webp';
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

/// Les douze, dans l'ordre d'affichage — le même que `AVATARS` dans
/// `scripts/avatars.mjs`.
const List<Avatar> avatars = [
  Avatar(
    cle: 'ton-01',
    animal: 'léopard',
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
