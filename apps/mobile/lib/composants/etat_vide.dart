import 'package:flutter/material.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// État vide : aucune matière, aucune correction, aucun filleul.
///
/// Toujours accompagné d'une porte de sortie — un seul CTA par écran.
class EtatVide extends StatelessWidget {
  const EtatVide({
    super.key,
    required this.titre,
    this.description,
    this.icone = Icons.inbox_outlined,
    this.action,
  });

  final String titre;
  final String? description;
  final IconData icone;
  final Widget? action;

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
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Couleurs.surfaceConteneur,
              shape: BoxShape.circle,
            ),
            child: Icon(icone, size: 32, color: Couleurs.attenue),
          ),
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
          if (action != null) ...[
            const SizedBox(height: Espaces.x16),
            action!,
          ],
        ],
      ),
    );
  }
}
