import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../composants/bouton.dart';
import '../composants/carte.dart';
import '../composants/etat_vide.dart';
import '../composants/mascotte.dart';
import '../composants/puce.dart';
import '../donnees/api.dart';
import '../donnees/tuteur.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../metier/plateforme.dart';
import '../metier/tuteur.dart';
import '../routage.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Le tuteur de maîtrise : trois questions ouvertes sur un chapitre, après
/// une série de QCM.
///
/// Le QCM vérifie qu'on reconnaît la bonne réponse ; le tuteur, qu'on sait
/// l'expliquer. L'étudiant tape sa réponse, le tuteur la juge en deux
/// phrases — juste en jaune, en partie en orange, pas encore en rouge, jamais
/// de vert — puis pose la suivante. Après la troisième, un bilan : maîtrisé
/// (deux points sur trois) ou à revoir.
///
/// Réservé aux packs, avec un essai gratuit par compte. C'est le serveur qui
/// tranche ; l'écran dit seulement ce qu'il a répondu.
class EcranTuteur extends ConsumerStatefulWidget {
  const EcranTuteur({
    super.key,
    required this.coursId,
    required this.chapitreId,
  });

  final String coursId;
  final String chapitreId;

  @override
  ConsumerState<EcranTuteur> createState() => _EcranTuteurState();
}

/// Une ligne du fil : une question du tuteur, ou une réponse et son jugement.
sealed class _Ligne {
  const _Ligne();
}

class _Question extends _Ligne {
  const _Question(this.question);
  final QuestionTuteur question;
}

class _Reponse extends _Ligne {
  _Reponse(this.texte);
  final String texte;
  EvaluationTuteur? evaluation;
}

class _EcranTuteurState extends ConsumerState<EcranTuteur> {
  final _saisie = TextEditingController();
  final _defile = ScrollController();

  String? _sessionId;
  bool _essai = false;
  final List<_Ligne> _fil = [];
  FinTuteur? _fin;

  /// Le tuteur prépare une question ou lit une réponse.
  bool _attente = true;
  ReponseEchec<Object?>? _echec;

  @override
  void initState() {
    super.initState();
    _demarrer();
  }

  @override
  void dispose() {
    _saisie.dispose();
    _defile.dispose();
    super.dispose();
  }

  Future<void> _demarrer() async {
    setState(() {
      _attente = true;
      _echec = null;
    });
    final r = await ref
        .read(depotTuteurProvider)
        .demarrer(coursId: widget.coursId, chapitreId: widget.chapitreId);
    if (!mounted) return;
    setState(() {
      _attente = false;
      switch (r) {
        case ReponseSucces(:final data):
          _sessionId = data.sessionId;
          _essai = data.essai;
          _fil
            ..clear()
            ..add(_Question(data.question));
        case ReponseEchec(:final erreur, :final motif, :final statut):
          _echec = ReponseEchec(erreur, motif: motif, statut: statut);
      }
    });
  }

  Future<void> _envoyer() async {
    final texte = _saisie.text.trim();
    final id = _sessionId;
    if (texte.isEmpty || id == null || _attente) return;

    final ligne = _Reponse(texte);
    setState(() {
      _fil.add(ligne);
      _attente = true;
      _saisie.clear();
    });
    _versLeBas();

    final r = await ref
        .read(depotTuteurProvider)
        .repondre(sessionId: id, reponse: texte);
    if (!mounted) return;

    switch (r) {
      case ReponseSucces(:final data):
        setState(() {
          _attente = false;
          ligne.evaluation = data.evaluation;
          switch (data.suite) {
            case final QuestionTuteur q:
              _fil.add(_Question(q));
            case final FinTuteur f:
              _fin = f;
          }
        });
      case ReponseEchec(:final erreur):
        // La réponse n'est pas perdue : elle revient dans le champ.
        setState(() {
          _attente = false;
          _fil.remove(ligne);
          _saisie.text = texte;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(erreur)));
    }
    _versLeBas();
  }

  void _versLeBas() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_defile.hasClients) return;
      final reduit = MediaQuery.disableAnimationsOf(context);
      final cible = _defile.position.maxScrollExtent;
      if (reduit) {
        _defile.jumpTo(cible);
      } else {
        _defile.animateTo(
          cible,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final f = Fr.tuteur;
    return Scaffold(
      backgroundColor: Couleurs.fond,
      appBar: AppBar(
        backgroundColor: Couleurs.fond,
        surfaceTintColor: Colors.transparent,
        title: Text(f.titre, style: Typo.headlineLg),
        leading: IconButton(
          onPressed: () => context.remonter(Chemins.cours(widget.coursId)),
          icon: const Icon(Icons.arrow_back, color: Couleurs.encre),
          tooltip: Fr.commun.retour,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Mesures.largeurApp),
            child: _echec != null ? _refus(_echec!) : _conversation(),
          ),
        ),
      ),
    );
  }

  Widget _refus(ReponseEchec<Object?> e) {
    final f = Fr.tuteur;
    if (e.motif == 'essai-utilise') {
      return Center(
        child: EtatVide(
          mascotte: EtatMascotte.cadeau,
          titre: f.packTitre,
          description: achatsDansLApplication ? f.packDetail : f.packSansAchat,
          action: achatsDansLApplication
              ? Bouton(
                  libelle: f.voirPacks,
                  icone: Icons.shopping_bag_outlined,
                  onTap: () => context.go(Chemins.boutique),
                )
              : null,
        ),
      );
    }
    final reseau = e.motif == 'reseau';
    return Center(
      child: EtatVide(
        mascotte: reseau ? EtatMascotte.horsLigne : EtatMascotte.oups,
        titre: reseau ? f.reseau : f.erreurTitre,
        description: reseau ? null : e.erreur,
        action: Bouton(
          libelle: e.motif == 'plafond-du-jour' ? f.quitter : f.reessayer,
          icone: e.motif == 'plafond-du-jour'
              ? Icons.arrow_back
              : Icons.refresh,
          onTap: e.motif == 'plafond-du-jour'
              ? () => context.remonter(Chemins.cours(widget.coursId))
              : _demarrer,
        ),
      ),
    );
  }

  Widget _conversation() {
    final f = Fr.tuteur;
    final fin = _fin;
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _defile,
            padding: const EdgeInsets.fromLTRB(
              Espaces.ecran,
              Espaces.x8,
              Espaces.ecran,
              Espaces.x24,
            ),
            children: [
              Text(
                f.sousTitre,
                style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
              ),
              if (_essai) ...[
                const SizedBox(height: Espaces.x12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Puce(
                    libelle: f.essai,
                    ton: TonPuce.bleu,
                    icone: Icons.card_giftcard,
                  ),
                ),
              ],
              const SizedBox(height: Espaces.x16),
              for (final l in _fil) ...[
                switch (l) {
                  _Question(:final question) => _BulleTuteur(question),
                  final _Reponse r => _BulleEtudiant(r),
                },
                const SizedBox(height: Espaces.x12),
              ],
              if (_attente) _Reflexion(premier: _fil.isEmpty),
              if (fin != null)
                _Bilan(
                  fin: fin,
                  onRevoir: () => context.pushReplacement(
                    Chemins.session(
                      widget.coursId,
                      chapitre: widget.chapitreId,
                    ),
                  ),
                  onTerminer: () =>
                      context.remonter(Chemins.cours(widget.coursId)),
                ),
            ],
          ),
        ),
        if (fin == null && _sessionId != null) _saisieReponse(),
      ],
    );
  }

  Widget _saisieReponse() {
    final f = Fr.tuteur;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        Espaces.ecran,
        Espaces.x12,
        Espaces.ecran,
        Espaces.x12,
      ),
      decoration: const BoxDecoration(
        color: Couleurs.carte,
        border: Border(top: BorderSide(color: Couleurs.bordure)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _saisie,
            enabled: !_attente,
            minLines: 2,
            maxLines: 5,
            maxLength: reponseMax,
            textCapitalization: TextCapitalization.sentences,
            style: Typo.bodyLg,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: f.champ,
              hintText: f.champAide,
              counterText: '',
              filled: true,
              fillColor: Couleurs.surfaceBasse,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Rayons.normal),
                borderSide: const BorderSide(color: Couleurs.bordure),
              ),
            ),
          ),
          const SizedBox(height: Espaces.x8),
          Bouton(
            libelle: f.envoyer,
            icone: Icons.send,
            chargement: _attente,
            onTap: _attente || _saisie.text.trim().isEmpty ? null : _envoyer,
          ),
        ],
      ),
    );
  }
}

class _BulleTuteur extends StatelessWidget {
  const _BulleTuteur(this.question);

  final QuestionTuteur question;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TeteMascotte(etat: EtatMascotte.curieux, taille: 34),
        const SizedBox(width: Espaces.x8),
        Expanded(
          child: Carte(
            enfants: [
              Text(
                Fr.tuteur.question(question.numero, question.total),
                style: Typo.labelSm.copyWith(color: Couleurs.orangeProfond),
              ),
              Text(question.texte, style: Typo.headlineSm),
            ],
          ),
        ),
      ],
    );
  }
}

class _BulleEtudiant extends StatelessWidget {
  const _BulleEtudiant(this.reponse);

  final _Reponse reponse;

  @override
  Widget build(BuildContext context) {
    final ev = reponse.evaluation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: Espaces.x40),
          child: Container(
            padding: const EdgeInsets.all(Espaces.x16),
            decoration: ShapeDecoration(
              color: Couleurs.jauneDoux,
              shape: formeContinue(Rayons.normal),
            ),
            child: Text(reponse.texte, style: Typo.bodyMd),
          ),
        ),
        if (ev != null) ...[const SizedBox(height: Espaces.x8), _Jugement(ev)],
      ],
    );
  }
}

/// Le jugement d'une réponse : jaune, orange ou rouge — jamais de vert.
class _Jugement extends StatelessWidget {
  const _Jugement(this.evaluation);

  final EvaluationTuteur evaluation;

  @override
  Widget build(BuildContext context) {
    final f = Fr.tuteur;
    final (fond, encre, libelle, icone) = switch (evaluation.niveau) {
      NiveauReponse.juste => (
        Couleurs.jauneDoux,
        Couleurs.encre,
        f.juste,
        Icons.check_circle,
      ),
      NiveauReponse.partiel => (
        Couleurs.orangeDoux,
        Couleurs.orangeProfond,
        f.partiel,
        Icons.adjust,
      ),
      NiveauReponse.faux => (
        Couleurs.dangerDoux,
        Couleurs.surDangerDoux,
        f.faux,
        Icons.cancel_outlined,
      ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Espaces.x12),
      decoration: ShapeDecoration(
        color: fond,
        shape: formeContinue(Rayons.moyen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 18, color: encre),
              const SizedBox(width: Espaces.x8),
              Text(libelle, style: Typo.labelMd.copyWith(color: encre)),
            ],
          ),
          if (evaluation.retour.isNotEmpty) ...[
            const SizedBox(height: Espaces.x4),
            Text(evaluation.retour, style: Typo.bodyMd),
          ],
        ],
      ),
    );
  }
}

class _Reflexion extends StatelessWidget {
  const _Reflexion({required this.premier});

  final bool premier;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Espaces.x12),
      child: Row(
        children: [
          const Mascotte(etat: EtatMascotte.reflexion, taille: 64),
          const SizedBox(width: Espaces.x12),
          Expanded(
            child: Text(
              premier ? Fr.tuteur.demarrage : Fr.tuteur.reflexion,
              style: Typo.labelMd.copyWith(color: Couleurs.attenue),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bilan extends StatelessWidget {
  const _Bilan({
    required this.fin,
    required this.onRevoir,
    required this.onTerminer,
  });

  final FinTuteur fin;
  final VoidCallback onRevoir;
  final VoidCallback onTerminer;

  @override
  Widget build(BuildContext context) {
    final f = Fr.tuteur;
    return Carte(
      enfants: [
        Center(
          child: Mascotte(
            etat: fin.maitrise ? EtatMascotte.bravo : EtatMascotte.courage,
            taille: 120,
          ),
        ),
        Text(
          fin.maitrise ? f.maitriseTitre : f.aRevoirTitre,
          style: Typo.headlineLg,
          textAlign: TextAlign.center,
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: Espaces.x8,
          runSpacing: Espaces.x8,
          children: [
            Puce(
              libelle: f.score(fin.score, questionsParSession),
              ton: fin.maitrise ? TonPuce.jaune : TonPuce.orange,
            ),
            if (fin.maitrise)
              Puce(libelle: f.xp, ton: TonPuce.jaune, icone: Icons.bolt),
          ],
        ),
        Text(fin.bilan, style: Typo.bodyMd),
        if (fin.aRevoir.isNotEmpty) ...[
          Text(f.notions, style: Typo.labelLg),
          for (final n in fin.aRevoir)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6, right: Espaces.x8),
                  child: Icon(Icons.circle, size: 6, color: Couleurs.orange),
                ),
                Expanded(child: Text(n, style: Typo.bodyMd)),
              ],
            ),
        ],
        const SizedBox(height: Espaces.x4),
        if (fin.maitrise) ...[
          Bouton(libelle: f.terminer, icone: Icons.check, onTap: onTerminer),
          Bouton(
            libelle: f.revoirChapitre,
            icone: Icons.replay,
            variante: VarianteBouton.secondaire,
            onTap: onRevoir,
          ),
        ] else ...[
          Bouton(
            libelle: f.revoirChapitre,
            icone: Icons.replay,
            onTap: onRevoir,
          ),
          Bouton(
            libelle: f.terminer,
            variante: VarianteBouton.secondaire,
            onTap: onTerminer,
          ),
        ],
      ],
    );
  }
}
