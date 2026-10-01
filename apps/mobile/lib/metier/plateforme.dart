import 'package:flutter/foundation.dart';

/// Ce que l'application montre selon l'endroit où elle tourne, et pourquoi.
///
/// Trois cas : l'APK Android, l'application iPhone de l'App Store
/// (arbitrage du 1er octobre 2026) et la version web servie sur `/web`
/// (même jour). Sur le web, `defaultTargetPlatform` vaut `iOS` dans le
/// Safari d'un iPhone : il faut donc tester `kIsWeb` **d'abord**, sans quoi un
/// étudiant sur iPhone perdrait dans son navigateur ce que seule l'App Store
/// interdit.

/// L'application iPhone de l'App Store, et elle seule.
bool get applicationIphone =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// App Store 3.1.1 : un contenu numérique ne s'achète dans l'application
/// iPhone que par l'achat intégré d'Apple, qui prend sa commission et ne
/// parle pas Mobile Money. Là, aucun prix, aucun bouton d'achat, aucun renvoi
/// vers un achat ailleurs : l'étudiant y retrouve l'accès acheté sur Android
/// ou le web, reconnu à la connexion. **Le web n'est pas concerné** : c'est
/// même là qu'un étudiant sur iPhone achète.
bool get achatsDansLApplication => !applicationIphone;

/// Google, seulement dans l'APK.
///
/// iPhone (App Store 4.8) : Google obligerait à proposer aussi « Se connecter
/// avec Apple ». Web : `google_sign_in` n'y ouvre pas la même fenêtre
/// (il exige le bouton dessiné par Google) ; l'e-mail y suffit.
bool get connexionGoogleProposee =>
    !kIsWeb && defaultTargetPlatform != TargetPlatform.iOS;

/// Les rappels du soir sont des notifications locales du téléphone : rien de
/// tel dans un navigateur.
bool get rappelsDisponibles => !kIsWeb;

/// Une mise à jour à télécharger n'existe que pour une application
/// installée : le web est toujours à la dernière version.
bool get versionAInstaller => !kIsWeb;

/// Le push (Firebase) : Android et l'application iPhone. Pas le web dans
/// cette version — le centre de notifications y suffit.
bool get pushDisponible => !kIsWeb;
