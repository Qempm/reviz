import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../donnees/modeles.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../metier/acces.dart';
import '../metier/maitrise.dart';
import '../metier/plateforme.dart';
import '../metier/tuteur.dart';
import '../routage.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';
import 'chargement.dart';
import 'mascotte.dart';
import 'puce.dart';

/// Les portes vers le tuteur de maîtrise (2.10.0).
///
/// Dans la 2.9.0, le tuteur ne s'ouvrait qu'au résultat d'une série lancée
/// sur **un seul** chapitre — or « Réviser », « Continuer » et « Réviser la
/// matière » lancent des séries sans chapitre. Personne ne le trouvait. Il a
/// maintenant une bulle de discussion sur la page de chaque cours, une carte
/// sur l'accueil, et une place au résultat de chaque série.

/// La bulle de discussion, en bas à droite de la page d'un cours : la tête du
/// panthéreau qui parle. Elle entre sur un ressort, sauf en mouvement réduit.
class BulleTuteur extends StatelessWidget {
  const BulleTuteur({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduit = MediaQuery.disableAnimationsOf(context);
    final bulle = Semantics(
      button: true,
      label: Fr.tuteur.bulleAide,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        shape: formeContinue(Rayons.heros),
        child: InkWell(
          customBorder: formeContinue(Rayons.heros),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.fromLTRB(6, 6, Espaces.x16, 6),
            decoration: ShapeDecoration(
              color: Couleurs.carte,
              shape: formeContinue(Rayons.heros),
              shadows: Ombres.carte,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Couleurs.jaune,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(2),
                  child: const TeteMascotte(
                    etat: EtatMascotte.curieux,
                    taille: 40,
                  ),
                ),
                const SizedBox(width: Espaces.x8),
                Text(Fr.tuteur.bulle, style: Typo.labelMd),
                const SizedBox(width: Espaces.x4),
                const Icon(
                  Icons.chat_bubble_rounded,
                  size: 18,
                  color: Couleurs.orange,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (reduit) return bulle;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Mouvement.ample,
      curve: Mouvement.courbeGlisse,
      builder: (context, t, enfant) => Transform.scale(
        scale: 0.6 + 0.4 * t,
        alignment: Alignment.bottomRight,
        child: Opacity(opacity: t.clamp(0, 1), child: enfant),
      ),
      child: bulle,
    );
  }
}

/// La feuille « Vérifie ta maîtrise » : le droit d'accès, puis les chapitres
/// du cours qui ont des QCM — d'abord ceux déjà travaillés.
Future<void> ouvrirFeuilleTuteur(BuildContext context, String coursId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Couleurs.carte,
    shape: formeContinue(Rayons.feuille),
    builder: (_) => FeuilleTuteur(coursId: coursId),
  );
}

class FeuilleTuteur extends ConsumerWidget {
  const FeuilleTuteur({super.key, required this.coursId});

  final String coursId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chemin = ref.watch(cheminProvider(coursId));
    final hauteurMax = MediaQuery.sizeOf(context).height * 0.8;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: hauteurMax),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Espaces.ecran,
            Espaces.x12,
            Espaces.ecran,
            Espaces.x16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Couleurs.bordure,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: Espaces.x16),
              Row(
                children: [
                  const TeteMascotte(etat: EtatMascotte.curieux, taille: 48),
                  const SizedBox(width: Espaces.x12),
                  Expanded(
                    child: Text(Fr.tuteur.titre, style: Typo.headlineLg),
                  ),
                ],
              ),
              const SizedBox(height: Espaces.x8),
              Text(
                Fr.tuteur.feuilleDetail,
                style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
              ),
              const SizedBox(height: Espaces.x12),
              const Align(
                alignment: Alignment.centerLeft,
                child: PuceDroitTuteur(),
              ),
              const SizedBox(height: Espaces.x16),
              Flexible(
                child: switch (chemin) {
                  AsyncData(:final value) => _ListeChapitres(
                    coursId: coursId,
                    chemin: value,
                  ),
                  AsyncError() => Text(
                    Fr.erreurs.chargementImpossible,
                    style: Typo.labelSm.copyWith(color: Couleurs.danger),
                  ),
                  _ => const Chargement.bloc(hauteur: 160),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// « Essai gratuit », « Inclus dans ton pack » ou « Fait partie des packs ».
/// Rien tant que l'accès n'est pas lu : mieux vaut taire que se tromper.
/// Sur l'iPhone sans achats, jamais « Fait partie des packs ».
class PuceDroitTuteur extends ConsumerWidget {
  const PuceDroitTuteur({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acces = ref.watch(boutiqueProvider).value?.acces;
    final essai = ref.watch(essaiTuteurUtiliseProvider).value;
    if (acces == null) return const SizedBox.shrink();
    if (acces is! AccesActif && essai == null) return const SizedBox.shrink();

    final droit = droitTuteur(acces: acces, essaiUtilise: essai ?? false);
    return switch (droit) {
      DroitTuteur.pack => Puce(
        libelle: Fr.tuteur.droitPack,
        ton: TonPuce.jaune,
        icone: Icons.check_circle,
      ),
      DroitTuteur.essai => Puce(
        libelle: Fr.tuteur.droitEssai,
        ton: TonPuce.bleu,
        icone: Icons.card_giftcard,
      ),
      DroitTuteur.essaiUtilise =>
        achatsDansLApplication
            ? Puce(
                libelle: Fr.tuteur.droitPacks,
                ton: TonPuce.orange,
                icone: Icons.lock_outline,
              )
            : const SizedBox.shrink(),
    };
  }
}

class _ListeChapitres extends StatelessWidget {
  const _ListeChapitres({required this.coursId, required this.chemin});

  final String coursId;
  final List<ChapitreDuChemin> chemin;

  @override
  Widget build(BuildContext context) {
    final jouables = chemin
        .where((c) => c.chapitre.nbQuestions > 0)
        .toList(growable: false);
    if (jouables.isEmpty) {
      return Text(
        Fr.tuteur.aucunChapitre,
        style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
      );
    }
    final revises = [
      for (final c in jouables)
        if (c.maitrise.tentees > 0) c,
    ];
    final autres = [
      for (final c in jouables)
        if (c.maitrise.tentees == 0) c,
    ];

    return ListView(
      shrinkWrap: true,
      children: [
        if (revises.isNotEmpty) ...[
          _Groupe(Fr.tuteur.revises),
          for (final c in revises) _LigneChapitre(coursId: coursId, c: c),
        ],
        if (autres.isNotEmpty) ...[
          if (revises.isNotEmpty) const SizedBox(height: Espaces.x12),
          _Groupe(Fr.tuteur.pasEncore),
          for (final c in autres) _LigneChapitre(coursId: coursId, c: c),
        ],
      ],
    );
  }
}

class _Groupe extends StatelessWidget {
  const _Groupe(this.libelle);

  final String libelle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Espaces.x4),
      child: Text(
        libelle.toUpperCase(),
        style: Typo.labelSm.copyWith(
          color: Couleurs.attenue,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _LigneChapitre extends StatelessWidget {
  const _LigneChapitre({required this.coursId, required this.c});

  final String coursId;
  final ChapitreDuChemin c;

  @override
  Widget build(BuildContext context) {
    final couronnes = c.maitrise.etat == EtatChapitre.couronne
        ? c.maitrise.couronnes
        : 0;
    return InkWell(
      customBorder: formeContinue(Rayons.normal),
      onTap: () {
        Navigator.of(context).pop();
        context.descendre(Chemins.tuteur(coursId, c.chapitre.id));
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Espaces.x8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  color: couronnes > 0
                      ? Couleurs.jauneDoux
                      : Couleurs.surfaceBasse,
                  shape: formeContinue(Rayons.petit),
                ),
                child: Text('${c.chapitre.index}', style: Typo.headlineSm),
              ),
              const SizedBox(width: Espaces.x12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.chapitre.titre ??
                          Fr.matiere.chapitre(c.chapitre.index - 1, null),
                      style: Typo.labelMd,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (c.maitrise.tentees > 0)
                      Text(
                        Fr.tuteur.couronnes(couronnes),
                        style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: Espaces.x8),
              const Icon(
                Icons.chat_bubble_outline,
                size: 20,
                color: Couleurs.orangeProfond,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
