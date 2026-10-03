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
import '../metier/offre.dart';
import '../metier/plateforme.dart';
import '../routage.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// La boutique : les packs, et l'accès en cours.
///
/// Un pack se paie **une fois** pour une durée donnée. L'écran le dit deux
/// fois — sur la carte d'accès et en pied de page — parce que c'est la règle
/// métier n° 1 et que tout le monde s'attend à un abonnement.
///
/// Sur iPhone, l'écran devient « Mon accès » : l'accès en cours et le pack
/// gratuit, sans prix ni bouton de paiement (`metier/plateforme.dart`).
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
        title: Text(
          achatsDansLApplication ? Fr.boutique.titre : Fr.boutique.titreAcces,
          style: Typo.headlineLg,
        ),
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
              AsyncError() => Padding(
                padding: const EdgeInsets.all(Espaces.ecran),
                child: EtatVide(
                  mascotte: EtatMascotte.oups,
                  titre: Fr.erreurs.chargementImpossible,
                  description: Fr.erreurs.chargementDetail,
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

  /// Le pack mis en avant : le conseillé à l'ouverture, puis celui que
  /// l'étudiant choisit — par son objectif ou en touchant une carte.
  String? _choix;

  /// Payer se fait sur un écran à part, dans l'application : numéro,
  /// opérateur, puis la demande part sur le téléphone.
  void _payer(PackBoutique pack) =>
      context.descendre(Chemins.payer, extra: pack);

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
    if (achatsDansLApplication) return _vitrine(context);

    final acces = widget.donnees.acces;
    // Sur iPhone, seul le pack gratuit reste : il ne s'achète pas.
    final packs = widget.donnees.packs.where((p) => p.gratuit);

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaces.ecran,
        vertical: Espaces.x8,
      ),
      children: [
        Text(
          achatsDansLApplication
              ? Fr.boutique.sousTitre
              : Fr.boutique.accesLieAuCompte,
          style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
        ),
        const SizedBox(height: Espaces.x16),

        _CarteAcces(acces: acces),
        const SizedBox(height: Espaces.x20),

        for (final pack in packs) ...[
          _CartePack(
            pack: pack,
            decouverteUtilisee: widget.donnees.decouverteUtilisee,
            enCours: _enCours,
            onActiver: _activerDecouverte,
            onPayer: () => _payer(pack),
          ),
          const SizedBox(height: Espaces.x12),
        ],

        if (achatsDansLApplication) ...[
          const SizedBox(height: Espaces.x8),
          Text(
            Fr.boutique.sansReconduction,
            style: Typo.labelSm.copyWith(color: Couleurs.attenue),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: Espaces.x32),
      ],
    );
  }

  /// La boutique d'après la maquette « Packs » de l'identité du 3 octobre :
  /// l'objectif d'abord (« Tu prépares quoi ? »), le pack qui y répond en
  /// carte héros jaune, les autres en cartes compactes, la découverte à part.
  Widget _vitrine(BuildContext context) {
    final donnees = widget.donnees;
    final payants = donnees.packs.where((p) => !p.gratuit).toList();
    final gratuit = donnees.packs.where((p) => p.gratuit).firstOrNull;

    PackOffre offre(PackBoutique p) =>
        (code: p.code, prixFcfa: p.prixFcfa, jours: p.dureeJours);
    final meilleur = meilleurPrixParJour(payants.map(offre));
    final codeActif = payants.any((p) => p.code == _choix)
        ? _choix
        : choixInitial(payants.map(offre));
    final actif = payants.where((p) => p.code == codeActif).firstOrNull;

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

        _CarteAcces(acces: donnees.acces),
        if (donnees.acces is! AucunAcces) const SizedBox(height: Espaces.x20),

        if (actif != null) ...[
          Text(Fr.boutique.questionObjectif, style: Typo.headlineMd),
          const SizedBox(height: Espaces.x12),
          Wrap(
            spacing: Espaces.x8,
            runSpacing: Espaces.x8,
            children: [
              for (final p in payants)
                _PastilleObjectif(
                  libelle: objectifDe(p.code, p.libelle).bouton,
                  choisie: p.code == actif.code,
                  onTap: () => setState(() => _choix = p.code),
                ),
            ],
          ),
          const SizedBox(height: Espaces.x12),
          Text(
            phraseConseil(
              code: actif.code,
              libelle: actif.libelle,
              jours: actif.dureeJours,
              matieres: actif.plafondMatieres,
              corrections: actif.correctionsIncluses,
            ),
            style: Typo.labelSm.copyWith(color: Couleurs.attenue),
          ),
          // De l'air au-dessus de la carte héros : le panthéreau à sa
          // médaille en dépasse.
          const SizedBox(height: Espaces.x40),
          _CarteHeros(pack: actif, onPayer: () => _payer(actif)),
          const SizedBox(height: Espaces.x16),
          for (final p in payants.where((p) => p.code != actif.code)) ...[
            _CarteCompacte(
              pack: p,
              meilleurPrix: p.code == meilleur,
              onTap: () => setState(() => _choix = p.code),
            ),
            const SizedBox(height: Espaces.x12),
          ],
        ],

        if (gratuit != null) ...[
          const SizedBox(height: Espaces.x8),
          _CarteDecouverte(
            pack: gratuit,
            utilisee: donnees.decouverteUtilisee,
            enCours: _enCours,
            onActiver: _activerDecouverte,
          ),
        ],

        const SizedBox(height: Espaces.x16),
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

/// Une pastille « Tu prépares quoi ? » : l'encre quand elle est choisie, le
/// blanc sinon — le même geste que le sélecteur de la page d'accueil.
class _PastilleObjectif extends StatelessWidget {
  const _PastilleObjectif({
    required this.libelle,
    required this.choisie,
    required this.onTap,
  });

  final String libelle;
  final bool choisie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: choisie,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Mouvement.doux,
          constraints: const BoxConstraints(minHeight: Mesures.zoneTactile),
          padding: const EdgeInsets.symmetric(horizontal: Espaces.x16),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: choisie ? Couleurs.encre : Couleurs.carte,
            shape: const StadiumBorder(),
            shadows: choisie ? const [] : Ombres.cartePetite,
          ),
          child: Text(
            libelle,
            style: Typo.labelMd.copyWith(
              color: choisie ? Colors.white : Couleurs.encre,
            ),
          ),
        ),
      ),
    );
  }
}

/// Le pack choisi : la carte jaune de la maquette, prix en Fredoka, le
/// panthéreau et sa médaille qui en dépasse, et le seul bouton de l'écran.
class _CarteHeros extends StatelessWidget {
  const _CarteHeros({required this.pack, required this.onPayer});

  final PackBoutique pack;
  final VoidCallback onPayer;

  @override
  Widget build(BuildContext context) {
    final texte = Couleurs.surJaune;

    Widget ligne(IconData icone, String libelle) => Row(
      children: [
        Icon(icone, size: 20, color: texte),
        const SizedBox(width: Espaces.x8),
        Expanded(
          child: Text(libelle, style: Typo.labelLg.copyWith(color: texte)),
        ),
      ],
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            Espaces.x20,
            Espaces.x20,
            Espaces.x20,
            Espaces.x20,
          ),
          decoration: ShapeDecoration(
            color: Couleurs.jaune,
            shape: formeContinue(Rayons.heros),
            shadows: Ombres.lueurJaune,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Espaces.x12,
                  vertical: Espaces.x4,
                ),
                decoration: const ShapeDecoration(
                  color: Couleurs.encre,
                  shape: StadiumBorder(),
                ),
                child: Text(
                  Fr.boutique.recommande,
                  style: Typo.labelSm.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(height: Espaces.x12),
              // La place du panthéreau, à droite : le titre et le prix ne
              // passent jamais dessous.
              Padding(
                padding: const EdgeInsets.only(right: 88),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack.libelle,
                      style: Typo.headlineLg.copyWith(color: texte),
                    ),
                    const SizedBox(height: Espaces.x4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            milliers(pack.prixFcfa),
                            style: Typo.displayHerosMobile.copyWith(
                              color: texte,
                              fontSize: 44,
                            ),
                          ),
                          const SizedBox(width: Espaces.x4),
                          Text(
                            Fr.boutique.fcfa,
                            style: Typo.labelLg.copyWith(color: texte),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Espaces.x8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Espaces.x8,
                  vertical: Espaces.x4,
                ),
                decoration: ShapeDecoration(
                  color: Couleurs.encre.withValues(alpha: 0.1),
                  shape: formeContinue(Rayons.petit),
                ),
                child: Text(
                  prixParJour(pack.prixFcfa, pack.dureeJours),
                  style: Typo.labelSm.copyWith(color: texte),
                ),
              ),
              const SizedBox(height: Espaces.x16),
              ligne(Icons.schedule, Fr.boutique.accesPendant(pack.dureeJours)),
              const SizedBox(height: Espaces.x8),
              ligne(
                Icons.menu_book_outlined,
                matieresLisibles(pack.plafondMatieres),
              ),
              const SizedBox(height: Espaces.x8),
              ligne(
                Icons.fact_check_outlined,
                Fr.boutique.corrections(pack.correctionsIncluses),
              ),
              if (pack.description != null) ...[
                const SizedBox(height: Espaces.x12),
                Text(
                  pack.description!,
                  style: Typo.bodyMd.copyWith(color: const Color(0xFF3B3424)),
                ),
              ],
              const SizedBox(height: Espaces.x16),
              Bouton(
                libelle: Fr.boutique.payer(pack.prixFcfa),
                icone: Icons.smartphone,
                variante: VarianteBouton.encre,
                onTap: onPayer,
              ),
              const SizedBox(height: Espaces.x8),
              Center(
                child: Text(
                  Fr.boutique.mobileMoney,
                  style: Typo.labelSm.copyWith(color: const Color(0xFF3B3424)),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        const Positioned(
          top: -36,
          right: -4,
          child: IgnorePointer(
            child: Mascotte(etat: EtatMascotte.medaille, taille: 112),
          ),
        ),
      ],
    );
  }
}

/// Un pack qui n'est pas choisi : une ligne blanche, le prix à droite.
/// Toucher la carte la met en avant.
class _CarteCompacte extends StatelessWidget {
  const _CarteCompacte({
    required this.pack,
    required this.meilleurPrix,
    required this.onTap,
  });

  final PackBoutique pack;
  final bool meilleurPrix;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: Fr.boutique.choisirPack(pack.libelle),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(Espaces.x16),
          decoration: ShapeDecoration(
            color: Couleurs.carte,
            shape: formeContinue(Rayons.carte),
            shadows: Ombres.cartePetite,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: Espaces.x8,
                      runSpacing: Espaces.x4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(pack.libelle, style: Typo.headlineMd),
                        if (meilleurPrix)
                          Puce(
                            libelle: Fr.boutique.meilleurPrix,
                            ton: TonPuce.orange,
                          ),
                      ],
                    ),
                    const SizedBox(height: Espaces.x4),
                    Text(
                      Fr.boutique.resume(
                        dureeLisible(pack.dureeJours),
                        matieresLisibles(pack.plafondMatieres),
                        correctionsLisibles(pack.correctionsIncluses),
                      ),
                      style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Espaces.x12),
              Text(
                '${milliers(pack.prixFcfa)} F',
                style: Typo.headlineLg,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le pack gratuit, à part : il ne se paie pas, il s'active.
class _CarteDecouverte extends StatelessWidget {
  const _CarteDecouverte({
    required this.pack,
    required this.utilisee,
    required this.enCours,
    required this.onActiver,
  });

  final PackBoutique pack;
  final bool utilisee;
  final bool enCours;
  final VoidCallback onActiver;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Espaces.x16),
      decoration: ShapeDecoration(
        color: Couleurs.surfaceBasse,
        shape: formeContinue(
          Rayons.carte,
          bord: const BorderSide(color: Couleurs.bordure, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Mascotte(etat: EtatMascotte.cadeau, taille: 72),
              const SizedBox(width: Espaces.x12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Fr.boutique.essaiTitre, style: Typo.headlineMd),
                    const SizedBox(height: Espaces.x4),
                    Text(
                      Fr.boutique.resume(
                        dureeLisible(pack.dureeJours),
                        matieresLisibles(pack.plafondMatieres),
                        correctionsLisibles(pack.correctionsIncluses),
                      ),
                      style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Espaces.x12),
          Bouton(
            libelle: utilisee
                ? Fr.boutique.decouverteUtilisee
                : Fr.boutique.activerDecouverte,
            icone: utilisee ? Icons.check : Icons.card_giftcard,
            variante: VarianteBouton.secondaire,
            onTap: !utilisee && !enCours ? onActiver : null,
          ),
        ],
      ),
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
            achatsDansLApplication
                ? Fr.boutique.accesExpireDetail
                : Fr.boutique.accesExpireDetailSansAchat,
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
    required this.onPayer,
  });

  final PackBoutique pack;
  final bool decouverteUtilisee;
  final bool enCours;

  final VoidCallback onActiver;
  final VoidCallback onPayer;

  @override
  Widget build(BuildContext context) {
    // Le pack gratuit s'active tout de suite, sans fournisseur de paiement.
    // Les autres ouvrent l'écran de paiement, dans l'application.
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
              pack.gratuit ? Fr.boutique.gratuit : '${milliers(pack.prixFcfa)} F',
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
            onTap: onPayer,
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
