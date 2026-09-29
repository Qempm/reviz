import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../composants/bouton.dart';
import '../composants/carte.dart';
import '../composants/coquille.dart';
import '../composants/etat_vide.dart';
import '../composants/progression.dart';
import '../composants/puce.dart';
import '../donnees/api.dart';
import '../donnees/modeles.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../metier/acces.dart';
import '../metier/serie.dart';
import '../routage.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Dépôt d'une copie à corriger.
///
/// Remplace le seul onglet qui menait encore au vide. La photo ne traverse
/// pas nos fonctions : elle monte du téléphone vers le stockage par une URL
/// signée, parce qu'une copie de téléphone récent pèse 3 à 8 Mo et que la
/// charge utile d'une fonction serverless est plafonnée à 4,5 Mo.
///
/// Le refus est annoncé **avant** le clic : `peutCorriger()` distingue
/// « aucun pack », « pack expiré », « plafond du jour » et « crédit épuisé ».
/// Quatre phrases, pas un seul « accès refusé ».
class EcranCorriger extends ConsumerStatefulWidget {
  const EcranCorriger({super.key});

  @override
  ConsumerState<EcranCorriger> createState() => _EcranCorrigerState();
}

class _EcranCorrigerState extends ConsumerState<EcranCorriger> {
  /// Photo redimensionnée avant l'envoi — pour le forfait data de
  /// l'étudiant, plus pour une limite de plateforme. 2 000 px de large reste
  /// largement lisible pour une écriture manuscrite.
  static const _largeurMax = 2000.0;
  static const _qualite = 85;

  _Photo? _copie;
  _Photo? _sujet;

  bool _envoi = false;
  double _part = 0;
  String? _erreur;

  Future<void> _choisir({
    required bool estCopie,
    required ImageSource source,
  }) async {
    final choisie = await ImagePicker().pickImage(
      source: source,
      maxWidth: _largeurMax,
      imageQuality: _qualite,
    );

    if (choisie == null) return;

    final octets = await choisie.readAsBytes();
    if (!mounted) return;

    setState(() {
      _erreur = null;
      final photo = _Photo(
        octets: octets,
        typeMime: _typeMime(choisie.name, choisie.mimeType),
      );
      if (estCopie) {
        _copie = photo;
      } else {
        _sujet = photo;
      }
    });
  }

  /// Le type déclaré par le sélecteur quand il en donne un, sinon déduit de
  /// l'extension. La route n'accepte que jpeg, png et webp.
  static String _typeMime(String nom, String? declare) {
    if (declare != null && declare.startsWith('image/')) return declare;
    final bas = nom.toLowerCase();
    if (bas.endsWith('.png')) return 'image/png';
    if (bas.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _envoyer() async {
    final copie = _copie;
    if (copie == null) return;

    setState(() {
      _envoi = true;
      _part = 0;
      _erreur = null;
    });

    final reponse = await ref.read(depotCorrectionsProvider).deposer(
      api: ref.read(apiProvider),
      fichiers: [
        FichierAEnvoyer(
          champ: 'copie',
          octets: copie.octets,
          typeMime: copie.typeMime,
        ),
        if (_sujet != null)
          FichierAEnvoyer(
            champ: 'sujet',
            octets: _sujet!.octets,
            typeMime: _sujet!.typeMime,
          ),
      ],
      progression: (part) {
        if (mounted) setState(() => _part = part);
      },
    );

    if (!mounted) return;

    switch (reponse) {
      case ReponseSucces(:final data):
        // L'historique a changé, et le crédit aussi.
        ref.invalidate(correctionsProvider);
        ref.invalidate(boutiqueProvider);
        context.descendre(Chemins.correction(data));
      case ReponseEchec(:final erreur):
        setState(() {
          _envoi = false;
          _erreur = erreur;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profil = ref.watch(profilProvider);
    final acces = ref.watch(accesCorrectionProvider);
    final historique = ref.watch(correctionsProvider);

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
      enfant: _envoi
          ? _Envoi(part: _part)
          : ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: Espaces.ecran,
                vertical: Espaces.x16,
              ),
              children: [
                Text(Fr.correction.titre, style: Typo.headlineXl),
                const SizedBox(height: Espaces.x4),
                Text(
                  Fr.correction.sousTitre,
                  style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
                ),
                const SizedBox(height: Espaces.x20),

                switch (acces) {
                  AsyncData(:final value) => _Depot(
                    acces: value,
                    copie: _copie,
                    sujet: _sujet,
                    erreur: _erreur,
                    onChoisir: _choisir,
                    onRetirerSujet: () => setState(() => _sujet = null),
                    onEnvoyer: _envoyer,
                  ),
                  AsyncError() => Carte(
                    enfants: [
                      EtatVide(
                        icone: Icons.cloud_off,
                        titre: Fr.erreurs.chargementImpossible,
                        action: Bouton(
                          libelle: Fr.commun.reessayer,
                          icone: Icons.refresh,
                          onTap: () => ref.invalidate(boutiqueProvider),
                        ),
                      ),
                    ],
                  ),
                  _ => const Center(child: CircularProgressIndicator()),
                },

                const SizedBox(height: Espaces.x24),
                Text(Fr.correction.historique, style: Typo.headlineLg),
                const SizedBox(height: Espaces.x12),

                switch (historique) {
                  AsyncData(:final value) when value.isEmpty => Carte(
                    enfants: [
                      EtatVide(
                        icone: Icons.fact_check_outlined,
                        titre: Fr.correction.aucune,
                        description: Fr.correction.aucuneDetail,
                      ),
                    ],
                  ),
                  AsyncData(:final value) => Column(
                    children: [
                      for (final c in value) ...[
                        _LigneHistorique(correction: c),
                        const SizedBox(height: Espaces.x8),
                      ],
                    ],
                  ),
                  _ => const SizedBox.shrink(),
                },

                const SizedBox(height: Espaces.x32),
              ],
            ),
    );
  }
}

/// Une photo choisie, en mémoire.
class _Photo {
  const _Photo({required this.octets, required this.typeMime});
  final List<int> octets;
  final String typeMime;
}

/// La partie « choisir et envoyer ».
class _Depot extends StatelessWidget {
  const _Depot({
    required this.acces,
    required this.copie,
    required this.sujet,
    required this.erreur,
    required this.onChoisir,
    required this.onRetirerSujet,
    required this.onEnvoyer,
  });

  final EtatAcces acces;
  final _Photo? copie;
  final _Photo? sujet;
  final String? erreur;
  final Future<void> Function({
    required bool estCopie,
    required ImageSource source,
  })
  onChoisir;
  final VoidCallback onRetirerSujet;
  final VoidCallback onEnvoyer;

  /// Ce qui empêche de corriger, ou `null` si rien.
  String? get _blocage => switch (acces) {
    AucunAcces() => Fr.correction.aucunPack,
    AccesExpire() => Fr.correction.packExpire,
    AccesActif(:final correctionsRestantes) when correctionsRestantes <= 0 =>
      Fr.correction.creditEpuise,
    AccesActif() => null,
  };

  @override
  Widget build(BuildContext context) {
    final blocage = _blocage;

    if (blocage != null) {
      return Carte(
        enfants: [
          EtatVide(
            icone: Icons.lock_outline,
            titre: blocage,
            action: Bouton(
              libelle: Fr.correction.voirLesPacks,
              icone: Icons.shopping_bag_outlined,
              onTap: () => context.descendre(Chemins.boutique),
            ),
          ),
        ],
      );
    }

    final restantes = acces is AccesActif
        ? (acces as AccesActif).correctionsRestantes
        : 0;

    return Carte(
      enfants: [
        Puce(
          libelle: Fr.correction.restantes(restantes),
          ton: TonPuce.jaune,
          icone: Icons.fact_check_outlined,
        ),

        if (copie == null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Bouton(
                libelle: Fr.correction.prendrePhoto,
                icone: Icons.photo_camera,
                onTap: () => onChoisir(
                  estCopie: true,
                  source: ImageSource.camera,
                ),
              ),
              const SizedBox(height: Espaces.x8),
              Bouton(
                libelle: Fr.correction.choisirGalerie,
                icone: Icons.photo_library_outlined,
                variante: VarianteBouton.secondaire,
                onTap: () => onChoisir(
                  estCopie: true,
                  source: ImageSource.gallery,
                ),
              ),
              const SizedBox(height: Espaces.x8),
              Text(
                Fr.correction.conseilPhoto,
                style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                textAlign: TextAlign.center,
              ),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Apercu(
                libelle: Fr.correction.copie,
                photo: copie!,
                onRemplacer: () => onChoisir(
                  estCopie: true,
                  source: ImageSource.camera,
                ),
              ),
              const SizedBox(height: Espaces.x12),

              if (sujet == null)
                Bouton(
                  libelle: Fr.correction.sujetFacultatif,
                  icone: Icons.description_outlined,
                  variante: VarianteBouton.secondaire,
                  onTap: () => onChoisir(
                    estCopie: false,
                    source: ImageSource.camera,
                  ),
                )
              else
                _Apercu(
                  libelle: Fr.correction.sujet,
                  photo: sujet!,
                  onRetirer: onRetirerSujet,
                ),

              const SizedBox(height: Espaces.x4),
              Text(
                Fr.correction.aideSujet,
                style: Typo.labelSm.copyWith(color: Couleurs.attenue),
              ),
              const SizedBox(height: Espaces.x16),

              Bouton(
                libelle: Fr.correction.envoyer,
                icone: Icons.send,
                onTap: onEnvoyer,
              ),
            ],
          ),

        if (erreur != null)
          Container(
            padding: const EdgeInsets.all(Espaces.x12),
            decoration: BoxDecoration(
              color: Couleurs.dangerDoux,
              borderRadius: BorderRadius.circular(Rayons.normal),
            ),
            child: Text(
              erreur!,
              style: Typo.labelMd.copyWith(color: Couleurs.surDangerDoux),
            ),
          ),
      ],
    );
  }
}

/// Miniature d'une photo choisie, avec de quoi la refaire.
class _Apercu extends StatelessWidget {
  const _Apercu({
    required this.libelle,
    required this.photo,
    this.onRemplacer,
    this.onRetirer,
  });

  final String libelle;
  final _Photo photo;
  final VoidCallback? onRemplacer;
  final VoidCallback? onRetirer;

  @override
  Widget build(BuildContext context) {
    final kilos = (photo.octets.length / 1024).round();

    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Couleurs.surfaceConteneur,
            borderRadius: BorderRadius.circular(Rayons.normal),
          ),
          child: const Icon(
            Icons.image_outlined,
            size: 28,
            color: Couleurs.attenue,
          ),
        ),
        const SizedBox(width: Espaces.x12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(libelle, style: Typo.labelLg, maxLines: 1),
              Text(
                '$kilos ko',
                style: Typo.labelSm.copyWith(color: Couleurs.attenue),
              ),
            ],
          ),
        ),
        if (onRemplacer != null)
          IconButton(
            onPressed: onRemplacer,
            icon: const Icon(Icons.refresh),
            color: Couleurs.texteAccent,
            tooltip: Fr.correction.reprendrePhoto,
          ),
        if (onRetirer != null)
          IconButton(
            onPressed: onRetirer,
            icon: const Icon(Icons.close),
            color: Couleurs.attenue,
            tooltip: Fr.correction.retirerSujet,
          ),
      ],
    );
  }
}

/// L'envoi en cours, avec sa barre.
class _Envoi extends StatelessWidget {
  const _Envoi({required this.part});

  final double part;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Espaces.ecran),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_upload_outlined, size: 56, color: Couleurs.orange),
          const SizedBox(height: Espaces.x16),
          Text(
            Fr.correction.envoiPourcent((part * 100).round()),
            style: Typo.headlineMd,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Espaces.x16),
          BarreProgression(valeur: part.clamp(0.0, 1.0)),
        ],
      ),
    );
  }
}

/// Une correction passée, dans l'historique.
class _LigneHistorique extends StatelessWidget {
  const _LigneHistorique({required this.correction});

  final Correction correction;

  @override
  Widget build(BuildContext context) {
    final note = correction.note;
    final bareme = correction.bareme;

    return GestureDetector(
      onTap: () => context.descendre(Chemins.correction(correction.id)),
      child: Container(
        padding: const EdgeInsets.all(Espaces.x12),
        decoration: BoxDecoration(
          color: Couleurs.carte,
          borderRadius: BorderRadius.circular(Rayons.normal),
        ),
        child: Row(
          children: [
            Icon(
              correction.prete
                  ? Icons.fact_check
                  : correction.echouee
                  ? Icons.error_outline
                  : Icons.hourglass_top,
              size: 24,
              color: correction.prete
                  ? Couleurs.texteAccent
                  : correction.echouee
                  ? Couleurs.danger
                  : Couleurs.orange,
            ),
            const SizedBox(width: Espaces.x12),
            Expanded(
              child: Text(
                correction.prete && note != null && bareme != null
                    ? Fr.correction.note(nombreFr(note), nombreFr(bareme))
                    : correction.illisible
                    ? Fr.correction.illisible
                    : correction.echouee
                    ? Fr.correction.echec
                    : Fr.correction.enAttente,
                style: Typo.labelLg,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 24,
              color: Couleurs.attenue,
            ),
          ],
        ),
      ),
    );
  }
}
