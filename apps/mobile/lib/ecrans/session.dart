import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../composants/bouton.dart';
import '../composants/carte.dart';
import '../composants/chargement.dart';
import '../composants/chiffre_anime.dart';
import '../composants/etat_vide.dart';
import '../composants/mascotte.dart';
import '../composants/option_qcm.dart';
import '../composants/progression.dart';
import '../composants/puce.dart';
import '../composants/niveau.dart';
import '../donnees/api.dart';
import '../donnees/file_hors_ligne.dart';
import '../donnees/modeles.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../metier/selection.dart';
import '../metier/identifiant.dart';
import '../metier/niveaux.dart';
import '../routage.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Session de QCM : une question par écran, puis le résultat.
///
/// La correction affichée est locale, pour être immédiate ; celle qui compte
/// est refaite par le serveur depuis `questions.answer`. Le client n'envoie
/// que **ce qu'il a choisi**, jamais son verdict — sans quoi une requête
/// bricolée vaudrait dix bonnes réponses et la première place du classement.
class EcranSession extends ConsumerWidget {
  const EcranSession({
    super.key,
    required this.coursId,
    this.chapitreId,
    this.mode = ModeSession.normal,
  });

  final String coursId;

  /// Donné : la session ne porte que sur ce chapitre.
  final String? chapitreId;
  final ModeSession mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questions = ref.watch(
      questionsProvider((cours: coursId, chapitre: chapitreId, mode: mode)),
    );

    return Scaffold(
      backgroundColor: Couleurs.fond,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Mesures.largeurApp),
            child: switch (questions) {
              AsyncData(:final value) when value.isEmpty => Padding(
                padding: const EdgeInsets.all(Espaces.ecran),
                child: EtatVide(
                  mascotte: mode == ModeSession.erreurs
                      ? EtatMascotte.bravo
                      : EtatMascotte.curieux,
                  titre: mode == ModeSession.erreurs
                      ? Fr.session.aucuneErreur
                      : Fr.session.aucuneQuestion,
                  description: mode == ModeSession.erreurs
                      ? Fr.session.aucuneErreurDetail
                      : Fr.session.aucuneQuestionDetail,
                  action: Bouton(
                    libelle: Fr.session.retourCours,
                    icone: Icons.arrow_back,
                    variante: VarianteBouton.secondaire,
                    onTap: () => context.remonter(Chemins.cours(coursId)),
                  ),
                ),
              ),
              AsyncData(:final value) => _Session(
                coursId: coursId,
                chapitreId: chapitreId,
                questions: value,
              ),
              AsyncError() => Padding(
                padding: const EdgeInsets.all(Espaces.ecran),
                child: EtatVide(
                  mascotte: EtatMascotte.oups,
                  titre: Fr.erreurs.chargementImpossible,
                  description: Fr.erreurs.chargementDetail,
                  action: Bouton(
                    libelle: Fr.session.retourCours,
                    icone: Icons.arrow_back,
                    variante: VarianteBouton.secondaire,
                    onTap: () => context.remonter(Chemins.cours(coursId)),
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

class _Session extends ConsumerStatefulWidget {
  const _Session({
    required this.coursId,
    required this.questions,
    this.chapitreId,
  });

  final String coursId;
  final String? chapitreId;
  final List<QuestionQcm> questions;

  @override
  ConsumerState<_Session> createState() => _SessionState();
}

class _SessionState extends ConsumerState<_Session> {
  static const _lettres = ['A', 'B', 'C', 'D', 'E', 'F'];

  int _index = 0;
  String? _choix;
  bool _corrige = false;
  bool _enCours = false;

  final _reponses = <({String questionId, String? choix})>[];
  late final List<EtatSegment> _etats = List.filled(
    widget.questions.length,
    EtatSegment.aVenir,
  );

  ResultatSession? _resultat;
  int? _xpAvant;
  String? _erreurEnvoi;

  /// Tiré au départ : si la série doit attendre le réseau, son renvoi sera
  /// reconnu par le serveur et ne comptera pas deux fois.
  final String _sessionId = identifiantAleatoire();

  /// Série finie sans réseau, gardée dans la file (`FileHorsLigne`).
  bool _gardee = false;

  QuestionQcm get _question => widget.questions[_index];
  bool get _derniere => _index == widget.questions.length - 1;

  void _valider() {
    if (_choix == null || _corrige) return;

    final juste = _choix == _question.reponse;
    setState(() {
      _corrige = true;
      _etats[_index] = juste ? EtatSegment.juste : EtatSegment.faux;
      _reponses.add((questionId: _question.id, choix: _choix));
    });
  }

  /// Quitter une série entamée la perd : on le dit avant, pas après.
  Future<void> _quitter() async {
    if (_reponses.isEmpty) {
      context.remonter(Chemins.cours(widget.coursId));
      return;
    }
    final quitter = await showDialog<bool>(
      context: context,
      builder: (contexte) => AlertDialog(
        title: Text(Fr.session.quitterTitre),
        content: Text(Fr.session.quitterDetail),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexte).pop(false),
            child: Text(Fr.session.quitterNon),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexte).pop(true),
            child: Text(Fr.session.quitterOui),
          ),
        ],
      ),
    );
    if (quitter == true && mounted) {
      context.remonter(Chemins.cours(widget.coursId));
    }
  }

  Future<void> _suivant() async {
    if (!_derniere) {
      setState(() {
        _index++;
        _choix = null;
        _corrige = false;
      });
      return;
    }

    setState(() => _enCours = true);

    final reponse = await ref
        .read(depotCoursProvider)
        .terminerSession(
          api: ref.read(apiProvider),
          coursId: widget.coursId,
          reponses: _reponses,
          sessionId: _sessionId,
        );

    if (!mounted) return;

    // Pas de réseau : la série n'est pas perdue, elle attend.
    if (reponse case ReponseEchec(motif: 'reseau')) {
      final gardee = await ref
          .read(fileHorsLigneProvider)
          .ajouter(
            SessionEnAttente(
              sessionId: _sessionId,
              coursId: widget.coursId,
              reponses: List.of(_reponses),
              le: DateTime.now(),
            ),
          );
      if (!mounted) return;
      if (gardee) {
        setState(() {
          _gardee = true;
          _enCours = false;
        });
        return;
      }
    }

    switch (reponse) {
      case ReponseSucces(:final data):
        // L'XP d'avant, lue avant que le profil ne se recharge : la barre de
        // niveau part de là.
        _xpAvant = ref.read(profilProvider).value?.xpTotal;
        // Les compteurs ont bougé en base : l'accueil et le cours doivent se
        // relire, sinon l'étudiant revient sur des chiffres périmés.
        ref.invalidate(accueilProvider);
        ref.invalidate(profilProvider);
        ref.invalidate(ligueProvider);
        ref.invalidate(unCoursProvider(widget.coursId));
        // Une couronne se gagne — ou se perd — ici.
        ref.invalidate(cheminProvider(widget.coursId));
        ref.invalidate(coursProvider);
        // Le moment où un rappel a du sens : il vient de faire une série.
        ref.read(servicePushProvider).demanderPermissionUneFois();
        setState(() {
          _resultat = data;
          _enCours = false;
        });
      case ReponseEchec(:final erreur):
        setState(() {
          _erreurEnvoi = erreur;
          _enCours = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_resultat != null || _erreurEnvoi != null || _gardee) {
      return _Resultat(
        gardee: _gardee,
        coursId: widget.coursId,
        chapitreId: widget.chapitreId,
        resultat: _resultat,
        erreur: _erreurEnvoi,
        etats: _etats,
        xpAvant: _xpAvant,
        total: widget.questions.length,
      );
    }

    final attendue = _question.reponse;
    final juste = _corrige && _choix == attendue;

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaces.ecran,
        vertical: Espaces.x16,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: BarreSegmentee(
                segments: [
                  for (var i = 0; i < _etats.length; i++)
                    if (i == _index && !_corrige)
                      EtatSegment.aVenir
                    else
                      _etats[i],
                ],
              ),
            ),
            const SizedBox(width: Espaces.x12),
            IconButton(
              onPressed: _quitter,
              icon: const Icon(Icons.close),
              color: Couleurs.attenue,
              tooltip: Fr.session.retourCours,
            ),
          ],
        ),
        const SizedBox(height: Espaces.x8),

        Row(
          children: [
            Expanded(
              child: Text(
                Fr.session.question(_index + 1, widget.questions.length),
                style: Typo.labelSm.copyWith(color: Couleurs.attenue),
              ),
            ),
            if (_question.souventPosee)
              Puce(
                libelle: Fr.session.probable,
                ton: TonPuce.orange,
                icone: Icons.local_fire_department,
              ),
          ],
        ),
        const SizedBox(height: Espaces.x16),

        Carte(enfants: [Text(_question.enonce, style: Typo.headlineMd)]),
        const SizedBox(height: Espaces.x12),

        for (var i = 0; i < _question.options.length; i++) ...[
          if (i > 0) const SizedBox(height: Espaces.x8),
          OptionQcm(
            lettre: i < _lettres.length ? _lettres[i] : '?',
            libelle: _question.options[i],
            etat: _etatOption(_question.options[i], attendue),
            onTap: _corrige
                ? null
                : () => setState(() => _choix = _question.options[i]),
          ),
        ],

        // Retour immédiat.
        if (_corrige) ...[
          const SizedBox(height: Espaces.x12),
          Carte(
            petite: true,
            enfants: [
              Row(
                children: [
                  Icon(
                    juste ? Icons.check_circle : Icons.cancel,
                    size: 20,
                    color: juste
                        ? Couleurs.texteAccent
                        : Couleurs.surDangerDoux,
                  ),
                  const SizedBox(width: Espaces.x8),
                  Expanded(
                    child: Text(
                      juste ? Fr.session.juste : Fr.session.faux,
                      style: Typo.labelLg.copyWith(
                        color: juste
                            ? Couleurs.texteAccent
                            : Couleurs.surDangerDoux,
                      ),
                    ),
                  ),
                ],
              ),
              if (!juste)
                Text(
                  '${Fr.session.bonneReponse} : $attendue',
                  style: Typo.labelMd,
                ),
              if (_question.explication != null)
                Text(
                  _question.explication!,
                  style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
                ),
            ],
          ),
        ],

        const SizedBox(height: Espaces.x16),
        if (_corrige)
          Bouton(
            libelle: _enCours
                ? Fr.commun.chargement
                : _derniere
                ? Fr.session.voirResultat
                : Fr.session.suivante,
            icone: _derniere ? Icons.flag : Icons.arrow_forward,
            onTap: _enCours ? null : _suivant,
          )
        else
          Bouton(
            libelle: Fr.session.valider,
            icone: Icons.check,
            onTap: _choix == null ? null : _valider,
          ),

        const SizedBox(height: Espaces.x32),
      ],
    );
  }

  EtatOption _etatOption(String option, String attendue) {
    if (!_corrige) {
      return _choix == option ? EtatOption.choisie : EtatOption.repos;
    }
    if (option == attendue) return EtatOption.juste;
    if (option == _choix) return EtatOption.fausse;
    return EtatOption.repos;
  }
}

/// Écran de résultat.
class _Resultat extends StatefulWidget {
  const _Resultat({
    required this.coursId,
    this.chapitreId,
    required this.resultat,
    required this.erreur,
    required this.etats,
    required this.total,
    this.xpAvant,
    this.gardee = false,
  });

  /// Série finie hors ligne et gardée : elle partira au retour du réseau.
  final bool gardee;

  final String coursId;
  final String? chapitreId;
  final ResultatSession? resultat;

  /// L'XP totale avant cette session ; `null` si le profil n'était pas lu.
  final int? xpAvant;
  final String? erreur;
  final List<EtatSegment> etats;
  final int total;

  @override
  State<_Resultat> createState() => _ResultatState();
}

class _ResultatState extends State<_Resultat> {
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

  /// Dans `didChangeDependencies` et non `initState` : on y lit `MediaQuery`.
  ///
  /// Les confettis partaient ici sans condition, en ignorant le mouvement
  /// réduit — le seul écran à le faire. `MediaQuery` porte désormais aussi le
  /// réglage du profil (`MouvementReduit`, à la racine).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_confettisLances) return;
    _confettisLances = true;

    if (_pourcentage >= 60 && !MediaQuery.disableAnimationsOf(context)) {
      _confettis.play();
    }

    // Un niveau franchi se fête par-dessus le résultat, une fois la barre
    // remplie.
    final avant = widget.xpAvant;
    final r = widget.resultat;
    if (avant != null && r != null) {
      final numero = niveauDepuisXp(avant + r.xp).numero;
      if (numero > niveauDepuisXp(avant).numero) {
        final delai = MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 1100);
        Future<void>.delayed(delai, () {
          if (mounted) montrerNiveauSuperieur(context, numero);
        });
      }
    }
  }

  @override
  void dispose() {
    _confettis.dispose();
    super.dispose();
  }

  /// La session s'est déroulée, seul l'enregistrement a échoué : on montre le
  /// score compté localement plutôt qu'un écran d'erreur qui effacerait
  /// l'effort de l'étudiant.
  int get _bonnes =>
      widget.resultat?.bonnes ??
      widget.etats.where((e) => e == EtatSegment.juste).length;

  int get _erreurs => widget.etats.where((e) => e == EtatSegment.faux).length;

  int get _pourcentage =>
      widget.total == 0 ? 0 : (_bonnes / widget.total * 100).round();

  @override
  Widget build(BuildContext context) {
    final r = widget.resultat;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: Espaces.ecran,
            vertical: Espaces.x24,
          ),
          children: [
            Center(
              child: Mascotte(
                etat: _pourcentage == 100
                    ? EtatMascotte.champion
                    // La journée vient d'être validée : la flamme de la
                    // série, plutôt qu'un simple bravo.
                    : widget.resultat?.gains.any(
                            (g) => g.motif == 'daily_goal',
                          ) ??
                          false
                    ? EtatMascotte.flamme
                    : _pourcentage >= 60
                    ? EtatMascotte.bravo
                    : EtatMascotte.courage,
                taille: 148,
              ),
            ),
            const SizedBox(height: Espaces.x8),
            Text(
              Fr.session.resultatTitre,
              style: Typo.headlineLg,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Espaces.x20),

            Carte(
              enfants: [
                ChiffreAnime(
                  valeur: _bonnes,
                  depuisZero: true,
                  construire: (n) => Text(
                    Fr.session.score(n, widget.total),
                    style: Typo.displayHerosMobile.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Text(
                  Fr.session.precision(_pourcentage),
                  style: Typo.labelMd.copyWith(color: Couleurs.attenue),
                  textAlign: TextAlign.center,
                ),
                BarreSegmentee(segments: widget.etats),
              ],
            ),
            const SizedBox(height: Espaces.x16),

            if (r != null)
              Carte(
                enfants: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          Fr.session.xpGagnes(r.xp),
                          style: Typo.labelLg,
                        ),
                      ),
                      if (r.objectifAtteint)
                        Puce(
                          libelle: Fr.session.serie(r.serie),
                          ton: TonPuce.jaune,
                          icone: Icons.local_fire_department,
                        ),
                    ],
                  ),
                  if (widget.xpAvant != null) ...[
                    BarreNiveau(
                      xpAvant: widget.xpAvant!,
                      xpApres: widget.xpAvant! + r.xp,
                    ),
                    const Divider(
                      height: Espaces.x8,
                      color: Couleurs.surfaceHaute,
                    ),
                  ],
                  for (final g in r.gains)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            Fr.session.detailXp[g.motif] ?? g.motif,
                            style: Typo.labelSm.copyWith(
                              color: Couleurs.attenue,
                            ),
                          ),
                        ),
                        Text('+${g.montant}', style: Typo.labelSm),
                      ],
                    ),
                ],
              )
            else if (widget.gardee)
              Carte(
                petite: true,
                enfants: [
                  Row(
                    children: [
                      const TeteMascotte(
                        etat: EtatMascotte.horsLigne,
                        taille: 44,
                      ),
                      const SizedBox(width: Espaces.x12),
                      Expanded(
                        child: Text(
                          Fr.session.gardeeTitre,
                          style: Typo.labelLg,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    Fr.session.gardeeDetail,
                    style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                  ),
                ],
              )
            else
              Carte(
                petite: true,
                enfants: [
                  Text(
                    Fr.session.echecEnregistrement,
                    style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                  ),
                  if (widget.erreur != null)
                    Text(
                      widget.erreur!,
                      style: Typo.labelSm.copyWith(color: Couleurs.danger),
                    ),
                ],
              ),

            const SizedBox(height: Espaces.x20),
            // Des erreurs : les revoir tout de suite, c'est là que s'apprend
            // le plus. Elles sont enregistrées quand le résultat l'est.
            if (_erreurs > 0 && widget.resultat != null) ...[
              Bouton(
                libelle: Fr.session.revoirErreurs(_erreurs),
                icone: Icons.replay,
                onTap: () => context.pushReplacement(
                  Chemins.session(
                    widget.coursId,
                    chapitre: widget.chapitreId,
                    erreurs: true,
                  ),
                ),
              ),
              const SizedBox(height: Espaces.x8),
            ],
            Bouton(
              libelle: Fr.session.refaire,
              icone: Icons.restart_alt,
              variante: _erreurs > 0 && widget.resultat != null
                  ? VarianteBouton.secondaire
                  : VarianteBouton.principal,
              onTap: () => context.pushReplacement(
                Chemins.session(widget.coursId, chapitre: widget.chapitreId),
              ),
            ),
            const SizedBox(height: Espaces.x8),
            Bouton(
              libelle: Fr.session.retourCours,
              icone: Icons.arrow_back,
              variante: VarianteBouton.secondaire,
              onTap: () => context.remonter(Chemins.cours(widget.coursId)),
            ),
            const SizedBox(height: Espaces.x32),
          ],
        ),
        ConfettiWidget(
          confettiController: _confettis,
          blastDirectionality: BlastDirectionality.explosive,
          colors: _couleursConfettis,
          numberOfParticles: 24,
          maxBlastForce: 14,
          minBlastForce: 6,
          gravity: 0.25,
          shouldLoop: false,
        ),
      ],
    );
  }
}
