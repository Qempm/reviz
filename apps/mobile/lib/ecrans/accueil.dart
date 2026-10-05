import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../composants/apparition.dart';
import '../composants/blason_ligue.dart';
import '../composants/bouton.dart';
import '../composants/carte.dart';
import '../composants/carte_matiere.dart';
import '../composants/carte_serie.dart';
import '../composants/chargement.dart';
import '../composants/coquille.dart';
import '../composants/etat_vide.dart';
import '../composants/mascotte.dart';
import '../composants/progression.dart';
import '../donnees/api.dart';
import '../donnees/depots.dart';
import '../donnees/modeles.dart';
import '../donnees/push_navigateur.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../metier/acces.dart';
import '../metier/examen.dart';
import '../metier/serie.dart';
import '../routage.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';
import 'notifications_reglages.dart' show CartePushNavigateur;

/// Tableau de bord.
///
/// Tout ce qu'il affiche arrive en une salve (`DepotAccueil.charger`) : quatre
/// allers-retours en série se voient sur une connexion instable.
class EcranAccueil extends ConsumerWidget {
  const EcranAccueil({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Les rappels du téléphone suivent l'état du compte : ils se
    // reprogramment d'eux-mêmes quand l'accueil se relit.
    ref.watch(rappelsProvider);
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
        AsyncError() => _Panne(
          message: Fr.erreurs.chargementDetail,
          onReessayer: () => ref.invalidate(accueilProvider),
        ),
        _ => const Chargement.liste(),
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
    // « Ta série s'est arrêtée » ne se dit qu'à qui en a eu une : une
    // nouvelle inscrite n'a rien perdu, elle commence.
    final message = serie.rompue
        ? (donnees.profil.dernierJourValide == null
              ? Fr.tableauDeBord.seriePremiere
              : Fr.tableauDeBord.serieRompue)
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

          // Un compte sans pack : le pack gratuit, proposé ici et pas au
          // fond du profil. Rien ne s'affiche une fois qu'il a servi.
          const _CarteGratuit(),

          // L'app web installée (iPhone sans compte Apple) : l'invitation à
          // activer les notifications, qui exige un toucher.
          const _InvitationPush(),

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

          // La ligue de la semaine : rien tant qu'elle n'a pas répondu, pour
          // ne pas faire sauter la page au chargement.
          const _CarteLigue(),
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
                      style: Typo.labelMd.copyWith(color: Couleurs.texteAccent),
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
              // Chaque matière ouvre son écran : maîtrise, chapitres à
              // retravailler, cours.
              entre(
                CarteMatiere(
                  matiere: m,
                  onTap: () => context.descendre(Chemins.matiere(m.matiereId)),
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
              // À une semaine et moins, le panthéreau sort son réveil.
              if (proche)
                const TeteMascotte(etat: EtatMascotte.reveil, taille: 36)
              else
                const Icon(Icons.event, size: 24, color: Couleurs.texteAccent),
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
        mascotte: EtatMascotte.oups,
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

/// « Commence gratuitement » : pour un compte qui n'a jamais eu de pack.
///
/// Avant, le pack gratuit n'était proposé nulle part : il fallait aller dans
/// Profil → packs pour le trouver, et l'étudiant qui voulait déposer son
/// premier cours se heurtait à un refus. La carte l'active en un appui.
/// Sur le web, quand les notifications sont possibles mais pas encore
/// demandées : une carte pour les activer. « Plus tard » l'écarte une
/// semaine.
class _InvitationPush extends ConsumerStatefulWidget {
  const _InvitationPush();

  @override
  ConsumerState<_InvitationPush> createState() => _InvitationPushState();
}

class _InvitationPushState extends ConsumerState<_InvitationPush> {
  static const _cle = 'reviz.push.plus-tard';
  bool _ecartee = true;

  @override
  void initState() {
    super.initState();
    _lire();
  }

  Future<void> _lire() async {
    try {
      final p = await SharedPreferences.getInstance();
      final le = DateTime.tryParse(p.getString(_cle) ?? '');
      final ecartee = le != null && DateTime.now().difference(le).inDays < 7;
      if (mounted) setState(() => _ecartee = ecartee);
    } catch (_) {
      if (mounted) setState(() => _ecartee = false);
    }
  }

  Future<void> _plusTard() async {
    setState(() => _ecartee = true);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_cle, DateTime.now().toIso8601String());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final etat = ref.watch(etatPushNavigateurProvider);
    if (_ecartee || etat != EtatPushNavigateur.aDemander) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: Espaces.x12),
      child: CartePushNavigateur(etat: etat, plusTard: _plusTard),
    );
  }
}

class _CarteGratuit extends ConsumerStatefulWidget {
  const _CarteGratuit();

  @override
  ConsumerState<_CarteGratuit> createState() => _CarteGratuitState();
}

class _CarteGratuitState extends ConsumerState<_CarteGratuit> {
  bool _enCours = false;

  Future<void> _activer() async {
    setState(() => _enCours = true);
    final reponse = await ref
        .read(depotBoutiqueProvider)
        .activerDecouverte(ref.read(apiProvider));
    if (!mounted) return;
    setState(() => _enCours = false);
    switch (reponse) {
      case ReponseSucces():
        ref.invalidate(boutiqueProvider);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(Fr.tableauDeBord.gratuitActive)));
      case ReponseEchec(:final erreur):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              erreur.isEmpty ? Fr.boutique.activationImpossible : erreur,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final boutique = ref.watch(boutiqueProvider).value;
    if (boutique == null ||
        boutique.decouverteUtilisee ||
        boutique.acces is! AucunAcces) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: Espaces.x12),
      child: Carte(
        enfants: [
          Row(
            children: [
              // Il tend un cadeau : le pack gratuit.
              const Mascotte(etat: EtatMascotte.cadeau, taille: 64),
              const SizedBox(width: Espaces.x12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Fr.tableauDeBord.gratuitTitre, style: Typo.headlineSm),
                    const SizedBox(height: Espaces.x2),
                    Text(
                      Fr.tableauDeBord.gratuitDetail,
                      style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Secondaire : l'écran garde un seul bouton principal, « Continuer ».
          Bouton(
            libelle: Fr.tableauDeBord.gratuitBouton,
            icone: Icons.card_giftcard,
            variante: VarianteBouton.secondaire,
            chargement: _enCours,
            onTap: _enCours ? null : _activer,
          ),
        ],
      ),
    );
  }
}

/// « Ligue Argent · tu es 4e » : la porte vers l'écran de la ligue.
class _CarteLigue extends ConsumerWidget {
  const _CarteLigue();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ligue = ref.watch(ligueProvider).value;
    if (ligue == null) return const SizedBox.shrink();
    final moi = ligue.moi;

    return Padding(
      padding: const EdgeInsets.only(top: Espaces.x12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.descendre(Chemins.ligue),
        child: Carte(
          petite: true,
          enfants: [
            Row(
              children: [
                BlasonLigue(division: ligue.division, taille: 44),
                const SizedBox(width: Espaces.x12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(Fr.ligue.nom(ligue.division), style: Typo.labelLg),
                      Text(
                        moi == null
                            ? Fr.ligue.entrer
                            : Fr.ligue.position(moi.rang, moi.xp),
                        style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Couleurs.attenue),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
