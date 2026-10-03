import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../composants/bouton.dart';
import '../composants/carte.dart';
import '../composants/carte_matiere.dart';
import '../composants/chargement.dart';
import '../composants/etat_vide.dart';
import '../composants/mascotte.dart';
import '../composants/progression.dart';
import '../composants/puce.dart';
import '../donnees/depots.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../metier/matieres.dart';
import '../routage.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';
import 'reviser.dart' show CarteCours;

/// Une matière : où l'étudiant en est, ce qu'il doit retravailler, et ses
/// cours.
///
/// Ouverte depuis « Mes matières » sur l'accueil. Les chapitres à
/// retravailler sont ceux de **tous** les cours de la matière, du plus
/// fragile au moins fragile : c'est la question que l'étudiant se pose la
/// veille d'un contrôle — « qu'est-ce que je ne sais pas encore ? ».
class EcranMatiere extends ConsumerWidget {
  const EcranMatiere({super.key, required this.matiereId});

  final String matiereId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matiere = ref.watch(matiereProvider(matiereId));

    return Scaffold(
      backgroundColor: Couleurs.fond,
      appBar: AppBar(
        backgroundColor: Couleurs.fond,
        surfaceTintColor: Colors.transparent,
        title: Text(
          switch (matiere) {
            AsyncData(:final value) => value.nom ?? Fr.matiere.titreParDefaut,
            _ => Fr.matiere.titreParDefaut,
          },
          style: Typo.headlineLg,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          onPressed: () => context.remonter(Chemins.accueil),
          icon: const Icon(Icons.arrow_back, color: Couleurs.encre),
          tooltip: Fr.commun.retour,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Mesures.largeurApp),
            child: switch (matiere) {
              AsyncData(:final value) => RefreshIndicator(
                color: Couleurs.encre,
                onRefresh: () => ref.refresh(matiereProvider(matiereId).future),
                child: _Contenu(donnees: value),
              ),
              AsyncError() => Padding(
                padding: const EdgeInsets.all(Espaces.ecran),
                child: EtatVide(
                  mascotte: EtatMascotte.oups,
                  titre: Fr.erreurs.chargementImpossible,
                  description: Fr.erreurs.chargementDetail,
                  action: Bouton(
                    libelle: Fr.commun.reessayer,
                    icone: Icons.refresh,
                    onTap: () => ref.invalidate(matiereProvider(matiereId)),
                  ),
                ),
              ),
              _ => const Chargement.liste(),
            },
          ),
        ),
      ),
    );
  }
}

class _Contenu extends StatelessWidget {
  const _Contenu({required this.donnees});

  final DonneesMatiere donnees;

  @override
  Widget build(BuildContext context) {
    final stat = donnees.stat;
    final famille = familleDe(donnees.nom);
    final aReviser = donnees.coursAReviser;

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaces.ecran,
        vertical: Espaces.x8,
      ),
      children: [
        // --- La maîtrise de la matière
        Container(
          padding: const EdgeInsets.all(Espaces.x20),
          decoration: ShapeDecoration(
            color: Couleurs.carte,
            shape: formeContinue(Rayons.heros),
            shadows: Ombres.carte,
          ),
          child: Row(
            children: [
              MedaillonMatiere(famille: famille, taille: 88),
              const SizedBox(width: Espaces.x16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Fr.matiere.maitrise,
                      style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                    ),
                    if (stat == null)
                      Text(
                        Fr.matiere.pasEncore,
                        style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
                      )
                    else ...[
                      Text(
                        '${(stat.scoreMoyen * 100).round()} %',
                        style: Typo.displayHerosMobile,
                      ),
                      const SizedBox(height: Espaces.x4),
                      BarreProgression(valeur: stat.scoreMoyen),
                      const SizedBox(height: Espaces.x4),
                      Wrap(
                        spacing: Espaces.x8,
                        runSpacing: Espaces.x4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            Fr.matiere.questions(stat.questionsFaites),
                            style: Typo.labelSm.copyWith(
                              color: Couleurs.attenue,
                            ),
                          ),
                          if (stat.aRevoir)
                            Puce(
                              libelle: Fr.tableauDeBord.pointFaible,
                              ton: TonPuce.danger,
                              icone: Icons.priority_high,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Espaces.x16),

        if (aReviser != null) ...[
          Bouton(
            libelle: Fr.matiere.reviserMatiere,
            icone: Icons.bolt,
            onTap: () => context.descendre(
              Chemins.session(
                aReviser.id,
                erreurs: donnees.aRetravailler.isNotEmpty,
              ),
            ),
          ),
          const SizedBox(height: Espaces.x24),
        ],

        // --- À retravailler
        Text(Fr.matiere.aRetravailler, style: Typo.headlineLg),
        const SizedBox(height: Espaces.x4),
        Text(
          Fr.matiere.aRetravaillerDetail,
          style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
        ),
        const SizedBox(height: Espaces.x12),
        if (donnees.aRetravailler.isEmpty)
          Carte(
            enfants: [
              EtatVide(
                mascotte: EtatMascotte.courage,
                titre: Fr.matiere.rienARetravailler,
                description: Fr.matiere.rienARetravaillerDetail,
              ),
            ],
          )
        else
          for (final r in donnees.aRetravailler) ...[
            _LigneARetravailler(element: r),
            const SizedBox(height: Espaces.x8),
          ],
        const SizedBox(height: Espaces.x24),

        // --- Les cours de la matière
        Text(Fr.matiere.tesCours, style: Typo.headlineLg),
        const SizedBox(height: Espaces.x12),
        if (donnees.cours.isEmpty)
          Carte(
            enfants: [
              EtatVide(
                mascotte: EtatMascotte.curieux,
                titre: Fr.matiere.aucunCours,
                description: Fr.matiere.aucunCoursDetail,
              ),
            ],
          )
        else
          for (final c in donnees.cours) ...[
            CarteCours(cours: c),
            const SizedBox(height: Espaces.x12),
          ],
        const SizedBox(height: Espaces.x32),
      ],
    );
  }
}

/// Un chapitre fragile : son cours, son taux de réussite, et la reprise de ce
/// seul chapitre.
class _LigneARetravailler extends StatelessWidget {
  const _LigneARetravailler({required this.element});

  final ChapitreARetravailler element;

  @override
  Widget build(BuildContext context) {
    final ch = element.chapitre;
    final taux = ch.taux ?? 0;

    return Container(
      padding: const EdgeInsets.all(Espaces.x12),
      decoration: ShapeDecoration(
        color: Couleurs.carte,
        shape: formeContinue(Rayons.carte),
        shadows: Ombres.cartePetite,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: Couleurs.dangerDoux,
              shape: formeContinue(Rayons.moyen),
            ),
            child: Text(
              '${(taux * 100).round()}%',
              style: Typo.labelSm.merge(Typo.chiffres).copyWith(
                color: Couleurs.surDangerDoux,
              ),
            ),
          ),
          const SizedBox(width: Espaces.x12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Fr.matiere.chapitre(ch.index, ch.titre),
                  style: Typo.labelLg,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Espaces.x2),
                Text(
                  element.cours.titre ?? '—',
                  style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: Espaces.x8),
          TextButton(
            onPressed: () => context.descendre(
              Chemins.session(element.cours.id, chapitre: ch.id),
            ),
            style: TextButton.styleFrom(
              minimumSize: const Size(Mesures.zoneTactile, Mesures.zoneTactile),
              foregroundColor: Couleurs.encre,
              backgroundColor: Couleurs.jauneDoux,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: Espaces.x12),
            ),
            child: Text(Fr.matiere.reprendre, style: Typo.labelMd),
          ),
        ],
      ),
    );
  }
}
