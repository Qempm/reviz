import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../composants/bouton.dart';
import '../composants/carte.dart';
import '../composants/mascotte.dart';
import '../composants/progression.dart';
import '../donnees/api.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../routage.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Dépôt de la carte étudiante.
///
/// C'est la seule barrière « un compte par personne » depuis que le téléphone
/// est facultatif : sans elle, une personne ouvre dix comptes, se parraine
/// elle-même et encaisse 25 % de ses propres paiements. L'écran le dit, parce
/// qu'un étudiant qui comprend pourquoi on lui demande sa carte la donne plus
/// volontiers.
///
/// **Le verdict se lit dans `profiles.verification_status`**, pas dans la
/// réponse de la route : la vérification part après la réponse, et
/// `jobs` n'est lisible par personne côté client. L'écran relit donc le
/// profil, d'abord souvent puis plus lentement, et s'arrête au bout d'une
/// minute.
///
/// Ce dernier point est un arbitrage assumé. Une lecture trop floue laisse le
/// profil en `pending` — l'état « on regarde », qui attend un humain — et
/// `pending` est exactement ce qu'on voit aussi pendant que le traitement
/// tourne. Les deux sont indiscernables du téléphone. Mais ils demandent la
/// même chose à l'étudiant : rien. Passé le délai, on affiche donc « on
/// regarde ta carte », ce qui est vrai dans les deux cas.
class EcranCarte extends ConsumerStatefulWidget {
  const EcranCarte({super.key});

  @override
  ConsumerState<EcranCarte> createState() => _EcranCarteState();
}

/// Où en est l'étudiant sur cet écran.
enum _Etape { choix, envoi, attente, fini }

class _EcranCarteState extends ConsumerState<EcranCarte> {
  /// 1 600 px de large : le numéro d'étudiant reste net, et la photo pèse
  /// quelques centaines de kilo-octets sur un forfait data béninois.
  static const _largeurMax = 1600.0;
  static const _qualite = 85;

  /// Cadence de relecture du profil, puis abandon. Le traitement met 10 à
  /// 30 secondes ; une minute laisse de la marge sans faire tourner le
  /// téléphone pour rien.
  static const _cadence = [3, 3, 4, 5, 5, 8, 10, 10, 12];

  _Etape _etape = _Etape.choix;
  Uint8List? _octets;
  String _typeMime = 'image/jpeg';
  double _part = 0;
  String? _erreur;
  Timer? _minuteur;

  /// Après un refus, l'étudiant a demandé à redéposer : l'écran ne doit plus
  /// lui remontrer l'issue tant qu'il n'a pas renvoyé.
  bool _forcerDepot = false;

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  Future<void> _choisir(ImageSource source) async {
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
      _octets = octets;
      _typeMime = _typeMimeDe(choisie.name, choisie.mimeType);
    });
  }

  /// Le type déclaré par le sélecteur quand il en donne un, sinon déduit de
  /// l'extension. La route n'accepte que jpeg, png et webp.
  static String _typeMimeDe(String nom, String? declare) {
    if (declare != null && declare.startsWith('image/')) return declare;
    final bas = nom.toLowerCase();
    if (bas.endsWith('.png')) return 'image/png';
    if (bas.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _envoyer() async {
    final octets = _octets;
    if (octets == null) return;

    setState(() {
      _etape = _Etape.envoi;
      _part = 0;
      _erreur = null;
    });

    final reponse = await ref.read(depotProfilProvider).deposerCarte(
      api: ref.read(apiProvider),
      octets: octets,
      typeMime: _typeMime,
      progression: (part) {
        if (mounted) setState(() => _part = part);
      },
    );

    if (!mounted) return;

    switch (reponse) {
      case ReponseSucces():
        // Le profil est déjà passé en attente côté serveur : le relire tout
        // de suite évite que l'écran continue de proposer un dépôt.
        ref.invalidate(profilProvider);
        setState(() => _etape = _Etape.attente);
        _attendre(0);
      case ReponseEchec(:final erreur):
        setState(() {
          _etape = _Etape.choix;
          _erreur = erreur.isEmpty ? Fr.carte.echec : erreur;
        });
    }
  }

  /// Revient au dépôt, après un refus.
  void _recommencer() {
    _minuteur?.cancel();
    setState(() {
      _etape = _Etape.choix;
      _octets = null;
      _erreur = null;
      _forcerDepot = true;
    });
  }

  /// Relit le profil jusqu'à ce que le statut sorte de `pending`.
  void _attendre(int tour) {
    if (tour >= _cadence.length) {
      if (mounted) setState(() => _etape = _Etape.fini);
      return;
    }

    _minuteur?.cancel();
    _minuteur = Timer(Duration(seconds: _cadence[tour]), () async {
      if (!mounted) return;
      ref.invalidate(profilProvider);

      final profil = await ref.read(profilProvider.future);
      if (!mounted) return;

      if (profil != null && !profil.verificationEnCours) {
        setState(() => _etape = _Etape.fini);
        return;
      }

      _attendre(tour + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final profil = ref.watch(profilProvider);
    final statut = switch (profil) {
      AsyncData(:final value) when value != null => value.statutVerification,
      _ => null,
    };

    // Déjà vérifié ou déjà refusé en arrivant : l'écran montre l'issue, pas
    // un formulaire de dépôt.
    final issueDejaLa =
        _etape == _Etape.choix &&
        !_forcerDepot &&
        statut != null &&
        statut != 'none';

    return Scaffold(
      backgroundColor: Couleurs.fond,
      appBar: AppBar(
        backgroundColor: Couleurs.fond,
        surfaceTintColor: Colors.transparent,
        title: Text(Fr.carte.titre, style: Typo.headlineLg),
        leading: IconButton(
          onPressed: () => context.remonter(Chemins.profil),
          icon: const Icon(Icons.arrow_back, color: Couleurs.encre),
          tooltip: Fr.commun.retour,
        ),
      ),
      body: SafeArea(
        child: switch (_etape) {
          _Etape.envoi => _Envoi(part: _part),
          _Etape.attente => const _Attente(),
          _Etape.fini => _Issue(statut: statut, onReprendre: _recommencer),
          _Etape.choix when issueDejaLa => _Issue(
            statut: statut,
            onReprendre: _recommencer,
          ),
          _Etape.choix => _Choix(
            octets: _octets,
            erreur: _erreur,
            onChoisir: _choisir,
            onReprendre: () => setState(() => _octets = null),
            onEnvoyer: _envoyer,
          ),
        },
      ),
    );
  }
}

/// Choisir la photo, puis l'envoyer.
class _Choix extends StatelessWidget {
  const _Choix({
    required this.octets,
    required this.erreur,
    required this.onChoisir,
    required this.onReprendre,
    required this.onEnvoyer,
  });

  final Uint8List? octets;
  final String? erreur;
  final Future<void> Function(ImageSource source) onChoisir;
  final VoidCallback onReprendre;
  final VoidCallback onEnvoyer;

  @override
  Widget build(BuildContext context) {
    final photo = octets;

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaces.ecran,
        vertical: Espaces.x16,
      ),
      children: [
        Text(
          Fr.carte.sousTitre,
          style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
        ),
        const SizedBox(height: Espaces.x20),

        Carte(
          enfants: [
            if (photo == null) ...[
              Bouton(
                libelle: Fr.carte.prendrePhoto,
                icone: Icons.photo_camera,
                onTap: () => onChoisir(ImageSource.camera),
              ),
              Bouton(
                libelle: Fr.carte.choisirGalerie,
                icone: Icons.photo_library_outlined,
                variante: VarianteBouton.secondaire,
                onTap: () => onChoisir(ImageSource.gallery),
              ),
              Text(
                Fr.carte.conseil,
                style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(Rayons.normal),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.memory(
                    photo,
                    fit: BoxFit.cover,
                    // Une photo illisible ici le sera aussi pour le modèle :
                    // mieux vaut que l'étudiant la voie avant l'envoi.
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: Couleurs.surfaceConteneur,
                      child: Center(
                        child: Icon(Icons.badge_outlined, size: 40),
                      ),
                    ),
                  ),
                ),
              ),
              Bouton(
                libelle: Fr.carte.envoyer,
                icone: Icons.cloud_upload_outlined,
                onTap: onEnvoyer,
              ),
              Bouton(
                libelle: Fr.carte.reprendre,
                icone: Icons.refresh,
                variante: VarianteBouton.secondaire,
                onTap: onReprendre,
              ),
            ],

            if (erreur != null)
              Text(
                erreur!,
                style: Typo.labelMd.copyWith(color: Couleurs.danger),
                textAlign: TextAlign.center,
              ),
          ],
        ),

        const SizedBox(height: Espaces.x16),
        Text(
          Fr.carte.uneSeuleFois,
          style: Typo.labelSm.copyWith(color: Couleurs.attenue),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Espaces.x32),
      ],
    );
  }
}

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
          const Icon(
            Icons.cloud_upload_outlined,
            size: 56,
            color: Couleurs.orange,
          ),
          const SizedBox(height: Espaces.x16),
          Text(
            Fr.carte.envoiPourcent((part * 100).round()),
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

class _Attente extends StatelessWidget {
  const _Attente();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Espaces.ecran),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Le panthéreau lit la carte, et respire tant que l'attente dure.
          const Mascotte(etat: EtatMascotte.reflexion, taille: 140),
          const SizedBox(height: Espaces.x20),
          Text(Fr.carte.lecture, style: Typo.headlineMd, textAlign: TextAlign.center),
          const SizedBox(height: Espaces.x8),
          Text(
            Fr.carte.lectureDetail,
            style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// L'issue, telle que la porte le profil.
///
/// Trois états, et aucun vert : une carte validée se célèbre en jaune.
class _Issue extends StatelessWidget {
  const _Issue({required this.statut, this.onReprendre});

  final String? statut;

  /// Proposé seulement quand un nouveau dépôt a une chance d'aboutir.
  final VoidCallback? onReprendre;

  @override
  Widget build(BuildContext context) {
    final (icone, couleur, titre, detail) = switch (statut) {
      'verified' => (
        Icons.verified_user,
        Couleurs.texteAccent,
        Fr.carte.verifie,
        Fr.carte.verifieDetail,
      ),
      'rejected' => (
        Icons.error_outline,
        Couleurs.danger,
        Fr.carte.refusee,
        Fr.carte.refuseeDetail,
      ),
      // `pending`, et tout statut qu'on ne connaît pas : on regarde.
      _ => (
        Icons.hourglass_top,
        Couleurs.orange,
        Fr.carte.enAttente,
        Fr.carte.enAttenteDetail,
      ),
    };

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaces.ecran,
        vertical: Espaces.x16,
      ),
      children: [
        Carte(
          enfants: [
            Icon(icone, size: 48, color: couleur),
            Text(titre, style: Typo.headlineMd, textAlign: TextAlign.center),
            Text(
              detail,
              style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
              textAlign: TextAlign.center,
            ),

            // Refusée est le seul état qui laisse redéposer : la route
            // refuse un nouvel envoi quand le compte est vérifié ou qu'une
            // vérification est déjà en cours.
            if (statut == 'rejected' && onReprendre != null)
              Bouton(
                libelle: Fr.carte.reprendre,
                icone: Icons.photo_camera,
                onTap: onReprendre,
              ),

            Bouton(
              libelle: Fr.carte.retour,
              icone: Icons.arrow_back,
              variante: VarianteBouton.secondaire,
              onTap: () => context.remonter(Chemins.profil),
            ),
          ],
        ),
        const SizedBox(height: Espaces.x32),
      ],
    );
  }
}
