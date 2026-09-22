import 'package:flutter/material.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Les quatre variantes de bouton du design system.
enum VarianteBouton { principal, secondaire, danger }

/// Bouton Reviz, avec la **signature tactile** : une ombre pleine sans flou
/// sous l'élément, réduite à l'appui, l'élément descendant d'autant. La
/// hauteur totale ne change donc pas — c'est ce qui donne la sensation
/// d'enfoncer un bouton plutôt que de le voir sauter.
class Bouton extends StatefulWidget {
  const Bouton({
    super.key,
    required this.libelle,
    this.onTap,
    this.variante = VarianteBouton.principal,
    this.icone,
  });

  final String libelle;
  final VoidCallback? onTap;
  final VarianteBouton variante;
  final IconData? icone;

  bool get actif => onTap != null;

  @override
  State<Bouton> createState() => _BoutonState();
}

class _BoutonState extends State<Bouton> {
  bool _enfonce = false;

  ({Color fond, Color texte, Color arete}) get _palette =>
      switch (widget.variante) {
        VarianteBouton.principal => (
          fond: Couleurs.jaune,
          texte: Couleurs.surJaune,
          arete: Couleurs.areteJaune,
        ),
        VarianteBouton.secondaire => (
          fond: Couleurs.carte,
          texte: Couleurs.encre,
          arete: Couleurs.areteNeutre,
        ),
        VarianteBouton.danger => (
          fond: Couleurs.danger,
          texte: Colors.white,
          arete: Couleurs.areteDanger,
        ),
      };

  @override
  Widget build(BuildContext context) {
    final p = _palette;
    final actif = widget.actif;

    return Semantics(
      button: true,
      enabled: actif,
      label: widget.libelle,
      child: GestureDetector(
        onTapDown: actif ? (_) => setState(() => _enfonce = true) : null,
        onTapUp: actif ? (_) => setState(() => _enfonce = false) : null,
        onTapCancel: actif ? () => setState(() => _enfonce = false) : null,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          transform: Matrix4.translationValues(0, _enfonce ? 2 : 0, 0),
          height: Mesures.hauteurCta,
          decoration: BoxDecoration(
            color: actif ? p.fond : Couleurs.surfaceConteneur,
            borderRadius: BorderRadius.circular(Rayons.normal),
            boxShadow: actif
                ? (_enfonce
                      ? Ombres.tactileEnfoncee(p.arete)
                      : Ombres.tactile(p.arete))
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icone != null) ...[
                Icon(
                  widget.icone,
                  size: 20,
                  color: actif ? p.texte : Couleurs.attenue,
                ),
                const SizedBox(width: Espaces.x8),
              ],
              // `Flexible` et non `Text` nu : un libellé long dans un bouton
              // étroit débordait — attrapé par le test de rendu à 375 px
              // avant qu'un écran ne le montre. L'ellipse vaut mieux qu'un
              // débordement, mais elle signale surtout un libellé à raccourcir.
              Flexible(
                child: Text(
                  widget.libelle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Typo.headlineMd.copyWith(
                    color: actif ? p.texte : Couleurs.attenue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
