import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../composants/bouton.dart';
import '../composants/carte.dart';
import '../composants/champ.dart';
import '../composants/champ_recherche.dart';
import '../composants/chargement.dart';
import '../composants/etat_vide.dart';
import '../composants/mascotte.dart';
import '../composants/progression.dart';
import '../donnees/api.dart';
import '../donnees/modeles.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../metier/plateforme.dart';
import '../routage.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Déposer un cours.
///
/// Le bouton de l'écran « Réviser » disait « bientôt » depuis le début, et
/// pour une raison : les traitements `ingest_course` et `generate_questions`
/// n'existaient pas, si bien qu'un cours déposé serait resté « en
/// préparation » pour toujours. Ils existent.
///
/// Le fichier ne traverse pas nos fonctions : 25 Mo dépasseraient la charge
/// utile d'une fonction serverless. Il monte du téléphone vers le stockage par
/// une URL signée, et l'empreinte SHA-256 calculée ici permet au serveur de
/// reconnaître un document que quelqu'un de la même faculté a déjà fait
/// traiter — auquel cas rien n'est repayé.
class EcranAjouterCours extends ConsumerStatefulWidget {
  const EcranAjouterCours({super.key});

  @override
  ConsumerState<EcranAjouterCours> createState() => _EcranAjouterCoursState();
}

class _EcranAjouterCoursState extends ConsumerState<EcranAjouterCours> {
  /// 25 Mo, comme le seau `cours`.
  static const _tailleMax = 26214400;

  /// Une photo de polycopié n'a pas besoin de plus : au-delà, on paie du
  /// forfait data pour des pixels que le modèle de vision n'exploite pas.
  static const _largeurMaxPhoto = 2200.0;
  static const _qualitePhoto = 88;

  final _titre = TextEditingController();

  DocumentChoisi? _document;
  String? _matiereId;
  DateTime? _dateExamen;

  bool _envoi = false;
  double _part = 0;
  String? _erreur;
  String? _motif;
  String? _coursExistant;

  @override
  void dispose() {
    _titre.dispose();
    super.dispose();
  }

  void _retenir(DocumentChoisi doc) {
    setState(() {
      _document = doc;
      _erreur = null;
      _motif = null;
      _coursExistant = null;
      if (_titre.text.trim().isEmpty) _titre.text = doc.titreSuggere;
    });
  }

  Future<void> _choisirFichier() async {
    final fichier = await FilePicker.pickFile(
      type: FileType.custom,
      // `doc` n'y est pas : l'ancien format binaire de Word n'est lisible par
      // aucune bibliothèque utilisable en serverless, et le serveur le
      // refuse. Le proposer ici reviendrait à faire envoyer 20 Mo pour rien.
      allowedExtensions: const ['pdf', 'docx', 'jpg', 'jpeg', 'png', 'webp'],
    );

    if (fichier == null) return;

    final mime = _typeMime(fichier.name);
    if (mime == null) {
      setState(
        () => _erreur = fichier.name.toLowerCase().endsWith('.doc')
            ? Fr.depot.docRefuse
            : Fr.depot.formatRefuse,
      );
      return;
    }

    // La taille se lit avant les octets quand le sélecteur la connaît : on
    // évite de charger quarante mégaoctets en mémoire pour les refuser
    // ensuite.
    final annoncee = await fichier.length();
    if (!mounted) return;

    if (annoncee != null && annoncee > _tailleMax) {
      setState(() => _erreur = Fr.depot.tropGros);
      return;
    }

    final octets = await fichier.readAsBytes();
    if (!mounted) return;

    if (octets.length > _tailleMax) {
      setState(() => _erreur = Fr.depot.tropGros);
      return;
    }

    _retenir(DocumentChoisi(nom: fichier.name, octets: octets, typeMime: mime));
  }

  Future<void> _prendrePhoto() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: _largeurMaxPhoto,
      imageQuality: _qualitePhoto,
    );

    if (photo == null) return;
    final octets = await photo.readAsBytes();
    if (!mounted) return;

    _retenir(
      DocumentChoisi(
        nom: photo.name,
        octets: octets,
        typeMime: _typeMime(photo.name) ?? 'image/jpeg',
      ),
    );
  }

  /// Le type d'après l'extension. Les sélecteurs de fichiers Android rendent
  /// volontiers un type vide ou `application/octet-stream`.
  static String? _typeMime(String nom) {
    final bas = nom.toLowerCase();
    if (bas.endsWith('.pdf')) return 'application/pdf';
    if (bas.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (bas.endsWith('.png')) return 'image/png';
    if (bas.endsWith('.webp')) return 'image/webp';
    if (bas.endsWith('.jpg') || bas.endsWith('.jpeg')) return 'image/jpeg';
    return null;
  }

  Future<void> _choisirDate() async {
    final maintenant = DateTime.now();
    final choisie = await showDatePicker(
      context: context,
      initialDate: _dateExamen ?? maintenant.add(const Duration(days: 14)),
      firstDate: maintenant,
      // Un examen au-delà d'un an n'est pas un examen qu'on révise.
      lastDate: maintenant.add(const Duration(days: 365)),
      helpText: Fr.depot.dateExamen,
    );

    if (choisie != null) setState(() => _dateExamen = choisie);
  }

  bool _activation = false;

  /// Une matière absente du catalogue, ajoutée pour l'étudiant et ses
  /// camarades de filière, à son année d'étude.
  Future<Reponse<(String, String)>> _ajouterMatiere(String nom) async {
    final profil = await ref.read(profilProvider.future);
    final faculte = profil?.faculteId;
    if (faculte == null) {
      return Reponse.echec(Fr.depot.echec);
    }
    final r = await ref
        .read(depotProfilProvider)
        .ajouterAuCatalogue(
          ref.read(apiProvider),
          type: 'matiere',
          nom: nom,
          parentId: faculte,
          annee: profil?.anneeEtude,
        );
    if (r is ReponseSucces) ref.invalidate(matieresProvider);
    return r;
  }

  /// Le pack gratuit, activé depuis le refus même : l'étudiant n'a pas à
  /// chercher la boutique au fond du profil. Le dépôt repart aussitôt.
  Future<void> _activerGratuit() async {
    setState(() => _activation = true);
    final reponse = await ref
        .read(depotBoutiqueProvider)
        .activerDecouverte(ref.read(apiProvider));
    if (!mounted) return;
    setState(() => _activation = false);

    switch (reponse) {
      case ReponseSucces():
        ref.invalidate(boutiqueProvider);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(Fr.depot.packGratuitActive)));
        await _deposer();
      case ReponseEchec(:final erreur):
        setState(() => _erreur = erreur.isEmpty ? Fr.depot.echec : erreur);
    }
  }

  Future<void> _deposer() async {
    final document = _document;
    final matiere = _matiereId;
    final titre = _titre.text.trim();

    if (document == null) return;
    if (titre.length < 2) {
      setState(() => _erreur = Fr.depot.titreManquant);
      return;
    }
    if (matiere == null) {
      setState(() => _erreur = Fr.depot.matiereManquante);
      return;
    }

    setState(() {
      _envoi = true;
      _part = 0;
      _erreur = null;
      _motif = null;
      _coursExistant = null;
    });

    final reponse = await ref
        .read(depotCoursProvider)
        .deposer(
          api: ref.read(apiProvider),
          document: document,
          matiereId: matiere,
          titre: titre,
          dateExamen: _dateExamen,
          progression: (part) {
            if (mounted) setState(() => _part = part);
          },
        );

    if (!mounted) return;

    switch (reponse) {
      case ReponseSucces(:final data):
        // La liste des cours et l'accès ont changé.
        ref.invalidate(coursProvider);
        ref.invalidate(boutiqueProvider);
        context.pushReplacement(Chemins.cours(data));
      case ReponseEchec(:final erreur, :final motif):
        setState(() {
          _envoi = false;
          _motif = motif;
          _erreur = _messageDe(motif, erreur);
        });

        // « Déjà déposé » n'est pas un échec : le cours existe, on y mène.
        if (motif == 'deja-depose') {
          final dejaLa = await _retrouverParTitre(titre);
          if (mounted) setState(() => _coursExistant = dejaLa);
        }
    }
  }

  /// Le serveur renvoie l'identifiant du cours déjà déposé dans son enveloppe,
  /// mais `ApiReviz` ne déplie que `data` — et sur un refus il n'y en a pas.
  /// On le retrouve donc dans la liste, par son empreinte de titre.
  Future<String?> _retrouverParTitre(String titre) async {
    final cours = await ref.read(coursProvider.future);
    for (final c in cours) {
      if ((c.titre ?? '').trim().toLowerCase() == titre.toLowerCase()) {
        return c.id;
      }
    }
    return null;
  }

  /// Les refus du serveur, traduits. Le message qu'il envoie est déjà en
  /// français ; on le remplace seulement quand on sait dire mieux.
  String _messageDe(String? motif, String parDefaut) => switch (motif) {
    'aucun-acces' => Fr.depot.aucunAcces,
    'acces-expire' =>
      achatsDansLApplication
          ? Fr.depot.accesExpire
          : Fr.depot.accesExpireSansAchat,
    'deja-depose' => Fr.depot.dejaDepose,
    _ => parDefaut.isEmpty ? Fr.depot.echec : parDefaut,
  };

  @override
  Widget build(BuildContext context) {
    final matieres = ref.watch(matieresProvider);

    return Scaffold(
      backgroundColor: Couleurs.fond,
      appBar: AppBar(
        backgroundColor: Couleurs.fond,
        surfaceTintColor: Colors.transparent,
        title: Text(Fr.depot.titre, style: Typo.headlineLg),
        leading: IconButton(
          onPressed: _envoi ? null : () => context.remonter(Chemins.reviser),
          icon: const Icon(Icons.arrow_back, color: Couleurs.encre),
          tooltip: Fr.commun.retour,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Mesures.largeurApp),
            child: _envoi
                ? _Envoi(part: _part)
                : ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Espaces.ecran,
                      vertical: Espaces.x8,
                    ),
                    children: [
                      Text(
                        Fr.depot.sousTitre,
                        style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
                      ),
                      const SizedBox(height: Espaces.x20),

                      _ChoixFichier(
                        document: _document,
                        onFichier: _choisirFichier,
                        onPhoto: _prendrePhoto,
                      ),

                      if (_document != null) ...[
                        const SizedBox(height: Espaces.x16),
                        Champ(
                          libelle: Fr.depot.titreDuCours,
                          aide: Fr.depot.aideTitre,
                          controleur: _titre,
                          maxCaracteres: 200,
                        ),
                        const SizedBox(height: Espaces.x16),

                        switch (matieres) {
                          // Plus d'impasse « aucune matière » : l'étudiant
                          // l'ajoute lui-même.
                          AsyncData(:final value) => ChampRecherche(
                            libelle: Fr.depot.matiere,
                            valeur: _matiereId,
                            marqueur: Fr.depot.marqueurMatiere,
                            entrees: [for (final m in value) (m.id, m.nom)],
                            onChoisir: (id, _) =>
                                setState(() => _matiereId = id),
                            onAjouter: _ajouterMatiere,
                          ),
                          AsyncError() => Carte(
                            enfants: [
                              EtatVide(
                                mascotte: EtatMascotte.oups,
                                titre: Fr.erreurs.chargementImpossible,
                                action: Bouton(
                                  libelle: Fr.commun.reessayer,
                                  icone: Icons.refresh,
                                  variante: VarianteBouton.secondaire,
                                  onTap: () => ref.invalidate(matieresProvider),
                                ),
                              ),
                            ],
                          ),
                          _ => const Chargement.bloc(),
                        },

                        const SizedBox(height: Espaces.x16),
                        _Date(
                          date: _dateExamen,
                          onChoisir: _choisirDate,
                          onRetirer: () => setState(() => _dateExamen = null),
                        ),
                      ],

                      if (_erreur != null) ...[
                        const SizedBox(height: Espaces.x16),
                        _Refus(
                          message: _erreur!,
                          motif: _motif,
                          coursExistant: _coursExistant,
                          // Proposé seulement si le pack gratuit n'a pas
                          // déjà servi.
                          onActiverGratuit:
                              ref
                                      .watch(boutiqueProvider)
                                      .value
                                      ?.decouverteUtilisee ==
                                  false
                              ? (_activation ? null : _activerGratuit)
                              : null,
                          activationEnCours: _activation,
                        ),
                      ],

                      const SizedBox(height: Espaces.x24),
                      Bouton(
                        libelle: Fr.depot.envoyer,
                        icone: Icons.cloud_upload_outlined,
                        onTap: _document == null ? null : _deposer,
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

/// Le choix du document, ou son aperçu quand il est choisi.
class _ChoixFichier extends StatelessWidget {
  const _ChoixFichier({
    required this.document,
    required this.onFichier,
    required this.onPhoto,
  });

  final DocumentChoisi? document;
  final VoidCallback onFichier;
  final VoidCallback onPhoto;

  @override
  Widget build(BuildContext context) {
    final doc = document;

    if (doc == null) {
      return Carte(
        enfants: [
          Bouton(
            libelle: Fr.depot.choisirFichier,
            icone: Icons.attach_file,
            onTap: onFichier,
          ),
          Bouton(
            libelle: Fr.depot.prendrePhoto,
            icone: Icons.photo_camera,
            variante: VarianteBouton.secondaire,
            onTap: onPhoto,
          ),
          Text(
            Fr.depot.formatsAcceptes,
            style: Typo.labelSm.copyWith(color: Couleurs.attenue),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return Carte(
      enfants: [
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Couleurs.jauneDoux,
                borderRadius: BorderRadius.circular(Rayons.normal),
              ),
              child: Icon(
                doc.typeMime.startsWith('image/')
                    ? Icons.image_outlined
                    : Icons.description_outlined,
                size: 28,
                color: Couleurs.surJaune,
              ),
            ),
            const SizedBox(width: Espaces.x12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    doc.nom,
                    style: Typo.labelLg,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${doc.kilos} ko',
                    style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                  ),
                ],
              ),
            ),
          ],
        ),
        Bouton(
          libelle: Fr.depot.changerFichier,
          icone: Icons.swap_horiz,
          variante: VarianteBouton.secondaire,
          onTap: onFichier,
        ),
      ],
    );
  }
}

/// La date d'examen, facultative.
class _Date extends StatelessWidget {
  const _Date({
    required this.date,
    required this.onChoisir,
    required this.onRetirer,
  });

  final DateTime? date;
  final VoidCallback onChoisir;
  final VoidCallback onRetirer;

  @override
  Widget build(BuildContext context) {
    final d = date;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(Fr.depot.dateExamen, style: Typo.labelMd),
        const SizedBox(height: Espaces.x8),
        Row(
          children: [
            Expanded(
              child: Bouton(
                libelle: d == null
                    ? Fr.depot.choisirDate
                    : '${d.day.toString().padLeft(2, '0')}/'
                          '${d.month.toString().padLeft(2, '0')}/${d.year}',
                icone: Icons.event,
                variante: VarianteBouton.secondaire,
                onTap: onChoisir,
              ),
            ),
            if (d != null)
              IconButton(
                onPressed: onRetirer,
                icon: const Icon(Icons.close),
                color: Couleurs.attenue,
                tooltip: Fr.depot.retirerDate,
              ),
          ],
        ),
        const SizedBox(height: Espaces.x4),
        Text(
          Fr.depot.aideDateExamen,
          style: Typo.labelSm.copyWith(color: Couleurs.attenue),
        ),
      ],
    );
  }
}

/// Un refus du serveur, avec l'action qui va avec quand il y en a une.
class _Refus extends StatelessWidget {
  const _Refus({
    required this.message,
    required this.motif,
    required this.coursExistant,
    this.onActiverGratuit,
    this.activationEnCours = false,
  });

  final String message;
  final String? motif;
  final String? coursExistant;

  /// Donné quand le pack gratuit est encore disponible.
  final VoidCallback? onActiverGratuit;
  final bool activationEnCours;

  @override
  Widget build(BuildContext context) {
    final manqueAcces = motif == 'aucun-acces' || motif == 'acces-expire';
    final deja = motif == 'deja-depose';

    return Container(
      padding: const EdgeInsets.all(Espaces.x12),
      decoration: BoxDecoration(
        // « Déjà déposé » n'est pas une erreur : le cours existe.
        color: deja ? Couleurs.jauneDoux : Couleurs.dangerDoux,
        borderRadius: BorderRadius.circular(Rayons.normal),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: Typo.labelMd.copyWith(
              color: deja ? Couleurs.surJaune : Couleurs.surDangerDoux,
            ),
          ),
          if (manqueAcces) ...[
            const SizedBox(height: Espaces.x12),
            if (motif == 'aucun-acces' &&
                (onActiverGratuit != null || activationEnCours))
              Bouton(
                libelle: Fr.depot.commencerGratuitement,
                icone: Icons.card_giftcard,
                chargement: activationEnCours,
                onTap: onActiverGratuit,
              )
            else if (achatsDansLApplication)
              Bouton(
                libelle: Fr.depot.voirLesPacks,
                icone: Icons.shopping_bag_outlined,
                onTap: () => context.descendre(Chemins.boutique),
              ),
          ],
          if (deja && coursExistant != null) ...[
            const SizedBox(height: Espaces.x12),
            Bouton(
              libelle: Fr.depot.voirLeCours,
              icone: Icons.arrow_forward,
              onTap: () =>
                  context.pushReplacement(Chemins.cours(coursExistant!)),
            ),
          ],
        ],
      ),
    );
  }
}

/// L'envoi en cours.
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
          // Le panthéreau porte le cours ; la barre dit où en est le
          // fichier.
          const Mascotte(etat: EtatMascotte.envoi, taille: 128),
          const SizedBox(height: Espaces.x16),
          Text(
            part <= 0
                ? Fr.depot.preparation
                : Fr.depot.envoiPourcent((part * 100).round()),
            style: Typo.headlineMd,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Espaces.x16),
          BarreProgression(valeur: part.clamp(0.0, 1.0)),
          const SizedBox(height: Espaces.x20),
          Text(
            Fr.depot.enTraitementDetail,
            style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
