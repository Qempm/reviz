import 'package:flutter/material.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Champ de saisie du design system.
///
/// Même hauteur que le CTA : sur mobile, un champ plus bas qu'un bouton se
/// rate au pouce. Contrairement aux cartes, le contour porte l'état — repos,
/// focus, erreur —, il ne peut donc pas être implicite.
class Champ extends StatefulWidget {
  const Champ({
    super.key,
    this.libelle,
    this.aide,
    this.erreur,
    this.controleur,
    this.typeClavier,
    this.obscur = false,
    this.autoFocus = false,
    this.maxCaracteres,
    this.onChange,
    this.onSoumis,
    this.actif = true,
  });

  final String? libelle;
  final String? aide;

  /// Remplace l'aide et colore le contour.
  final String? erreur;
  final TextEditingController? controleur;
  final TextInputType? typeClavier;
  final bool obscur;
  final bool autoFocus;
  final int? maxCaracteres;
  final ValueChanged<String>? onChange;
  final ValueChanged<String>? onSoumis;
  final bool actif;

  @override
  State<Champ> createState() => _ChampState();
}

/// Le champ sait s'il a le focus, et le montre.
///
/// Au repos, un filet fin ; quand on écrit dedans, un **anneau jaune** et un
/// halo à peine visible — on sait où va la frappe sans chercher le curseur.
/// Le contour passait avant de 2 px gris à 2 px gris : le focus ne se voyait
/// pas du tout.
class _ChampState extends State<Champ> {
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final message = widget.erreur ?? widget.aide;
    final enErreur = widget.erreur != null;

    final bord = switch ((enErreur, _focus)) {
      (true, _) => const BorderSide(color: Couleurs.danger, width: 2),
      (false, true) => const BorderSide(color: Couleurs.jaune, width: 2),
      (false, false) => const BorderSide(color: Couleurs.bordure),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.libelle != null) ...[
          Text(widget.libelle!, style: Typo.labelMd),
          const SizedBox(height: Espaces.x8),
        ],
        Focus(
          onFocusChange: (focus) => setState(() => _focus = focus),
          child: AnimatedContainer(
            duration: Mouvement.doux,
            curve: Mouvement.courbeDouce,
            height: Mesures.hauteurCta,
            padding: const EdgeInsets.symmetric(horizontal: Espaces.x16),
            alignment: Alignment.centerLeft,
            decoration: ShapeDecoration(
              color: widget.actif ? Couleurs.carte : Couleurs.surfaceBasse,
              shape: formeContinue(
                Rayons.normal,
                bord: bord.copyWith(
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              shadows: _focus && !enErreur
                  ? const [
                      BoxShadow(
                        color: Color(0x33FFC300),
                        blurRadius: 0,
                        spreadRadius: 4,
                      ),
                    ]
                  : const [],
            ),
            child: TextField(
              controller: widget.controleur,
              keyboardType: widget.typeClavier,
              obscureText: widget.obscur,
              autofocus: widget.autoFocus,
              maxLength: widget.maxCaracteres,
              enabled: widget.actif,
              onChanged: widget.onChange,
              onSubmitted: widget.onSoumis,
              style: Typo.bodyLg,
              cursorColor: Couleurs.encre,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                counterText: '',
              ),
            ),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: Espaces.x4),
          Text(
            message,
            style: Typo.labelSm.copyWith(
              color: enErreur ? Couleurs.danger : Couleurs.attenue,
            ),
          ),
        ],
      ],
    );
  }
}

/// Liste déroulante, même gabarit que [Champ].
class ChampListe<T> extends StatelessWidget {
  const ChampListe({
    super.key,
    required this.libelle,
    required this.valeur,
    required this.entrees,
    required this.onChange,
    this.marqueur,
    this.actif = true,
  });

  final String libelle;
  final T? valeur;
  final List<(T, String)> entrees;
  final ValueChanged<T?> onChange;

  /// Texte affiché tant que rien n'est choisi.
  final String? marqueur;
  final bool actif;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(libelle, style: Typo.labelMd),
        const SizedBox(height: Espaces.x8),
        Container(
          height: Mesures.hauteurCta,
          padding: const EdgeInsets.symmetric(horizontal: Espaces.x16),
          decoration: ShapeDecoration(
            color: Couleurs.carte,
            shape: formeContinue(
              Rayons.normal,
              bord: const BorderSide(color: Couleurs.bordure),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: valeur,
              isExpanded: true,
              onChanged: actif ? onChange : null,
              hint: marqueur == null
                  ? null
                  : Text(
                      marqueur!,
                      style: Typo.bodyLg.copyWith(color: Couleurs.attenue),
                    ),
              style: Typo.bodyLg,
              dropdownColor: Couleurs.carte,
              borderRadius: BorderRadius.circular(Rayons.normal),
              items: [
                for (final (v, libelle) in entrees)
                  DropdownMenuItem(
                    value: v,
                    child: Text(libelle, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
