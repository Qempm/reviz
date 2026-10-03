import 'package:flutter/material.dart';
import '../donnees/modeles.dart';
import '../i18n/fr.dart';
import '../metier/matieres.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';
import 'progression.dart';
import 'puce.dart';

/// L'illustration d'une matière dans un disque crème : l'objet 3D de sa
/// famille (`assets/matieres/<famille>.webp`, `scripts/matieres.mjs`).
///
/// Si l'image manque — un nom de famille ajouté sans son dessin —, une icône
/// de la famille la remplace : la carte ne s'affiche jamais trouée.
class MedaillonMatiere extends StatelessWidget {
  const MedaillonMatiere({super.key, required this.famille, this.taille = 52});

  final FamilleMatiere famille;
  final double taille;

  static IconData icone(FamilleMatiere f) => switch (f) {
    FamilleMatiere.droit => Icons.gavel,
    FamilleMatiere.economie => Icons.trending_up,
    FamilleMatiere.sante => Icons.medical_services_outlined,
    FamilleMatiere.maths => Icons.calculate_outlined,
    FamilleMatiere.sciences => Icons.science_outlined,
    FamilleMatiere.agronomie => Icons.grass,
    FamilleMatiere.lettres => Icons.menu_book_outlined,
    FamilleMatiere.informatique => Icons.computer,
    FamilleMatiere.education => Icons.school_outlined,
    FamilleMatiere.generique => Icons.edit_note,
  };

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Container(
      width: taille,
      height: taille,
      decoration: const BoxDecoration(
        color: Couleurs.fond,
        shape: BoxShape.circle,
      ),
      padding: EdgeInsets.all(taille * 0.1),
      child: Image.asset(
        famille.image,
        fit: BoxFit.contain,
        cacheWidth: (taille * dpr).round(),
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => Icon(
          icone(famille),
          size: taille * 0.5,
          color: Couleurs.texteAccent,
        ),
      ),
    );
  }
}

/// Une matière sur l'accueil : son illustration, sa maîtrise, et le chemin
/// vers l'écran de la matière.
class CarteMatiere extends StatelessWidget {
  const CarteMatiere({super.key, required this.matiere, required this.onTap});

  final StatMatiere matiere;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: Fr.matiere.ouvrir(matiere.matiereNom ?? ''),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(Espaces.x12),
          decoration: ShapeDecoration(
            color: Couleurs.carte,
            shape: formeContinue(Rayons.carte),
            shadows: Ombres.cartePetite,
          ),
          child: Row(
            children: [
              MedaillonMatiere(famille: familleDe(matiere.matiereNom)),
              const SizedBox(width: Espaces.x12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            matiere.matiereNom ?? '—',
                            style: Typo.labelLg,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (matiere.aRevoir)
                          Puce(
                            libelle: Fr.tableauDeBord.pointFaible,
                            ton: TonPuce.danger,
                            icone: Icons.priority_high,
                          ),
                      ],
                    ),
                    const SizedBox(height: Espaces.x8),
                    BarreProgression(valeur: matiere.scoreMoyen),
                    const SizedBox(height: Espaces.x4),
                    Text(
                      Fr.tableauDeBord.questionsFaites(matiere.questionsFaites),
                      style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Espaces.x4),
              const Icon(
                Icons.chevron_right,
                size: 24,
                color: Couleurs.attenue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
