import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../composants/bouton.dart';
import '../composants/carte.dart';
import '../composants/champ.dart';
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

/// Payer un pack, sans quitter l'application.
///
/// L'étudiant ne saisit que son numéro et choisit son opérateur : son nom et
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

  Operateur? _operateur;
  String? _erreurTelephone;
  String? _erreurGenerale;
  bool _envoi = false;

  /// L'étudiant a-t-il touché au numéro ? Si oui, un pré-remplissage qui
  /// arriverait en retard ne doit pas l'écraser.
  bool _saisiALaMain = false;

  @override
  void initState() {
    super.initState();
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
      _telephone.text = n.pays.code == paysParDefaut.code
          ? formaterNational(n.national, n.pays)
          : '+${n.pays.indicatif} ${formaterNational(n.national, n.pays)}';
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

  /// Le pays du numéro en cours de saisie : celui de son indicatif s'il en
  /// porte un, le Bénin sinon — comme `normaliserTelephone`.
  Pays get _pays {
    final texte = _telephone.text.trim();
    var chiffres = texte.replaceAll(RegExp(r'\D'), '');
    final international = texte.startsWith('+') || chiffres.startsWith('00');
    if (chiffres.startsWith('00')) chiffres = chiffres.substring(2);
    if (international) {
      for (final p in pays) {
        if (chiffres.startsWith(p.indicatif)) return p;
      }
    }
    return paysParDefaut;
  }

  List<Operateur> get _operateurs => operateursDuPays(_pays.code);

  /// Garde le choix s'il reste valable pour le pays ; choisit d'office quand
  /// il n'y a qu'un opérateur possible.
  void _ajusterOperateur() {
    final possibles = _operateurs;
    if (_operateur != null && !possibles.contains(_operateur)) {
      _operateur = null;
    }
    if (possibles.length == 1) _operateur = possibles.single;
  }

  Future<void> _payer() async {
    final numero = normaliserTelephone(_telephone.text);

    setState(() {
      _erreurGenerale = null;
      _erreurTelephone = numero is NumeroNormalise
          ? null
          : Fr.boutique.numeroInvalide;
      if (_erreurTelephone == null && _operateur == null) {
        _erreurGenerale = Fr.boutique.choisisOperateur;
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
        context.descendre(Chemins.paiement(data));
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

                // --- Le seul champ à remplir
                Champ(
                  libelle: Fr.boutique.numeroPaiement,
                  aide: Fr.boutique.aideNumero,
                  erreur: _erreurTelephone,
                  controleur: _telephone,
                  typeClavier: TextInputType.phone,
                  actif: !_envoi,
                  onChange: (_) => setState(() {
                    _saisiALaMain = true;
                    _ajusterOperateur();
                  }),
                ),
                const SizedBox(height: Espaces.x20),

                Text(
                  Fr.boutique.operateurTitre.toUpperCase(),
                  style: Typo.caption.copyWith(color: Couleurs.attenue),
                ),
                const SizedBox(height: Espaces.x8),
                if (operateurs.isEmpty)
                  Text(
                    Fr.boutique.paysIndisponible(_pays.nom),
                    style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
                  )
                else
                  Wrap(
                    spacing: Espaces.x8,
                    runSpacing: Espaces.x8,
                    children: [
                      for (final o in operateurs)
                        _ChoixOperateur(
                          operateur: o,
                          choisi: _operateur == o,
                          onTap: _envoi
                              ? null
                              : () => setState(() {
                                  _operateur = o;
                                  _erreurGenerale = null;
                                }),
                        ),
                    ],
                  ),

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
                  libelle: Fr.boutique.payer(pack.prixFcfa),
                  icone: Icons.smartphone,
                  chargement: _envoi,
                  onTap: _envoi || operateurs.isEmpty ? null : _payer,
                ),
                const SizedBox(height: Espaces.x12),
                Text(
                  Fr.boutique.commentCaMarche,
                  style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Espaces.x24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Un opérateur à choisir : la pastille de l'objectif dans la boutique —
/// l'encre quand il est choisi, le blanc sinon.
class _ChoixOperateur extends StatelessWidget {
  const _ChoixOperateur({
    required this.operateur,
    required this.choisi,
    required this.onTap,
  });

  final Operateur operateur;
  final bool choisi;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
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
              Text(
                operateur.libelle,
                style: Typo.labelMd.copyWith(
                  color: choisi ? Colors.white : Couleurs.encre,
                ),
              ),
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
