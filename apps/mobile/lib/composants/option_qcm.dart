import 'package:flutter/material.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// États d'une option de QCM.
///
/// Deux points où le rendu Stitch prime sur la prose de CLAUDE.md : **pas de
/// bordure de 2 px** — la distinction vient du fond et de l'arête tactile — et
/// **pas de vert de succès** : la bonne réponse se célèbre en jaune, la
/// mauvaise en rouge d'erreur.
enum EtatOption { repos, choisie, juste, fausse }

/// Option de QCM, une par ligne et pleine largeur.
class OptionQcm extends StatelessWidget {
  const OptionQcm({
    super.key,
    required this.lettre,
    required this.libelle,
    this.etat = EtatOption.repos,
    this.onTap,
  });

  /// Lettre affichée dans la pastille : A, B, C, D.
  final String lettre;
  final String libelle;
  final EtatOption etat;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (fond, arete, pastille, surPastille, texte) = switch (etat) {
      EtatOption.repos => (
        Couleurs.carte,
        null,
        Couleurs.surfaceConteneur,
        Couleurs.attenue,
        Couleurs.encre,
      ),
      EtatOption.choisie => (
        Couleurs.jauneDoux,
        Couleurs.areteJaune,
        Couleurs.jaune,
        Couleurs.surJaune,
        Couleurs.encre,
      ),
      EtatOption.juste => (
        Couleurs.jauneDoux,
        Couleurs.areteJaune,
        Couleurs.jaune,
        Couleurs.surJaune,
        Couleurs.encre,
      ),
      EtatOption.fausse => (
        Couleurs.dangerDoux,
        Couleurs.areteDanger,
        Couleurs.danger,
        Colors.white,
        Couleurs.surDangerDoux,
      ),
    };

    final icone = switch (etat) {
      EtatOption.juste => Icons.check,
      EtatOption.fausse => Icons.close,
      _ => null,
    };

    return Semantics(
      button: onTap != null,
      selected: etat == EtatOption.choisie,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: Mesures.zoneTactile),
          padding: const EdgeInsets.all(Espaces.x16),
          decoration: BoxDecoration(
            color: fond,
            borderRadius: BorderRadius.circular(Rayons.normal),
            boxShadow: arete == null
                ? Ombres.cartePetite
                : Ombres.tactile(arete),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: pastille,
                  shape: BoxShape.circle,
                ),
                child: icone != null
                    ? Icon(icone, size: 20, color: surPastille)
                    : Text(
                        lettre,
                        style: Typo.labelMd.copyWith(color: surPastille),
                      ),
              ),
              const SizedBox(width: Espaces.x12),
              Expanded(
                child: Text(libelle, style: Typo.bodyLg.copyWith(color: texte)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
