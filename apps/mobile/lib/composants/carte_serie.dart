import 'package:flutter/material.dart';
import '../donnees/modeles.dart';
import '../i18n/fr.dart';
import '../metier/serie.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';
import 'carte.dart';
import 'progression.dart';

/// Carte de série de révision.
///
/// Sept carrés arrondis légèrement inclinés, et non sept losanges à 45° comme
/// l'annonçait CLAUDE.md : ce sont les carrés que Stitch a produits.
///
/// La série affichée vient de [etatSerie], **jamais de
/// `profiles.current_streak` brut** : celui-ci garde la valeur du dernier jour
/// validé, même vieille d'une semaine. C'était le défaut § 4.1 du rapport, et
/// il ne doit pas traverser le portage.
class CarteSerie extends StatelessWidget {
  const CarteSerie({
    super.key,
    required this.etat,
    required this.jours,
    required this.xpDuJour,
    required this.questionsFaites,
    required this.objectif,
    this.message,
    this.afficherObjectif = true,
  });

  final EtatSerie etat;
  final List<JourSerie> jours;
  final int xpDuJour;
  final int questionsFaites;
  final int objectif;
  final String? message;

  /// La barre de l'objectif du jour. L'accueil l'éteint : sa carte héros
  /// porte déjà la jauge, et deux compteurs du même chiffre se contredisent
  /// le jour où l'un est en retard sur l'autre.
  final bool afficherObjectif;

  static const _lettres = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  /// Inclinaisons relevées dans le markup Stitch : les cases validées ne sont
  /// pas alignées au cordeau, ce qui donne son côté « collé à la main ».
  static const _inclinaisons = [0.05, -0.05, 0.035, 0.0, 0.05, -0.035, 0.02];

  @override
  Widget build(BuildContext context) {
    final eteinte = etat.rompue || etat.jours == 0;

    return Carte(
      enfants: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Éteinte, la flamme reste chaude mais sourde : pas de gris
                // froid, la palette n'en a pas.
                color: eteinte ? Couleurs.surfaceConteneur : Couleurs.jaune,
              ),
              child: Icon(
                Icons.local_fire_department,
                size: 28,
                color: eteinte ? Couleurs.attenue : Couleurs.surJaune,
              ),
            ),
            const SizedBox(width: Espaces.x12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    eteinte
                        ? Fr.tableauDeBord.lanceTaSerie
                        : Fr.tableauDeBord.flamme(etat.jours),
                    style: Typo.headlineMd,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (xpDuJour > 0)
                    Text(
                      Fr.tableauDeBord.xpAujourdhui(xpDuJour),
                      style: Typo.labelSm.copyWith(color: Couleurs.texteAccent),
                    ),
                ],
              ),
            ),
          ],
        ),

        // Sept cases de 40 px ne tiennent pas dans les 248 px utiles d'un
        // écran de 320 : on dimensionne à la place disponible plutôt que de
        // déborder. Attrapé par le test de rendu à 320 px.
        LayoutBuilder(
          builder: (context, contraintes) {
            const gouttiere = Espaces.x4;
            final dispo = contraintes.maxWidth - gouttiere * 6;
            final taille = (dispo / 7).clamp(24.0, 40.0);

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < jours.length && i < 7; i++)
                  _Case(
                    lettre: _lettres[i],
                    jour: jours[i],
                    inclinaison: _inclinaisons[i],
                    taille: taille,
                  ),
              ],
            );
          },
        ),

        // Objectif du jour : sans compteur, « réponds à 10 questions » n'est
        // qu'une phrase.
        if (afficherObjectif && questionsFaites < objectif)
          BarreProgression(
            valeur: progressionDuJour(questionsFaites, objectif),
            libelle: Fr.tableauDeBord.objectifDuJour(questionsFaites, objectif),
          ),

        if (message != null)
          Container(
            padding: const EdgeInsets.all(Espaces.x12),
            decoration: BoxDecoration(
              color: Couleurs.surfaceBasse,
              borderRadius: BorderRadius.circular(Rayons.normal),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.military_tech,
                  size: 22,
                  color: Couleurs.orange,
                ),
                const SizedBox(width: Espaces.x8),
                Expanded(child: Text(message!, style: Typo.labelSm)),
              ],
            ),
          ),
      ],
    );
  }
}

class _Case extends StatelessWidget {
  const _Case({
    required this.lettre,
    required this.jour,
    required this.inclinaison,
    required this.taille,
  });

  final String lettre;
  final JourSerie jour;
  final double inclinaison;

  /// Côté du carré, calculé par la carte depuis la place disponible.
  final double taille;

  @override
  Widget build(BuildContext context) {
    final Widget carre;

    if (jour.aujourdhui && jour.valide) {
      // Aujourd'hui, et c'est fait : la case ne clignote plus. Une case qui
      // appelle encore alors que le jour est validé annule la récompense.
      carre = _Carre(
        fond: Couleurs.orange,
        icone: Icons.local_fire_department,
        teinte: Couleurs.carte,
        taille: taille,
      );
    } else if (jour.aujourdhui) {
      carre = _Carre(
        fond: Couleurs.orangeDoux,
        icone: Icons.local_fire_department,
        teinte: Couleurs.orange,
        taille: taille,
      );
    } else if (jour.valide) {
      carre = Transform.rotate(
        angle: inclinaison,
        child: _Carre(
          fond: Couleurs.jaune,
          icone: Icons.check,
          teinte: Couleurs.surJaune,
          taille: taille * 0.9,
        ),
      );
    } else {
      carre = _Carre(fond: Couleurs.surfaceConteneur, taille: taille * 0.9);
    }

    return Opacity(
      opacity: jour.valide || jour.aujourdhui ? 1 : 0.5,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            lettre,
            style: Typo.caption.copyWith(
              color: jour.aujourdhui ? Couleurs.orangeProfond : Couleurs.attenue,
            ),
          ),
          const SizedBox(height: Espaces.x4),
          carre,
        ],
      ),
    );
  }
}

class _Carre extends StatelessWidget {
  const _Carre({
    required this.fond,
    required this.taille,
    this.icone,
    this.teinte,
  });

  final Color fond;
  final double taille;
  final IconData? icone;
  final Color? teinte;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: taille,
      height: taille,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(Rayons.normal),
      ),
      child: icone == null
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Couleurs.bordure,
                shape: BoxShape.circle,
              ),
            )
          : Icon(icone, size: taille * 0.55, color: teinte),
    );
  }
}
