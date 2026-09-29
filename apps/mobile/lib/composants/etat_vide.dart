import 'package:flutter/material.dart';
import '../theme/jetons.dart';
import 'mascotte.dart';
import '../theme/typographie.dart';

/// État vide : aucune matière, aucune correction, aucun filleul.
///
/// Toujours accompagné d'une porte de sortie — un seul CTA par écran.
///
/// **Toujours avec le panthéreau**, dans la pose qui dit l'état : `curieux`
/// pour un vide, `oups` pour une panne, `courage` pour un refus. Le
/// propriétaire ne voulait plus d'icône par défaut nulle part ; la règle
/// précédente — « une panne garde son icône » — est levée, et c'est `oups`,
/// qui ne sourit pas, qui porte désormais les pannes. `mascotte` est donc
/// obligatoire : un appel oublié ne compile pas.
class EtatVide extends StatelessWidget {
  const EtatVide({
    super.key,
    required this.titre,
    this.description,
    this.action,
    required this.mascotte,
  });

  final String titre;
  final String? description;
  final Widget? action;
  final EtatMascotte mascotte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaces.x24,
        vertical: Espaces.x32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Mascotte(etat: mascotte, taille: 112),
          const SizedBox(height: Espaces.x16),
          Text(titre, style: Typo.headlineMd, textAlign: TextAlign.center),
          if (description != null) ...[
            const SizedBox(height: Espaces.x4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                description!,
                style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (action != null) ...[const SizedBox(height: Espaces.x16), action!],
        ],
      ),
    );
  }
}
