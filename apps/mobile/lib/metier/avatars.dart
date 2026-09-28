// Les douze avatars, et leurs couleurs.
//
// CLAUDE.md prévoit 24 PNG dans `public/avatars/`. Ils n'existent pas, et le
// dossier non plus : l'écran web construisait `/avatars/${avatar_key}.png` et
// récoltait des 404, tandis que son sélecteur affichait en réalité
// `avatar.substring(7, 9)` — deux lettres découpées dans la clé, avec un
// commentaire « Placeholder avatar » assumé.
//
// **On n'attend pas les images.** Un avatar est une initiale sur un fond tiré
// de la palette du design system : aucun asset, et quelque chose à choisir dès
// maintenant. Les clés sont stables — le jour où les PNG arrivent, `ton-03`
// désigne un fichier au lieu d'une couleur, sans migration ni écran à
// réécrire.
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

/// Un avatar : une clé stable, un fond, une encre.
class Avatar {
  const Avatar({required this.cle, required this.fond, required this.encre});

  final String cle;
  final Color fond;
  final Color encre;
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
  fond: Couleurs.jauneDoux,
  encre: Couleurs.texteAccent,
);

/// Les douze, dans l'ordre d'affichage.
const List<Avatar> avatars = [
  Avatar(cle: 'ton-01', fond: Couleurs.jaune, encre: Couleurs.surJaune),
  avatarParDefaut,
  Avatar(cle: 'ton-03', fond: Couleurs.orange, encre: Couleurs.carte),
  Avatar(cle: 'ton-04', fond: Couleurs.orangeDoux, encre: Couleurs.aretePeche),
  Avatar(cle: 'ton-05', fond: Couleurs.bleu, encre: Couleurs.encre),
  Avatar(cle: 'ton-06', fond: Couleurs.bleuDoux, encre: Couleurs.texteAccent),
  Avatar(cle: 'ton-07', fond: Couleurs.areteJaune, encre: Couleurs.carte),
  Avatar(cle: 'ton-08', fond: Couleurs.areteOrange, encre: Couleurs.carte),
  Avatar(cle: 'ton-09', fond: Couleurs.dangerDoux, encre: Couleurs.surDangerDoux),
  Avatar(cle: 'ton-10', fond: Couleurs.bordure, encre: Couleurs.encre),
  Avatar(cle: 'ton-11', fond: Couleurs.surfaceHaute, encre: Couleurs.attenue),
  Avatar(cle: 'ton-12', fond: Couleurs.texteAccent, encre: Couleurs.carte),
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
