import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../donnees/api.dart';
import '../donnees/depots.dart';
import '../donnees/modeles.dart';
import '../donnees/supabase.dart';
import '../metier/acces.dart';

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

final questionsProvider = FutureProvider.family<List<QuestionQcm>, String>((
  ref,
  coursId,
) {
  return ref.read(depotCoursProvider).questionsDeSession(coursId);
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
