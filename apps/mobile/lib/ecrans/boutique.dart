import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../composants/bouton.dart';
import '../composants/carte.dart';
import '../composants/chargement.dart';
import '../composants/etat_vide.dart';
import '../composants/mascotte.dart';
import '../composants/puce.dart';
import '../donnees/api.dart';
import '../donnees/depots.dart';
import '../donnees/modeles.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../metier/acces.dart';
import '../routage.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// La boutique : les packs, et l'accès en cours.
///
/// Un pack se paie **une fois** pour une durée donnée. L'écran le dit deux
/// fois — sur la carte d'accès et en pied de page — parce que c'est la règle
/// métier n° 1 et que tout le monde s'attend à un abonnement.
class EcranBoutique extends ConsumerWidget {
  const EcranBoutique({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boutique = ref.watch(boutiqueProvider);

    return Scaffold(
      backgroundColor: Couleurs.fond,
      appBar: AppBar(
        backgroundColor: Couleurs.fond,
        surfaceTintColor: Colors.transparent,
        title: Text(Fr.boutique.titre, style: Typo.headlineLg),
        leading: IconButton(
          onPressed: () => context.remonter(Chemins.profil),
          icon: const Icon(Icons.arrow_back, color: Couleurs.encre),
          tooltip: Fr.commun.retour,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Mesures.largeurApp),
            child: switch (boutique) {
              AsyncData(:final value) => _Contenu(
                donnees: value,
                onRafraichir: () => ref.invalidate(boutiqueProvider),
              ),
              AsyncError(:final error) => Padding(
                padding: const EdgeInsets.all(Espaces.ecran),
                child: EtatVide(
                  icone: Icons.cloud_off,
                  titre: Fr.erreurs.chargementImpossible,
                  description: '$error',
                  action: Bouton(
                    libelle: Fr.commun.reessayer,
                    icone: Icons.refresh,
                    onTap: () => ref.invalidate(boutiqueProvider),
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

class _Contenu extends ConsumerStatefulWidget {
  const _Contenu({required this.donnees, required this.onRafraichir});

  final DonneesBoutique donnees;
  final VoidCallback onRafraichir;

  @override
  ConsumerState<_Contenu> createState() => _ContenuState();
}

class _ContenuState extends ConsumerState<_Contenu> {
  bool _enCours = false;

  Future<void> _activerDecouverte() async {
    setState(() => _enCours = true);

    final reponse = await ref
        .read(depotBoutiqueProvider)
        .activerDecouverte(ref.read(apiProvider));

    if (!mounted) return;
    setState(() => _enCours = false);

    switch (reponse) {
      case ReponseSucces():
        widget.onRafraichir();
      case ReponseEchec(:final erreur):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              // Le serveur renvoie déjà un message en français ; on garde le
              // repli pour les cas d'erreur réseau, où il n'y en a pas.
              erreur.isEmpty ? Fr.boutique.activationImpossible : erreur,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final acces = widget.donnees.acces;

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaces.ecran,
        vertical: Espaces.x8,
      ),
      children: [
        Text(
          Fr.boutique.sousTitre,
          style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
        ),
        const SizedBox(height: Espaces.x16),

        _CarteAcces(acces: acces),
        const SizedBox(height: Espaces.x20),

        for (final pack in widget.donnees.packs) ...[
          _CartePack(
            pack: pack,
            decouverteUtilisee: widget.donnees.decouverteUtilisee,
            enCours: _enCours,
            onActiver: _activerDecouverte,
          ),
          const SizedBox(height: Espaces.x12),
        ],

        const SizedBox(height: Espaces.x8),
        Text(
          Fr.boutique.sansReconduction,
          style: Typo.labelSm.copyWith(color: Couleurs.attenue),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Espaces.x32),
      ],
    );
  }
}

/// L'accès en cours, au-dessus des packs.
///
/// Affiché depuis [EtatAcces], donc depuis la logique portée et testée : les
/// corrections restantes sont la **somme** de tous les packs actifs, pas
/// celles du premier trouvé. C'était le défaut § 4.10 du rapport.
class _CarteAcces extends StatelessWidget {
  const _CarteAcces({required this.acces});

  final EtatAcces acces;

  @override
  Widget build(BuildContext context) {
    return switch (acces) {
      AccesActif(
        :final joursRestants,
        :final correctionsRestantes,
        :final plafondMatieres,
      ) =>
        Carte(
          enfants: [
            Row(
              children: [
                const Icon(
                  Icons.verified_outlined,
                  size: 24,
                  color: Couleurs.texteAccent,
                ),
                const SizedBox(width: Espaces.x8),
                Expanded(
                  child: Text(
                    Fr.boutique.accesActif(joursRestants),
                    style: Typo.headlineMd,
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: Espaces.x8,
              runSpacing: Espaces.x8,
              children: [
                Puce(
                  libelle: Fr.boutique.correctionsRestantes(
                    correctionsRestantes,
                  ),
                  ton: correctionsRestantes == 0
                      ? TonPuce.neutre
                      : TonPuce.jaune,
                  icone: Icons.fact_check_outlined,
                ),
                Puce(
                  libelle: Fr.boutique.matieres(plafondMatieres),
                  icone: Icons.school_outlined,
                ),
              ],
            ),
          ],
        ),

      AccesExpire() => Carte(
        enfants: [
          Row(
            children: [
              const Mascotte(etat: EtatMascotte.dodo, taille: 72),
              const SizedBox(width: Espaces.x12),
              Expanded(
                child: Text(Fr.boutique.accesExpire, style: Typo.headlineMd),
              ),
            ],
          ),
          Text(
            Fr.boutique.accesExpireDetail,
            style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
          ),
        ],
      ),

      AucunAcces() => const SizedBox.shrink(),
    };
  }
}

class _CartePack extends StatelessWidget {
  const _CartePack({
    required this.pack,
    required this.decouverteUtilisee,
    required this.enCours,
    required this.onActiver,
  });

  final PackBoutique pack;
  final bool decouverteUtilisee;
  final bool enCours;
  final VoidCallback onActiver;

  @override
  Widget build(BuildContext context) {
    // Le pack gratuit est le seul activable tout de suite : il n'y a pas de
    // fournisseur de paiement à appeler. Les autres attendent FedaPay, et le
    // bouton le dit plutôt que d'ouvrir un écran vide.
    final gratuitDisponible = pack.gratuit && !decouverteUtilisee;

    return Carte(
      enfants: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pack.libelle,
                    style: Typo.headlineMd,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: Espaces.x4),
                  Text(
                    Fr.boutique.duree(pack.dureeJours),
                    style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Espaces.x8),
            Text(
              pack.gratuit ? Fr.boutique.gratuit : '${pack.prixFcfa} F',
              style: Typo.headlineLg.copyWith(color: Couleurs.texteAccent),
            ),
          ],
        ),

        if (pack.description != null)
          Text(
            pack.description!,
            style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
          ),

        Wrap(
          spacing: Espaces.x8,
          runSpacing: Espaces.x8,
          children: [
            Puce(
              libelle: Fr.boutique.corrections(pack.correctionsIncluses),
              icone: Icons.fact_check_outlined,
            ),
            Puce(
              libelle: Fr.boutique.matieres(pack.plafondMatieres),
              icone: Icons.school_outlined,
            ),
          ],
        ),

        if (pack.gratuit)
          Bouton(
            libelle: decouverteUtilisee
                ? Fr.boutique.decouverteUtilisee
                : Fr.boutique.activerDecouverte,
            icone: decouverteUtilisee ? Icons.check : Icons.card_giftcard,
            onTap: gratuitDisponible && !enCours ? onActiver : null,
          )
        else ...[
          Bouton(libelle: Fr.boutique.choisir, icone: Icons.smartphone),
          Text(
            Fr.boutique.paiementBientot,
            style: Typo.labelSm.copyWith(color: Couleurs.attenue),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
