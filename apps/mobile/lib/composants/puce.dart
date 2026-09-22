import 'package:flutter/material.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

enum TonPuce { neutre, jaune, orange, bleu, danger }

/// Pilule d'information. Toujours complètement arrondie.
class Puce extends StatelessWidget {
  const Puce({super.key, required this.libelle, this.ton = TonPuce.neutre, this.icone});

  final String libelle;
  final TonPuce ton;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    final (fond, texte) = switch (ton) {
      TonPuce.neutre => (Couleurs.surfaceConteneur, Couleurs.attenue),
      TonPuce.jaune => (Couleurs.jaune, Couleurs.surJaune),
      TonPuce.orange => (Couleurs.orangeDoux, Couleurs.aretePeche),
      TonPuce.bleu => (Couleurs.bleu, Couleurs.encre),
      TonPuce.danger => (Couleurs.dangerDoux, Couleurs.surDangerDoux),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaces.x8,
        vertical: Espaces.x4,
      ),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 14, color: texte),
            const SizedBox(width: Espaces.x4),
          ],
          // Flexible : une pilule posée à côté d'un texte extensible doit
          // céder du terrain plutôt que de pousser la ligne au débordement.
          Flexible(
            child: Text(
              libelle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Typo.caption.copyWith(color: texte),
            ),
          ),
        ],
      ),
    );
  }
}
