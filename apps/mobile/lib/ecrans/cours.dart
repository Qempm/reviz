import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../composants/bouton.dart';
import '../composants/carte.dart';
import '../composants/etat_vide.dart';
import '../composants/progression.dart';
import '../composants/puce.dart';
import '../donnees/modeles.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../routage.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Page d'un cours : progression, chapitres, et le CTA de session.
///
/// Trois états selon `courses.status`. Un cours qui vient d'être déposé n'a ni
/// chapitre ni question : montrer une page vide laisserait croire à une panne.
class EcranCours extends ConsumerWidget {
  const EcranCours({super.key, required this.coursId});

  final String coursId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cours = ref.watch(unCoursProvider(coursId));

    return Scaffold(
      backgroundColor: Couleurs.cream,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Mesures.largeurApp),
            child: switch (cours) {
              AsyncData(:final value) when value != null => _Contenu(
                cours: value,
                onRafraichir: () {
                  ref.invalidate(unCoursProvider(coursId));
                  ref.invalidate(chapitresProvider(coursId));
                },
              ),
              AsyncData() => _Absent(),
              AsyncError(:final error) => Padding(
                padding: const EdgeInsets.all(Espaces.ecran),
                child: EtatVide(
                  icone: Icons.cloud_off,
                  titre: Fr.erreurs.chargementImpossible,
                  description: '$error',
                  action: Bouton(
                    libelle: Fr.commun.retour,
                    icone: Icons.arrow_back,
                    variante: VarianteBouton.secondaire,
                    onTap: () => context.go(Chemins.reviser),
                  ),
                ),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ),
      ),
    );
  }
}

class _Absent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Espaces.ecran),
      child: EtatVide(
        icone: Icons.search_off,
        titre: 'Ce cours est introuvable',
        description:
            'Il a peut-être été supprimé, ou il n’est pas partagé avec ta '
            'faculté.',
        action: Bouton(
          libelle: Fr.commun.retour,
          icone: Icons.arrow_back,
          variante: VarianteBouton.secondaire,
          onTap: () => context.go(Chemins.reviser),
        ),
      ),
    );
  }
}

/// Jours restants avant l'examen, `null` s'il est passé.
///
/// Arithmétique de calendrier, pas de millisecondes : « demain » doit rester
/// « demain » quelle que soit l'heure qu'il est.
int? joursAvant(String iso) {
  final p = iso.split('T').first.split('-');
  if (p.length < 3) return null;
  final a = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  final j = int.tryParse(p[2]);
  if (a == null || m == null || j == null) return null;

  final examen = DateTime(a, m, j);
  final maintenant = DateTime.now();
  final aujourdhui = DateTime(maintenant.year, maintenant.month, maintenant.day);

  final jours = examen.difference(aujourdhui).inDays;
  return jours < 0 ? null : jours;
}

class _Contenu extends ConsumerWidget {
  const _Contenu({required this.cours, required this.onRafraichir});

  final ApercuCours cours;
  final VoidCallback onRafraichir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cours.echoue) return _Echec(cours: cours);
    if (!cours.pret) return _EnTraitement(cours: cours, onRafraichir: onRafraichir);

    final chapitres = ref.watch(chapitresProvider(cours.id));
    final jours = cours.dateExamen == null ? null : joursAvant(cours.dateExamen!);

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaces.ecran,
        vertical: Espaces.x16,
      ),
      children: [
        _Retour(titre: Fr.reviser.titre),
        const SizedBox(height: Espaces.x8),

        Wrap(
          spacing: Espaces.x8,
          runSpacing: Espaces.x4,
          children: [
            if (cours.demo)
              Puce(
                libelle: Fr.reviser.exemple,
                ton: TonPuce.jaune,
                icone: Icons.auto_awesome,
              ),
            if (cours.dateExamen != null)
              Puce(
                libelle: jours == null
                    ? Fr.cours.examenPasse
                    : Fr.cours.jMoins(jours),
                ton: TonPuce.orange,
                icone: Icons.hourglass_top,
              ),
          ],
        ),
        const SizedBox(height: Espaces.x8),

        Text(cours.titre ?? '—', style: Typo.headlineXl),
        if (cours.matiereNom != null) ...[
          const SizedBox(height: Espaces.x4),
          Row(
            children: [
              const Icon(Icons.school, size: 18, color: Couleurs.attenue),
              const SizedBox(width: Espaces.x4),
              Expanded(
                child: Text(
                  cours.matiereNom!,
                  style: Typo.labelMd.copyWith(color: Couleurs.attenue),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: Espaces.x20),

        Carte(
          enfants: [
            Row(
              children: [
                JaugeCirculaire(
                  valeur: cours.progression,
                  taille: 88,
                  centre: Text(
                    '${(cours.progression * 100).round()} %',
                    style: Typo.headlineMd,
                  ),
                ),
                const SizedBox(width: Espaces.x20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        Fr.cours.progression(cours.nbTentees, cours.nbQuestions),
                        style: Typo.labelLg,
                      ),
                      const SizedBox(height: Espaces.x4),
                      Text(
                        Fr.reviser.decompte(
                          cours.nbChapitres,
                          cours.nbQuestions,
                          cours.nbFiches,
                        ),
                        style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Bouton(
              libelle: Fr.cours.reviser,
              icone: Icons.bolt,
              onTap: cours.nbQuestions == 0
                  ? null
                  : () => context.go(Chemins.session(cours.id)),
            ),
          ],
        ),
        const SizedBox(height: Espaces.x24),

        Text(Fr.cours.chapitres, style: Typo.headlineLg),
        const SizedBox(height: Espaces.x12),

        switch (chapitres) {
          AsyncData(:final value) when value.isEmpty => Carte(
            enfants: [
              EtatVide(
                icone: Icons.menu_book,
                titre: Fr.cours.aucunChapitre,
                description: Fr.cours.aucunChapitreDetail,
              ),
            ],
          ),
          AsyncData(:final value) => Column(
            children: [
              for (final ch in value) ...[
                _LigneChapitre(chapitre: ch),
                const SizedBox(height: Espaces.x8),
              ],
            ],
          ),
          AsyncError() => Text(
            Fr.erreurs.chargementImpossible,
            style: Typo.labelSm.copyWith(color: Couleurs.danger),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },

        const SizedBox(height: Espaces.x32),
      ],
    );
  }
}

class _LigneChapitre extends StatelessWidget {
  const _LigneChapitre({required this.chapitre});

  final ApercuChapitre chapitre;

  @override
  Widget build(BuildContext context) {
    return Carte(
      petite: true,
      enfants: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Couleurs.jauneDoux,
                borderRadius: BorderRadius.circular(Rayons.normal),
              ),
              child: Text(
                '${chapitre.index}',
                style: Typo.labelLg.copyWith(color: Couleurs.texteAccent),
              ),
            ),
            const SizedBox(width: Espaces.x12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    chapitre.titre ?? '—',
                    style: Typo.labelLg,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    Fr.cours.decompteChapitre(
                      chapitre.nbQuestions,
                      chapitre.nbFiches,
                    ),
                    style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                  ),
                ],
              ),
            ),
            if (chapitre.aRevoir)
              Puce(
                libelle: Fr.tableauDeBord.pointFaible,
                ton: TonPuce.danger,
                icone: Icons.priority_high,
              )
            else if (chapitre.taux != null)
              Text(
                '${(chapitre.taux! * 100).round()} %',
                style: Typo.labelMd.copyWith(color: Couleurs.attenue),
              ),
          ],
        ),
      ],
    );
  }
}

class _EnTraitement extends StatelessWidget {
  const _EnTraitement({required this.cours, required this.onRafraichir});

  final ApercuCours cours;
  final VoidCallback onRafraichir;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Espaces.ecran),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Retour(titre: Fr.reviser.titre),
          const Spacer(),
          const Icon(Icons.hourglass_top, size: 56, color: Couleurs.orange),
          const SizedBox(height: Espaces.x16),
          Text(
            Fr.cours.traitementTitre,
            style: Typo.headlineMd,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Espaces.x8),
          Text(
            Fr.cours.traitementDetail,
            style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Espaces.x24),
          Carte(
            petite: true,
            enfants: [
              Text(
                Fr.cours.traitementAstuce,
                style: Typo.labelSm.copyWith(color: Couleurs.attenue),
              ),
            ],
          ),
          const Spacer(),
          Bouton(
            libelle: Fr.commun.reessayer,
            icone: Icons.refresh,
            variante: VarianteBouton.secondaire,
            onTap: onRafraichir,
          ),
        ],
      ),
    );
  }
}

class _Echec extends StatelessWidget {
  const _Echec({required this.cours});

  final ApercuCours cours;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Espaces.ecran),
      child: Column(
        children: [
          _Retour(titre: Fr.reviser.titre),
          const Spacer(),
          const Icon(
            Icons.sentiment_dissatisfied,
            size: 56,
            color: Couleurs.danger,
          ),
          const SizedBox(height: Espaces.x16),
          Text(
            Fr.cours.echecTitre,
            style: Typo.headlineMd,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Espaces.x8),
          Text(
            Fr.cours.echecDetail,
            style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          Bouton(
            libelle: Fr.commun.retour,
            icone: Icons.arrow_back,
            variante: VarianteBouton.secondaire,
            onTap: () => context.go(Chemins.reviser),
          ),
        ],
      ),
    );
  }
}

class _Retour extends StatelessWidget {
  const _Retour({required this.titre});

  final String titre;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => context.go(Chemins.reviser),
        icon: const Icon(Icons.arrow_back, size: 20),
        label: Text(titre),
        style: TextButton.styleFrom(
          foregroundColor: Couleurs.attenue,
          minimumSize: const Size(0, Mesures.zoneTactile),
        ),
      ),
    );
  }
}
