import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../metier/serie.dart';
import '../routage.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Coquille des écrans connectés : en-tête collant, contenu, navigation basse.
///
/// L'en-tête porte la série et les XP ; la navigation est **plate, de 80 px,
/// à cinq onglets**, l'actif en pilule jaune — pas de bouton flottant
/// central, conformément à l'arbitrage de docs/DESIGN.md § 11.
class Coquille extends StatelessWidget {
  const Coquille({
    super.key,
    required this.enfant,
    required this.ongletActif,
    this.serie,
    this.xpTotal,
  });

  final Widget enfant;
  final String ongletActif;

  /// Série **déjà corrigée** par `etatSerie()`. `null` tant que le profil
  /// n'est pas chargé.
  final EtatSerie? serie;
  final int? xpTotal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Couleurs.cream,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Mesures.largeurApp),
            child: Column(
              children: [
                _EnTete(serie: serie, xpTotal: xpTotal),
                Expanded(child: enfant),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _NavBasse(actif: ongletActif),
    );
  }
}

class _EnTete extends StatelessWidget {
  const _EnTete({this.serie, this.xpTotal});

  final EtatSerie? serie;
  final int? xpTotal;

  @override
  Widget build(BuildContext context) {
    final eteinte = serie == null || serie!.rompue;

    return Container(
      height: Mesures.hauteurEnTete,
      padding: const EdgeInsets.symmetric(horizontal: Espaces.ecran),
      decoration: const BoxDecoration(
        color: Couleurs.cream,
        boxShadow: Ombres.cartePetite,
      ),
      child: Row(
        children: [
          // `Expanded` et non `Text` + `Spacer` : à 320 px, les deux badges
          // et le titre ne tiennent pas côte à côte, et c'est le titre qui
          // doit céder — les compteurs sont l'information.
          Expanded(
            child: Text(
              'Reviz',
              style: Typo.headlineLg,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: Espaces.x8),
          _Badge(
            icone: Icons.local_fire_department,
            texte: '${serie?.jours ?? 0} j',
            fond: Couleurs.surfaceConteneur,
            teinteIcone: eteinte ? Couleurs.attenue : Couleurs.orange,
            teinteTexte: Couleurs.encre,
          ),
          const SizedBox(width: Espaces.x8),
          _Badge(
            icone: Icons.stars,
            texte: '${xpTotal ?? 0} XP',
            fond: Couleurs.jaune,
            teinteIcone: Couleurs.surJaune,
            teinteTexte: Couleurs.surJaune,
            arete: Couleurs.areteJaune,
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icone,
    required this.texte,
    required this.fond,
    required this.teinteIcone,
    required this.teinteTexte,
    this.arete,
  });

  final IconData icone;
  final String texte;
  final Color fond;
  final Color teinteIcone;
  final Color teinteTexte;
  final Color? arete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaces.x8,
        vertical: Espaces.x4,
      ),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(999),
        boxShadow: arete == null
            ? null
            : [BoxShadow(color: arete!, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 16, color: teinteIcone),
          const SizedBox(width: Espaces.x4),
          Text(texte, style: Typo.labelSm.copyWith(color: teinteTexte)),
        ],
      ),
    );
  }
}

/// Les cinq onglets, dans l'ordre de CLAUDE.md.
const _onglets = [
  (Chemins.accueil, 'Accueil', Icons.home_rounded),
  (Chemins.reviser, 'Réviser', Icons.menu_book_rounded),
  (Chemins.corriger, 'Corriger', Icons.fact_check_rounded),
  (Chemins.gains, 'Gains', Icons.emoji_events_rounded),
  (Chemins.profil, 'Profil', Icons.person_rounded),
];

class _NavBasse extends StatelessWidget {
  const _NavBasse({required this.actif});

  final String actif;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Couleurs.carte,
        boxShadow: Ombres.cartePetite,
      ),
      child: SafeArea(
        top: false,
        // `SizedBox` **avant** le `Center`, et non après : `Align` — donc
        // `Center` — s'étend pour remplir ses contraintes quand elles sont
        // bornées. Placé à l'extérieur, il prenait 748 des 812 pixels de
        // l'écran, ne laissait que 64 au corps, et la liste de contenu se
        // retrouvait avec une hauteur nulle — donc vide, une `ListView`
        // construisant paresseusement. Attrapé par le test de rendu.
        child: SizedBox(
          height: Mesures.hauteurNav,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Mesures.largeurApp),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final (chemin, libelle, icone) in _onglets)
                    _Onglet(
                      chemin: chemin,
                      libelle: libelle,
                      icone: icone,
                      actif: chemin == actif,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Onglet extends StatelessWidget {
  const _Onglet({
    required this.chemin,
    required this.libelle,
    required this.icone,
    required this.actif,
  });

  final String chemin;
  final String libelle;
  final IconData icone;
  final bool actif;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: actif,
        label: libelle,
        child: InkWell(
          onTap: actif ? null : () => context.go(chemin),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Espaces.x12,
                  vertical: Espaces.x4,
                ),
                decoration: BoxDecoration(
                  // L'onglet actif est une pilule jaune.
                  color: actif ? Couleurs.jaune : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(
                  icone,
                  size: 24,
                  color: actif ? Couleurs.surJaune : Couleurs.attenue,
                ),
              ),
              const SizedBox(height: Espaces.x2),
              Text(
                libelle,
                style: Typo.caption.copyWith(
                  color: actif ? Couleurs.encre : Couleurs.attenue,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
