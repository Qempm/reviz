import 'package:flutter/material.dart';
import '../donnees/modeles.dart';
import '../i18n/fr.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// L'XP des sept derniers jours, en barres qui montent.
///
/// Un jour validé est jaune plein, un jour commencé mais pas validé jaune
/// pâle, un jour vide un simple trait. Aujourd'hui a son initiale en orange,
/// comme sur la carte de série.
class GraphiqueSemaine extends StatelessWidget {
  const GraphiqueSemaine({super.key, required this.jours});

  final List<JourSerie> jours;

  static const _hauteur = 96.0;
  static const _lettres = 'LMMJVSD';

  @override
  Widget build(BuildContext context) {
    final max = jours.fold<int>(0, (m, j) => j.xp > m ? j.xp : m);
    final animer = !MediaQuery.disableAnimationsOf(context);
    final total = jours.fold<int>(0, (s, j) => s + j.xp);

    return Semantics(
      label: Fr.profil.xpSemaine(total),
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final j in jours)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    j.xp == 0 ? '' : '${j.xp}',
                    style: Typo.caption.copyWith(
                      color: Couleurs.attenue,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: Espaces.x2),
                  SizedBox(
                    height: _hauteur,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: max == 0 ? 0 : j.xp / max),
                        duration: animer ? Mouvement.ample * 2 : Duration.zero,
                        curve: Mouvement.courbeDouce,
                        builder: (_, v, _) => Container(
                          width: 22,
                          // Un trait de 4 px même à zéro : le jour existe.
                          height: 4 + (_hauteur - 4) * v,
                          decoration: BoxDecoration(
                            color: j.valide
                                ? Couleurs.jaune
                                : j.xp > 0
                                ? Couleurs.jauneDoux
                                : Couleurs.surfaceHaute,
                            borderRadius: BorderRadius.circular(Rayons.petit),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Espaces.x4),
                  Text(
                    _lettres[(j.jourSemaine - 1).clamp(0, 6)],
                    style: Typo.caption.copyWith(
                      color: j.aujourdhui ? Couleurs.orange : Couleurs.attenue,
                      fontWeight: j.aujourdhui ? FontWeight.w800 : null,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
