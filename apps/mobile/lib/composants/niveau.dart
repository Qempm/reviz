import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../i18n/fr.dart';
import '../metier/niveaux.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';
import 'bouton.dart';
import 'mascotte.dart';

/// Le numéro du niveau dans un anneau qui se remplit vers le suivant — le
/// badge de l'en-tête.
class AnneauNiveau extends StatelessWidget {
  const AnneauNiveau({
    super.key,
    required this.xp,
    this.taille = 22,
    this.couleur = Couleurs.surJaune,
  });

  final int xp;
  final double taille;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    final n = niveauDepuisXp(xp);
    return Semantics(
      label: Fr.niveaux.titre(n.numero),
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: taille,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: taille,
              child: CircularProgressIndicator(
                value: n.progression,
                strokeWidth: 2.5,
                strokeCap: StrokeCap.round,
                color: couleur,
                backgroundColor: couleur.withValues(alpha: 0.18),
              ),
            ),
            Text(
              '${n.numero}',
              style: Typo.labelSm.copyWith(
                color: couleur,
                fontSize: taille * 0.46,
                fontWeight: FontWeight.w800,
                height: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La barre du niveau en fin de session : elle part de l'XP d'avant et se
/// remplit jusqu'à celle d'après. Un niveau franchi la fait partir de zéro
/// dans le nouveau niveau.
class BarreNiveau extends StatelessWidget {
  const BarreNiveau({super.key, required this.xpAvant, required this.xpApres});

  final int xpAvant;
  final int xpApres;

  @override
  Widget build(BuildContext context) {
    final avant = niveauDepuisXp(xpAvant);
    final apres = niveauDepuisXp(xpApres);
    final depart = apres.numero > avant.numero ? 0.0 : avant.progression;
    final animer = !MediaQuery.disableAnimationsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            AnneauNiveau(xp: xpApres, taille: 28, couleur: Couleurs.encre),
            const SizedBox(width: Espaces.x8),
            Expanded(
              child: Text(
                Fr.niveaux.titre(apres.numero),
                style: Typo.labelLg,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: Espaces.x8),
        Semantics(
          value: '${(apres.progression * 100).round()} %',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 12,
              color: Couleurs.surfaceConteneur,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: depart, end: apres.progression),
                duration: animer
                    ? const Duration(milliseconds: 900)
                    : Duration.zero,
                curve: Mouvement.courbeDouce,
                builder: (_, valeur, _) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: valeur.clamp(0.0, 1.0),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Couleurs.jaune, Couleurs.orange],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Espaces.x4),
        Text(
          Fr.niveaux.restants(apres.xpRestants, apres.numero + 1),
          style: Typo.labelSm.copyWith(
            color: Couleurs.attenue,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// « Niveau supérieur ! », en plein écran, par-dessus le résultat.
Future<void> montrerNiveauSuperieur(BuildContext context, int numero) {
  HapticFeedback.heavyImpact();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Couleurs.encre.withValues(alpha: 0.5),
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Mouvement.ample,
    pageBuilder: (_, _, _) => _NiveauSuperieur(numero: numero),
    transitionBuilder: (_, animation, _, enfant) => ScaleTransition(
      scale: CurvedAnimation(parent: animation, curve: Mouvement.courbeGlisse),
      child: FadeTransition(opacity: animation, child: enfant),
    ),
  );
}

class _NiveauSuperieur extends StatelessWidget {
  const _NiveauSuperieur({required this.numero});

  final int numero;

  @override
  Widget build(BuildContext context) {
    final nom = Fr.niveaux.nom(numero);
    final nouveauNom = nom != Fr.niveaux.nom(numero - 1);

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Espaces.ecran),
          child: Material(
            color: Couleurs.carte,
            shape: formeContinue(Rayons.heros),
            child: Padding(
              padding: const EdgeInsets.all(Espaces.x24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Mascotte(etat: EtatMascotte.bravo, taille: 132),
                  const SizedBox(height: Espaces.x12),
                  Text(
                    Fr.niveaux.superieur,
                    style: Typo.headlineLg,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Espaces.x16),
                  Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Couleurs.jaune,
                      shape: BoxShape.circle,
                      boxShadow: Ombres.lueurJaune,
                    ),
                    child: Text(
                      '$numero',
                      style: Typo.displayHerosMobile.copyWith(
                        color: Couleurs.surJaune,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: Espaces.x16),
                  Text(
                    nouveauNom
                        ? Fr.niveaux.nouveauNom(nom)
                        : Fr.niveaux.superieurDetail(numero),
                    style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Espaces.x24),
                  Bouton(
                    libelle: Fr.niveaux.continuer,
                    onTap: () => Navigator.of(context).pop(),
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
