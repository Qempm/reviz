import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../composants/bouton.dart';
import '../composants/carte.dart';
import '../composants/carte_serie.dart';
import '../composants/coquille.dart';
import '../composants/etat_vide.dart';
import '../composants/mascotte.dart';
import '../composants/progression.dart';
import '../composants/puce.dart';
import '../donnees/depots.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../metier/serie.dart';
import '../routage.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Tableau de bord.
///
/// Tout ce qu'il affiche arrive en une salve (`DepotAccueil.charger`) : quatre
/// allers-retours en série se voient sur une connexion instable.
class EcranAccueil extends ConsumerWidget {
  const EcranAccueil({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accueil = ref.watch(accueilProvider);

    final serie = switch (accueil) {
      AsyncData(:final value) when value != null => etatSerie(
        current: value.profil.serieCourante,
        lastValidatedOn: value.profil.dernierJourValide,
      ),
      _ => null,
    };

    return Coquille(
      serie: serie,
      xpTotal: switch (accueil) {
        AsyncData(:final value) when value != null => value.profil.xpTotal,
        _ => null,
      },
      enfant: switch (accueil) {
        AsyncData(:final value) when value != null => _Contenu(
          donnees: value,
          serie: serie!,
          onRafraichir: () => ref.invalidate(accueilProvider),
        ),
        AsyncError(:final error) => _Panne(
          message: '$error',
          onReessayer: () => ref.invalidate(accueilProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Contenu extends StatelessWidget {
  const _Contenu({
    required this.donnees,
    required this.serie,
    required this.onRafraichir,
  });

  final DonneesAccueil donnees;
  final EtatSerie serie;
  final VoidCallback onRafraichir;

  @override
  Widget build(BuildContext context) {
    final aujourdhui = donnees.aujourdhui;
    final repondues = aujourdhui?.questions ?? 0;

    // Un seul message, choisi par ce qui est en jeu maintenant.
    final message = serie.rompue
        ? Fr.tableauDeBord.serieRompue
        : serie.enJeu
        ? Fr.tableauDeBord.serieEnJeu(
            resteAvantObjectif(repondues, donnees.objectif),
          )
        : null;

    return RefreshIndicator(
      onRefresh: () async => onRafraichir(),
      color: Couleurs.orange,
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: Espaces.ecran,
          vertical: Espaces.x16,
        ),
        children: [
          Text(
            Fr.tableauDeBord.salutation(donnees.profil.prenom ?? ''),
            style: Typo.headlineXl,
          ),
          const SizedBox(height: Espaces.x4),
          Text(
            Fr.tableauDeBord.sousTitre,
            style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
          ),
          const SizedBox(height: Espaces.x20),

          if (donnees.semaine.isNotEmpty)
            CarteSerie(
              etat: serie,
              jours: donnees.semaine,
              xpDuJour: aujourdhui?.xp ?? 0,
              questionsFaites: repondues,
              objectif: donnees.objectif,
              message: message,
            ),
          const SizedBox(height: Espaces.x20),

          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  Fr.tableauDeBord.mesMatieres,
                  style: Typo.headlineLg,
                ),
              ),
              if (donnees.matieres.isNotEmpty)
                TextButton(
                  onPressed: () => context.go(Chemins.reviser),
                  child: Text(
                    Fr.commun.voirTout,
                    style: Typo.labelMd.copyWith(color: Couleurs.texteAccent),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Espaces.x12),

          if (donnees.matieres.isEmpty)
            Carte(
              enfants: [
                EtatVide(
                  mascotte: EtatMascotte.curieux,
                  titre: Fr.tableauDeBord.aucuneMatiere,
                  description: Fr.tableauDeBord.aucuneMatiereDetail,
                  action: Bouton(
                    libelle: Fr.tableauDeBord.ajouterCours,
                    icone: Icons.add,
                    onTap: () => context.go(Chemins.reviser),
                  ),
                ),
              ],
            )
          else
            for (final m in donnees.matieres) ...[
              Carte(
                petite: true,
                enfants: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          m.matiereNom ?? '—',
                          style: Typo.labelLg,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (m.aRevoir)
                        Puce(
                          libelle: Fr.tableauDeBord.pointFaible,
                          ton: TonPuce.danger,
                          icone: Icons.priority_high,
                        ),
                    ],
                  ),
                  BarreProgression(valeur: m.scoreMoyen),
                  Text(
                    Fr.tableauDeBord.questionsFaites(m.questionsFaites),
                    style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                  ),
                ],
              ),
              const SizedBox(height: Espaces.x12),
            ],

          const SizedBox(height: Espaces.x32),
        ],
      ),
    );
  }
}

class _Panne extends StatelessWidget {
  const _Panne({required this.message, required this.onReessayer});

  final String message;
  final VoidCallback onReessayer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Espaces.ecran),
      child: EtatVide(
        icone: Icons.cloud_off,
        titre: Fr.erreurs.chargementImpossible,
        description: message,
        action: Bouton(
          libelle: Fr.commun.reessayer,
          icone: Icons.refresh,
          onTap: onReessayer,
        ),
      ),
    );
  }
}
