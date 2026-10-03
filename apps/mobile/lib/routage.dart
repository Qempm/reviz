import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;
import 'package:go_router/go_router.dart';
import 'composants/bouton.dart';
import 'composants/coquille.dart';
import 'composants/etat_vide.dart';
import 'composants/mascotte.dart';
import 'donnees/supabase.dart';
import 'ecrans/accueil.dart';
import 'ecrans/ajouter_cours.dart';
import 'ecrans/aide.dart';
import 'ecrans/avatar.dart';
import 'ecrans/carte.dart';
import 'donnees/modeles.dart';
import 'ecrans/boutique.dart';
import 'ecrans/paiement.dart';
import 'ecrans/payer.dart';
import 'ecrans/classement.dart';
import 'ecrans/connexion.dart';
import 'ecrans/correction.dart';
import 'ecrans/corriger.dart';
import 'ecrans/cours.dart';
import 'ecrans/fiches.dart';
import 'ecrans/ligue.dart';
import 'ecrans/matiere.dart';
import 'ecrans/notifications.dart';
import 'ecrans/notifications_reglages.dart';
import 'ecrans/gains.dart';
import 'ecrans/galerie.dart';
import 'ecrans/inscription.dart';
import 'ecrans/profil.dart';
import 'ecrans/reviser.dart';
import 'ecrans/suppression.dart';
import 'ecrans/session.dart';
import 'metier/selection.dart';
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
  static const ajouterCours = '/reviser/ajouter';
  static const galerie = '/galerie';
  static const boutique = '/boutique';
  static const gains = '/gains';
  static const classement = '/classement';
  static const ligue = '/ligue';
  static const notifications = '/notifications';
  static const reglagesNotifications = '/profil/notifications';
  static const profil = '/profil';
  static const suppression = '/profil/supprimer-compte';
  static const avatar = '/profil/avatar';
  static const aide = '/profil/aide';
  static const carte = '/profil/carte-etudiante';

  static const corriger = '/corriger';

  static String cours(String id) => '/cours/$id';

  /// Une matière : sa maîtrise, ses chapitres à retravailler, ses cours.
  static String matiere(String id) => '/matiere/$id';

  /// Une session du cours, d'un chapitre, ou de ses seules erreurs.
  static String session(String id, {String? chapitre, bool erreurs = false}) {
    final params = {'chapitre': ?chapitre, if (erreurs) 'mode': 'erreurs'};
    return Uri(
      path: '/cours/$id/session',
      queryParameters: params.isEmpty ? null : params,
    ).toString();
  }

  static String fiches(String id) => '/cours/$id/fiches';
  static String correction(String id) => '/corrections/$id';
  static String paiement(String id) => '/boutique/paiement/$id';
  static const payer = '/boutique/payer';
}

/// Les deux gestes de navigation de l'application.
///
/// Avant, il n'y avait que `context.go` — une quarantaine d'appels. `go`
/// **remplace** la pile par la destination : on n'y empilait donc jamais
/// rien, et le bouton retour d'Android, ne trouvant aucune page sous la
/// courante, sortait de l'application depuis n'importe quel écran.
///
/// Deux verbes, parce qu'il y a deux intentions, et qu'un nom qui les dit
/// évite de reconfondre les deux :
extension NavigationReviz on BuildContext {
  /// Aller plus loin : de la liste au détail, du profil à l'avatar, du cours
  /// à la session. La page d'où l'on vient reste dessous, et le retour y
  /// ramène.
  ///
  /// `extra` passe à l'écran ce qui ne va pas dans l'adresse — le lien de la
  /// page de paiement, par exemple, qui porte un jeton.
  void descendre(String chemin, {Object? extra}) => push(chemin, extra: extra);

  /// Revenir d'où l'on vient. S'il n'y a rien dessous — l'écran a été ouvert
  /// par un lien direct —, on va au `repli`, qui est le parent logique : le
  /// retour ne doit jamais faire sortir de l'application depuis le fond.
  void remonter(String repli) => canPop() ? pop() : go(repli);
}

/// Chemins accessibles sans session.
const _publics = {Chemins.connexion, Chemins.galerie};

/// Le routeur, construit avec accès aux fournisseurs.
///
/// La garde d'accès est ici et non dans chaque écran : elle a besoin de deux
/// choses — une session, **et** un profil. Un compte sans profil doit finir
/// son inscription avant de voir quoi que ce soit, exactement comme côté web.
GoRouter creerRouteur(Ref ref) {
  // Le navigateur qui porte tout, onglets compris. Une route qui le désigne
  // comme parent se pose **par-dessus** la barre du bas au lieu de s'ouvrir
  // dans l'onglet.
  final racine = GlobalKey<NavigatorState>(debugLabel: 'racine');

  return GoRouter(
    navigatorKey: racine,
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
      // --- Hors des onglets : pas de barre du bas -------------------------
      GoRoute(
        path: Chemins.connexion,
        builder: (_, _) => const EcranConnexion(),
      ),
      GoRoute(
        path: Chemins.inscription,
        builder: (_, _) => const EcranInscription(),
      ),
      GoRoute(path: Chemins.galerie, builder: (_, _) => const Galerie()),

      // Ouverte depuis trois endroits (profil, dépôt de cours, correction) :
      // elle se pose par-dessus les onglets, et le retour ramène là d'où
      // l'on venait — plus au profil, codé en dur, quel que soit le départ.
      GoRoute(
        path: Chemins.boutique,
        parentNavigatorKey: racine,
        builder: (_, _) => const EcranBoutique(),
        routes: [
          // Payer un pack : le pack arrive par `extra`, depuis la boutique.
          // Ouvert autrement (lien direct), il n'y a rien à payer : retour
          // à la boutique.
          GoRoute(
            path: 'payer',
            parentNavigatorKey: racine,
            redirect: (_, etat) =>
                etat.extra is PackBoutique ? null : Chemins.boutique,
            builder: (_, etat) => EcranPayer(pack: etat.extra! as PackBoutique),
          ),
          // Le suivi d'un paiement, au-dessus de l'écran de paiement : le
          // retour y ramène, numéro et opérateur gardés.
          GoRoute(
            path: 'paiement/:id',
            parentNavigatorKey: racine,
            builder: (_, etat) =>
                EcranPaiement(paiementId: etat.pathParameters['id']!),
          ),
        ],
      ),

      // --- Les cinq onglets ------------------------------------------------
      //
      // `StatefulShellRoute.indexedStack` : un navigateur par onglet, gardés
      // en vie côte à côte. Changer d'onglet ne détruit ni la barre du bas
      // ni la page qu'on quitte — on retrouve sa liste à l'endroit où on
      // l'avait laissée. L'ordre des branches est celui de `onglets` dans
      // `composants/coquille.dart`.
      StatefulShellRoute.indexedStack(
        builder: (_, _, coquille) => CoquilleOnglets(coquille: coquille),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Chemins.accueil,
                builder: (_, _) => const EcranAccueil(),
              ),
              GoRoute(
                path: Chemins.ligue,
                builder: (_, _) => const EcranLigue(),
              ),
              GoRoute(
                path: '/matiere/:id',
                builder: (_, etat) =>
                    EcranMatiere(matiereId: etat.pathParameters['id'] ?? ''),
              ),
              GoRoute(
                path: Chemins.notifications,
                builder: (_, _) => const EcranNotifications(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Chemins.reviser,
                builder: (_, _) => const EcranReviser(),
                routes: [
                  // Un formulaire de dépôt se remplit en plein écran : la
                  // barre du bas y serait une porte de sortie au milieu d'un
                  // envoi.
                  GoRoute(
                    path: 'ajouter',
                    parentNavigatorKey: racine,
                    builder: (_, _) => const EcranAjouterCours(),
                  ),
                ],
              ),
              GoRoute(
                path: '/cours/:id',
                builder: (_, etat) =>
                    EcranCours(coursId: etat.pathParameters['id'] ?? ''),
                routes: [
                  // Une session de QCM et les fiches prennent tout l'écran :
                  // une question à la fois, sans rien autour.
                  GoRoute(
                    path: 'session',
                    parentNavigatorKey: racine,
                    builder: (_, etat) => EcranSession(
                      coursId: etat.pathParameters['id'] ?? '',
                      chapitreId: etat.uri.queryParameters['chapitre'],
                      mode: etat.uri.queryParameters['mode'] == 'erreurs'
                          ? ModeSession.erreurs
                          : ModeSession.normal,
                    ),
                  ),
                  GoRoute(
                    path: 'fiches',
                    parentNavigatorKey: racine,
                    builder: (_, etat) =>
                        EcranFiches(coursId: etat.pathParameters['id'] ?? ''),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Chemins.corriger,
                builder: (_, _) => const EcranCorriger(),
              ),
              GoRoute(
                path: '/corrections/:id',
                builder: (_, etat) => EcranCorrection(
                  correctionId: etat.pathParameters['id'] ?? '',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Chemins.gains,
                builder: (_, _) => const EcranGains(),
              ),
              GoRoute(
                path: Chemins.classement,
                builder: (_, _) => const EcranClassement(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Chemins.profil,
                builder: (_, _) => const EcranProfil(),
                routes: [
                  GoRoute(path: 'aide', builder: (_, _) => const EcranAide()),
                  GoRoute(
                    path: 'notifications',
                    builder: (_, _) => const EcranReglagesNotifications(),
                  ),
                  GoRoute(
                    path: 'avatar',
                    builder: (_, _) => const EcranAvatar(),
                  ),
                  // La photo de carte et la suppression de compte sont des
                  // parcours où l'on ne doit pas se retrouver ailleurs par
                  // un effleurement : plein écran.
                  GoRoute(
                    path: 'carte-etudiante',
                    parentNavigatorKey: racine,
                    builder: (_, _) => const EcranCarte(),
                  ),
                  GoRoute(
                    path: 'supprimer-compte',
                    parentNavigatorKey: racine,
                    builder: (_, _) => const EcranSuppression(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, etat) => Scaffold(
      backgroundColor: Couleurs.fond,
      body: SafeArea(
        child: EtatVide(
          mascotte: EtatMascotte.curieux,
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
