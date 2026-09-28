import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;
import 'package:go_router/go_router.dart';
import 'composants/bouton.dart';
import 'composants/etat_vide.dart';
import 'donnees/supabase.dart';
import 'ecrans/accueil.dart';
import 'ecrans/boutique.dart';
import 'ecrans/classement.dart';
import 'ecrans/connexion.dart';
import 'ecrans/correction.dart';
import 'ecrans/corriger.dart';
import 'ecrans/cours.dart';
import 'ecrans/fiches.dart';
import 'ecrans/gains.dart';
import 'ecrans/galerie.dart';
import 'ecrans/inscription.dart';
import 'ecrans/profil.dart';
import 'ecrans/reviser.dart';
import 'ecrans/suppression.dart';
import 'ecrans/session.dart';
import 'etat/fournisseurs.dart';
import 'i18n/fr.dart';
import 'theme/jetons.dart';

/// Les chemins, nommés une seule fois.
///
/// Ils reprennent **exactement** ceux du web (docs/API.md § 5) : un lien
/// partagé par WhatsApp doit pouvoir ouvrir l'application aussi bien que le
/// site, et l'équivalence rend la cartographie du rapport lisible des deux
/// côtés.
abstract final class Chemins {
  static const connexion = '/connexion';
  static const inscription = '/inscription';
  static const accueil = '/';
  static const reviser = '/reviser';
  static const galerie = '/galerie';
  static const boutique = '/boutique';
  static const gains = '/gains';
  static const classement = '/classement';
  static const profil = '/profil';
  static const suppression = '/profil/supprimer-compte';

  static const corriger = '/corriger';

  static String cours(String id) => '/cours/$id';
  static String session(String id) => '/cours/$id/session';
  static String fiches(String id) => '/cours/$id/fiches';
  static String chapitre(String id) => '/chapitre/$id';
  static String correction(String id) => '/corrections/$id';
}

/// Chemins accessibles sans session.
const _publics = {Chemins.connexion, Chemins.galerie};

/// Le routeur, construit avec accès aux fournisseurs.
///
/// La garde d'accès est ici et non dans chaque écran : elle a besoin de deux
/// choses — une session, **et** un profil. Un compte sans profil doit finir
/// son inscription avant de voir quoi que ce soit, exactement comme côté web.
GoRouter creerRouteur(Ref ref) {
  return GoRouter(
    initialLocation: Chemins.accueil,
    refreshListenable: _EcouteAuth(ref),
    redirect: (context, etat) {
      final chemin = etat.matchedLocation;
      if (_publics.contains(chemin)) {
        // Déjà connecté : la page de connexion n'a plus de sens.
        return connecte && chemin == Chemins.connexion ? Chemins.accueil : null;
      }

      if (!connecte) return Chemins.connexion;

      // Le profil est lu de façon asynchrone : tant qu'il n'est pas connu, on
      // laisse passer et l'écran affiche son attente. Une redirection prise
      // sur une valeur inconnue ferait clignoter l'inscription.
      final profil = ref.read(profilProvider);
      final manque = profil.hasValue && profil.value == null;

      if (manque && chemin != Chemins.inscription) return Chemins.inscription;
      if (!manque && chemin == Chemins.inscription) return Chemins.accueil;

      return null;
    },
    routes: [
      GoRoute(path: Chemins.connexion, builder: (_, _) => const EcranConnexion()),
      GoRoute(
        path: Chemins.inscription,
        builder: (_, _) => const EcranInscription(),
      ),
      GoRoute(path: Chemins.accueil, builder: (_, _) => const EcranAccueil()),
      GoRoute(path: Chemins.reviser, builder: (_, _) => const EcranReviser()),
      GoRoute(path: Chemins.galerie, builder: (_, _) => const Galerie()),
      GoRoute(
        path: '/cours/:id',
        builder: (_, etat) =>
            EcranCours(coursId: etat.pathParameters['id'] ?? ''),
        routes: [
          GoRoute(
            path: 'session',
            builder: (_, etat) =>
                EcranSession(coursId: etat.pathParameters['id'] ?? ''),
          ),
          GoRoute(
            path: 'fiches',
            builder: (_, etat) =>
                EcranFiches(coursId: etat.pathParameters['id'] ?? ''),
          ),
        ],
      ),

      GoRoute(path: Chemins.boutique, builder: (_, _) => const EcranBoutique()),
      GoRoute(path: Chemins.gains, builder: (_, _) => const EcranGains()),
      GoRoute(
        path: Chemins.classement,
        builder: (_, _) => const EcranClassement(),
      ),
      GoRoute(
        path: Chemins.profil,
        builder: (_, _) => const EcranProfil(),
        routes: [
          GoRoute(
            path: 'supprimer-compte',
            builder: (_, _) => const EcranSuppression(),
          ),
        ],
      ),

      GoRoute(path: Chemins.corriger, builder: (_, _) => const EcranCorriger()),
      GoRoute(
        path: '/corrections/:id',
        builder: (_, etat) =>
            EcranCorrection(correctionId: etat.pathParameters['id'] ?? ''),
      ),
    ],
    errorBuilder: (context, etat) => Scaffold(
      backgroundColor: Couleurs.cream,
      body: SafeArea(
        child: EtatVide(
          icone: Icons.explore_off,
          titre: 'Écran introuvable',
          description: '${etat.uri}',
          action: Bouton(
            libelle: Fr.commun.retour,
            icone: Icons.arrow_back,
            onTap: () => context.go(Chemins.accueil),
          ),
        ),
      ),
    ),
  );
}

/// Fait réévaluer la redirection quand l'authentification change.
///
/// `GoRouter` ne connaît pas Riverpod : ce pont minimal évite d'avoir à
/// dupliquer la logique de redirection dans chaque écran.
class _EcouteAuth extends ChangeNotifier {
  _EcouteAuth(Ref ref) {
    _abonnement = supabase.auth.onAuthStateChange.listen((_) {
      // Le profil dépend de la session : il doit être relu avant que la
      // redirection ne le consulte.
      ref.invalidate(profilProvider);
      notifyListeners();
    });

    // Un profil qui vient d'être créé change aussi la destination.
    ref.listen(profilProvider, (_, _) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _abonnement;

  @override
  void dispose() {
    _abonnement.cancel();
    super.dispose();
  }
}

/// Le routeur, exposé aux widgets.
final routeurProvider = Provider<GoRouter>((ref) => creerRouteur(ref));
