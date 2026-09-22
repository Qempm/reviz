import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'ecrans/galerie.dart';

/// Routage de l'application.
///
/// Les chemins reprennent **exactement** ceux du web (`docs/API.md` § 5) :
/// un lien partagé par WhatsApp doit pouvoir ouvrir l'application aussi bien
/// que le site, et l'équivalence de nommage rend la cartographie du rapport
/// lisible des deux côtés.
///
/// Seule la galerie existe pour l'instant : les écrans arrivent à la phase 4,
/// après validation du rendu à 375 px.
final routeur = GoRouter(
  initialLocation: Chemins.galerie,
  routes: [
    GoRoute(
      path: Chemins.galerie,
      builder: (_, _) => const Galerie(),
    ),
  ],
  errorBuilder: (_, etat) => Scaffold(
    body: Center(child: Text('Écran introuvable : ${etat.uri}')),
  ),
);

/// Les chemins, nommés une seule fois.
abstract final class Chemins {
  static const galerie = '/galerie';

  // À venir en phase 4, dans cet ordre de valeur.
  static const connexion = '/connexion';
  static const inscription = '/inscription';
  static const accueil = '/';
  static const reviser = '/reviser';
  static const ajouterCours = '/reviser/ajouter';
  static const boutique = '/boutique';
  static const corriger = '/corriger';
  static const gains = '/gains';
  static const classement = '/classement';
  static const profil = '/profil';

  static String cours(String id) => '/cours/$id';
  static String session(String id) => '/cours/$id/session';
  static String fiches(String id) => '/cours/$id/fiches';
  static String chapitre(String id) => '/chapitre/$id';
}
