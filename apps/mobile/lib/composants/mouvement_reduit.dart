import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../donnees/reglages.dart';

/// Fait entendre le réglage « Réduire les animations » du profil à tous les
/// composants, comme s'il venait du téléphone.
///
/// Posé une fois, à la racine de l'application. Chaque composant animé lit
/// `MediaQuery.disableAnimationsOf(context)` et rien d'autre : sans ce relais,
/// il aurait fallu que chacun lise aussi le fournisseur du réglage — et le
/// premier oubli (les confettis de fin de session l'ignoraient) aurait
/// suffi à trahir un étudiant que le mouvement gêne.
class MouvementReduit extends ConsumerWidget {
  const MouvementReduit({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reglage = ref.watch(animationsReduitesProvider);
    final media = MediaQuery.of(context);

    if (!reglage || media.disableAnimations) return child;

    return MediaQuery(
      data: media.copyWith(disableAnimations: true),
      child: child,
    );
  }
}
