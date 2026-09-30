import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../donnees/modeles.dart';
import '../i18n/fr.dart';
import '../metier/maitrise.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';
import 'mascotte.dart';

/// Le chemin d'un cours, à la manière de Duolingo : un nœud par chapitre, en
/// zigzag, du premier au dernier.
///
/// Chaque nœud dit l'état du chapitre sans un mot : cadenas gris (fermé),
/// jaune avec « lecture » (à faire), orange (à revoir), couronne (acquis). Le
/// premier chapitre à faire porte le panthéreau et une bulle « Commencer » :
/// l'étudiant voit d'un coup d'œil où il en est et par où reprendre.
///
/// La règle — quand un chapitre s'ouvre, combien de couronnes il vaut — est
/// dans `metier/maitrise.dart`, testée ; ce composant ne fait que la montrer.
class CheminChapitres extends StatelessWidget {
  const CheminChapitres({
    super.key,
    required this.chapitres,
    required this.onOuvrir,
  });

  final List<ChapitreDuChemin> chapitres;
  final void Function(ChapitreDuChemin chapitre) onOuvrir;

  /// Décalage horizontal de chaque nœud, de -1 (à gauche) à 1 (à droite) :
  /// une sinusoïde grossière, qui se répète tous les huit chapitres.
  static const _zigzag = [0.0, 0.45, 0.7, 0.45, 0.0, -0.45, -0.7, -0.45];

  @override
  Widget build(BuildContext context) {
    // Le nœud courant : le premier chapitre ouvert qui n'a pas de couronne.
    final courant = chapitres.indexWhere(
      (c) =>
          c.maitrise.etat == EtatChapitre.aDecouvrir ||
          c.maitrise.etat == EtatChapitre.aRevoir,
    );

    return Column(
      children: [
        for (var i = 0; i < chapitres.length; i++) ...[
          Align(
            alignment: Alignment(_zigzag[i % _zigzag.length], 0),
            child: _Etape(
              chapitre: chapitres[i],
              courant: i == courant,
              // Le panthéreau se tient du côté où il y a de la place.
              mascotteADroite: _zigzag[i % _zigzag.length] <= 0,
              precedent: _precedent(i),
              onOuvrir: () => onOuvrir(chapitres[i]),
            ),
          ),
          if (i < chapitres.length - 1) const SizedBox(height: Espaces.x16),
        ],
      ],
    );
  }

  /// Le numéro du chapitre dont la couronne ouvrirait le chapitre `i`.
  int _precedent(int i) {
    for (var j = i - 1; j >= 0; j--) {
      if (chapitres[j].maitrise.etat != EtatChapitre.sansQcm) {
        return chapitres[j].chapitre.index;
      }
    }
    return chapitres[i].chapitre.index;
  }
}

class _Etape extends StatelessWidget {
  const _Etape({
    required this.chapitre,
    required this.courant,
    required this.mascotteADroite,
    required this.precedent,
    required this.onOuvrir,
  });

  final ChapitreDuChemin chapitre;
  final bool courant;
  final bool mascotteADroite;
  final int precedent;
  final VoidCallback onOuvrir;

  /// Largeur du titre ; l'étape entière tient en 200 px, pour garder de
  /// la place au zigzag même sur un écran de 320 px.
  static const _largeur = 160.0;

  String _etatLisible(Maitrise m) => switch (m.etat) {
    EtatChapitre.verrouille => Fr.cours.etatVerrouille,
    EtatChapitre.aDecouvrir => Fr.cours.etatADecouvrir,
    EtatChapitre.aRevoir => Fr.cours.aRevoirChapitre,
    EtatChapitre.couronne => Fr.cours.palier(m.couronnes),
    EtatChapitre.sansQcm => Fr.cours.etatSansQuestions,
  };

  void _toucher(BuildContext context) {
    final m = chapitre.maitrise;
    final message = switch (m.etat) {
      EtatChapitre.verrouille => Fr.cours.verrouille(precedent),
      EtatChapitre.sansQcm when chapitre.chapitre.nbFiches == 0 =>
        Fr.cours.sansQuestions,
      _ => null,
    };
    if (message != null) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    HapticFeedback.selectionClick();
    onOuvrir();
  }

  @override
  Widget build(BuildContext context) {
    final m = chapitre.maitrise;
    final noeud = _Noeud(maitrise: m, courant: courant);

    final tete = courant
        ? const TeteMascotte(etat: EtatMascotte.enRoute, taille: 44)
        : const SizedBox(width: 44);

    return Semantics(
      button: true,
      label: Fr.cours.noeud(
        chapitre.chapitre.titre ?? '${chapitre.chapitre.index}',
        _etatLisible(m),
      ),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _toucher(context),
        child: SizedBox(
          width: 200,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (courant) ...[
                _Bulle(
                  texte: m.tentees == 0
                      ? Fr.cours.commencer
                      : m.etat == EtatChapitre.aRevoir
                      ? Fr.cours.aRevoirChapitre
                      : Fr.cours.continuer,
                ),
                const SizedBox(height: Espaces.x8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (mascotteADroite) const SizedBox(width: 44) else tete,
                  const SizedBox(width: Espaces.x8),
                  noeud,
                  const SizedBox(width: Espaces.x8),
                  if (mascotteADroite) tete else const SizedBox(width: 44),
                ],
              ),
              const SizedBox(height: Espaces.x8),
              SizedBox(
                width: _largeur,
                child: Text(
                  chapitre.chapitre.titre ?? '—',
                  style: Typo.labelMd.copyWith(
                    color: m.etat == EtatChapitre.verrouille
                        ? Couleurs.attenue
                        : Couleurs.encre,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (m.etat != EtatChapitre.verrouille &&
                  m.etat != EtatChapitre.sansQcm) ...[
                const SizedBox(height: Espaces.x4),
                RangeeCouronnes(nombre: m.couronnes),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Le rond d'un chapitre. Le nœud courant porte un anneau : la part des
/// questions du chapitre déjà tentées.
class _Noeud extends StatelessWidget {
  const _Noeud({required this.maitrise, required this.courant});

  final Maitrise maitrise;
  final bool courant;

  static const _cote = 72.0;

  @override
  Widget build(BuildContext context) {
    final m = maitrise;
    final (fond, encre, icone) = switch (m.etat) {
      EtatChapitre.verrouille => (
        Couleurs.surfaceHaute,
        Couleurs.attenue,
        Icons.lock_rounded,
      ),
      EtatChapitre.aDecouvrir => (
        courant ? Couleurs.jaune : Couleurs.carte,
        Couleurs.encre,
        Icons.play_arrow_rounded,
      ),
      EtatChapitre.aRevoir => (
        Couleurs.orange,
        Couleurs.encre,
        Icons.replay_rounded,
      ),
      EtatChapitre.couronne when m.couronnes >= 3 => (
        Couleurs.jaune,
        Couleurs.encre,
        null,
      ),
      EtatChapitre.couronne => (
        Couleurs.jauneDoux,
        Couleurs.jauneProfond,
        null,
      ),
      EtatChapitre.sansQcm => (
        Couleurs.bleuDoux,
        Couleurs.encre,
        Icons.menu_book_rounded,
      ),
    };

    final rond = Container(
      width: _cote,
      height: _cote,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fond,
        shape: BoxShape.circle,
        border: m.etat == EtatChapitre.aDecouvrir && !courant
            ? Border.all(color: Couleurs.jaune, width: 3)
            : null,
        boxShadow: m.etat == EtatChapitre.verrouille
            ? null
            : courant
            ? Ombres.lueurJaune
            : Ombres.cartePetite,
      ),
      child: icone != null
          ? Icon(icone, size: 34, color: encre)
          : IconeCouronne(taille: 34, couleur: encre),
    );

    if (!courant) return rond;

    // L'anneau de progression, qui se remplit à mesure qu'on tente les
    // questions du chapitre.
    final animer = !MediaQuery.disableAnimationsOf(context);
    return SizedBox.square(
      dimension: _cote + 14,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: m.couverture),
            duration: animer ? Mouvement.ample : Duration.zero,
            curve: Mouvement.courbeDouce,
            builder: (_, valeur, _) => SizedBox.square(
              dimension: _cote + 14,
              child: CircularProgressIndicator(
                value: valeur,
                strokeWidth: 5,
                strokeCap: StrokeCap.round,
                color: Couleurs.jaune,
                backgroundColor: Couleurs.surfaceHaute,
              ),
            ),
          ),
          rond,
        ],
      ),
    );
  }
}

class _Bulle extends StatelessWidget {
  const _Bulle({required this.texte});

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaces.x12,
        vertical: Espaces.x4 + 2,
      ),
      decoration: ShapeDecoration(
        color: Couleurs.encre,
        shape: formeContinue(Rayons.normal),
      ),
      child: Text(texte, style: Typo.labelMd.copyWith(color: Couleurs.carte)),
    );
  }
}

/// Trois couronnes, les gagnées en jaune.
class RangeeCouronnes extends StatelessWidget {
  const RangeeCouronnes({super.key, required this.nombre, this.taille = 18});

  final int nombre;
  final double taille;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: IconeCouronne(
              taille: taille,
              couleur: i < nombre ? Couleurs.jaune : Couleurs.surfaceHaute,
            ),
          ),
      ],
    );
  }
}

/// Une couronne dessinée : les icônes Material n'en ont pas.
class IconeCouronne extends StatelessWidget {
  const IconeCouronne({super.key, required this.taille, required this.couleur});

  final double taille;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(taille),
      painter: _PeintreCouronne(couleur),
    );
  }
}

class _PeintreCouronne extends CustomPainter {
  const _PeintreCouronne(this.couleur);

  final Color couleur;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final pinceau = Paint()
      ..color = couleur
      ..style = PaintingStyle.fill;

    // Trois pointes, une base ; les pointes finissent sur une perle.
    final corps = Path()
      ..moveTo(w * 0.10, h * 0.34)
      ..lineTo(w * 0.32, h * 0.56)
      ..lineTo(w * 0.50, h * 0.24)
      ..lineTo(w * 0.68, h * 0.56)
      ..lineTo(w * 0.90, h * 0.34)
      ..lineTo(w * 0.82, h * 0.74)
      ..lineTo(w * 0.18, h * 0.74)
      ..close();
    canvas.drawPath(corps, pinceau);
    canvas.drawRRect(
      RRect.fromLTRBR(
        w * 0.18,
        h * 0.78,
        w * 0.82,
        h * 0.88,
        Radius.circular(w * 0.04),
      ),
      pinceau,
    );
    for (final (x, y) in [(0.10, 0.30), (0.50, 0.19), (0.90, 0.30)]) {
      canvas.drawCircle(Offset(w * x, h * y), w * 0.07, pinceau);
    }
  }

  @override
  bool shouldRepaint(_PeintreCouronne ancien) => ancien.couleur != couleur;
}
