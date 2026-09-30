import 'package:flutter/material.dart';
import '../i18n/fr.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Le blason d'une division : un écu teinté, et son rang en étoiles.
class BlasonLigue extends StatelessWidget {
  const BlasonLigue({super.key, required this.division, this.taille = 48});

  final int division;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final couleur = Couleurs
        .divisions[(division - 1).clamp(0, Couleurs.divisions.length - 1)];
    return Semantics(
      label: Fr.ligue.nom(division),
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: taille,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.shield_rounded, size: taille, color: couleur),
            Padding(
              padding: EdgeInsets.only(bottom: taille * 0.06),
              child: Text(
                '$division',
                style: Typo.headlineMd.copyWith(
                  // Noir sur l'or, comme tout texte posé sur le jaune.
                  color: division == 3 ? Couleurs.surJaune : Couleurs.carte,
                  fontSize: taille * 0.36,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
