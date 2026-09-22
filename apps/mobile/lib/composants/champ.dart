import 'package:flutter/material.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Champ de saisie du design system.
///
/// Hauteur 56 px comme le CTA : sur mobile, un champ plus bas qu'un bouton se
/// rate au pouce. Bordure de 2 px, contrairement aux cartes — ici le contour
/// porte l'état (repos, focus, erreur), il ne peut pas être implicite.
class Champ extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final message = erreur ?? aide;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (libelle != null) ...[
          Text(libelle!, style: Typo.labelMd),
          const SizedBox(height: Espaces.x8),
        ],
        Container(
          height: Mesures.hauteurCta,
          padding: const EdgeInsets.symmetric(horizontal: Espaces.x16),
          decoration: BoxDecoration(
            color: Couleurs.carte,
            borderRadius: BorderRadius.circular(Rayons.normal),
            border: Border.all(
              width: 2,
              color: erreur != null ? Couleurs.danger : Couleurs.bordure,
            ),
          ),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: controleur,
            keyboardType: typeClavier,
            obscureText: obscur,
            autofocus: autoFocus,
            maxLength: maxCaracteres,
            enabled: actif,
            onChanged: onChange,
            onSubmitted: onSoumis,
            style: Typo.bodyLg,
            cursorColor: Couleurs.orange,
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              counterText: '',
            ),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: Espaces.x4),
          Text(
            message,
            style: Typo.labelSm.copyWith(
              color: erreur != null ? Couleurs.danger : Couleurs.attenue,
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
          decoration: BoxDecoration(
            color: Couleurs.carte,
            borderRadius: BorderRadius.circular(Rayons.normal),
            border: Border.all(width: 2, color: Couleurs.bordure),
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
