import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../composants/bouton.dart';
import '../composants/champ.dart';
import '../composants/champ_recherche.dart';
import '../donnees/api.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Écran d'inscription : prénom, université, filière, année, code parrain.
///
/// La création passe par `/api/profil` et non par une insertion directe : le
/// code parrain désigne un profil dont la RLS ne laisse rien lire, donc la
/// recherche exige le rôle de service.
class EcranInscription extends ConsumerStatefulWidget {
  const EcranInscription({super.key});

  @override
  ConsumerState<EcranInscription> createState() => _EcranInscriptionState();
}

class _EcranInscriptionState extends ConsumerState<EcranInscription> {
  final _prenom = TextEditingController();
  final _parrain = TextEditingController();
  final _telephone = TextEditingController();

  String? _universiteId;
  String? _faculteId;
  int _annee = 1;

  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _prenom.dispose();
    _parrain.dispose();
    _telephone.dispose();
    super.dispose();
  }

  Future<void> _terminer() async {
    final prenom = _prenom.text.trim();
    if (prenom.length < 2) {
      return setState(() => _erreur = Fr.inscription.prenomManquant);
    }
    if (_universiteId == null) {
      return setState(() => _erreur = Fr.inscription.choisirUniversite);
    }
    if (_faculteId == null) {
      return setState(() => _erreur = Fr.inscription.choisirFiliere);
    }

    setState(() {
      _enCours = true;
      _erreur = null;
    });

    final reponse = await ref.read(depotProfilProvider).creer(
      api: ref.read(apiProvider),
      prenom: prenom,
      universiteId: _universiteId!,
      faculteId: _faculteId!,
      annee: _annee,
      codeParrain: _parrain.text.trim(),
      telephone: _telephone.text.trim(),
    );

    if (!mounted) return;

    switch (reponse) {
      case ReponseSucces():
        // Le profil existe : on invalide, le routeur redirige vers l'accueil.
        ref.invalidate(profilProvider);
        ref.invalidate(accueilProvider);
      case ReponseEchec(:final erreur):
        setState(() {
          _enCours = false;
          _erreur = erreur;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final universites = ref.watch(universitesProvider);

    return Scaffold(
      backgroundColor: Couleurs.fond,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Mesures.largeurApp),
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: Espaces.ecran,
                vertical: Espaces.x32,
              ),
              children: [
                Text(Fr.inscription.titre, style: Typo.headlineXl),
                const SizedBox(height: Espaces.x8),
                Text(
                  Fr.inscription.sousTitre,
                  style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
                ),
                const SizedBox(height: Espaces.x32),

                Champ(
                  libelle: Fr.inscription.labelPrenom,
                  controleur: _prenom,
                  actif: !_enCours,
                  maxCaracteres: 60,
                ),
                const SizedBox(height: Espaces.x16),

                switch (universites) {
                  AsyncData(:final value) => ChampRecherche(
                    libelle: Fr.inscription.labelUniversite,
                    marqueur: Fr.inscription.marqueurUniversite,
                    valeur: _universiteId,
                    actif: !_enCours,
                    entrees: [for (final u in value) (u.id, u.nom)],
                    onChoisir: (id, _) => setState(() {
                      _universiteId = id;
                      // Changer d'université invalide la filière choisie :
                      // les filières n'existent que sous leur université.
                      _faculteId = null;
                    }),
                    onAjouter: (nom) async {
                      final r = await ref
                          .read(depotProfilProvider)
                          .ajouterAuCatalogue(
                            ref.read(apiProvider),
                            type: 'universite',
                            nom: nom,
                          );
                      if (r is ReponseSucces) ref.invalidate(universitesProvider);
                      return r;
                    },
                  ),
                  AsyncError() => Text(
                    Fr.erreurs.chargementImpossible,
                    style: Typo.labelSm.copyWith(color: Couleurs.danger),
                  ),
                  _ => const _Attente(),
                },
                const SizedBox(height: Espaces.x16),

                if (_universiteId != null)
                  Consumer(
                    builder: (context, ref, _) {
                      final facultes = ref.watch(
                        facultesProvider(_universiteId!),
                      );
                      return switch (facultes) {
                        AsyncData(:final value) => ChampRecherche(
                          libelle: Fr.inscription.labelFiliere,
                          marqueur: Fr.inscription.marqueurFiliere,
                          valeur: _faculteId,
                          actif: !_enCours,
                          entrees: [for (final f in value) (f.id, f.nom)],
                          onChoisir: (id, _) => setState(() => _faculteId = id),
                          onAjouter: (nom) async {
                            final universite = _universiteId!;
                            final r = await ref
                                .read(depotProfilProvider)
                                .ajouterAuCatalogue(
                                  ref.read(apiProvider),
                                  type: 'filiere',
                                  nom: nom,
                                  parentId: universite,
                                );
                            if (r is ReponseSucces) {
                              ref.invalidate(facultesProvider(universite));
                            }
                            return r;
                          },
                        ),
                        AsyncError() => Text(
                          Fr.erreurs.chargementImpossible,
                          style: Typo.labelSm.copyWith(color: Couleurs.danger),
                        ),
                        _ => const _Attente(),
                      };
                    },
                  ),
                if (_universiteId != null) const SizedBox(height: Espaces.x16),

                ChampListe<int>(
                  libelle: Fr.inscription.labelAnnee,
                  valeur: _annee,
                  actif: !_enCours,
                  entrees: [
                    for (var n = 1; n <= 7; n++) (n, Fr.inscription.annee(n)),
                  ],
                  onChange: (v) => setState(() => _annee = v ?? 1),
                ),
                const SizedBox(height: Espaces.x16),

                Champ(
                  libelle: Fr.inscription.labelTelephone,
                  aide: Fr.inscription.aideTelephone,
                  controleur: _telephone,
                  typeClavier: TextInputType.phone,
                  actif: !_enCours,
                ),
                const SizedBox(height: Espaces.x16),

                Champ(
                  libelle: Fr.inscription.labelParrain,
                  aide: Fr.inscription.aideParrain,
                  controleur: _parrain,
                  actif: !_enCours,
                  maxCaracteres: 12,
                ),
                const SizedBox(height: Espaces.x24),

                Bouton(
                  libelle: _enCours
                      ? Fr.commun.chargement
                      : Fr.inscription.terminer,
                  icone: Icons.check,
                  onTap: _enCours ? null : _terminer,
                ),

                if (_erreur != null) ...[
                  const SizedBox(height: Espaces.x16),
                  Text(
                    _erreur!,
                    style: Typo.labelSm.copyWith(color: Couleurs.danger),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Attente extends StatelessWidget {
  const _Attente();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Mesures.hauteurCta,
      alignment: Alignment.centerLeft,
      child: Text(
        Fr.commun.chargement,
        style: Typo.labelSm.copyWith(color: Couleurs.attenue),
      ),
    );
  }
}
