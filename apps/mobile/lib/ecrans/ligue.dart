import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../composants/blason_ligue.dart';
import '../composants/bouton.dart';
import '../composants/carte.dart';
import '../composants/chargement.dart';
import '../composants/etat_vide.dart';
import '../composants/mascotte.dart';
import '../composants/podium.dart';
import '../donnees/modeles.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../metier/ligues.dart';
import '../routage.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// La ligue de la semaine : trente étudiants, sept qui montent, cinq qui
/// descendent, et un compte à rebours jusqu'à lundi.
///
/// Ce que ChatGPT ne donne pas : une raison de revenir demain. La règle est
/// dans `metier/ligues.dart` (miroir de `cloturer_ligues()`), les données
/// viennent de `ma_ligue()`, qui ne rend aucun identifiant.
class EcranLigue extends ConsumerWidget {
  const EcranLigue({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ligue = ref.watch(ligueProvider);

    return Scaffold(
      backgroundColor: Couleurs.fond,
      appBar: AppBar(
        backgroundColor: Couleurs.fond,
        surfaceTintColor: Colors.transparent,
        title: Text(Fr.ligue.titre, style: Typo.headlineLg),
        leading: IconButton(
          onPressed: () => context.remonter(Chemins.accueil),
          icon: const Icon(Icons.arrow_back, color: Couleurs.encre),
          tooltip: Fr.commun.retour,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Mesures.largeurApp),
            child: switch (ligue) {
              AsyncData(:final value) => RefreshIndicator(
                color: Couleurs.encre,
                onRefresh: () => ref.refresh(ligueProvider.future),
                child: _Contenu(ligue: value),
              ),
              AsyncError() => Padding(
                padding: const EdgeInsets.all(Espaces.ecran),
                child: EtatVide(
                  mascotte: EtatMascotte.oups,
                  titre: Fr.erreurs.chargementImpossible,
                  description: Fr.erreurs.chargementDetail,
                  action: Bouton(
                    libelle: Fr.commun.reessayer,
                    icone: Icons.refresh,
                    onTap: () => ref.invalidate(ligueProvider),
                  ),
                ),
              ),
              _ => const Chargement.liste(),
            },
          ),
        ),
      ),
    );
  }
}

class _Contenu extends StatelessWidget {
  const _Contenu({required this.ligue});

  final DonneesLigue ligue;

  @override
  Widget build(BuildContext context) {
    final membres = ligue.membres;
    final n = membres.length;
    IssueLigue issue(LigneClassement l) => issueDuRang(
      rang: l.rang,
      membres: n,
      division: ligue.division,
      xp: l.xp,
    );

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaces.ecran,
        vertical: Espaces.x8,
      ),
      children: [
        _EnTeteLigue(ligue: ligue),
        const SizedBox(height: Espaces.x16),

        if (ligue.bilanRecent case final bilan?) ...[
          _Bilan(bilan: bilan),
          const SizedBox(height: Espaces.x16),
        ],

        if (membres.isEmpty)
          Carte(
            enfants: [
              EtatVide(
                mascotte: EtatMascotte.curieux,
                titre: Fr.ligue.videTitre,
                description: Fr.ligue.videDetail,
                action: Bouton(
                  libelle: Fr.ligue.commencer,
                  icone: Icons.bolt,
                  onTap: () => context.go(Chemins.reviser),
                ),
              ),
            ],
          )
        else
          for (var i = 0; i < n; i++) ...[
            // Les frontières des zones, là où elles tombent.
            if (i > 0 &&
                issue(membres[i - 1]) == IssueLigue.monte &&
                issue(membres[i]) != IssueLigue.monte)
              _Frontiere(
                texte: Fr.ligue.zoneMontee,
                couleur: Couleurs.jauneProfond,
                icone: Icons.keyboard_double_arrow_up_rounded,
              ),
            if (i > 0 &&
                issue(membres[i - 1]) != IssueLigue.descend &&
                issue(membres[i]) == IssueLigue.descend)
              _Frontiere(
                texte: Fr.ligue.zoneDescente,
                couleur: Couleurs.orangeProfond,
                icone: Icons.keyboard_double_arrow_down_rounded,
              ),
            RangeeClassement(ligne: membres[i]),
            const SizedBox(height: Espaces.x8),
          ],

        const SizedBox(height: Espaces.x16),
        Center(
          child: TextButton.icon(
            onPressed: () => context.descendre(Chemins.classement),
            icon: const Icon(Icons.leaderboard_rounded, size: 20),
            label: Text(Fr.ligue.classementFaculte),
            style: TextButton.styleFrom(
              foregroundColor: Couleurs.attenue,
              minimumSize: const Size(0, Mesures.zoneTactile),
            ),
          ),
        ),
        const SizedBox(height: Espaces.x32),
      ],
    );
  }
}

/// Le blason de la division, son nom et le temps qu'il reste.
class _EnTeteLigue extends StatelessWidget {
  const _EnTeteLigue({required this.ligue});

  final DonneesLigue ligue;

  @override
  Widget build(BuildContext context) {
    final reste = ligue.fin.difference(DateTime.now());
    return Carte(
      enfants: [
        Row(
          children: [
            BlasonLigue(division: ligue.division, taille: 64),
            const SizedBox(width: Espaces.x16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(Fr.ligue.nom(ligue.division), style: Typo.headlineMd),
                  const SizedBox(height: Espaces.x4),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 16,
                        color: Couleurs.orange,
                      ),
                      const SizedBox(width: Espaces.x4),
                      Flexible(
                        child: Text(
                          Fr.ligue.finDans(
                            reste.isNegative ? Duration.zero : reste,
                          ),
                          style: Typo.labelMd.copyWith(color: Couleurs.orange),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        Text(
          Fr.ligue.regle,
          style: Typo.labelSm.copyWith(color: Couleurs.attenue),
        ),
      ],
    );
  }
}

/// L'issue de la semaine dernière : montée, maintien ou descente.
class _Bilan extends StatelessWidget {
  const _Bilan({required this.bilan});

  final BilanLigue bilan;

  @override
  Widget build(BuildContext context) {
    final issue = issueDepuis(bilan.issue) ?? IssueLigue.reste;
    final (titre, pose) = switch (issue) {
      IssueLigue.monte => (
        Fr.ligue.monte(bilan.division + 1),
        EtatMascotte.medaille,
      ),
      IssueLigue.descend => (
        Fr.ligue.descend(bilan.division - 1),
        EtatMascotte.courage,
      ),
      IssueLigue.reste => (Fr.ligue.reste(bilan.division), EtatMascotte.bravo),
    };
    return Carte(
      petite: true,
      enfants: [
        Row(
          children: [
            TeteMascotte(etat: pose, taille: 48),
            const SizedBox(width: Espaces.x12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(titre, style: Typo.labelLg),
                  Text(
                    Fr.ligue.bilan(bilan.rang),
                    style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Frontiere extends StatelessWidget {
  const _Frontiere({
    required this.texte,
    required this.couleur,
    required this.icone,
  });

  final String texte;
  final Color couleur;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Espaces.x8),
      child: Row(
        children: [
          Icon(icone, size: 18, color: couleur),
          const SizedBox(width: Espaces.x4),
          Flexible(
            child: Text(texte, style: Typo.labelSm.copyWith(color: couleur)),
          ),
          const SizedBox(width: Espaces.x8),
          Expanded(child: Container(height: 2, color: couleur)),
        ],
      ),
    );
  }
}
