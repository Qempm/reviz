import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../composants/bouton.dart';
import '../composants/chargement.dart';
import '../composants/etat_vide.dart';
import '../composants/progression.dart';
import '../donnees/modeles.dart';
import '../donnees/reglages.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../routage.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Les fiches d'un cours, retournables.
///
/// Une fiche à l'écran, comme une question de QCM : sur 375 px, deux fiches
/// côte à côte seraient illisibles, et une liste déroulante ferait perdre
/// l'effort de rappel qui fait tout l'intérêt de la fiche.
class EcranFiches extends ConsumerWidget {
  const EcranFiches({super.key, required this.coursId});

  final String coursId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fiches = ref.watch(fichesProvider(coursId));

    return Scaffold(
      backgroundColor: Couleurs.fond,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Mesures.largeurApp),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Espaces.ecran),
              child: switch (fiches) {
                AsyncData(:final value) when value.isEmpty => _Vide(
                  coursId: coursId,
                ),
                AsyncData(:final value) => _Paquet(
                  coursId: coursId,
                  fiches: value,
                ),
                AsyncError(:final error) => EtatVide(
                  icone: Icons.cloud_off,
                  titre: Fr.erreurs.chargementImpossible,
                  description: '$error',
                  action: Bouton(
                    libelle: Fr.session.retourCours,
                    icone: Icons.arrow_back,
                    variante: VarianteBouton.secondaire,
                    onTap: () => context.remonter(Chemins.cours(coursId)),
                  ),
                ),
                _ => const Chargement.liste(),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Vide extends StatelessWidget {
  const _Vide({required this.coursId});

  final String coursId;

  @override
  Widget build(BuildContext context) {
    return EtatVide(
      icone: Icons.style,
      titre: Fr.fiches.aucune,
      description: Fr.fiches.aucuneDetail,
      action: Bouton(
        libelle: Fr.session.retourCours,
        icone: Icons.arrow_back,
        variante: VarianteBouton.secondaire,
        onTap: () => context.remonter(Chemins.cours(coursId)),
      ),
    );
  }
}

class _Paquet extends ConsumerStatefulWidget {
  const _Paquet({required this.coursId, required this.fiches});

  final String coursId;
  final List<Fiche> fiches;

  @override
  ConsumerState<_Paquet> createState() => _PaquetState();
}

class _PaquetState extends ConsumerState<_Paquet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _retournement = AnimationController(
    duration: const Duration(milliseconds: 420),
    vsync: this,
  );

  int _index = 0;
  final _vues = <int>{0};

  Fiche get _fiche => widget.fiches[_index];
  bool get _retournee => _retournement.value > 0.5;

  @override
  void dispose() {
    _retournement.dispose();
    super.dispose();
  }

  void _basculer() {
    // Les deux sources comptent : `MediaQuery.disableAnimations` porte la
    // préférence système, et le réglage de l'écran profil ne concerne que
    // Reviz. Sans animation, la fiche bascule d'un coup — elle bascule tout
    // de même, c'est l'information qui compte.
    final sansAnimation =
        MediaQuery.disableAnimationsOf(context) ||
        ref.read(animationsReduitesProvider);

    if (sansAnimation) {
      _retournement.value = _retournee ? 0 : 1;
      setState(() {});
      return;
    }
    if (_retournee) {
      _retournement.reverse();
    } else {
      _retournement.forward();
    }
  }

  void _aller(int delta) {
    final suivant = (_index + delta).clamp(0, widget.fiches.length - 1);
    if (suivant == _index) return;
    setState(() {
      _index = suivant;
      _vues.add(suivant);
      _retournement.value = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final derniere = _index == widget.fiches.length - 1;
    final toutesVues = _vues.length == widget.fiches.length;

    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.remonter(Chemins.cours(widget.coursId)),
            icon: const Icon(Icons.arrow_back, size: 20),
            label: Text(Fr.session.retourCours),
            style: TextButton.styleFrom(
              foregroundColor: Couleurs.attenue,
              minimumSize: const Size(0, Mesures.zoneTactile),
            ),
          ),
        ),

        BarreSegmentee(
          segments: [
            for (var i = 0; i < widget.fiches.length; i++)
              _vues.contains(i) ? EtatSegment.juste : EtatSegment.aVenir,
          ],
        ),
        const SizedBox(height: Espaces.x8),
        Text(
          Fr.fiches.position(_index + 1, widget.fiches.length),
          style: Typo.labelSm.copyWith(color: Couleurs.attenue),
        ),
        const SizedBox(height: Espaces.x16),

        Expanded(
          child: Center(
            child: GestureDetector(
              onTap: _basculer,
              child: AnimatedBuilder(
                animation: _retournement,
                builder: (context, _) {
                  final angle = _retournement.value * math.pi;
                  final verso = angle > math.pi / 2;

                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      // Un peu de perspective, sinon la rotation ressemble à
                      // un simple aplatissement.
                      ..setEntry(3, 2, 0.0012)
                      ..rotateY(angle),
                    child: verso
                        // La face arrière est contre-tournée, sinon son
                        // texte apparaîtrait en miroir.
                        ? Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()..rotateY(math.pi),
                            child: _Face(
                              etiquette: Fr.fiches.verso,
                              texte: _fiche.verso,
                              chapitre: _fiche.chapitre,
                              versoStyle: true,
                            ),
                          )
                        : _Face(
                            etiquette: Fr.fiches.recto,
                            texte: _fiche.recto,
                            chapitre: _fiche.chapitre,
                            versoStyle: false,
                          ),
                  );
                },
              ),
            ),
          ),
        ),

        Text(
          toutesVues && derniere ? Fr.fiches.terminee : Fr.fiches.sousTitre,
          style: Typo.labelSm.copyWith(color: Couleurs.attenue),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Espaces.x12),

        Row(
          children: [
            Expanded(
              child: Bouton(
                libelle: Fr.fiches.precedente,
                icone: Icons.chevron_left,
                variante: VarianteBouton.secondaire,
                onTap: _index == 0 ? null : () => _aller(-1),
              ),
            ),
            const SizedBox(width: Espaces.x12),
            Expanded(
              child: derniere
                  ? Bouton(
                      libelle: Fr.fiches.recommencer,
                      icone: Icons.restart_alt,
                      onTap: () => setState(() {
                        _index = 0;
                        _retournement.value = 0;
                      }),
                    )
                  : Bouton(
                      libelle: Fr.fiches.suivante,
                      icone: Icons.chevron_right,
                      onTap: () => _aller(1),
                    ),
            ),
          ],
        ),
        const SizedBox(height: Espaces.x24),
      ],
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({
    required this.etiquette,
    required this.texte,
    required this.chapitre,
    required this.versoStyle,
  });

  final String etiquette;
  final String texte;
  final String? chapitre;
  final bool versoStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 280),
      width: double.infinity,
      padding: const EdgeInsets.all(Espaces.x24),
      decoration: BoxDecoration(
        color: versoStyle ? Couleurs.jauneDoux : Couleurs.carte,
        borderRadius: BorderRadius.circular(Rayons.carte),
        boxShadow: Ombres.carte,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            etiquette,
            style: Typo.caption.copyWith(color: Couleurs.attenue),
          ),
          const SizedBox(height: Espaces.x12),
          Text(
            texte,
            style: Typo.headlineMd.copyWith(
              color: versoStyle ? Couleurs.surJaune : Couleurs.encre,
            ),
            textAlign: TextAlign.center,
          ),
          if (chapitre != null) ...[
            const SizedBox(height: Espaces.x12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.bookmark_outline,
                  size: 16,
                  color: Couleurs.attenue,
                ),
                const SizedBox(width: Espaces.x4),
                Flexible(
                  child: Text(
                    chapitre!,
                    style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
