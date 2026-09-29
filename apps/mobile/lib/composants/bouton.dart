import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Les trois variantes de bouton du design system.
enum VarianteBouton { principal, secondaire, danger }

/// Bouton Reviz.
///
/// L'ancienne signature — une ombre pleine sans flou sous le bouton, dans
/// laquelle il descendait à l'appui — est abandonnée par l'arbitrage du
/// 29 septembre 2026 : c'était elle, avec le brun, qui donnait l'air amateur.
///
/// Le relief vient maintenant de trois choses :
///
///  * une **forme continue** (coins en superellipse, pas en quart de cercle) ;
///  * pour le bouton principal, un **halo teinté de jaune** plutôt qu'une
///    ombre grise, qui salit le jaune ;
///  * et le geste : sous le doigt le bouton **se contracte**, puis revient sur
///    le ressort de la navigation, avec un léger dépassement. C'est ce retour
///    qui donne l'impression d'un objet qui a une masse.
class Bouton extends StatefulWidget {
  const Bouton({
    super.key,
    required this.libelle,
    this.onTap,
    this.variante = VarianteBouton.principal,
    this.icone,
    this.chargement = false,
  });

  final String libelle;
  final VoidCallback? onTap;
  final VarianteBouton variante;
  final IconData? icone;

  /// Une action est en cours : le bouton garde sa place, montre qu'il
  /// travaille, et ne se laisse plus toucher. Mieux qu'un libellé remplacé
  /// par « Un instant… », qui fait sauter la largeur du texte.
  final bool chargement;

  bool get actif => onTap != null && !chargement;

  @override
  State<Bouton> createState() => _BoutonState();
}

class _BoutonState extends State<Bouton> {
  bool _enfonce = false;

  ({Color fond, Color texte, List<BoxShadow> ombre, List<BoxShadow> ombreEnfoncee})
  get _palette => switch (widget.variante) {
    VarianteBouton.principal => (
      fond: Couleurs.jaune,
      texte: Couleurs.surJaune,
      ombre: Ombres.lueurJaune,
      ombreEnfoncee: Ombres.lueurJauneEnfoncee,
    ),
    // Un gris de remplissage plutôt qu'un blanc bordé : c'est le bouton
    // secondaire d'iOS. Il se voit sur une carte blanche comme sur le fond.
    VarianteBouton.secondaire => (
      fond: Couleurs.surfaceConteneur,
      texte: Couleurs.encre,
      ombre: const [],
      ombreEnfoncee: const [],
    ),
    VarianteBouton.danger => (
      fond: Couleurs.danger,
      texte: Colors.white,
      ombre: const [
        BoxShadow(color: Color(0x33D92D20), blurRadius: 16, offset: Offset(0, 6)),
      ],
      ombreEnfoncee: const [
        BoxShadow(color: Color(0x33D92D20), blurRadius: 6, offset: Offset(0, 2)),
      ],
    ),
  };

  void _enfoncer(bool oui) {
    if (_enfonce != oui) setState(() => _enfonce = oui);
  }

  void _toucher() {
    // Un choc léger sous le doigt pour l'action principale : on sent que
    // quelque chose est parti.
    if (widget.variante == VarianteBouton.principal) {
      HapticFeedback.lightImpact();
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette;
    final actif = widget.actif;
    final reduit = MediaQuery.disableAnimationsOf(context);
    final couleurTexte = actif || widget.chargement ? p.texte : Couleurs.attenue;

    return Semantics(
      button: true,
      enabled: actif,
      label: widget.libelle,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: actif ? (_) => _enfoncer(true) : null,
        onTapUp: actif ? (_) => _enfoncer(false) : null,
        onTapCancel: actif ? () => _enfoncer(false) : null,
        onTap: actif ? _toucher : null,
        child: AnimatedScale(
          // Contraction rapide à l'appui ; au relâché, le ressort — et son
          // dépassement. Durée et courbe changent selon le sens, ce que
          // `AnimatedScale` accepte en cours de route.
          scale: _enfonce && !reduit ? 0.97 : 1,
          duration: _enfonce ? Mouvement.appui : Mouvement.glisse,
          curve: _enfonce ? Curves.easeOut : Mouvement.courbeGlisse,
          child: AnimatedContainer(
            duration: Mouvement.appui,
            height: Mesures.hauteurCta,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: Espaces.x16),
            decoration: ShapeDecoration(
              color: actif || widget.chargement ? p.fond : Couleurs.surfaceHaute,
              shape: formeContinue(Rayons.normal),
              shadows: actif ? (_enfonce ? p.ombreEnfoncee : p.ombre) : const [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.chargement) ...[
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: couleurTexte,
                    ),
                  ),
                  const SizedBox(width: Espaces.x12),
                ] else if (widget.icone != null) ...[
                  Icon(widget.icone, size: 20, color: couleurTexte),
                  const SizedBox(width: Espaces.x8),
                ],
                // `Flexible` et non `Text` nu : un libellé long dans un bouton
                // étroit débordait — attrapé par le test de rendu à 375 px.
                Flexible(
                  child: Text(
                    widget.libelle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Typo.labelLg.copyWith(
                      color: couleurTexte,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
