import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../composants/bouton.dart';
import '../composants/carte.dart';
import '../composants/champ.dart';
import '../donnees/api.dart';
import '../donnees/supabase.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../metier/commission.dart';
import '../routage.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Supprimer son compte.
///
/// L'écran **dit ce qui part et ce qui reste**, parce que les deux ne sont pas
/// symétriques : le contenu personnel disparaît, les lignes financières
/// gardent leurs montants sans identité dessus — un grand livre immuable ne
/// s'efface pas. Cacher cette moitié serait mentir sur ce que fait le bouton.
///
/// Et il prévient quand un solde reste à retirer : après l'anonymisation, plus
/// personne ne sait à qui verser.
class EcranSuppression extends ConsumerStatefulWidget {
  const EcranSuppression({super.key});

  @override
  ConsumerState<EcranSuppression> createState() => _EcranSuppressionState();
}

class _EcranSuppressionState extends ConsumerState<EcranSuppression> {
  final _saisie = TextEditingController();

  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _saisie.dispose();
    super.dispose();
  }

  /// Le mot à recopier : le prénom, ou un mot de secours pour un profil qui
  /// n'en a pas — l'inscription le rend facultatif.
  String _attendu(String? prenom) =>
      (prenom == null || prenom.trim().isEmpty)
      ? Fr.suppression.motSansPrenom
      : prenom.trim();

  Future<void> _supprimer(String? prenom) async {
    final attendu = _attendu(prenom);

    if (_saisie.text.trim().toLowerCase() != attendu.toLowerCase()) {
      setState(() => _erreur = Fr.suppression.prenomIncorrect);
      return;
    }

    setState(() {
      _enCours = true;
      _erreur = null;
    });

    final reponse = await ref
        .read(depotProfilProvider)
        .supprimer(ref.read(apiProvider));

    if (!mounted) return;

    switch (reponse) {
      case ReponseSucces():
        // Les sessions ont été révoquées côté serveur ; on ferme la nôtre
        // pour que le routeur ramène à l'écran de connexion.
        await supabase.auth.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(Fr.suppression.faite)));
      case ReponseEchec(:final erreur):
        setState(() {
          _enCours = false;
          _erreur = erreur.isEmpty ? Fr.suppression.echec : erreur;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profil = ref.watch(profilProvider);
    final gains = ref.watch(gainsProvider);

    final prenom = switch (profil) {
      AsyncData(:final value) when value != null => value.prenom,
      _ => null,
    };

    final solde = switch (gains) {
      AsyncData(:final value) => value.soldeFcfa,
      _ => 0,
    };

    return Scaffold(
      backgroundColor: Couleurs.cream,
      appBar: AppBar(
        backgroundColor: Couleurs.cream,
        surfaceTintColor: Colors.transparent,
        title: Text(Fr.suppression.titre, style: Typo.headlineLg),
        leading: IconButton(
          onPressed: () => context.go(Chemins.profil),
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
              padding: const EdgeInsets.symmetric(
                horizontal: Espaces.ecran,
                vertical: Espaces.x8,
              ),
              children: [
                Container(
                  padding: const EdgeInsets.all(Espaces.x12),
                  decoration: BoxDecoration(
                    color: Couleurs.dangerDoux,
                    borderRadius: BorderRadius.circular(Rayons.normal),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 24,
                        color: Couleurs.surDangerDoux,
                      ),
                      const SizedBox(width: Espaces.x8),
                      Expanded(
                        child: Text(
                          Fr.suppression.avertissement,
                          style: Typo.labelMd.copyWith(
                            color: Couleurs.surDangerDoux,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Espaces.x16),

                // Un solde non retiré est perdu : le dire avant, pas après.
                if (solde >= seuilRetraitFcfa) ...[
                  Carte(
                    enfants: [
                      Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 24,
                            color: Couleurs.orange,
                          ),
                          const SizedBox(width: Espaces.x8),
                          Expanded(
                            child: Text(
                              Fr.suppression.soldeEnJeu,
                              style: Typo.headlineMd,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        Fr.suppression.soldeEnJeuDetail(solde),
                        style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
                      ),
                      Bouton(
                        libelle: Fr.suppression.demanderRetrait,
                        icone: Icons.emoji_events,
                        onTap: () => context.go(Chemins.gains),
                      ),
                    ],
                  ),
                  const SizedBox(height: Espaces.x16),
                ],

                _Liste(
                  titre: Fr.suppression.cePartTitre,
                  icone: Icons.delete_outline,
                  teinte: Couleurs.danger,
                  entrees: Fr.suppression.cePart,
                ),
                const SizedBox(height: Espaces.x12),

                _Liste(
                  titre: Fr.suppression.celaResteTitre,
                  icone: Icons.receipt_long_outlined,
                  teinte: Couleurs.attenue,
                  entrees: Fr.suppression.celaReste,
                  note: Fr.suppression.pourquoiReste,
                ),
                const SizedBox(height: Espaces.x20),

                Champ(
                  libelle: Fr.suppression.confirmation,
                  aide: prenom == null || prenom.trim().isEmpty
                      ? Fr.suppression.prenomAbsent
                      : Fr.suppression.aideConfirmation(prenom.trim()),
                  erreur: _erreur,
                  controleur: _saisie,
                  actif: !_enCours,
                  onChange: (_) {
                    if (_erreur != null) setState(() => _erreur = null);
                  },
                ),
                const SizedBox(height: Espaces.x20),

                Bouton(
                  libelle: _enCours
                      ? Fr.suppression.enCours
                      : Fr.suppression.supprimer,
                  icone: Icons.delete_forever,
                  variante: VarianteBouton.danger,
                  onTap: _enCours ? null : () => _supprimer(prenom),
                ),
                const SizedBox(height: Espaces.x12),

                TextButton(
                  onPressed: _enCours ? null : () => context.go(Chemins.profil),
                  child: Text(Fr.commun.annuler),
                ),
                const SizedBox(height: Espaces.x32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Une liste à puces, avec sa raison d'être quand il en faut une.
class _Liste extends StatelessWidget {
  const _Liste({
    required this.titre,
    required this.icone,
    required this.teinte,
    required this.entrees,
    this.note,
  });

  final String titre;
  final IconData icone;
  final Color teinte;
  final List<String> entrees;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Carte(
      enfants: [
        Row(
          children: [
            Icon(icone, size: 22, color: teinte),
            const SizedBox(width: Espaces.x8),
            Expanded(child: Text(titre, style: Typo.headlineMd)),
          ],
        ),
        for (final entree in entrees)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: Espaces.x4),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: teinte,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(width: Espaces.x8),
              Expanded(child: Text(entree, style: Typo.bodyMd)),
            ],
          ),
        if (note != null)
          Text(
            note!,
            style: Typo.labelSm.copyWith(color: Couleurs.attenue),
          ),
      ],
    );
  }
}
