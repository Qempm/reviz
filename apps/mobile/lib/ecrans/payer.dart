import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../composants/bouton.dart';
import '../composants/carte.dart';
import '../composants/champ.dart';
import '../composants/lien_site.dart';
import '../donnees/api.dart';
import '../donnees/modeles.dart';
import '../donnees/supabase.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../composants/mascotte.dart';
import '../metier/offre.dart';
import '../metier/operateurs.dart';
import '../metier/telephone.dart';
import '../routage.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Payer un pack : Mobile Money sans quitter l'application, ou carte
/// bancaire sur la page de FedaPay (2.10.0).
///
/// L'étudiant choisit son pays, puis un opérateur de ce pays ou la carte ;
/// « Autre pays » n'a que la carte. En Mobile Money, il ne saisit que son
/// numéro ; par carte, rien du tout ici. Son nom et
/// son e-mail sont ceux de son compte, affichés en lecture seule — c'est le
/// serveur qui les lit et les transmet à FedaPay, pas cet écran. Le numéro
/// est pré-rempli avec celui du profil, sinon celui du dernier paiement.
///
/// Au bouton, la demande part sur le téléphone ; `EcranPaiement` prend le
/// relais et suit l'issue.
class EcranPayer extends ConsumerStatefulWidget {
  const EcranPayer({super.key, required this.pack, this.emailCompte});

  final PackBoutique pack;

  /// Remplaçable pour les tests ; par défaut, celui de la session.
  final String? emailCompte;

  @override
  ConsumerState<EcranPayer> createState() => _EcranPayerState();
}

class _EcranPayerState extends ConsumerState<EcranPayer> {
  final _telephone = TextEditingController();

  /// Le pays choisi ; `null` pour « Autre pays », où seule la carte se paie.
  Pays? _pays = paysParDefaut;

  /// La carte bancaire plutôt qu'un opérateur Mobile Money.
  bool _carte = false;

  Operateur? _operateur;
  String? _erreurTelephone;
  String? _erreurGenerale;
  bool _envoi = false;

  /// L'étudiant a-t-il touché au numéro ou au pays ? Si oui, un
  /// pré-remplissage qui arriverait en retard ne doit pas l'écraser.
  bool _saisiALaMain = false;

  @override
  void initState() {
    super.initState();
    _ajusterOperateur();
    _preremplir();
  }

  Future<void> _preremplir() async {
    final profil = await ref
        .read(profilProvider.future)
        .catchError((_) => null);
    var numero = profil?.telephone;
    numero ??= await ref.read(depotBoutiqueProvider).dernierTelephone();
    if (!mounted || numero == null || _saisiALaMain) return;

    final n = normaliserTelephone(numero);
    if (n is! NumeroNormalise) return;
    setState(() {
      _pays = n.pays;
      _telephone.text = formaterNational(n.national, n.pays);
      _ajusterOperateur();
    });
  }

  /// L'e-mail du compte. Protégé : sans Supabase initialisé (tests, galerie),
  /// l'accès lèverait.
  String? get _emailSession {
    try {
      return supabase.auth.currentUser?.email;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _telephone.dispose();
    super.dispose();
  }

  /// Le pays d'un numéro tapé avec son indicatif (`+228…`), s'il en porte un.
  Pays? get _paysDuNumero {
    final texte = _telephone.text.trim();
    var chiffres = texte.replaceAll(RegExp(r'\D'), '');
    final international = texte.startsWith('+') || chiffres.startsWith('00');
    if (!international) return null;
    if (chiffres.startsWith('00')) chiffres = chiffres.substring(2);
    for (final p in pays) {
      if (chiffres.startsWith(p.indicatif)) return p;
    }
    return null;
  }

  List<Operateur> get _operateurs =>
      _pays == null ? const [] : operateursDuPays(_pays!.code);

  /// Garde le choix s'il reste valable pour le pays ; choisit d'office quand
  /// il n'y a qu'une possibilité. Sans opérateur, c'est la carte.
  void _ajusterOperateur() {
    final possibles = _operateurs;
    if (_operateur != null && !possibles.contains(_operateur)) {
      _operateur = null;
    }
    if (possibles.isEmpty) {
      _carte = true;
    } else if (possibles.length == 1 && !_carte) {
      _operateur = possibles.single;
    }
  }

  void _choisirPays(Pays? p) {
    setState(() {
      _saisiALaMain = true;
      _pays = p;
      _erreurGenerale = null;
      _ajusterOperateur();
    });
  }

  Future<void> _payer() async {
    if (_carte) return _payerParCarte();

    final numero = normaliserTelephone(_telephone.text, _pays ?? paysParDefaut);

    setState(() {
      _erreurGenerale = null;
      _erreurTelephone = numero is NumeroNormalise
          ? null
          : Fr.boutique.numeroInvalide;
      if (_erreurTelephone == null && _operateur == null) {
        _erreurGenerale = Fr.boutique.choisisMoyen;
      }
    });
    if (numero is! NumeroNormalise || _operateur == null) return;

    setState(() => _envoi = true);
    HapticFeedback.lightImpact();

    final reponse = await ref
        .read(depotBoutiqueProvider)
        .ouvrirPaiement(
          ref.read(apiProvider),
          codePack: widget.pack.code,
          operateur: _operateur!.code,
          telephoneE164: numero.e164,
        );

    if (!mounted) return;
    setState(() => _envoi = false);

    switch (reponse) {
      case ReponseSucces(:final data):
        context.descendre(Chemins.paiement(data.id));
      case ReponseEchec(:final erreur):
        setState(() {
          _erreurGenerale = erreur.isEmpty
              ? Fr.boutique.ouvertureImpossible
              : erreur;
        });
    }
  }

  /// La carte : le serveur ouvre la transaction et rend la page FedaPay,
  /// ouverte dans le navigateur. L'écran de suivi prend le relais, et relit
  /// le paiement quand l'étudiant revient dans l'application.
  Future<void> _payerParCarte() async {
    setState(() {
      _envoi = true;
      _erreurGenerale = null;
      _erreurTelephone = null;
    });
    HapticFeedback.lightImpact();

    final reponse = await ref
        .read(depotBoutiqueProvider)
        .ouvrirPaiement(
          ref.read(apiProvider),
          codePack: widget.pack.code,
          carte: true,
        );

    if (!mounted) return;
    setState(() => _envoi = false);

    switch (reponse) {
      case ReponseSucces(:final data) when data.url != null:
        context.descendre(Chemins.paiement(data.id, carte: true));
        final ouverte = await ouvrirPagePaiement(Uri.parse(data.url!));
        if (!ouverte && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(Fr.boutique.pageImpossible)));
        }
      case ReponseSucces():
        setState(() => _erreurGenerale = Fr.boutique.pageImpossible);
      case ReponseEchec(:final erreur):
        setState(() {
          _erreurGenerale = erreur.isEmpty
              ? Fr.boutique.ouvertureImpossible
              : erreur;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pack = widget.pack;
    final prenom = ref.watch(profilProvider).value?.prenom;
    final email = widget.emailCompte ?? _emailSession;
    final operateurs = _operateurs;

    return Scaffold(
      backgroundColor: Couleurs.fond,
      appBar: AppBar(
        backgroundColor: Couleurs.fond,
        title: Text(Fr.boutique.payerTitre, style: Typo.headlineMd),
        leading: IconButton(
          onPressed: () => context.remonter(Chemins.boutique),
          icon: const Icon(Icons.arrow_back, color: Couleurs.encre),
          tooltip: Fr.commun.retour,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Mesures.largeurApp),
            child: ListView(
              padding: const EdgeInsets.all(Espaces.ecran),
              children: [
                // --- Ce qu'on achète : le jaune de la carte héros de la
                //     boutique, qu'on retrouve d'un écran à l'autre.
                Container(
                  padding: const EdgeInsets.all(Espaces.x20),
                  decoration: ShapeDecoration(
                    color: Couleurs.jaune,
                    shape: formeContinue(Rayons.heros),
                    shadows: Ombres.lueurJaune,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pack.libelle,
                              style: Typo.headlineLg.copyWith(
                                color: Couleurs.surJaune,
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${milliers(pack.prixFcfa)} ${Fr.boutique.fcfa}',
                                style: Typo.displayHerosMobile.copyWith(
                                  color: Couleurs.surJaune,
                                ),
                              ),
                            ),
                            const SizedBox(height: Espaces.x4),
                            Text(
                              Fr.boutique.resume(
                                dureeLisible(pack.dureeJours),
                                matieresLisibles(pack.plafondMatieres),
                                correctionsLisibles(pack.correctionsIncluses),
                              ),
                              style: Typo.labelSm.copyWith(
                                color: Couleurs.surJaune,
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
                                style: Typo.labelSm.copyWith(
                                  color: Couleurs.surJaune,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Espaces.x8),
                      const Mascotte(etat: EtatMascotte.telephone, taille: 84),
                    ],
                  ),
                ),
                const SizedBox(height: Espaces.x16),

                // --- Au nom de qui : lu dans le compte, pas saisi.
                if (prenom != null || email != null) ...[
                  Text(
                    Fr.boutique.auNomDe.toUpperCase(),
                    style: Typo.caption.copyWith(color: Couleurs.attenue),
                  ),
                  const SizedBox(height: Espaces.x8),
                  Carte(
                    petite: true,
                    enfants: [
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 22,
                            color: Couleurs.attenue,
                          ),
                          const SizedBox(width: Espaces.x12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (prenom != null)
                                  Text(prenom, style: Typo.labelLg),
                                if (email != null)
                                  Text(
                                    email,
                                    style: Typo.labelSm.copyWith(
                                      color: Couleurs.attenue,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: Espaces.x20),
                ],

                // --- Le pays : il décide des opérateurs proposés.
                Text(
                  Fr.boutique.paysTitre.toUpperCase(),
                  style: Typo.caption.copyWith(color: Couleurs.attenue),
                ),
                const SizedBox(height: Espaces.x8),
                Wrap(
                  spacing: Espaces.x8,
                  runSpacing: Espaces.x8,
                  children: [
                    for (final p in pays)
                      _Choix(
                        libelle: '${p.emoji} ${p.nom}',
                        choisi: _pays == p,
                        onTap: _envoi ? null : () => _choisirPays(p),
                      ),
                    _Choix(
                      libelle: Fr.boutique.autrePays,
                      icone: Icons.public,
                      choisi: _pays == null,
                      onTap: _envoi ? null : () => _choisirPays(null),
                    ),
                  ],
                ),
                const SizedBox(height: Espaces.x20),

                // --- Comment payer : les opérateurs du pays, et la carte.
                Text(
                  Fr.boutique.moyenTitre.toUpperCase(),
                  style: Typo.caption.copyWith(color: Couleurs.attenue),
                ),
                const SizedBox(height: Espaces.x8),
                Wrap(
                  spacing: Espaces.x8,
                  runSpacing: Espaces.x8,
                  children: [
                    for (final o in operateurs)
                      _Choix(
                        libelle: o.libelle,
                        choisi: !_carte && _operateur == o,
                        onTap: _envoi
                            ? null
                            : () => setState(() {
                                _carte = false;
                                _operateur = o;
                                _erreurGenerale = null;
                              }),
                      ),
                    _Choix(
                      libelle: Fr.boutique.carteBancaire,
                      icone: Icons.credit_card,
                      choisi: _carte,
                      onTap: _envoi
                          ? null
                          : () => setState(() {
                              _carte = true;
                              _erreurGenerale = null;
                            }),
                    ),
                  ],
                ),

                // --- Mobile Money : le seul champ à remplir.
                if (!_carte) ...[
                  const SizedBox(height: Espaces.x20),
                  Champ(
                    libelle: Fr.boutique.numeroPaiement,
                    aide: Fr.boutique.aideNumero,
                    erreur: _erreurTelephone,
                    controleur: _telephone,
                    typeClavier: TextInputType.phone,
                    actif: !_envoi,
                    onChange: (_) => setState(() {
                      _saisiALaMain = true;
                      final p = _paysDuNumero;
                      if (p != null && p != _pays) _pays = p;
                      _ajusterOperateur();
                    }),
                  ),
                ],

                if (_erreurGenerale != null) ...[
                  const SizedBox(height: Espaces.x16),
                  Container(
                    padding: const EdgeInsets.all(Espaces.x12),
                    decoration: ShapeDecoration(
                      color: Couleurs.dangerDoux,
                      shape: formeContinue(Rayons.normal),
                    ),
                    child: Text(
                      _erreurGenerale!,
                      style: Typo.labelSm.copyWith(
                        color: Couleurs.surDangerDoux,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: Espaces.x24),
                Bouton(
                  libelle: _carte
                      ? Fr.boutique.payerCarte(pack.prixFcfa)
                      : Fr.boutique.payer(pack.prixFcfa),
                  icone: _carte ? Icons.credit_card : Icons.smartphone,
                  chargement: _envoi,
                  onTap: _envoi ? null : _payer,
                ),
                const SizedBox(height: Espaces.x12),
                Text(
                  _carte
                      ? Fr.boutique.commentCaMarcheCarte
                      : Fr.boutique.commentCaMarche,
                  style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                  textAlign: TextAlign.center,
                ),
                LienSite(
                  page: PageSite.conditions,
                  avant: Fr.legal.avantPaiement,
                  lien: Fr.legal.lesConditions,
                ),
                const SizedBox(height: Espaces.x16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Un choix — pays, opérateur ou carte : la pastille de l'objectif dans la
/// boutique, l'encre quand il est choisi, le blanc sinon.
class _Choix extends StatelessWidget {
  const _Choix({
    required this.libelle,
    required this.choisi,
    required this.onTap,
    this.icone,
  });

  final String libelle;
  final bool choisi;
  final VoidCallback? onTap;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    final couleur = choisi ? Colors.white : Couleurs.encre;
    return Semantics(
      button: true,
      selected: choisi,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: AnimatedContainer(
          duration: Mouvement.doux,
          curve: Mouvement.courbeDouce,
          constraints: const BoxConstraints(minHeight: Mesures.zoneTactile),
          padding: const EdgeInsets.symmetric(
            horizontal: Espaces.x16,
            vertical: Espaces.x12,
          ),
          decoration: ShapeDecoration(
            color: choisi ? Couleurs.encre : Couleurs.carte,
            shape: const StadiumBorder(),
            shadows: choisi ? const [] : Ombres.cartePetite,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icone != null) ...[
                Icon(icone, size: 18, color: couleur),
                const SizedBox(width: Espaces.x8),
              ],
              Text(libelle, style: Typo.labelMd.copyWith(color: couleur)),
              if (choisi) ...[
                const SizedBox(width: Espaces.x8),
                const Icon(Icons.check, size: 18, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Ouvre la page de paiement FedaPay hors de l'application. Remplaçable par
/// les tests, qui n'ont pas de navigateur.
Future<bool> Function(Uri) ouvrirPagePaiement = (adresse) async {
  try {
    return await launchUrl(adresse, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
};
