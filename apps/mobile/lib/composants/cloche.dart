import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../routage.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// La cloche de l'en-tête, avec la pastille des non lues.
///
/// Dans l'en-tête de chaque onglet (`coquille.dart`) : un cours prêt ou une
/// commission reçue se voit d'où qu'on soit. Une zone tactile de 48 px,
/// comme tout le reste ; la pastille en orange, la couleur de ce qui attend
/// l'étudiant — et seulement quand il y a quelque chose.
class Cloche extends ConsumerWidget {
  const Cloche({super.key, this.nonLues});

  /// Forcé dans les tests et les aperçus ; sinon lu dans le centre.
  final int? nonLues;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int n = nonLues ?? ref.watch<int>(nonLuesProvider);

    return Semantics(
      button: true,
      label: n > 0
          ? '${Fr.notifications.titre}, ${Fr.notifications.nonLues(n)}'
          : Fr.notifications.ouvrirCentre,
      child: SizedBox(
        width: 44,
        height: 48,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.descendre(Chemins.notifications),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Icon(
                  n > 0
                      ? Icons.notifications_rounded
                      : Icons.notifications_none_rounded,
                  size: 26,
                  color: Couleurs.encre,
                ),
                if (n > 0)
                  Positioned(
                    top: 8,
                    right: 4,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: Couleurs.orangeProfond,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: Couleurs.fond, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        n > 9 ? '9+' : '$n',
                        style: Typo.labelSm.merge(Typo.chiffres).copyWith(
                          color: Colors.white,
                          fontSize: 10,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
