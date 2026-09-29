import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
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

  /// Le pack dont le paiement s'ouvre, pour mettre **son** bouton en attente.
  String? _paiementEnOuverture;

  /// Ouvre la page FedaPay du pack, puis l'écran qui suit le paiement.
  ///
  /// La page s'ouvre dans un onglet du navigateur posé sur l'application
  /// (`inAppBrowserView`), et non dans une vue web : l'étudiant y voit
  /// l'adresse de FedaPay et son cadenas, ce qui compte au moment de payer.
  Future<void> _payer(PackBoutique pack) async {
    setState(() => _paiementEnOuverture = pack.code);

    final reponse = await ref
        .read(depotBoutiqueProvider)
        .ouvrirPaiement(ref.read(apiProvider), pack.code);

    if (!mounted) return;
    setState(() => _paiementEnOuverture = null);

    switch (reponse) {
      case ReponseSucces(:final data):
        // Le suivi d'abord : l'étudiant le trouvera en refermant l'onglet.
        context.descendre(Chemins.paiement(data.id), extra: data.url);
        try {
          await launchUrl(
            Uri.parse(data.url),
            mode: LaunchMode.inAppBrowserView,
          );
        } catch (_) {
          // Aucun navigateur : l'écran de suivi propose de rouvrir la page.
        }
      case ReponseEchec(:final erreur):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              erreur.isEmpty ? Fr.boutique.ouvertureImpossible : erreur,
            ),
          ),
        );
    }
  }

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
            ouvertureEnCours: _paiementEnOuverture == pack.code,
            occupe: _paiementEnOuverture != null,
            onActiver: _activerDecouverte,
            onPayer: () => _payer(pack),
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
    required this.ouvertureEnCours,
    required this.occupe,
    required this.onActiver,
    required this.onPayer,
  });

  final PackBoutique pack;
  final bool decouverteUtilisee;
  final bool enCours;

  /// Ce pack-ci ouvre son paiement : son bouton tourne.
  final bool ouvertureEnCours;

  /// Un paiement s'ouvre, quel qu'il soit : les autres boutons attendent,
  /// pour qu'un double appui n'ouvre pas deux transactions.
  final bool occupe;
  final VoidCallback onActiver;
  final VoidCallback onPayer;

  @override
  Widget build(BuildContext context) {
    // Le pack gratuit s'active tout de suite, sans fournisseur de paiement.
    // Les autres ouvrent la page FedaPay.
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
          Bouton(
            libelle: Fr.boutique.payer(pack.prixFcfa),
            icone: Icons.smartphone,
            chargement: ouvertureEnCours,
            onTap: occupe ? null : onPayer,
          ),
          Text(
            Fr.boutique.mobileMoney,
            style: Typo.labelSm.copyWith(color: Couleurs.attenue),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
