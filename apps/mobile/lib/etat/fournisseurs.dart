import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../donnees/api.dart';
import '../donnees/depots.dart';
import '../donnees/modeles.dart';
import '../donnees/reseau.dart';
import '../donnees/supabase.dart';
import '../donnees/version.dart';
import '../donnees/file_hors_ligne.dart';
import '../donnees/push.dart';
import '../donnees/rappels.dart';
import '../donnees/reglages.dart';
import '../metier/acces.dart';
import '../metier/notifications.dart';
import '../metier/plateforme.dart';
import '../metier/selection.dart';
import '../i18n/fr.dart';
import '../metier/rappels.dart';

/// Fournisseurs Riverpod de l'application.
///
/// Peu nombreux et explicites : l'état qui compte vient de Supabase, et
/// `AsyncValue` colle exactement à « en cours / chargé / en erreur » sans
/// qu'on ait à le réécrire à chaque écran.

final apiProvider = Provider<ApiReviz>((_) => ApiReviz());

final depotProfilProvider = Provider((_) => const DepotProfil());
final depotAccueilProvider = Provider((_) => const DepotAccueil());
final depotCoursProvider = Provider((_) => const DepotCours());
final depotFichesProvider = Provider((_) => const DepotFiches());
final depotBoutiqueProvider = Provider((_) => const DepotBoutique());
final depotGainsProvider = Provider((_) => const DepotGains());
final depotClassementProvider = Provider((_) => const DepotClassement());
final depotCorrectionsProvider = Provider((_) => const DepotCorrections());
final depotReseauProvider = Provider((_) => const DepotReseau());
final depotVersionProvider = Provider((_) => DepotVersion());

/// Flux d'authentification de Supabase, tel quel.
///
/// C'est lui qui commande la redirection du routeur : une session qui expire
/// ou une déconnexion doivent ramener à l'écran de connexion sans qu'aucun
/// écran ait à y penser.
final authProvider = StreamProvider<AuthState>((_) {
  return supabase.auth.onAuthStateChange;
});

/// Y a-t-il une session ouverte ? Lu de façon synchrone, pour le routeur.
bool get connecte => supabase.auth.currentSession != null;

/// Le profil de l'utilisateur connecté — `null` si l'inscription n'est pas
/// terminée, ce qui est un état normal entre la connexion et l'inscription.
final profilProvider = FutureProvider<Profil?>((ref) async {
  // Se relit à chaque changement d'authentification.
  ref.watch(authProvider);
  return ref.read(depotProfilProvider).mien();
});

final accueilProvider = FutureProvider<DonneesAccueil?>((ref) async {
  ref.watch(authProvider);
  return ref.read(depotAccueilProvider).charger();
});

final coursProvider = FutureProvider<List<ApercuCours>>((ref) async {
  ref.watch(authProvider);
  return ref.read(depotCoursProvider).liste();
});

final unCoursProvider = FutureProvider.family<ApercuCours?, String>((ref, id) {
  return ref.read(depotCoursProvider).un(id);
});

final chapitresProvider = FutureProvider.family<List<ApercuChapitre>, String>((
  ref,
  coursId,
) {
  return ref.read(depotCoursProvider).chapitres(coursId);
});

/// Le chemin d'un cours, chapitre par chapitre, avec couronnes et verrous.
/// Invalidé à la fin d'une session : c'est là qu'une couronne se gagne.
final cheminProvider = FutureProvider.family<List<ChapitreDuChemin>, String>((
  ref,
  coursId,
) {
  return ref.read(depotCoursProvider).chemin(coursId);
});

/// Les séries finies hors ligne, en attente du réseau. Une seule instance :
/// elle porte le verrou qui empêche deux renvois simultanés.
final fileHorsLigneProvider = Provider((_) => FileHorsLigne());

final serviceRappelsProvider = Provider((_) => ServiceRappels());

/// Reprogramme les rappels du téléphone à partir de l'état du compte :
/// série, examens à venir, fin du pack. Regardé par l'accueil, donc refait à
/// chaque retour sur l'accueil et après chaque série (qui l'invalide).
/// Une donnée qui manque retire un rappel, jamais l'écran.
final rappelsProvider = FutureProvider<void>((ref) async {
  // Avant tout `await` : un changement de réglage reprogramme le téléphone.
  final options = ref.watch(reglagesRappelsProvider);
  try {
    final accueil = await ref.watch(accueilProvider.future);
    if (accueil == null) return;
    final aujourdhui = accueil.semaine.where((j) => j.aujourdhui).firstOrNull;

    final cours = await ref
        .watch(coursProvider.future)
        .catchError((_) => <ApercuCours>[]);
    final examens = <ExamenAVenir>[
      for (final c in cours)
        if (DateTime.tryParse(c.dateExamen ?? '') case final jour?)
          (coursId: c.id, titre: c.titre ?? 'Ton examen', jour: jour),
    ];

    DateTime? finPack;
    try {
      final acces = await ref.watch(accesCorrectionProvider.future);
      if (acces is AccesActif) finPack = acces.fin;
    } catch (_) {}

    await ref
        .read(serviceRappelsProvider)
        .programmer(
          planifierRappels(
            maintenant: DateTime.now(),
            serie: accueil.profil.serieCourante,
            journeeFaite: aujourdhui?.valide ?? false,
            examens: examens,
            finPack: finPack,
            titreSerie: Fr.rappels.serieTitre,
            texteSerie: Fr.rappels.serieTexte,
            titreExamen: Fr.rappels.examenTitre,
            texteExamen: Fr.rappels.examenTexte,
            titrePack: Fr.rappels.packTitre,
            // Sur l'application iPhone, rien ne pousse à racheter.
            textePack: achatsDansLApplication
                ? Fr.rappels.packTexte
                : Fr.rappels.packTexteSansAchat,
            options: options,
          ),
        );
  } catch (_) {}
});

/// Ce qui définit une session : le cours, éventuellement un chapitre, et le
/// mode (tout, ou seulement les erreurs).
typedef CleSession = ({String cours, String? chapitre, ModeSession mode});

/// `autoDispose` : chaque ouverture d'une session tire de nouvelles
/// questions. Gardé en cache, « Nouvelle session » rouvrait les mêmes.
final questionsProvider = FutureProvider.autoDispose
    .family<List<QuestionQcm>, CleSession>((ref, cle) {
      return ref
          .read(depotCoursProvider)
          .questionsDeSession(
            cle.cours,
            chapitreId: cle.chapitre,
            mode: cle.mode,
          );
    });

final fichesProvider = FutureProvider.family<List<Fiche>, String>((
  ref,
  coursId,
) {
  return ref.read(depotFichesProvider).duCours(coursId);
});

final boutiqueProvider = FutureProvider<DonneesBoutique>((ref) async {
  ref.watch(authProvider);
  return ref.read(depotBoutiqueProvider).charger();
});

final gainsProvider = FutureProvider<DonneesGains>((ref) async {
  ref.watch(authProvider);
  return ref.read(depotGainsProvider).charger();
});

/// La ligue de la semaine. Invalidé en fin de session, avec le profil.
final ligueProvider = FutureProvider<DonneesLigue>((ref) {
  return ref.read(depotClassementProvider).maLigue();
});

final classementProvider = FutureProvider<DonneesClassement>((ref) async {
  ref.watch(authProvider);
  return ref.read(depotClassementProvider).charger();
});

/// L'historique des corrections.
final correctionsProvider = FutureProvider<List<Correction>>((ref) async {
  ref.watch(authProvider);
  return ref.read(depotCorrectionsProvider).mes();
});

/// Une correction, relue par la route — qui relance le traitement au besoin.
final correctionProvider = FutureProvider.family<Correction, String>((
  ref,
  id,
) async {
  final reponse = await ref
      .read(depotCorrectionsProvider)
      .une(ref.read(apiProvider), id);

  return switch (reponse) {
    ReponseSucces(:final data) => data,
    ReponseEchec(:final erreur) => throw Exception(erreur),
  };
});

/// L'accès aux corrections : combien il en reste, et ce qui bloque.
///
/// Réutilise les données de la boutique : ce sont les mêmes abonnements, et
/// les recharger deux fois ferait deux allers-retours pour rien.
final accesCorrectionProvider = FutureProvider<EtatAcces>((ref) async {
  final boutique = await ref.watch(boutiqueProvider.future);
  return boutique.acces;
});

/// L'état de la version installée.
///
/// Lu une fois à l'ouverture, et relisible à la demande depuis l'écran
/// bloquant — c'est le seul moyen d'en sortir quand un entretien se termine,
/// sans redémarrer l'application.
final miseAJourProvider = FutureProvider<EtatMiseAJour>((ref) {
  return ref.read(depotVersionProvider).etat();
});

/// Y a-t-il du réseau ? Vrai par défaut : un bandeau « hors ligne » affiché à
/// tort serait pire que pas de bandeau du tout.
final reseauProvider = StreamProvider<bool>((ref) async* {
  final depot = ref.read(depotReseauProvider);
  yield await depot.maintenant();
  yield* depot.flux();
});

/// Les matières de la faculté de l'étudiant, pour le dépôt d'un cours.
final matieresProvider = FutureProvider<List<Matiere>>((ref) async {
  final profil = await ref.watch(profilProvider.future);
  final faculte = profil?.faculteId;
  if (faculte == null) return const [];
  return ref.read(depotCoursProvider).matieres(faculte);
});

/// Les universités, pour l'inscription. Lues une fois.
final universitesProvider = FutureProvider<List<Universite>>((ref) {
  return ref.read(depotProfilProvider).universites();
});

final facultesProvider = FutureProvider.family<List<Faculte>, String>((
  ref,
  universiteId,
) {
  return ref.read(depotProfilProvider).facultes(universiteId);
});

// --------------------------------------------------------- Notifications

final depotNotificationsProvider = Provider((_) => const DepotNotifications());

/// Les 50 dernières notifications. Relues au retour au premier plan, à la
/// réception d'un push, et en tirant la liste vers le bas.
final notificationsProvider = FutureProvider<List<NotificationReviz>>((
  ref,
) async {
  ref.watch(authProvider);
  if (supabase.auth.currentUser == null) return const [];
  return ref.read(depotNotificationsProvider).liste();
});

/// Le nombre de non lues, pour la pastille de la cloche. Zéro tant que la
/// liste n'est pas lue : une pastille ne doit jamais mentir vers le haut.
final nonLuesProvider = Provider<int>((ref) {
  final liste = ref.watch(notificationsProvider).value ?? const [];
  return liste.where((n) => !n.lue).length;
});

final prefsPushProvider = FutureProvider<PrefsPush>((ref) async {
  ref.watch(authProvider);
  return ref.read(depotNotificationsProvider).prefs();
});

final servicePushProvider = Provider(
  (ref) => ServicePush(
    depot: ref.read(depotNotificationsProvider),
    api: ref.read(apiProvider),
    rappels: ref.read(serviceRappelsProvider),
  ),
);

/// Le push est-il possible ici (Firebase configuré, pas le web) ? Les
/// réglages n'affichent ses catégories que si oui.
final pushDisponibleProvider = FutureProvider<bool>(
  (ref) => ref.read(servicePushProvider).disponible(),
);
