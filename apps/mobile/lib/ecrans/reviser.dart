import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../composants/bouton.dart';
import '../composants/carte.dart';
import '../composants/chargement.dart';
import '../composants/coquille.dart';
import '../composants/etat_vide.dart';
import '../composants/mascotte.dart';
import '../composants/progression.dart';
import '../composants/puce.dart';
import '../donnees/modeles.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../metier/serie.dart';
import '../routage.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Liste des cours.
///
/// Les cours de démonstration sont épinglés en tête : un étudiant qui vient de
/// s'inscrire n'a rien déposé, et un écran vide ne lui apprend pas ce que
/// l'application sait faire.
class EcranReviser extends ConsumerWidget {
  const EcranReviser({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cours = ref.watch(coursProvider);
    final profil = ref.watch(profilProvider);

    return Coquille(
      serie: switch (profil) {
        AsyncData(:final value) when value != null => etatSerie(
          current: value.serieCourante,
          lastValidatedOn: value.dernierJourValide,
        ),
        _ => null,
      },
      xpTotal: switch (profil) {
        AsyncData(:final value) when value != null => value.xpTotal,
        _ => null,
      },
      enfant: switch (cours) {
        AsyncData(:final value) => _Liste(
          cours: value,
          onRafraichir: () => ref.invalidate(coursProvider),
        ),
        AsyncError(:final error) => Padding(
          padding: const EdgeInsets.all(Espaces.ecran),
          child: EtatVide(
            icone: Icons.cloud_off,
            titre: Fr.erreurs.chargementImpossible,
            description: '$error',
            action: Bouton(
              libelle: Fr.commun.reessayer,
              icone: Icons.refresh,
              onTap: () => ref.invalidate(coursProvider),
            ),
          ),
        ),
        _ => const Chargement.liste(),
      },
    );
  }
}

class _Liste extends StatelessWidget {
  const _Liste({required this.cours, required this.onRafraichir});

  final List<ApercuCours> cours;
  final VoidCallback onRafraichir;

  @override
  Widget build(BuildContext context) {
    final miens = cours.where((c) => !c.demo).toList();

    return RefreshIndicator(
      onRefresh: () async => onRafraichir(),
      color: Couleurs.orange,
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: Espaces.ecran,
          vertical: Espaces.x16,
        ),
        children: [
          Text(Fr.reviser.titre, style: Typo.headlineXl),
          const SizedBox(height: Espaces.x4),
          Text(
            Fr.reviser.sousTitre,
            style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
          ),
          const SizedBox(height: Espaces.x20),

          Bouton(
            libelle: Fr.reviser.ajouterCours,
            icone: Icons.add,
            onTap: () => context.descendre(Chemins.ajouterCours),
          ),
          const SizedBox(height: Espaces.x20),

          if (cours.isEmpty)
            Carte(
              enfants: [
                EtatVide(
                  mascotte: EtatMascotte.curieux,
                  titre: Fr.reviser.aucunCours,
                  description: Fr.reviser.aucunCoursDetail,
                  action: Bouton(
                    libelle: Fr.reviser.ajouterCours,
                    icone: Icons.add,
                    onTap: () => context.descendre(Chemins.ajouterCours),
                  ),
                ),
              ],
            )
          else
            for (final c in cours) ...[
              CarteCours(cours: c),
              const SizedBox(height: Espaces.x12),
            ],

          if (miens.isEmpty && cours.isNotEmpty) ...[
            const SizedBox(height: Espaces.x8),
            Text(
              Fr.reviser.seulementDemo,
              style: Typo.labelSm.copyWith(color: Couleurs.attenue),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: Espaces.x32),
        ],
      ),
    );
  }
}

/// Carte d'un cours dans la liste.
class CarteCours extends StatelessWidget {
  const CarteCours({super.key, required this.cours});

  final ApercuCours cours;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.descendre(Chemins.cours(cours.id)),
      child: Carte(
        enfants: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: Espaces.x8,
                      runSpacing: Espaces.x4,
                      children: [
                        if (cours.demo)
                          Puce(
                            libelle: Fr.reviser.exemple,
                            ton: TonPuce.jaune,
                            icone: Icons.auto_awesome,
                          ),
                        if (!cours.pret)
                          Puce(
                            libelle: Fr.reviser.enTraitement,
                            ton: TonPuce.orange,
                            icone: Icons.hourglass_top,
                          ),
                      ],
                    ),
                    if (cours.demo || !cours.pret)
                      const SizedBox(height: Espaces.x8),
                    Text(
                      cours.titre ?? '—',
                      style: Typo.headlineMd,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (cours.matiereNom != null) ...[
                      const SizedBox(height: Espaces.x4),
                      Row(
                        children: [
                          const Icon(
                            Icons.school,
                            size: 16,
                            color: Couleurs.attenue,
                          ),
                          const SizedBox(width: Espaces.x4),
                          Expanded(
                            child: Text(
                              cours.matiereNom!,
                              style: Typo.labelSm.copyWith(
                                color: Couleurs.attenue,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: Espaces.x4),
                    Text(
                      Fr.reviser.decompte(
                        cours.nbChapitres,
                        cours.nbQuestions,
                        cours.nbFiches,
                      ),
                      style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Espaces.x12),
              if (cours.pret && cours.nbQuestions > 0)
                JaugeCirculaire(
                  valeur: cours.progression,
                  taille: 64,
                  centre: Text(
                    '${(cours.progression * 100).round()} %',
                    style: Typo.labelMd,
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right,
                  size: 24,
                  color: Couleurs.attenue,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
