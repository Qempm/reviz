import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../composants/bouton.dart';
import '../composants/carte.dart';
import '../composants/chargement.dart';
import '../composants/chemin.dart';
import '../composants/etat_vide.dart';
import '../composants/mascotte.dart';
import '../composants/progression.dart';
import '../composants/puce.dart';
import '../donnees/modeles.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../metier/maitrise.dart';
import '../metier/examen.dart';
import '../routage.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Page d'un cours : progression, chapitres, et le CTA de session.
///
/// Trois états selon `courses.status`. Un cours qui vient d'être déposé n'a ni
/// chapitre ni question : montrer une page vide laisserait croire à une panne.
///
/// **Tant que le cours n'est pas prêt, l'écran interroge `/api/cours/:id`**, et
/// cet appel fait avancer la préparation d'un chapitre. Ce n'est pas un détail
/// d'affichage : la chaîne `ingest_course` → `generate_questions` traite un
/// chapitre par passage et se remet en file, et seul le premier job part
/// depuis l'invocation du dépôt. Les suivants attendaient le cron — une fois
/// par jour sur l'offre Hobby, cinq jobs par passage. Un cours de six
/// chapitres aurait mis des jours à être prêt, pour un produit dont la
/// promesse est « la nuit avant le contrôle ».
class EcranCours extends ConsumerStatefulWidget {
  const EcranCours({super.key, required this.coursId});

  final String coursId;

  @override
  ConsumerState<EcranCours> createState() => _EcranCoursState();
}

class _EcranCoursState extends ConsumerState<EcranCours> {
  /// Cadence d'interrogation : toutes les 4 s pendant trois minutes, puis
  /// toutes les 10 s, **sans abandon** tant que l'écran est ouvert.
  ///
  /// L'ancienne liste s'arrêtait après douze tours (~2 min) : le cours
  /// n'avançait plus qu'à la main ou au cron du soir. Depuis que le serveur
  /// s'enchaîne lui-même (`lancerJobMaintenant`), ce sondage ne fait plus
  /// avancer le cours — il dit où il en est, et relance au besoin une chaîne
  /// qui se serait arrêtée.
  static Duration _delai(int tour) => Duration(seconds: tour < 45 ? 4 : 10);

  Timer? _minuteur;
  int _tour = 0;

  /// Ce que la route a rendu au dernier tour, plus frais que le fournisseur.
  ApercuCours? _frais;

  @override
  void initState() {
    super.initState();

    // L'interrogation démarre quand on **sait** que le cours n'est pas prêt,
    // et pas avant : lancée depuis `build`, elle serait un effet de bord dans
    // une construction ; lancée à l'aveugle, elle coûterait un appel inutile
    // à chaque ouverture d'un cours déjà prêt.
    ref.listenManual(unCoursProvider(widget.coursId), (_, suivant) {
      final valeur = suivant.value;
      if (valeur != null) _programmer(valeur);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  /// Programme le tour suivant, si le cours n'est pas encore fixé.
  void _programmer(ApercuCours cours) {
    if (cours.pret || cours.echoue) return;
    _reprogrammer();
  }

  void _reprogrammer() {
    if (_minuteur?.isActive ?? false) return;
    _minuteur = Timer(_delai(_tour), _interroger);
  }

  Future<void> _interroger() async {
    final etat = await ref
        .read(depotCoursProvider)
        .etat(ref.read(apiProvider), widget.coursId);

    if (!mounted) return;

    setState(() {
      _tour++;
      // Un échec de lecture ne vide pas l'écran : on garde le dernier état
      // connu et on retentera au tour suivant.
      if (etat != null) _frais = etat;
    });

    if (etat != null && (etat.pret || etat.echoue)) {
      // Fixé : les chapitres, la page et la liste doivent se relire.
      ref.invalidate(unCoursProvider(widget.coursId));
      ref.invalidate(chapitresProvider(widget.coursId));
      ref.invalidate(cheminProvider(widget.coursId));
      ref.invalidate(coursProvider);
      return;
    }

    _reprogrammer();
  }

  /// Un appui volontaire relance la cadence depuis le début.
  void _rafraichirMaintenant() {
    _minuteur?.cancel();
    setState(() => _tour = 0);
    _interroger();
  }

  @override
  Widget build(BuildContext context) {
    final coursId = widget.coursId;
    final cours = ref.watch(unCoursProvider(coursId));

    return Scaffold(
      backgroundColor: Couleurs.fond,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Mesures.largeurApp),
            child: switch (cours) {
              AsyncData(:final value) when value != null => _Contenu(
                // Le plus frais des deux : la route rend l'avancement en
                // cours, le fournisseur la dernière lecture directe.
                cours: _frais ?? value,
                onRafraichir: _rafraichirMaintenant,
              ),
              AsyncData() => _Absent(),
              AsyncError() => Padding(
                padding: const EdgeInsets.all(Espaces.ecran),
                child: EtatVide(
                  mascotte: EtatMascotte.oups,
                  titre: Fr.erreurs.chargementImpossible,
                  description: Fr.erreurs.chargementDetail,
                  action: Bouton(
                    libelle: Fr.commun.retour,
                    icone: Icons.arrow_back,
                    variante: VarianteBouton.secondaire,
                    onTap: () => context.remonter(Chemins.reviser),
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

class _Absent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Espaces.ecran),
      child: EtatVide(
        mascotte: EtatMascotte.curieux,
        titre: Fr.erreurs.coursIntrouvable,
        description:
            'Il a peut-être été supprimé, ou il n’est pas partagé avec ta '
            'faculté.',
        action: Bouton(
          libelle: Fr.commun.retour,
          icone: Icons.arrow_back,
          variante: VarianteBouton.secondaire,
          onTap: () => context.remonter(Chemins.reviser),
        ),
      ),
    );
  }
}

class _Contenu extends ConsumerWidget {
  const _Contenu({required this.cours, required this.onRafraichir});

  final ApercuCours cours;
  final VoidCallback onRafraichir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cours.echoue) return _Echec(cours: cours);
    if (!cours.pret) {
      return _EnTraitement(cours: cours, onRafraichir: onRafraichir);
    }

    final chemin = ref.watch(cheminProvider(cours.id));
    final jours = cours.dateExamen == null
        ? null
        : joursAvant(cours.dateExamen!);

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaces.ecran,
        vertical: Espaces.x16,
      ),
      children: [
        _Retour(titre: Fr.reviser.titre),
        const SizedBox(height: Espaces.x8),

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
            if (cours.dateExamen != null)
              Puce(
                libelle: jours == null
                    ? Fr.cours.examenPasse
                    : Fr.cours.jMoins(jours),
                ton: TonPuce.orange,
                icone: Icons.hourglass_top,
              ),
          ],
        ),
        const SizedBox(height: Espaces.x8),

        Text(cours.titre ?? '—', style: Typo.headlineXl),
        if (cours.matiereNom != null) ...[
          const SizedBox(height: Espaces.x4),
          Row(
            children: [
              const Icon(Icons.school, size: 18, color: Couleurs.attenue),
              const SizedBox(width: Espaces.x4),
              Expanded(
                child: Text(
                  cours.matiereNom!,
                  style: Typo.labelMd.copyWith(color: Couleurs.attenue),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: Espaces.x20),

        Carte(
          enfants: [
            Row(
              children: [
                JaugeCirculaire(
                  valeur: cours.progression,
                  taille: 88,
                  centre: Text(
                    '${(cours.progression * 100).round()} %',
                    style: Typo.headlineMd,
                  ),
                ),
                const SizedBox(width: Espaces.x20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        Fr.cours.progression(
                          cours.nbTentees,
                          cours.nbQuestions,
                        ),
                        style: Typo.labelLg,
                      ),
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
              ],
            ),
            Bouton(
              libelle: Fr.cours.reviser,
              icone: Icons.bolt,
              onTap: cours.nbQuestions == 0
                  ? null
                  : () => context.descendre(Chemins.session(cours.id)),
            ),

            // Les fiches en second : le QCM est le cœur du produit, et un
            // écran ne porte qu'un seul CTA principal.
            if (cours.nbFiches > 0)
              Bouton(
                libelle: Fr.fiches.voirFiches,
                icone: Icons.style,
                variante: VarianteBouton.secondaire,
                onTap: () => context.descendre(Chemins.fiches(cours.id)),
              ),
          ],
        ),
        const SizedBox(height: Espaces.x24),

        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: Text(Fr.cours.chemin, style: Typo.headlineLg)),
            if (chemin case AsyncData(:final value) when value.isNotEmpty)
              _TotalCouronnes(chemin: value),
          ],
        ),
        const SizedBox(height: Espaces.x16),

        switch (chemin) {
          AsyncData(:final value) when value.isEmpty => Carte(
            enfants: [
              EtatVide(
                mascotte: EtatMascotte.curieux,
                titre: Fr.cours.aucunChapitre,
                description: Fr.cours.aucunChapitreDetail,
              ),
            ],
          ),
          AsyncData(:final value) => CheminChapitres(
            chapitres: value,
            onOuvrir: (c) => c.maitrise.etat == EtatChapitre.sansQcm
                ? context.descendre(Chemins.fiches(cours.id))
                : context.descendre(
                    Chemins.session(cours.id, chapitre: c.chapitre.id),
                  ),
          ),
          AsyncError() => Text(
            Fr.erreurs.chargementImpossible,
            style: Typo.labelSm.copyWith(color: Couleurs.danger),
          ),
          _ => const Chargement.bloc(hauteur: 240),
        },

        const SizedBox(height: Espaces.x32),
      ],
    );
  }
}

/// « 7 couronnes sur 36 » : la somme du chemin, en tête.
class _TotalCouronnes extends StatelessWidget {
  const _TotalCouronnes({required this.chemin});

  final List<ChapitreDuChemin> chemin;

  @override
  Widget build(BuildContext context) {
    final avecQcm = [
      for (final c in chemin)
        if (c.maitrise.etat != EtatChapitre.sansQcm) c,
    ];
    final gagnees = avecQcm.fold<int>(0, (s, c) => s + c.maitrise.couronnes);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const IconeCouronne(taille: 20, couleur: Couleurs.jaune),
        const SizedBox(width: Espaces.x4),
        Text(
          Fr.cours.couronnes(gagnees, avecQcm.length * 3),
          style: Typo.labelMd.copyWith(
            color: Couleurs.attenue,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _EnTraitement extends StatelessWidget {
  const _EnTraitement({required this.cours, required this.onRafraichir});

  final ApercuCours cours;
  final VoidCallback onRafraichir;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Espaces.ecran),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Retour(titre: Fr.reviser.titre),
          const Spacer(),
          // Il lit le cours, et respire tant que la lecture dure.
          const Mascotte(etat: EtatMascotte.reflexion, taille: 140),
          const SizedBox(height: Espaces.x16),
          Text(
            Fr.cours.traitementTitre,
            style: Typo.headlineMd,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Espaces.x8),
          Text(
            Fr.cours.traitementDetail,
            style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Espaces.x16),

          // L'avancement, chiffré. Un sablier immobile pendant deux minutes
          // se lit comme une panne ; « 3 chapitres · 12 questions » se lit
          // comme du travail en cours — et c'en est, puisque c'est cet écran
          // qui le fait avancer.
          Puce(
            libelle: Fr.cours.traitementAvance(
              cours.nbChapitres,
              cours.nbQuestions,
            ),
            ton: TonPuce.orange,
            icone: Icons.auto_stories_outlined,
          ),
          const SizedBox(height: Espaces.x24),
          Carte(
            petite: true,
            enfants: [
              // Avec le push, fermer n'est plus perdre la nouvelle : on la
              // reçoit quand le cours est prêt.
              Consumer(
                builder: (context, ref, _) => Text(
                  ref.watch(pushDisponibleProvider).value ?? false
                      ? Fr.cours.traitementAstucePush
                      : Fr.cours.traitementAstuce,
                  style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                ),
              ),
            ],
          ),
          const Spacer(),
          Bouton(
            libelle: Fr.commun.reessayer,
            icone: Icons.refresh,
            variante: VarianteBouton.secondaire,
            onTap: onRafraichir,
          ),
        ],
      ),
    );
  }
}

class _Echec extends StatelessWidget {
  const _Echec({required this.cours});

  final ApercuCours cours;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Espaces.ecran),
      child: Column(
        children: [
          _Retour(titre: Fr.reviser.titre),
          const Spacer(),
          const Mascotte(etat: EtatMascotte.oups, taille: 140),
          const SizedBox(height: Espaces.x16),
          Text(
            Fr.cours.echecTitre,
            style: Typo.headlineMd,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Espaces.x8),
          Text(
            Fr.cours.echecDetail,
            style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          Bouton(
            libelle: Fr.commun.retour,
            icone: Icons.arrow_back,
            variante: VarianteBouton.secondaire,
            onTap: () => context.remonter(Chemins.reviser),
          ),
        ],
      ),
    );
  }
}

class _Retour extends StatelessWidget {
  const _Retour({required this.titre});

  final String titre;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => context.remonter(Chemins.reviser),
        icon: const Icon(Icons.arrow_back, size: 20),
        label: Text(titre),
        style: TextButton.styleFrom(
          foregroundColor: Couleurs.attenue,
          minimumSize: const Size(0, Mesures.zoneTactile),
        ),
      ),
    );
  }
}
