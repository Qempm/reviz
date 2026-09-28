// Connexion Google, dans l'application.
//
// C'était la demande initiale — « que l'authentification ne me fasse pas
// sortir de l'application ». `signInWithIdToken` la satisfait sans navigateur :
// Google rend un jeton d'identité, Supabase l'échange contre une session, et
// l'étudiant ne quitte jamais l'écran. Le détour `reviz://auth` par onglet
// personnalisé, qui existait du temps du web, n'a plus lieu d'être.
//
// La règle est dans `metier/google.dart`, testée sans appareil ; ici,
// seulement l'aller-retour.

library;

import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../metier/google.dart';
import 'config.dart';
import 'supabase.dart';

/// Ce que rend une tentative.
sealed class ResultatGoogle {
  const ResultatGoogle();
}

/// La session est installée. Rien à faire : le routeur écoute
/// `onAuthStateChange` et redirige de lui-même.
class GoogleConnecte extends ResultatGoogle {
  const GoogleConnecte();
}

/// L'étudiant a refermé la feuille de choix de compte. **Pas un échec**, et
/// l'écran ne doit donc rien afficher.
class GoogleAnnule extends ResultatGoogle {
  const GoogleAnnule();
}

class GoogleEchec extends ResultatGoogle {
  const GoogleEchec(this.motif, {this.detail});

  final MotifEchecGoogle motif;

  /// Ce que le greffon ou Supabase a dit, pour les journaux. **Jamais affiché
  /// tel quel** : « DEVELOPER_ERROR » ne veut rien dire pour un étudiant.
  final String? detail;
}

class ConnexionGoogle {
  const ConnexionGoogle();

  /// Ouvre la feuille Google, puis échange le jeton contre une session.
  Future<ResultatGoogle> connecter() async {
    final clientWeb = Config.googleWebClientId;

    // Sans identifiant, `initialize` échouerait plus loin avec un message
    // technique : autant refuser ici, là où on sait pourquoi.
    if (clientWeb.isEmpty) {
      return const GoogleEchec(
        MotifEchecGoogle.configuration,
        detail: 'GOOGLE_WEB_CLIENT_ID absent du build.',
      );
    }

    final brut = nonceAleatoire();

    try {
      // `initialize` est rappelé à **chaque** tentative, pour que le nonce
      // change : c'est le seul moyen de lier le jeton à cette tentative-ci,
      // et le greffon ne propose pas de le passer à `authenticate`.
      //
      // Vérifié plutôt que supposé : `google_sign_in_android` 7.2.17
      // n'implémente pas `authenticationEvents`, la valeur par défaut de
      // l'interface est donc `null` et `initialize` ne s'abonne à aucun flux.
      // Le rappeler ne fuit rien.
      await GoogleSignIn.instance.initialize(
        serverClientId: clientWeb,
        // L'empreinte pour Google, le brut pour Supabase. Voir
        // `metier/google.dart` : inverser les deux donne un refus muet.
        nonce: empreinteNonce(brut),
      );

      final compte = await GoogleSignIn.instance.authenticate();
      final idToken = compte.authentication.idToken;

      if (idToken == null) {
        // Sur Android, le jeton d'identité n'arrive que si le
        // `serverClientId` désigne un vrai client **web**. Un client Android
        // mis là par erreur donne exactement ce cas.
        return const GoogleEchec(
          MotifEchecGoogle.configuration,
          detail: 'Google n’a pas rendu de jeton d’identité.',
        );
      }

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        nonce: brut,
      );

      return const GoogleConnecte();
    } on GoogleSignInException catch (e) {
      final motif = motifEchecGoogle(e.code);
      return motifSilencieux(motif)
          ? const GoogleAnnule()
          : GoogleEchec(motif, detail: e.description);
    } on AuthException catch (e) {
      // Le jeton est bon mais Supabase le refuse : fournisseur Google
      // désactivé côté projet, ou audience qui ne correspond pas à
      // l'identifiant client web déclaré là-bas.
      return GoogleEchec(
        MotifEchecGoogle.refuseParSupabase,
        detail: e.message,
      );
    } catch (e) {
      return GoogleEchec(MotifEchecGoogle.inconnu, detail: e.toString());
    }
  }

  /// Oublie le compte Google choisi, à la déconnexion de Reviz.
  ///
  /// Sans cela, « me déconnecter » puis « continuer avec Google » reconnecte
  /// **le même compte** instantanément, sans laisser le choix. Sur un
  /// téléphone partagé — courant dans le public visé — c'est la personne
  /// suivante qui se retrouve dans le compte de la précédente.
  ///
  /// Silencieux par construction : une déconnexion ne doit jamais échouer à
  /// cause de Google. `signOut()` lève d'ailleurs si `initialize` n'a jamais
  /// été appelé, ce qui est le cas de tous ceux qui se connectent par e-mail.
  Future<void> oublier() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Rien à dire : il n'y avait pas de compte Google à oublier.
    }
  }
}
