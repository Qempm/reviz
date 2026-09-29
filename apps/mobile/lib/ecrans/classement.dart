import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../composants/bouton.dart';
import '../composants/carte.dart';
import '../composants/etat_vide.dart';
import '../composants/podium.dart';
import '../donnees/depots.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../routage.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Le classement de sa faculté.
///
/// Sa faculté, et non un classement global : c'est ce que la fonction SQL
/// `classement_faculte()` rend, et c'est aussi le seul classement qui veut
/// dire quelque chose pour un étudiant. Aucun identifiant ne descend ici —
/// « c'est toi » est un booléen posé par la base.
class EcranClassement extends ConsumerWidget {
  const EcranClassement({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classement = ref.watch(classementProvider);

    return Scaffold(
      backgroundColor: Couleurs.cream,
      appBar: AppBar(
        backgroundColor: Couleurs.cream,
        surfaceTintColor: Colors.transparent,
        title: Text(Fr.classement.titre, style: Typo.headlineLg),
        leading: IconButton(
          onPressed: () => context.remonter(Chemins.gains),
          icon: const Icon(Icons.arrow_back, color: Couleurs.encre),
          tooltip: Fr.commun.retour,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Mesures.largeurApp),
            child: switch (classement) {
              AsyncData(:final value) when value.lignes.isEmpty => Padding(
                padding: const EdgeInsets.all(Espaces.ecran),
                child: EtatVide(
                  icone: Icons.emoji_events_outlined,
                  titre: Fr.classement.aucun,
                  description: Fr.classement.aucunDetail,
                  action: Bouton(
                    libelle: Fr.reviser.titre,
                    icone: Icons.bolt,
                    onTap: () => context.go(Chemins.reviser),
                  ),
                ),
              ),
              AsyncData(:final value) => _Tableau(donnees: value),
              AsyncError(:final error) => Padding(
                padding: const EdgeInsets.all(Espaces.ecran),
                child: EtatVide(
                  icone: Icons.cloud_off,
                  titre: Fr.erreurs.chargementImpossible,
                  description: '$error',
                  action: Bouton(
                    libelle: Fr.commun.reessayer,
                    icone: Icons.refresh,
                    onTap: () => ref.invalidate(classementProvider),
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

class _Tableau extends StatelessWidget {
  const _Tableau({required this.donnees});

  final DonneesClassement donnees;

  @override
  Widget build(BuildContext context) {
    final suite = donnees.lignes.where((l) => l.rang > 3).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaces.ecran,
        vertical: Espaces.x8,
      ),
      children: [
        Text(
          Fr.classement.sousTitre,
          style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
        ),
        const SizedBox(height: Espaces.x20),

        Podium(lignes: donnees.lignes),
        const SizedBox(height: Espaces.x20),

        // Sa propre position, même hors du haut de tableau : un 47ᵉ rang qui
        // n'apparaît nulle part donne l'impression de ne pas compter.
        Carte(
          enfants: [
            Row(
              children: [
                Icon(
                  donnees.monRang == null
                      ? Icons.play_circle_outline
                      : Icons.my_location,
                  size: 24,
                  color: Couleurs.texteAccent,
                ),
                const SizedBox(width: Espaces.x8),
                Expanded(
                  child: Text(
                    donnees.monRang == null
                        ? Fr.classement.nonClasse
                        : Fr.classement.monRang(donnees.monRang!),
                    style: Typo.headlineSm,
                  ),
                ),
              ],
            ),
          ],
        ),

        if (suite.isNotEmpty) ...[
          const SizedBox(height: Espaces.x20),
          for (final l in suite) ...[
            RangeeClassement(ligne: l),
            const SizedBox(height: Espaces.x8),
          ],
        ],

        const SizedBox(height: Espaces.x32),
      ],
    );
  }
}
