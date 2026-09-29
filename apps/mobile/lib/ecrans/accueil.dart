import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../composants/apparition.dart';
import '../composants/bouton.dart';
import '../composants/carte.dart';
import '../composants/carte_serie.dart';
import '../composants/coquille.dart';
import '../composants/etat_vide.dart';
import '../composants/mascotte.dart';
import '../composants/progression.dart';
import '../composants/puce.dart';
import '../donnees/depots.dart';
import '../donnees/modeles.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../metier/examen.dart';
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

    final examen = donnees.prochainExamen;
    final joursExamen = examen?.dateExamen == null
        ? null
        : joursAvant(examen!.dateExamen!);

    // L'ordre de lecture est l'ordre d'arrivée : chaque bloc entre un pas
    // après le précédent.
    var ordre = 0;
    Widget entre(Widget enfant) => Apparition(ordre: ordre++, child: enfant);

    return RefreshIndicator(
      onRefresh: () async => onRafraichir(),
      color: Couleurs.orange,
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: Espaces.ecran,
          vertical: Espaces.x16,
        ),
        children: [
          entre(
            Row(
              children: [
                const Mascotte(etat: EtatMascotte.salut, taille: 76),
                const SizedBox(width: Espaces.x12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Fr.tableauDeBord.salutation(
                          donnees.profil.prenom ?? '',
                        ),
                        style: Typo.headlineXl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: Espaces.x2),
                      Text(
                        Fr.tableauDeBord.sousTitre,
                        style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Espaces.x20),

          entre(
            _CarteHeros(
              repondues: repondues,
              objectif: donnees.objectif,
              cours: donnees.dernierCours,
            ),
          ),

          if (examen != null && joursExamen != null) ...[
            const SizedBox(height: Espaces.x12),
            entre(_CarteExamen(cours: examen, jours: joursExamen)),
          ],

          if (donnees.semaine.isNotEmpty) ...[
            const SizedBox(height: Espaces.x12),
            entre(
              CarteSerie(
                etat: serie,
                jours: donnees.semaine,
                xpDuJour: aujourdhui?.xp ?? 0,
                questionsFaites: repondues,
                objectif: donnees.objectif,
                message: message,
                afficherObjectif: false,
              ),
            ),
          ],
          const SizedBox(height: Espaces.x24),

          entre(
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
                      style: Typo.labelMd.copyWith(
                        color: Couleurs.texteAccent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Espaces.x12),

          if (donnees.matieres.isEmpty)
            entre(
              Carte(
                enfants: [
                  EtatVide(
                    mascotte: EtatMascotte.curieux,
                    titre: Fr.tableauDeBord.aucuneMatiere,
                    description: Fr.tableauDeBord.aucuneMatiereDetail,
                    // Un seul CTA principal par écran : sans cours, la carte
                    // héros n'a pas de bouton, c'est celui-ci qui compte.
                    action: Bouton(
                      libelle: Fr.tableauDeBord.ajouterCours,
                      icone: Icons.add,
                      onTap: () => context.go(Chemins.reviser),
                    ),
                  ),
                ],
              ),
            )
          else
            for (final m in donnees.matieres) ...[
              entre(
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
              ),
              const SizedBox(height: Espaces.x12),
            ],

          const SizedBox(height: Espaces.x32),
        ],
      ),
    );
  }
}

/// La carte qui ouvre la journée : où en est l'objectif, et le bouton qui
/// remet au travail en un geste.
///
/// Sombre, seule de l'écran à l'être : c'est elle que l'œil trouve d'abord,
/// et le jaune de la jauge et du bouton y ressort plus qu'il ne le ferait
/// jamais sur du blanc.
class _CarteHeros extends StatelessWidget {
  const _CarteHeros({
    required this.repondues,
    required this.objectif,
    required this.cours,
  });

  final int repondues;
  final int objectif;
  final ApercuCours? cours;

  @override
  Widget build(BuildContext context) {
    final atteint = repondues >= objectif;
    final cours = this.cours;
    final blancAttenue = Couleurs.carte.withValues(alpha: 0.64);

    return Container(
      padding: const EdgeInsets.all(Espaces.x20),
      decoration: ShapeDecoration(
        color: Couleurs.encre,
        shape: formeContinue(Rayons.heros),
        shadows: Ombres.flottante,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              JaugeCirculaire(
                valeur: progressionDuJour(repondues, objectif),
                taille: 84,
                epaisseur: 9,
                piste: Couleurs.carte.withValues(alpha: 0.14),
                centre: Text(
                  '$repondues',
                  style: Typo.headlineXl.copyWith(
                    color: Couleurs.carte,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: Espaces.x16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Fr.tableauDeBord.objectifTitre.toUpperCase(),
                      style: Typo.caption.copyWith(color: Couleurs.jaune),
                    ),
                    const SizedBox(height: Espaces.x4),
                    Text(
                      atteint
                          ? Fr.tableauDeBord.objectifAtteint
                          : Fr.tableauDeBord.objectifReste(
                              resteAvantObjectif(repondues, objectif),
                            ),
                      style: Typo.headlineMd.copyWith(color: Couleurs.carte),
                    ),
                    const SizedBox(height: Espaces.x4),
                    Text(
                      Fr.tableauDeBord.objectifDuJour(repondues, objectif),
                      style: Typo.labelSm.copyWith(color: blancAttenue),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (cours != null) ...[
            const SizedBox(height: Espaces.x20),
            Text(
              '${Fr.tableauDeBord.reprendre} · ${cours.titre ?? cours.matiereNom ?? ''}',
              style: Typo.labelMd.copyWith(color: blancAttenue),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: Espaces.x8),
            Bouton(
              libelle: Fr.tableauDeBord.continuer,
              icone: Icons.play_arrow_rounded,
              onTap: () => context.descendre(Chemins.session(cours.id)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Le compte à rebours : un examen proche change ce qu'on révise ce soir.
class _CarteExamen extends StatelessWidget {
  const _CarteExamen({required this.cours, required this.jours});

  final ApercuCours cours;
  final int jours;

  @override
  Widget build(BuildContext context) {
    // Orange à une semaine et moins : c'est la couleur de l'urgence. Au-delà,
    // le rappel reste, sans alarmer.
    final proche = jours <= 7;

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.descendre(Chemins.cours(cours.id)),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Espaces.x16,
            vertical: Espaces.x12,
          ),
          decoration: ShapeDecoration(
            color: proche ? Couleurs.orangeDoux : Couleurs.carte,
            shape: formeContinue(Rayons.carte),
            shadows: proche ? null : Ombres.cartePetite,
          ),
          child: Row(
            children: [
              Icon(
                Icons.event,
                size: 24,
                color: proche ? Couleurs.orangeProfond : Couleurs.texteAccent,
              ),
              const SizedBox(width: Espaces.x12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Fr.tableauDeBord.prochainExamen,
                      style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                    ),
                    Text(
                      cours.titre ?? cours.matiereNom ?? '—',
                      style: Typo.labelLg,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Espaces.x8),
              Text(
                Fr.cours.jMoins(jours),
                style: Typo.headlineMd.copyWith(
                  color: proche ? Couleurs.orangeProfond : Couleurs.encre,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
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
