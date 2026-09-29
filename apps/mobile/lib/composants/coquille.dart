import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../metier/serie.dart';
import '../routage.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Page d'un onglet : l'en-tête de l'onglet, puis son contenu.
///
/// **La barre du bas n'est plus ici.** Elle vivait dans cette coquille, que
/// chaque onglet construisait pour lui-même : changer d'onglet détruisait donc
/// la barre et en reconstruisait une autre, et l'étudiant voyait toute la page
/// changer — barre comprise. Elle vit désormais dans [CoquilleOnglets],
/// construite **une seule fois** par le routeur, sous les cinq onglets.
///
/// L'en-tête, lui, reste par onglet — comme les grands titres d'iOS, qui
/// appartiennent à leur page et changent avec elle.
class Coquille extends StatelessWidget {
  const Coquille({
    super.key,
    required this.enfant,
    this.serie,
    this.xpTotal,
  });

  final Widget enfant;

  /// Série **déjà corrigée** par `etatSerie()`. `null` tant que le profil
  /// n'est pas chargé.
  final EtatSerie? serie;
  final int? xpTotal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Couleurs.fond,
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

    // Posé sur le fond, sans ombre : c'est le grand titre d'iOS, qui
    // appartient à la page. Une ombre sous l'en-tête le décollait du contenu
    // et le faisait lire comme une barre d'outils.
    return Container(
      height: Mesures.hauteurEnTete,
      padding: const EdgeInsets.symmetric(horizontal: Espaces.ecran),
      color: Couleurs.fond,
      child: Row(
        children: [
          // Le logo à côté du nom : la marque vit dans l'application, pas
          // seulement sur l'écran d'accueil du téléphone.
          const LogoReviz(taille: 30),
          const SizedBox(width: Espaces.x8),
          // `Expanded` et non `Text` + `Spacer` : à 320 px, les deux badges
          // et le titre ne tiennent pas côte à côte, et c'est le titre qui
          // doit céder — les compteurs sont l'information.
          Expanded(
            child: Text(
              'Reviz',
              style: Typo.headlineXl.copyWith(fontSize: 26),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: Espaces.x8),
          _Badge(
            icone: Icons.local_fire_department_rounded,
            texte: '${serie?.jours ?? 0} j',
            fond: Couleurs.carte,
            teinteIcone: eteinte ? Couleurs.attenue : Couleurs.orange,
            teinteTexte: Couleurs.encre,
            ombre: Ombres.cartePetite,
          ),
          const SizedBox(width: Espaces.x8),
          _Badge(
            icone: Icons.bolt_rounded,
            texte: '${xpTotal ?? 0} XP',
            fond: Couleurs.jaune,
            teinteIcone: Couleurs.surJaune,
            teinteTexte: Couleurs.surJaune,
            ombre: Ombres.lueurJauneEnfoncee,
          ),
        ],
      ),
    );
  }
}

/// Le logo de Reviz : la pile de fiches cochée, sur le jaune.
///
/// C'est la même image que l'icône du téléphone (`scripts/icones.mjs`),
/// réduite : on reconnaît dans l'application ce qu'on a touché pour l'ouvrir.
class LogoReviz extends StatelessWidget {
  const LogoReviz({super.key, this.taille = 32});

  final double taille;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/marque/logo.png',
      width: taille,
      height: taille,
      // Décodé à la taille d'affichage : 288 px gardés en mémoire pour un
      // logo de 30 serait du gaspillage.
      cacheWidth: (taille * 3).round(),
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Reviz',
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
    this.ombre = const [],
  });

  final IconData icone;
  final String texte;
  final Color fond;
  final Color teinteIcone;
  final Color teinteTexte;
  final List<BoxShadow> ombre;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaces.x12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(999),
        boxShadow: ombre,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 16, color: teinteIcone),
          const SizedBox(width: Espaces.x4),
          Text(
            texte,
            style: Typo.labelMd.copyWith(
              color: teinteTexte,
              // Des chiffres de même largeur : le compteur ne danse pas
              // quand l'XP passe de 999 à 1 000.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Le socle des cinq onglets : la barre du bas, et ce qui se passe au retour.
///
/// Construit une seule fois par `StatefulShellRoute` (voir `routage.dart`) :
/// quand l'étudiant change d'onglet, **seul le contenu au-dessus change**. La
/// barre ne se reconstruit pas, elle ne clignote pas ; seule la pilule glisse.
///
/// Le bouton retour d'Android suit l'ordre qu'on attend d'une application :
///
///  1. s'il y a une page à dépiler dans l'onglet courant, on la dépile — c'est
///     le navigateur de la branche qui s'en charge, pas ce widget ;
///  2. sinon, sur un onglet autre qu'Accueil, on **revient à Accueil** ;
///  3. sur Accueil, on sort.
///
/// Avant, il n'y avait que des `context.go` dans toute l'application : la
/// pile ne contenait jamais qu'une page, et le retour sortait de l'app depuis
/// n'importe où.
class CoquilleOnglets extends StatelessWidget {
  const CoquilleOnglets({super.key, required this.coquille});

  /// Fourni par go_router : sait quel onglet est actif, et comment changer.
  final StatefulNavigationShell coquille;

  void _choisir(int index) {
    // Un léger clic sous le doigt : la sélection se sent autant qu'elle se
    // voit, comme sur iOS.
    HapticFeedback.selectionClick();

    coquille.goBranch(
      index,
      // Toucher l'onglet déjà actif le ramène à sa racine — le geste qu'on
      // fait sur iPhone pour « remonter » d'un coup depuis le fond d'une pile.
      initialLocation: index == coquille.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Seul l'onglet Accueil laisse sortir de l'application. Ce `PopScope`
      // n'intervient qu'une fois la pile de l'onglet vide : tant qu'il y a une
      // page à dépiler, le navigateur de la branche la dépile avant.
      canPop: coquille.currentIndex == 0,
      onPopInvokedWithResult: (aDepile, _) {
        if (!aDepile) _choisir(0);
      },
      child: Scaffold(
        backgroundColor: Couleurs.fond,
        body: coquille,
        bottomNavigationBar: NavBasse(
          indexActif: coquille.currentIndex,
          onChoisir: _choisir,
        ),
      ),
    );
  }
}

/// Un onglet : chemin de sa racine, libellé, icône au repos et active.
typedef Onglet = ({
  String chemin,
  String libelle,
  IconData repos,
  IconData actif,
});

/// Les cinq onglets, dans l'ordre de CLAUDE.md — et dans l'ordre des branches
/// du routeur, qui doit être le même.
const List<Onglet> onglets = [
  (
    chemin: Chemins.accueil,
    libelle: 'Accueil',
    repos: Icons.home_outlined,
    actif: Icons.home_rounded,
  ),
  (
    chemin: Chemins.reviser,
    libelle: 'Réviser',
    repos: Icons.menu_book_outlined,
    actif: Icons.menu_book_rounded,
  ),
  (
    chemin: Chemins.corriger,
    libelle: 'Corriger',
    repos: Icons.fact_check_outlined,
    actif: Icons.fact_check_rounded,
  ),
  (
    chemin: Chemins.gains,
    libelle: 'Gains',
    repos: Icons.emoji_events_outlined,
    actif: Icons.emoji_events_rounded,
  ),
  (
    chemin: Chemins.profil,
    libelle: 'Profil',
    repos: Icons.person_outline_rounded,
    actif: Icons.person_rounded,
  ),
];

/// La barre du bas : immobile, avec **une seule** pilule qui glisse.
///
/// La pilule était dessinée par chaque onglet — une pilule apparaissait sous
/// le nouvel onglet pendant que l'ancienne disparaissait, sans rien entre les
/// deux. Elle est maintenant un seul objet, posé derrière les icônes, qui se
/// déplace sur un ressort (`Mouvement.courbeGlisse`) : un léger dépassement,
/// puis elle se pose. C'est ce qui donne à l'interface une masse.
class NavBasse extends StatelessWidget {
  const NavBasse({
    super.key,
    required this.indexActif,
    required this.onChoisir,
  });

  final int indexActif;
  final ValueChanged<int> onChoisir;

  /// Géométrie de la pilule. Placée en absolu : le haut de la zone d'icône
  /// et la hauteur de la pilule doivent coïncider au pixel près avec
  /// `_OngletNav`, sinon la pilule flotte à côté de son icône.
  static const _hautIcone = 12.0;
  static const _largeurPilule = 60.0;
  static const _hauteurPilule = 32.0;

  @override
  Widget build(BuildContext context) {
    final reduit = MediaQuery.disableAnimationsOf(context);

    // Blanc translucide sur un flou, et un filet d'un demi-pixel en haut :
    // la barre d'onglets d'iOS, sans rien lui emprunter d'autre que sa
    // géométrie. Une ombre portée la détachait comme un objet posé ; le filet
    // la raccorde au bas de l'écran, où elle appartient.
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xE6FFFFFF),
            border: Border(
              top: BorderSide(color: Couleurs.bordure, width: 0.5),
            ),
          ),
          child: SafeArea(
        top: false,
        // `SizedBox` **avant** le `Center`, et non après : `Align` — donc
        // `Center` — s'étend pour remplir ses contraintes quand elles sont
        // bornées. Placé à l'extérieur, il prenait presque tout l'écran et
        // laissait au corps une hauteur nulle. Attrapé par le test de rendu.
        child: SizedBox(
          height: Mesures.hauteurNav,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Mesures.largeurApp),
              child: LayoutBuilder(
                builder: (context, contraintes) {
                  final largeurOnglet = contraintes.maxWidth / onglets.length;

                  return Stack(
                    children: [
                      AnimatedPositioned(
                        duration: reduit ? Duration.zero : Mouvement.glisse,
                        curve: Mouvement.courbeGlisse,
                        top: _hautIcone,
                        left:
                            largeurOnglet * indexActif +
                            (largeurOnglet - _largeurPilule) / 2,
                        width: _largeurPilule,
                        height: _hauteurPilule,
                        child: const DecoratedBox(
                          key: ValueKey('nav-pilule'),
                          decoration: BoxDecoration(
                            color: Couleurs.jaune,
                            borderRadius: BorderRadius.all(
                              Radius.circular(999),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < onglets.length; i++)
                            Expanded(
                              child: _OngletNav(
                                onglet: onglets[i],
                                actif: i == indexActif,
                                onTap: () => onChoisir(i),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
        ),
      ),
    );
  }
}

class _OngletNav extends StatelessWidget {
  const _OngletNav({
    required this.onglet,
    required this.actif,
    required this.onTap,
  });

  final Onglet onglet;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final couleur = actif ? Couleurs.encre : Couleurs.attenue;

    return Semantics(
      button: true,
      selected: actif,
      label: onglet.libelle,
      excludeSemantics: true,
      // `GestureDetector` et non `InkWell` : pas d'éclaboussure d'encre. Sur
      // une barre dont un objet glisse déjà vers le doigt, une seconde
      // animation au même endroit se contredirait avec la première.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            const SizedBox(height: NavBasse._hautIcone),
            SizedBox(
              height: NavBasse._hauteurPilule,
              child: Center(
                // Contour au repos, plein une fois choisi : la forme change
                // en même temps que la couleur, ce qui se lit aussi sans voir
                // les couleurs.
                child: AnimatedSwitcher(
                  duration: Mouvement.doux,
                  switchInCurve: Mouvement.courbeDouce,
                  child: Icon(
                    actif ? onglet.actif : onglet.repos,
                    key: ValueKey(actif),
                    size: 24,
                    color: couleur,
                  ),
                ),
              ),
            ),
            const SizedBox(height: Espaces.x4),
            AnimatedDefaultTextStyle(
              duration: Mouvement.doux,
              curve: Mouvement.courbeDouce,
              // `labelSm` et non `caption` : `caption` est espacé pour les
              // étiquettes en capitales, et ces lettres écartées rendaient les
              // libellés d'onglet plus larges que leur colonne à 320 px.
              style: Typo.labelSm.copyWith(
                fontSize: 11,
                color: actif ? Couleurs.encre : Couleurs.attenue,
              ),
              child: Text(
                onglet.libelle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
