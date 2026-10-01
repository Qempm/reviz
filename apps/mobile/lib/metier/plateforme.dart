import 'package:flutter/foundation.dart';

/// Ce que l'application montre selon le système, et pourquoi.
///
/// Arbitrage du 1er octobre 2026 pour la version iPhone : les règles de
/// l'App Store ne sont pas celles d'un APK partagé par lien.

/// App Store 3.1.1 : un contenu numérique ne s'achète sur iPhone que par
/// l'achat intégré d'Apple, qui prend sa commission et ne parle pas Mobile
/// Money. Sur iPhone, aucun prix, aucun bouton d'achat, aucun renvoi vers un
/// achat ailleurs : l'étudiant y retrouve l'accès acheté sur Android ou le
/// web, reconnu à la connexion.
bool get achatsDansLApplication => defaultTargetPlatform != TargetPlatform.iOS;

/// App Store 4.8 : proposer Google obligerait à proposer aussi « Se connecter
/// avec Apple ». Sur iPhone, l'e-mail seul (code à 6 chiffres).
bool get connexionGoogleProposee => defaultTargetPlatform != TargetPlatform.iOS;
