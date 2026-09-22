import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../donnees/api.dart';
import '../donnees/depots.dart';
import '../donnees/modeles.dart';
import '../donnees/supabase.dart';

/// Fournisseurs Riverpod de l'application.
///
/// Peu nombreux et explicites : l'état qui compte vient de Supabase, et
/// `AsyncValue` colle exactement à « en cours / chargé / en erreur » sans
/// qu'on ait à le réécrire à chaque écran.

final apiProvider = Provider<ApiReviz>((_) => ApiReviz());

final depotProfilProvider = Provider((_) => const DepotProfil());
final depotAccueilProvider = Provider((_) => const DepotAccueil());
final depotCoursProvider = Provider((_) => const DepotCours());

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
