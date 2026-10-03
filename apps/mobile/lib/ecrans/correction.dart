import 'dart:async';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../composants/bouton.dart';
import '../composants/carte.dart';
import '../composants/chargement.dart';
import '../composants/etat_vide.dart';
import '../composants/mascotte.dart';
import '../composants/progression.dart';
import '../composants/puce.dart';
import '../donnees/modeles.dart';
import '../donnees/reglages.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../routage.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Le résultat d'une correction : attente, note, copie illisible ou échec.
///
/// L'écran **interroge** la route toutes les quelques secondes tant que la
/// correction n'est pas tranchée, plutôt que d'ouvrir un canal Realtime :
/// `corrections` n'est dans aucune publication, l'attente normale est de
/// vingt à soixante secondes, et un websocket sur un lien mobile béninois se
/// coupe sans arrêt. Surtout, chaque appel **relance** un traitement dont le
/// report est écoulé : l'attente de l'étudiant est le moteur des reprises.
class EcranCorrection extends ConsumerStatefulWidget {
  const EcranCorrection({super.key, required this.correctionId});

  final String correctionId;

  @override
  ConsumerState<EcranCorrection> createState() => _EcranCorrectionState();
}

class _EcranCorrectionState extends ConsumerState<EcranCorrection> {
  /// Cadence qui s'espace : serré au début, où la réponse est probable,
  /// relâché ensuite pour ne pas marteler la route.
  static const _cadences = [
    (jusqua: 10, secondes: 3),
    (jusqua: 24, secondes: 5),
    (jusqua: 999, secondes: 10),
  ];

  /// Au-delà, on cesse d'interroger et on propose un bouton : mieux vaut une
  /// action que trois minutes de roue qui tourne.
  static const _limiteSondages = 40;

  Timer? _minuteur;
  int _sondages = 0;

  @override
  void initState() {
    super.initState();
    _programmer();
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  void _programmer() {
    _minuteur?.cancel();
    if (_sondages >= _limiteSondages) return;

    final cadence = _cadences.firstWhere((c) => _sondages < c.jusqua).secondes;

    _minuteur = Timer(Duration(seconds: cadence), () {
      if (!mounted) return;
      _sondages++;
      ref.invalidate(correctionProvider(widget.correctionId));
      _programmer();
    });
  }

  void _relancerASonRythme() {
    setState(() => _sondages = 0);
    ref.invalidate(correctionProvider(widget.correctionId));
    _programmer();
  }

  @override
  Widget build(BuildContext context) {
    final correction = ref.watch(correctionProvider(widget.correctionId));

    // Tranché : plus rien à interroger.
    if (correction case AsyncData(:final value) when !value.enAttente) {
      _minuteur?.cancel();
    }

    return Scaffold(
      backgroundColor: Couleurs.fond,
      appBar: AppBar(
        backgroundColor: Couleurs.fond,
        surfaceTintColor: Colors.transparent,
        title: Text(Fr.correction.titre, style: Typo.headlineLg),
        leading: IconButton(
          onPressed: () => context.remonter(Chemins.corriger),
          icon: const Icon(Icons.arrow_back, color: Couleurs.encre),
          tooltip: Fr.commun.retour,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Mesures.largeurApp),
            child: switch (correction) {
              AsyncData(:final value) when value.prete => _Resultat(
                correction: value,
              ),
              // Rien n'a planté : l'étudiant n'a qu'à reprendre la photo.
              AsyncData(:final value) when value.illisible => _Message(
                mascotte: EtatMascotte.courage,
                titre: Fr.correction.illisible,
                description: value.motifIllisible,
                action: Fr.correction.reprendrePhoto,
              ),
              AsyncData(:final value) when value.echouee => _Message(
                mascotte: EtatMascotte.oups,
                titre: Fr.correction.echec,
                description: Fr.correction.echecDetail,
                action: Fr.correction.reprendrePhoto,
              ),
              AsyncData() => _Attente(
                epuise: _sondages >= _limiteSondages,
                onActualiser: _relancerASonRythme,
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
                    onTap: _relancerASonRythme,
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

/// L'attente pendant que le modèle corrige.
class _Attente extends StatelessWidget {
  const _Attente({required this.epuise, required this.onActualiser});

  final bool epuise;
  final VoidCallback onActualiser;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Espaces.ecran),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Le panthéreau corrige, stylo rouge en main. Il respire tant que
          // l'attente dure : une roue qui tourne trente secondes ressemble à
          // une panne.
          if (!epuise)
            const Mascotte(
              etat: EtatMascotte.stylo,
              taille: 140,
              enBoucle: true,
            )
          else
            // Plus long que prévu : il s'est assoupi en attendant, sans
            // que rien ne soit perdu.
            const Mascotte(etat: EtatMascotte.dodo, taille: 140),
          const SizedBox(height: Espaces.x20),
          Text(
            epuise ? Fr.correction.plusLongQuePrevu : Fr.correction.enCours,
            style: Typo.headlineMd,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Espaces.x8),
          Text(
            epuise
                ? Fr.correction.plusLongQuePrevuDetail
                : Fr.correction.enCoursDetail,
            style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
            textAlign: TextAlign.center,
          ),
          if (epuise) ...[
            const SizedBox(height: Espaces.x20),
            Bouton(
              libelle: Fr.correction.actualiser,
              icone: Icons.refresh,
              onTap: onActualiser,
            ),
          ],
        ],
      ),
    );
  }
}

/// Copie illisible, ou correction en échec. Deux états distincts : dans le
/// premier, rien n'a planté — l'étudiant n'a qu'à reprendre la photo.
class _Message extends StatelessWidget {
  const _Message({
    required this.mascotte,
    required this.titre,
    required this.description,
    required this.action,
  });

  final EtatMascotte mascotte;
  final String titre;
  final String? description;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Espaces.ecran),
      child: EtatVide(
        mascotte: mascotte,
        titre: titre,
        description: description,
        action: Bouton(
          libelle: action,
          icone: Icons.photo_camera,
          onTap: () => context.remonter(Chemins.corriger),
        ),
      ),
    );
  }
}

/// La note, le barème et le retour.
class _Resultat extends ConsumerStatefulWidget {
  const _Resultat({required this.correction});

  final Correction correction;

  @override
  ConsumerState<_Resultat> createState() => _ResultatState();
}

class _ResultatState extends ConsumerState<_Resultat> {
  /// Le seuil de la session de QCM, repris tel quel : au-dessus on fête,
  /// en dessous on encourage.
  static const _seuil = 0.6;

  /// Au-delà, la copie mérite la couronne : 16/20 et plus.
  static const _excellence = 0.8;

  late final ConfettiController _confettis = ConfettiController(
    duration: const Duration(seconds: 2),
  );

  /// Palette strictement chaude : la réussite se fête en jaune et orange,
  /// jamais en vert (docs/DESIGN.md § 11).
  static const _couleursConfettis = [
    Couleurs.jaune,
    Couleurs.jauneDoux,
    Couleurs.orange,
    Couleurs.orangeDoux,
  ];

  bool _confettisLances = false;

  /// Et non `initState` : `MediaQuery` passe par un `InheritedWidget`, qu'on
  /// n'a pas le droit de consulter avant que les dépendances soient prêtes.
  /// L'y appeler lève, et les deux écrans de résultat échouaient au test.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_confettisLances) return;

    // Les animations réduites valent aussi pour les confettis : c'est le
    // réglage de l'écran profil, et la préférence système.
    final sansAnimation =
        MediaQuery.disableAnimationsOf(context) ||
        ref.read(animationsReduitesProvider);

    if (widget.correction.taux >= _seuil && !sansAnimation) {
      _confettisLances = true;
      _confettis.play();
    }
  }

  @override
  void dispose() {
    _confettis.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.correction;
    final reussi = c.taux >= _seuil;
    final retour = c.retour;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: Espaces.ecran,
            vertical: Espaces.x16,
          ),
          children: [
            Center(
              child: Mascotte(
                etat: c.taux >= _excellence
                    ? EtatMascotte.champion
                    : reussi
                    ? EtatMascotte.bravo
                    : EtatMascotte.courage,
                taille: 148,
              ),
            ),
            const SizedBox(height: Espaces.x8),
            Text(
              reussi
                  ? Fr.correction.bravo
                  : c.taux >= 0.4
                  ? Fr.correction.presque
                  : Fr.correction.aRevoir,
              style: Typo.headlineLg,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Espaces.x20),

            // --- La note
            Carte(
              enfants: [
                Text(
                  c.note == null || c.bareme == null
                      ? '—'
                      : Fr.correction.note(
                          nombreFr(c.note!),
                          nombreFr(c.bareme!),
                        ),
                  style: Typo.displayHerosMobile.copyWith(
                    color: reussi ? Couleurs.texteAccent : Couleurs.orangeProfond,
                  ),
                  textAlign: TextAlign.center,
                ),
                BarreProgression(valeur: c.taux),
              ],
            ),

            // --- Le barème, ligne par ligne
            if (c.lignes.isNotEmpty) ...[
              const SizedBox(height: Espaces.x20),
              Text(Fr.correction.leBareme, style: Typo.headlineMd),
              const SizedBox(height: Espaces.x12),
              for (final ligne in c.lignes) ...[
                _LigneBareme(ligne: ligne),
                const SizedBox(height: Espaces.x8),
              ],
            ],

            // --- Le retour rédigé
            if (retour != null) ...[
              const SizedBox(height: Espaces.x12),
              Carte(
                enfants: [
                  if (retour.resume != null)
                    Text(retour.resume!, style: Typo.bodyMd),

                  if (retour.pointsForts.isNotEmpty) ...[
                    Text(Fr.correction.pointsForts, style: Typo.labelLg),
                    Wrap(
                      spacing: Espaces.x8,
                      runSpacing: Espaces.x8,
                      children: [
                        for (final p in retour.pointsForts)
                          Puce(
                            libelle: p,
                            ton: TonPuce.jaune,
                            icone: Icons.check,
                          ),
                      ],
                    ),
                  ],

                  if (retour.aTravailler.isNotEmpty) ...[
                    Text(Fr.correction.aTravailler, style: Typo.labelLg),
                    Wrap(
                      spacing: Espaces.x8,
                      runSpacing: Espaces.x8,
                      children: [
                        for (final p in retour.aTravailler)
                          Puce(
                            libelle: p,
                            ton: TonPuce.orange,
                            icone: Icons.trending_up,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ],

            // --- Ce que la copie dit de son cours : les chapitres à revoir,
            // chacun à un appui de sa série de questions. C'est là que la
            // correction cesse d'être une note et devient un plan.
            if (retour != null &&
                (retour.notions.isNotEmpty ||
                    (retour.chapitres.isNotEmpty && c.coursId != null))) ...[
              const SizedBox(height: Espaces.x12),
              Carte(
                enfants: [
                  Text(Fr.correction.aRevoirCours, style: Typo.headlineSm),
                  if (retour.notions.isNotEmpty) ...[
                    Text(Fr.correction.notionsManquees, style: Typo.labelLg),
                    Wrap(
                      spacing: Espaces.x8,
                      runSpacing: Espaces.x8,
                      children: [
                        for (final n in retour.notions)
                          Puce(
                            libelle: n,
                            ton: TonPuce.orange,
                            icone: Icons.lightbulb_outline,
                          ),
                      ],
                    ),
                  ],
                  // Le titre entier au-dessus, le verbe dans le bouton :
                  // « Réviser : Le contrôle de consti… » coupait le titre.
                  if (c.coursId != null)
                    for (final (id, titre) in retour.chapitres) ...[
                      Text(titre, style: Typo.labelLg),
                      Bouton(
                        libelle: Fr.correction.reviserCeChapitre,
                        icone: Icons.bolt,
                        onTap: () => context.descendre(
                          Chemins.session(c.coursId!, chapitre: id),
                        ),
                      ),
                    ],
                ],
              ),
            ],

            const SizedBox(height: Espaces.x20),
            Bouton(
              libelle: Fr.correction.titre,
              icone: Icons.photo_camera,
              variante: VarianteBouton.secondaire,
              onTap: () => context.remonter(Chemins.corriger),
            ),
            const SizedBox(height: Espaces.x32),
          ],
        ),

        ConfettiWidget(
          confettiController: _confettis,
          blastDirectionality: BlastDirectionality.explosive,
          colors: _couleursConfettis,
          numberOfParticles: 18,
          shouldLoop: false,
        ),
      ],
    );
  }
}

class _LigneBareme extends StatelessWidget {
  const _LigneBareme({required this.ligne});

  final LigneBareme ligne;

  @override
  Widget build(BuildContext context) {
    return Carte(
      petite: true,
      enfants: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                ligne.critere,
                style: Typo.labelLg,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: Espaces.x8),
            Text(
              Fr.correction.lignePoints(
                nombreFr(ligne.points),
                nombreFr(ligne.maximum),
              ),
              style: Typo.labelLg.copyWith(color: Couleurs.texteAccent),
            ),
          ],
        ),
        BarreProgression(valeur: ligne.part),
        if (ligne.commentaire != null)
          Text(
            ligne.commentaire!,
            style: Typo.labelSm.copyWith(color: Couleurs.attenue),
          ),
      ],
    );
  }
}
