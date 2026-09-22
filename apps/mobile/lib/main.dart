import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'donnees/config.dart';
import 'donnees/supabase.dart';
import 'i18n/fr.dart';
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
      builder: (context, enfant) {
        if (Config.estConfiguree) return enfant!;
        return _Avertissement(enfant: enfant!);
      },
    );
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
