import 'package:flutter/material.dart';
import '../donnees/modeles.dart';
import '../i18n/fr.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Podium des trois premiers, dans l'ordre **2 · 1 · 3**.
///
/// Les hauteurs (128 / 96 / 80) et les teintes viennent de docs/DESIGN.md : le
/// n° 1 en jaune, le n° 2 en bleu doux, le n° 3 en pêche. Aucun vert : une
/// réussite se célèbre en jaune dans toute l'application.
///
/// Les avatars sont pour l'instant l'initiale du prénom dans un rond : les
/// 24 PNG n'existent pas encore dans le dépôt. C'est un repli assumé, et non
/// le découpage de la chaîne `avatar_key` que faisait l'écran web
/// (rapport § 4.15).
class Podium extends StatelessWidget {
  const Podium({super.key, required this.lignes});

  /// Le haut du classement, déjà trié. Moins de trois entrées est un état
  /// normal dans une faculté qui démarre : les marches manquantes ne sont
  /// simplement pas dessinées.
  final List<LigneClassement> lignes;

  static const _hauteurs = {1: 128.0, 2: 96.0, 3: 80.0};

  static const _fonds = {
    1: Couleurs.jaune,
    2: Couleurs.bleu,
    3: Couleurs.orangeDoux,
  };

  @override
  Widget build(BuildContext context) {
    final parRang = {for (final l in lignes.take(3)) l.rang: l};

    // L'ordre visuel n'est pas l'ordre du classement.
    const ordre = [2, 1, 3];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final rang in ordre)
          Expanded(
            child: parRang[rang] == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Espaces.x4,
                    ),
                    child: _Marche(
                      ligne: parRang[rang]!,
                      hauteur: _hauteurs[rang]!,
                      fond: _fonds[rang]!,
                    ),
                  ),
          ),
      ],
    );
  }
}

class _Marche extends StatelessWidget {
  const _Marche({
    required this.ligne,
    required this.hauteur,
    required this.fond,
  });

  final LigneClassement ligne;
  final double hauteur;
  final Color fond;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AvatarInitiale(
          prenom: ligne.prenom,
          taille: ligne.rang == 1 ? 56 : 44,
          couronne: ligne.rang == 1,
        ),
        const SizedBox(height: Espaces.x8),
        Text(
          ligne.estMoi ? Fr.classement.toi : (ligne.prenom ?? '—'),
          style: Typo.labelMd,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          Fr.classement.xp(ligne.xp),
          style: Typo.labelSm.copyWith(color: Couleurs.attenue),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: Espaces.x8),
        Container(
          height: hauteur,
          width: double.infinity,
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: Espaces.x8),
          decoration: BoxDecoration(
            color: fond,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(Rayons.normal),
            ),
          ),
          child: Text(
            '${ligne.rang}',
            style: Typo.headlineXl.copyWith(
              color: ligne.rang == 1 ? Couleurs.surJaune : Couleurs.encre,
            ),
          ),
        ),
      ],
    );
  }
}

/// Rond portant l'initiale du prénom.
///
/// Repli en attendant les 24 avatars ; il se remplacera par une `Image.asset`
/// sans changer les appelants.
class AvatarInitiale extends StatelessWidget {
  const AvatarInitiale({
    super.key,
    required this.prenom,
    this.taille = 44,
    this.couronne = false,
  });

  final String? prenom;
  final double taille;
  final bool couronne;

  @override
  Widget build(BuildContext context) {
    final p = (prenom ?? '').trim();
    // Par rune et non par `substring(0, 1)` : un prénom commençant par un
    // caractère hors du plan de base se couperait en deux moitiés de paire.
    final initiale = p.isEmpty
        ? '?'
        : String.fromCharCode(p.runes.first).toUpperCase();

    final rond = Container(
      width: taille,
      height: taille,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Couleurs.jauneDoux,
        border: couronne
            ? Border.all(color: Couleurs.areteJaune, width: 2)
            : null,
      ),
      child: Text(
        initiale,
        style: Typo.headlineMd.copyWith(color: Couleurs.surJaune),
      ),
    );

    if (!couronne) return rond;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.workspace_premium, size: 20, color: Couleurs.jaune),
        rond,
      ],
    );
  }
}

/// Une ligne du classement à partir du 4ᵉ rang.
class RangeeClassement extends StatelessWidget {
  const RangeeClassement({super.key, required this.ligne});

  final LigneClassement ligne;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaces.x12,
        vertical: Espaces.x8,
      ),
      decoration: BoxDecoration(
        // Sa propre ligne est teintée : dans une liste de vingt prénoms, la
        // retrouver ne doit pas demander de lire.
        color: ligne.estMoi ? Couleurs.jauneDoux : Couleurs.carte,
        borderRadius: BorderRadius.circular(Rayons.normal),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${ligne.rang}',
              style: Typo.labelLg.copyWith(color: Couleurs.attenue),
            ),
          ),
          AvatarInitiale(prenom: ligne.prenom, taille: 36),
          const SizedBox(width: Espaces.x12),
          Expanded(
            child: Text(
              ligne.estMoi ? Fr.classement.toi : (ligne.prenom ?? '—'),
              style: Typo.labelLg,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: Espaces.x8),
          Text(
            Fr.classement.xp(ligne.xp),
            style: Typo.labelMd.copyWith(color: Couleurs.texteAccent),
          ),
        ],
      ),
    );
  }
}
