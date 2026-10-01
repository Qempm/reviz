import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../composants/bouton.dart';
import '../composants/carte.dart';
import '../composants/chargement.dart';
import '../composants/champ_recherche.dart';
import '../composants/coquille.dart';
import '../composants/etat_vide.dart';
import '../composants/mascotte.dart';
import '../composants/progression.dart';
import '../composants/puce.dart';
import '../donnees/api.dart';
import '../donnees/modeles.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../metier/acces.dart';
import '../metier/plateforme.dart';
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

  /// Les pages de la copie, dans l'ordre. Quatre au plus : la première
  /// part en `copie`, les suivantes en `page`.
  final List<_Photo> _pages = [];
  _Photo? _sujet;

  /// Le cours choisi à la main ; tant qu'il ne l'est pas, celui dont
  /// l'examen approche est pré-choisi (`_coursParDefaut`).
  String? _coursId;
  bool _coursTouche = false;
  String? _type;
  int _bareme = 20;

  static const _pagesMax = 4;

  bool _envoi = false;
  double _part = 0;
  String? _erreur;

  Future<void> _choisir({
    required bool estCopie,
    required ImageSource source,
    int? index,
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
        if (index != null && index < _pages.length) {
          _pages[index] = photo;
        } else if (_pages.length < _pagesMax) {
          _pages.add(photo);
        }
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

  /// Le cours dont l'examen est le plus proche, sinon le plus récent : c'est
  /// presque toujours celui de la copie qu'on photographie.
  static String? _coursParDefaut(List<ApercuCours> cours) {
    final prets = cours.where((c) => c.pret && !c.demo).toList();
    if (prets.isEmpty) return null;
    final hier = DateTime.now().subtract(const Duration(days: 1));
    final avecExamen =
        prets
            .where(
              (c) =>
                  DateTime.tryParse(c.dateExamen ?? '')?.isAfter(hier) ?? false,
            )
            .toList()
          ..sort((a, b) => a.dateExamen!.compareTo(b.dateExamen!));
    return (avecExamen.isNotEmpty ? avecExamen.first : prets.first).id;
  }

  String? _coursRetenu(List<ApercuCours> cours) =>
      _coursTouche ? _coursId : _coursParDefaut(cours);

  Future<void> _envoyer() async {
    if (_pages.isEmpty) return;
    final copie = _pages.first;
    final coursId = _coursRetenu(ref.read(coursProvider).value ?? const []);

    setState(() {
      _envoi = true;
      _part = 0;
      _erreur = null;
    });

    final reponse = await ref
        .read(depotCorrectionsProvider)
        .deposer(
          api: ref.read(apiProvider),
          fichiers: [
            FichierAEnvoyer(
              champ: 'copie',
              octets: copie.octets,
              typeMime: copie.typeMime,
            ),
            for (final p in _pages.skip(1))
              FichierAEnvoyer(
                champ: 'page',
                octets: p.octets,
                typeMime: p.typeMime,
              ),
            if (_sujet != null)
              FichierAEnvoyer(
                champ: 'sujet',
                octets: _sujet!.octets,
                typeMime: _sujet!.typeMime,
              ),
          ],
          coursId: coursId,
          typeEpreuve: _type,
          bareme: _bareme,
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
    final cours = ref.watch(coursProvider).value ?? const <ApercuCours>[];

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
                    pages: _pages,
                    pagesMax: _pagesMax,
                    sujet: _sujet,
                    erreur: _erreur,
                    onChoisir: _choisir,
                    onRetirerPage: (i) => setState(() => _pages.removeAt(i)),
                    onRetirerSujet: () => setState(() => _sujet = null),
                    onEnvoyer: _envoyer,
                    precisions: _Precisions(
                      cours: [
                        for (final c in cours)
                          if (c.pret && !c.demo) (c.id, c.titre ?? '—'),
                      ],
                      coursId: _coursRetenu(cours),
                      onCours: (id) => setState(() {
                        _coursTouche = true;
                        _coursId = id;
                      }),
                      type: _type,
                      onType: (t) =>
                          setState(() => _type = _type == t ? null : t),
                      bareme: _bareme,
                      onBareme: (b) => setState(() => _bareme = b),
                    ),
                  ),
                  AsyncError() => Carte(
                    enfants: [
                      EtatVide(
                        mascotte: EtatMascotte.oups,
                        titre: Fr.erreurs.chargementImpossible,
                        action: Bouton(
                          libelle: Fr.commun.reessayer,
                          icone: Icons.refresh,
                          onTap: () => ref.invalidate(boutiqueProvider),
                        ),
                      ),
                    ],
                  ),
                  _ => const Chargement.bloc(hauteur: 180),
                },

                const SizedBox(height: Espaces.x24),
                Text(Fr.correction.historique, style: Typo.headlineLg),
                const SizedBox(height: Espaces.x12),

                switch (historique) {
                  AsyncData(:final value) when value.isEmpty => Carte(
                    enfants: [
                      EtatVide(
                        mascotte: EtatMascotte.curieux,
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
    required this.pages,
    required this.pagesMax,
    required this.sujet,
    required this.erreur,
    required this.onChoisir,
    required this.onRetirerPage,
    required this.onRetirerSujet,
    required this.onEnvoyer,
    required this.precisions,
  });

  final EtatAcces acces;
  final List<_Photo> pages;
  final int pagesMax;
  final _Photo? sujet;
  final String? erreur;
  final Future<void> Function({
    required bool estCopie,
    required ImageSource source,
    int? index,
  })
  onChoisir;
  final void Function(int index) onRetirerPage;
  final VoidCallback onRetirerSujet;
  final VoidCallback onEnvoyer;
  final Widget precisions;

  /// Ce qui empêche de corriger, ou `null` si rien.
  String? get _blocage => switch (acces) {
    AucunAcces() => Fr.correction.aucunPack,
    AccesExpire() =>
      achatsDansLApplication
          ? Fr.correction.packExpire
          : Fr.correction.packExpireSansAchat,
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
            // Un pack arrivé à terme n'est pas une porte fermée : le
            // panthéreau dort, il se réveille au prochain pack. Pas encore
            // de pack : il cherche. Plus de crédit : il encourage.
            mascotte: switch (acces) {
              AccesExpire() => EtatMascotte.dodo,
              AucunAcces() => EtatMascotte.curieux,
              AccesActif() => EtatMascotte.courage,
            },
            titre: blocage,
            // Sur iPhone, pas de renvoi vers un achat (`metier/plateforme`).
            action: achatsDansLApplication
                ? Bouton(
                    libelle: Fr.correction.voirLesPacks,
                    icone: Icons.shopping_bag_outlined,
                    onTap: () => context.descendre(Chemins.boutique),
                  )
                : null,
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

        if (pages.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Bouton(
                libelle: Fr.correction.prendrePhoto,
                icone: Icons.photo_camera,
                onTap: () =>
                    onChoisir(estCopie: true, source: ImageSource.camera),
              ),
              const SizedBox(height: Espaces.x8),
              Bouton(
                libelle: Fr.correction.choisirGalerie,
                icone: Icons.photo_library_outlined,
                variante: VarianteBouton.secondaire,
                onTap: () =>
                    onChoisir(estCopie: true, source: ImageSource.gallery),
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
              for (var i = 0; i < pages.length; i++) ...[
                _Apercu(
                  libelle: pages.length == 1
                      ? Fr.correction.copie
                      : Fr.correction.page(i + 1),
                  photo: pages[i],
                  onRemplacer: () => onChoisir(
                    estCopie: true,
                    source: ImageSource.camera,
                    index: i,
                  ),
                  onRetirer: i == 0 ? null : () => onRetirerPage(i),
                ),
                const SizedBox(height: Espaces.x8),
              ],
              if (pages.length < pagesMax) ...[
                Bouton(
                  libelle: Fr.correction.ajouterPage,
                  icone: Icons.add_a_photo_outlined,
                  variante: VarianteBouton.secondaire,
                  onTap: () =>
                      onChoisir(estCopie: true, source: ImageSource.camera),
                ),
                const SizedBox(height: Espaces.x12),
              ],

              if (sujet == null)
                Bouton(
                  libelle: Fr.correction.sujetFacultatif,
                  icone: Icons.description_outlined,
                  variante: VarianteBouton.secondaire,
                  onTap: () =>
                      onChoisir(estCopie: false, source: ImageSource.camera),
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
              const SizedBox(height: Espaces.x20),
              precisions,
              const SizedBox(height: Espaces.x20),

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
          // Le panthéreau porte la copie ; la barre dit où elle en est.
          const Mascotte(etat: EtatMascotte.envoi, taille: 128),
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
            const Icon(Icons.chevron_right, size: 24, color: Couleurs.attenue),
          ],
        ),
      ),
    );
  }
}

/// Ce qui calibre la correction : le cours, le type d'épreuve, le barème.
class _Precisions extends StatelessWidget {
  const _Precisions({
    required this.cours,
    required this.coursId,
    required this.onCours,
    required this.type,
    required this.onType,
    required this.bareme,
    required this.onBareme,
  });

  final List<(String, String)> cours;
  final String? coursId;
  final void Function(String id) onCours;
  final String? type;
  final void Function(String type) onType;
  final int bareme;
  final void Function(int bareme) onBareme;

  static const _types = ['devoir', 'interrogation', 'partiel', 'examen', 'td'];
  static const _baremes = [10, 20, 40, 100];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(Fr.correction.precisions, style: Typo.headlineSm),
        const SizedBox(height: Espaces.x12),
        if (cours.isNotEmpty) ...[
          ChampRecherche(
            libelle: Fr.correction.coursConcerne,
            marqueur: Fr.correction.marqueurCours,
            valeur: coursId,
            entrees: cours,
            onChoisir: (id, _) => onCours(id),
          ),
          const SizedBox(height: Espaces.x4),
          Text(
            Fr.correction.aideCours,
            style: Typo.labelSm.copyWith(color: Couleurs.attenue),
          ),
          const SizedBox(height: Espaces.x16),
        ],
        Text(Fr.correction.typeEpreuve, style: Typo.labelMd),
        const SizedBox(height: Espaces.x8),
        Wrap(
          spacing: Espaces.x8,
          children: [
            for (final t in _types)
              _Choix(
                libelle: Fr.correction.nomEpreuve(t),
                choisi: type == t,
                onTap: () => onType(t),
              ),
          ],
        ),
        const SizedBox(height: Espaces.x8),
        Text(Fr.correction.noteSur, style: Typo.labelMd),
        const SizedBox(height: Espaces.x8),
        Wrap(
          spacing: Espaces.x8,
          children: [
            for (final b in _baremes)
              _Choix(
                libelle: '$b',
                choisi: bareme == b,
                onTap: () => onBareme(b),
              ),
          ],
        ),
      ],
    );
  }
}

/// Une pastille qu'on choisit : jaune quand elle l'est. La pastille fait
/// 36 px, sa zone tactile 48.
class _Choix extends StatelessWidget {
  const _Choix({
    required this.libelle,
    required this.choisi,
    required this.onTap,
  });

  final String libelle;
  final bool choisi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: choisi,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Mesures.zoneTactile),
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : Mouvement.appui,
              padding: const EdgeInsets.symmetric(
                horizontal: Espaces.x16,
                vertical: Espaces.x8,
              ),
              decoration: BoxDecoration(
                color: choisi ? Couleurs.jaune : Couleurs.surfaceConteneur,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                libelle,
                style: Typo.labelMd.copyWith(
                  color: choisi ? Couleurs.surJaune : Couleurs.encre,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
