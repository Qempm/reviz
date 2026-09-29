import 'package:flutter/material.dart';
import '../theme/jetons.dart';
import 'mascotte.dart';
import '../theme/typographie.dart';

/// État vide : aucune matière, aucune correction, aucun filleul.
///
/// Toujours accompagné d'une porte de sortie — un seul CTA par écran.
///
/// Avec `mascotte`, le panthéreau remplace la pastille d'icône : c'est ce
/// qu'on réserve aux vides **normaux** (pas encore de cours, pas encore de
/// filleul), qui sont une invitation. Une panne garde son icône : le
/// panthéreau qui sourit au-dessus d'un « chargement impossible » sonnerait
/// faux.
class EtatVide extends StatelessWidget {
  const EtatVide({
    super.key,
    required this.titre,
    this.description,
    this.icone = Icons.inbox_outlined,
    this.action,
    this.mascotte,
  });

  final String titre;
  final String? description;
  final IconData icone;
  final Widget? action;
  final EtatMascotte? mascotte;

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
          if (mascotte case final etat?)
            Mascotte(etat: etat, taille: 112)
          else
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
