import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'composants/bandeau.dart';
import 'donnees/config.dart';
import 'donnees/supabase.dart';
import 'ecrans/mise_a_jour.dart';
import 'etat/fournisseurs.dart';
import 'i18n/fr.dart';
import 'metier/version.dart';
import 'routage.dart';
import 'theme/jetons.dart';
import 'theme/typographie.dart';
import 'theme/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // La galerie doit s'ouvrir même sans configuration : elle sert à valider le
  // rendu, pas à parler à la base. Sans cette porte, un développeur qui
  // oublie ses `--dart-define` voit un écran noir sans savoir pourquoi.
  if (Config.estConfiguree) {
    await initSupabase();
  }

  runApp(const ProviderScope(child: AppReviz()));
}

class AppReviz extends ConsumerWidget {
  const AppReviz({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Reviz',
      theme: themeReviz,
      routerConfig: ref.watch(routeurProvider),
      debugShowCheckedModeBanner: false,
      // Les états transversaux se montent **ici**, au-dessus du routeur,
      // plutôt qu'écran par écran : c'est le seul endroit qui les voit tous.
      // Côté web, les quatre composants prévus pour ce rôle existaient et
      // n'étaient montés nulle part.
      builder: (context, enfant) => _Transversal(enfant: enfant!),
    );
  }
}

/// Ce qui se superpose à tous les écrans : configuration absente, version
/// périmée, réseau coupé.
class _Transversal extends ConsumerWidget {
  const _Transversal({required this.enfant});

  final Widget enfant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Config.estConfiguree) return _Avertissement(enfant: enfant);

    final miseAJour = ref.watch(miseAJourProvider);

    // Version trop ancienne, ou entretien annoncé : on remplace tout. C'est le
    // seul cas où l'on ferme la porte — une mise à jour simplement conseillée
    // passe par un bandeau.
    if (miseAJour case AsyncData(:final value) when value.bloquant) {
      return EcranMiseAJour(etat: value);
    }

    final horsLigne = ref.watch(reseauProvider).value == false;

    final conseillee = switch (miseAJour) {
      AsyncData(:final value) =>
        value.exigence == ExigenceVersion.conseillee ? value : null,
      _ => null,
    };

    return Stack(
      children: [
        enfant,
        if (horsLigne)
          const Positioned(left: 0, right: 0, top: 0, child: BandeauHorsLigne())
        else if (conseillee != null)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: BandeauVersion(
              onTelecharger: () => _ouvrir(context, conseillee.distante?.lien),
            ),
          ),
      ],
    );
  }

  /// Un lien absent ou illisible ne doit pas lever : le bandeau est une
  /// commodité, pas un passage obligé.
  static Future<void> _ouvrir(BuildContext context, String? lien) async {
    if (lien == null || lien.isEmpty) return;
    try {
      await launchUrl(Uri.parse(lien), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

/// Bandeau discret quand la configuration manque, plutôt qu'un écran d'erreur
/// qui empêcherait de regarder la galerie.
class _Avertissement extends StatelessWidget {
  const _Avertissement({required this.enfant});

  final Widget enfant;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        enfant,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            child: Container(
              color: Couleurs.dangerDoux,
              padding: const EdgeInsets.symmetric(
                horizontal: Espaces.x16,
                vertical: Espaces.x8,
              ),
              child: Text(
                Fr.erreurs.configurationManquante(Config.manquantes),
                style: Typo.labelSm.copyWith(color: Couleurs.surDangerDoux),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
