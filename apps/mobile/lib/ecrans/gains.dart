import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../composants/bouton.dart';
import '../composants/carte.dart';
import '../composants/champ.dart';
import '../composants/chargement.dart';
import '../composants/coquille.dart';
import '../composants/etat_vide.dart';
import '../composants/mascotte.dart';
import '../composants/progression.dart';
import '../donnees/api.dart';
import '../donnees/modeles.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../metier/commission.dart';
import '../metier/serie.dart';
import '../metier/telephone.dart';
import '../routage.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Le portefeuille : solde, code parrain, filleuls, retrait.
///
/// Trois défauts de l'écran web sont corrigés ici : le code parrain est
/// réellement copiable, le retrait a un chemin depuis cet écran, et le seuil
/// de 3 000 F est expliqué avant le clic plutôt que refusé après
/// (rapport § 4.15).
class EcranGains extends ConsumerWidget {
  const EcranGains({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gains = ref.watch(gainsProvider);
    final profil = ref.watch(profilProvider);

    return Coquille(
      serie: switch (profil) {
        AsyncData(:final value) when value != null => etatSerie(
          current: value.serieCourante,
          lastValidatedOn: value.dernierJourValide,
        ),
        _ => null,
      },
      xpTotal: switch (profil) {
        AsyncData(:final value) when value != null => value.xpTotal,
        _ => null,
      },
      enfant: switch (gains) {
        AsyncData(:final value) => _Contenu(donnees: value),
        AsyncError() => Padding(
          padding: const EdgeInsets.all(Espaces.ecran),
          child: EtatVide(
            mascotte: EtatMascotte.oups,
            titre: Fr.erreurs.chargementImpossible,
            description: Fr.erreurs.chargementDetail,
            action: Bouton(
              libelle: Fr.commun.reessayer,
              icone: Icons.refresh,
              onTap: () => ref.invalidate(gainsProvider),
            ),
          ),
        ),
        _ => const Chargement.liste(),
      },
    );
  }
}

class _Contenu extends ConsumerWidget {
  const _Contenu({required this.donnees});

  final DonneesGains donnees;

  Future<void> _copier(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(Fr.gains.copie)));
  }

  Future<void> _partager(String code) async {
    final lien = Uri.https('wa.me', '/', {
      'text': Fr.gains.messagePartage(code),
    });
    // WhatsApp peut ne pas être installé : `launchUrl` échoue alors, et un
    // partage raté n'a pas à remonter en erreur d'écran.
    try {
      await launchUrl(lien, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solde = donnees.soldeFcfa;
    final peutRetirer = solde >= seuilRetraitFcfa;
    final code = donnees.codeParrain;

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaces.ecran,
        vertical: Espaces.x16,
      ),
      children: [
        Text(Fr.gains.titre, style: Typo.headlineXl),
        const SizedBox(height: Espaces.x20),

        // --- Solde
        Carte(
          enfants: [
            Text(
              Fr.gains.solde,
              style: Typo.labelSm.copyWith(color: Couleurs.attenue),
            ),
            Text(
              '$solde F',
              style: Typo.displayHerosMobile.copyWith(
                color: Couleurs.texteAccent,
              ),
            ),

            if (peutRetirer)
              Text(
                Fr.gains.retraitPossible,
                style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
              )
            else ...[
              BarreProgression(
                valeur: (solde / seuilRetraitFcfa).clamp(0.0, 1.0),
              ),
              Text(
                Fr.gains.resteAvantRetrait(seuilRetraitFcfa - solde),
                style: Typo.labelSm.copyWith(color: Couleurs.attenue),
              ),
            ],

            Bouton(
              libelle: Fr.gains.demanderRetrait,
              icone: Icons.smartphone,
              onTap: peutRetirer
                  ? () => ouvrirFeuilleRetrait(context, solde: solde)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: Espaces.x16),

        // --- Code parrain
        Carte(
          enfants: [
            Text(
              Fr.gains.tonCode,
              style: Typo.labelSm.copyWith(color: Couleurs.attenue),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    code ?? '—',
                    style: Typo.headlineXl.copyWith(letterSpacing: 2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (code != null)
                  IconButton(
                    onPressed: () => _copier(context, code),
                    icon: const Icon(Icons.content_copy),
                    color: Couleurs.texteAccent,
                    tooltip: Fr.gains.copier,
                  ),
              ],
            ),
            Text(
              Fr.gains.aideCode,
              style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
            ),
            if (code != null)
              Bouton(
                libelle: Fr.gains.partager,
                icone: Icons.share,
                variante: VarianteBouton.secondaire,
                onTap: () => _partager(code),
              ),
          ],
        ),
        const SizedBox(height: Espaces.x16),

        // --- Filleuls
        if (donnees.filleuls == 0)
          Carte(
            enfants: [
              EtatVide(
                mascotte: EtatMascotte.curieux,
                titre: Fr.gains.aucunFilleul,
                description: Fr.gains.aucunFilleulDetail,
              ),
            ],
          )
        else
          Carte(
            enfants: [
              Row(
                children: [
                  const Icon(
                    Icons.groups_outlined,
                    size: 24,
                    color: Couleurs.texteAccent,
                  ),
                  const SizedBox(width: Espaces.x8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          Fr.gains.filleulsPayants(donnees.filleulsPayants),
                          style: Typo.headlineMd,
                        ),
                        Text(
                          Fr.gains.filleulsTotal(donnees.filleuls),
                          style: Typo.labelSm.copyWith(
                            color: Couleurs.attenue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        const SizedBox(height: Espaces.x16),

        Bouton(
          libelle: Fr.gains.voirClassement,
          icone: Icons.emoji_events,
          variante: VarianteBouton.secondaire,
          onTap: () => context.descendre(Chemins.classement),
        ),
        const SizedBox(height: Espaces.x32),
      ],
    );
  }
}

/// Ouvre la feuille de demande de retrait.
///
/// Une feuille et non un écran : le formulaire tient en trois champs, et
/// revenir aux gains après l'envoi doit être immédiat. L'écran web équivalent
/// existe mais n'a aucun lien entrant — c'est ce qu'on évite ici.
void ouvrirFeuilleRetrait(BuildContext context, {required int solde}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Couleurs.carte,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Rayons.feuille)),
    ),
    builder: (_) => _FeuilleRetrait(solde: solde),
  );
}

class _FeuilleRetrait extends ConsumerStatefulWidget {
  const _FeuilleRetrait({required this.solde});

  final int solde;

  @override
  ConsumerState<_FeuilleRetrait> createState() => _FeuilleRetraitState();
}

class _FeuilleRetraitState extends ConsumerState<_FeuilleRetrait> {
  /// Les trois opérateurs que la route accepte (`mtn` | `moov` | `wave`).
  /// Le libellé est pour l'étudiant, la valeur pour le serveur.
  static const _operateurs = [
    ('mtn', 'MTN MoMo'),
    ('moov', 'Moov Money'),
    ('wave', 'Wave'),
  ];

  final _montant = TextEditingController();
  final _telephone = TextEditingController();

  String? _operateur = _operateurs.first.$1;
  String? _erreurMontant;
  String? _erreurTelephone;
  String? _erreurGenerale;
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    // Le solde entier est le retrait le plus probable : on le propose, sans
    // l'imposer.
    _montant.text = '${widget.solde}';
  }

  @override
  void dispose() {
    _montant.dispose();
    _telephone.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    final montant = int.tryParse(_montant.text.replaceAll(RegExp(r'\s'), ''));
    final numero = normaliserTelephone(_telephone.text);

    // Vérification locale d'abord : elle évite un aller-retour et dit
    // précisément lequel des deux plafonds n'est pas atteint. Le serveur
    // refait le même contrôle sur son propre solde — c'est lui qui décide.
    final verdict = verifierRetrait(
      soldeFcfa: widget.solde,
      montantFcfa: montant ?? 0,
    );

    setState(() {
      _erreurGenerale = null;
      _erreurMontant = switch (verdict) {
        RetraitRefuse(motif: RefusRetrait.montantInvalide) =>
          Fr.gains.montantInvalide,
        RetraitRefuse(motif: RefusRetrait.sousLeSeuil, :final seuil) =>
          Fr.gains.sousLeSeuil(seuil),
        RetraitRefuse(motif: RefusRetrait.soldeInsuffisant, :final solde) =>
          Fr.gains.soldeInsuffisant(solde),
        RetraitAutorise() => null,
      };
      _erreurTelephone = numero is NumeroNormalise
          ? null
          : Fr.gains.telephoneInvalide;
    });

    if (_erreurMontant != null ||
        _erreurTelephone != null ||
        _operateur == null) {
      return;
    }

    setState(() => _envoi = true);

    final reponse = await ref.read(depotGainsProvider).demanderRetrait(
      api: ref.read(apiProvider),
      montantFcfa: montant!,
      operateur: _operateur!,
      telephone: (numero as NumeroNormalise).e164,
    );

    if (!mounted) return;
    setState(() => _envoi = false);

    switch (reponse) {
      case ReponseSucces():
        // Le solde a changé : l'écran des gains doit se relire.
        ref.invalidate(gainsProvider);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Fr.gains.demandeEnvoyee)),
        );
      case ReponseEchec(:final erreur):
        // Le serveur renvoie désormais un message français prêt à afficher.
        setState(() {
          _erreurGenerale = erreur.isEmpty ? Fr.gains.demandeImpossible : erreur;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: Espaces.ecran,
        right: Espaces.ecran,
        top: Espaces.x24,
        // Laisse la place au clavier : sans cela, les champs du bas passent
        // dessous et la feuille devient inutilisable.
        bottom: Espaces.x24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(Fr.gains.titreRetrait, style: Typo.headlineLg),
            const SizedBox(height: Espaces.x16),

            Champ(
              libelle: Fr.gains.montant,
              aide: Fr.gains.aideMontant(seuilRetraitFcfa),
              erreur: _erreurMontant,
              controleur: _montant,
              typeClavier: TextInputType.number,
              actif: !_envoi,
            ),
            const SizedBox(height: Espaces.x16),

            ChampListe<String>(
              libelle: Fr.gains.operateur,
              valeur: _operateur,
              marqueur: Fr.gains.choisirOperateur,
              entrees: _operateurs,
              actif: !_envoi,
              onChange: (v) => setState(() => _operateur = v),
            ),
            const SizedBox(height: Espaces.x16),

            Champ(
              libelle: Fr.gains.telephone,
              aide: Fr.gains.aideTelephone,
              erreur: _erreurTelephone,
              controleur: _telephone,
              typeClavier: TextInputType.phone,
              actif: !_envoi,
            ),

            if (_erreurGenerale != null) ...[
              const SizedBox(height: Espaces.x16),
              Container(
                padding: const EdgeInsets.all(Espaces.x12),
                decoration: BoxDecoration(
                  color: Couleurs.dangerDoux,
                  borderRadius: BorderRadius.circular(Rayons.normal),
                ),
                child: Text(
                  _erreurGenerale!,
                  style: Typo.labelMd.copyWith(color: Couleurs.surDangerDoux),
                ),
              ),
            ],

            const SizedBox(height: Espaces.x24),
            Bouton(
              libelle: Fr.gains.envoyerDemande,
              icone: Icons.send,
              onTap: _envoi ? null : _envoyer,
            ),
            const SizedBox(height: Espaces.x8),
            TextButton(
              onPressed: _envoi ? null : () => Navigator.of(context).pop(),
              child: Text(Fr.commun.annuler),
            ),
          ],
        ),
      ),
    );
  }
}
