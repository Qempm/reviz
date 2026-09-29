import 'package:flutter/material.dart';

/// Un nombre qui **défile** jusqu'à sa valeur au lieu d'y sauter.
///
/// Au premier affichage, il est posé tel quel — sauf `depuisZero`, pour un
/// score qu'on découvre. Ensuite, chaque changement défile de l'ancienne
/// valeur à la nouvelle : l'XP gagnée après une session se voit monter dans
/// le badge, au lieu d'être déjà là quand on revient à l'accueil.
///
/// C'est `construire` qui met en forme (« 1 280 XP », « 7 / 10 ») : ce
/// composant ne connaît que l'entier. En mouvement réduit, la valeur finale
/// est posée d'emblée.
class ChiffreAnime extends StatelessWidget {
  const ChiffreAnime({
    super.key,
    required this.valeur,
    required this.construire,
    this.depuisZero = false,
    this.duree = const Duration(milliseconds: 900),
  });

  final int valeur;
  final Widget Function(int valeur) construire;
  final bool depuisZero;
  final Duration duree;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return construire(valeur);

    return TweenAnimationBuilder<double>(
      tween: Tween(
        begin: depuisZero ? 0 : valeur.toDouble(),
        end: valeur.toDouble(),
      ),
      duration: duree,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => construire(v.round()),
    );
  }
}
