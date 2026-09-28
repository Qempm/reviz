import 'package:flutter/material.dart';
import '../i18n/fr.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Bandeaux d'information, posés au-dessus de tous les écrans.
///
/// Un **bandeau** et non une page : les QCM déjà chargés restent jouables
/// hors ligne, et couper l'écran serait pire que le manque de réseau. C'est
/// exactement ce que l'`OfflineWarning` du web aurait dû faire — il existait,
/// mais n'était monté nulle part.

/// Un bandeau plat, en haut, sous la barre d'état.
class Bandeau extends StatelessWidget {
  const Bandeau({
    super.key,
    required this.icone,
    required this.texte,
    required this.fond,
    required this.teinte,
    this.detail,
    this.action,
    this.onAction,
  });

  final IconData icone;
  final String texte;
  final String? detail;
  final Color fond;
  final Color teinte;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fond,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Espaces.x16,
            vertical: Espaces.x8,
          ),
          child: Row(
            children: [
              Icon(icone, size: 20, color: teinte),
              const SizedBox(width: Espaces.x8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      texte,
                      style: Typo.labelMd.copyWith(color: teinte),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (detail != null)
                      Text(
                        detail!,
                        style: Typo.labelSm.copyWith(color: teinte),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: Espaces.x8),
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: teinte,
                    minimumSize: const Size(0, Mesures.zoneTactile),
                    padding: const EdgeInsets.symmetric(
                      horizontal: Espaces.x8,
                    ),
                  ),
                  child: Text(action!, style: Typo.labelMd),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// « Pas de connexion ».
class BandeauHorsLigne extends StatelessWidget {
  const BandeauHorsLigne({super.key});

  @override
  Widget build(BuildContext context) {
    return Bandeau(
      icone: Icons.wifi_off,
      texte: Fr.miseAJour.horsLigne,
      detail: Fr.miseAJour.horsLigneDetail,
      // Orange et non rouge : c'est une gêne, pas une panne. Le rouge est
      // réservé à ce qui a échoué.
      fond: Couleurs.orangeDoux,
      teinte: Couleurs.aretePeche,
    );
  }
}

/// « Une nouvelle version est là » — proposé, jamais imposé.
class BandeauVersion extends StatelessWidget {
  const BandeauVersion({super.key, required this.onTelecharger, this.onFermer});

  final VoidCallback onTelecharger;
  final VoidCallback? onFermer;

  @override
  Widget build(BuildContext context) {
    return Bandeau(
      icone: Icons.system_update,
      texte: Fr.miseAJour.conseillee,
      fond: Couleurs.jauneDoux,
      teinte: Couleurs.surJaune,
      action: Fr.miseAJour.telecharger,
      onAction: onTelecharger,
    );
  }
}
