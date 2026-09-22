import 'package:flutter/material.dart';
import '../theme/jetons.dart';

/// Carte blanche du design system.
///
/// Sans bordure : la séparation d'avec le fond vient de l'ombre douce.
/// `petite` sert aux encarts internes — rayon 12 px et 12 px de gouttière,
/// contre 20 et 20.
class Carte extends StatelessWidget {
  const Carte({super.key, required this.enfants, this.petite = false});

  final List<Widget> enfants;
  final bool petite;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(petite ? Espaces.x12 : Espaces.x20),
      decoration: BoxDecoration(
        color: Couleurs.carte,
        borderRadius: BorderRadius.circular(
          petite ? Rayons.normal : Rayons.carte,
        ),
        boxShadow: petite ? Ombres.cartePetite : Ombres.carte,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < enfants.length; i++) ...[
            if (i > 0) SizedBox(height: petite ? Espaces.x8 : Espaces.x16),
            enfants[i],
          ],
        ],
      ),
    );
  }
}
