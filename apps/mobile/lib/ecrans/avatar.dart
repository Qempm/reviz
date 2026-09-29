import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../composants/bouton.dart';
import '../composants/carte.dart';
import '../composants/podium.dart' show AvatarInitiale;
import '../donnees/api.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../metier/avatars.dart';
import '../routage.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Choisir son avatar.
///
/// Douze animaux, chacun sur le fond de sa clé. L'écran n'a pas changé quand
/// les images sont arrivées : il montrait déjà `AvatarInitiale`, qui pose
/// maintenant un pochoir au lieu d'une lettre. C'est ce que promettaient les
/// clés stables — `ton-03` désigne un fichier là où il désignait une couleur,
/// sans migration.
class EcranAvatar extends ConsumerStatefulWidget {
  const EcranAvatar({super.key});

  @override
  ConsumerState<EcranAvatar> createState() => _EcranAvatarState();
}

class _EcranAvatarState extends ConsumerState<EcranAvatar> {
  String? _choisie;
  bool _envoi = false;
  String? _erreur;

  Future<void> _enregistrer(String cle) async {
    setState(() {
      _envoi = true;
      _erreur = null;
    });

    final reponse = await ref
        .read(depotProfilProvider)
        .choisirAvatar(ref.read(apiProvider), cle);

    if (!mounted) return;

    switch (reponse) {
      case ReponseSucces():
        // Le profil porte l'avatar, et le classement le lit : les deux
        // doivent se relire.
        ref.invalidate(profilProvider);
        ref.invalidate(classementProvider);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(Fr.avatar.enregistre)));
        context.go(Chemins.profil);
      case ReponseEchec(:final erreur):
        setState(() {
          _envoi = false;
          _erreur = erreur.isEmpty ? Fr.avatar.echec : erreur;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profil = ref.watch(profilProvider);

    final prenom = switch (profil) {
      AsyncData(:final value) when value != null => value.prenom,
      _ => null,
    };

    final actuelle = switch (profil) {
      AsyncData(:final value) when value != null => value.avatar,
      _ => null,
    };

    // Ce qu'on montre : le choix en cours, ou ce que porte le profil.
    final courante = _choisie ?? avatarDe(actuelle).cle;

    return Scaffold(
      backgroundColor: Couleurs.cream,
      appBar: AppBar(
        backgroundColor: Couleurs.cream,
        surfaceTintColor: Colors.transparent,
        title: Text(Fr.avatar.titre, style: Typo.headlineLg),
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
                Text(
                  Fr.avatar.sousTitre,
                  style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
                ),
                const SizedBox(height: Espaces.x20),

                // L'aperçu en grand : à 96 px on voit l'animal, ce qu'une
                // pastille de 80 px dans la grille ne montre qu'à moitié.
                Carte(
                  enfants: [
                    Text(
                      Fr.avatar.apercu,
                      style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                    ),
                    Center(
                      child: AvatarInitiale(
                        prenom: prenom,
                        cleAvatar: courante,
                        taille: 96,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Espaces.x20),

                // Quatre par ligne à 375 px, trois à 320 : la grille se
                // dimensionne à la place disponible plutôt que de déborder.
                LayoutBuilder(
                  builder: (context, contraintes) {
                    const gouttiere = Espaces.x12;
                    final parLigne = contraintes.maxWidth < 340 ? 3 : 4;
                    final cote =
                        (contraintes.maxWidth - gouttiere * (parLigne - 1)) /
                        parLigne;

                    return Wrap(
                      spacing: gouttiere,
                      runSpacing: gouttiere,
                      children: [
                        for (final a in avatars)
                          _Pastille(
                            // Clé stable : c'est par elle que le test
                            // désigne un animal, sans dépendre de sa
                            // position dans la grille.
                            key: ValueKey('avatar-${a.cle}'),
                            avatar: a,
                            prenom: prenom,
                            choisie: a.cle == courante,
                            cote: cote,
                            onTap: _envoi
                                ? null
                                : () => setState(() => _choisie = a.cle),
                          ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: Espaces.x12),
                Text(
                  Fr.avatar.desImages,
                  style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                ),

                if (_erreur != null) ...[
                  const SizedBox(height: Espaces.x16),
                  Container(
                    padding: const EdgeInsets.all(Espaces.x12),
                    decoration: BoxDecoration(
                      color: Couleurs.dangerDoux,
                      borderRadius: BorderRadius.circular(Rayons.normal),
                    ),
                    child: Text(
                      _erreur!,
                      style: Typo.labelMd.copyWith(
                        color: Couleurs.surDangerDoux,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: Espaces.x20),
                Bouton(
                  libelle: Fr.avatar.enregistrer,
                  icone: Icons.check,
                  // Rien de neuf à enregistrer tant qu'on n'a rien changé.
                  onTap: _envoi || _choisie == null || _choisie == actuelle
                      ? null
                      : () => _enregistrer(_choisie!),
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

/// Une couleur choisissable.
class _Pastille extends StatelessWidget {
  const _Pastille({
    super.key,
    required this.avatar,
    required this.prenom,
    required this.choisie,
    required this.cote,
    required this.onTap,
  });

  final Avatar avatar;
  final String? prenom;
  final bool choisie;
  final double cote;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: true,
        selected: choisie,
        label: avatar.cle,
        child: Container(
          width: cote,
          height: cote,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Couleurs.carte,
            borderRadius: BorderRadius.circular(Rayons.normal),
            // La sélection se lit à l'arête, pas à une coche posée dessus :
            // une coche cacherait la couleur qu'on est en train de juger.
            border: Border.all(
              width: choisie ? 3 : 1,
              color: choisie ? Couleurs.areteJaune : Couleurs.bordure,
            ),
          ),
          child: AvatarInitiale(
            prenom: prenom,
            cleAvatar: avatar.cle,
            taille: cote * 0.62,
          ),
        ),
      ),
    );
  }
}
