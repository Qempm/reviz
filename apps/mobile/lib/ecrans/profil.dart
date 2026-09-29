import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../composants/bouton.dart';
import '../composants/carte.dart';
import '../composants/chargement.dart';
import '../composants/coquille.dart';
import '../composants/etat_vide.dart';
import '../composants/podium.dart' show AvatarInitiale;
import '../composants/puce.dart';
import '../donnees/modeles.dart';
import '../donnees/reglages.dart';
import '../donnees/google.dart';
import '../donnees/supabase.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../metier/serie.dart';
import '../routage.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Le profil : qui on est, où on en est, et les deux réglages qui existent.
///
/// Les entrées qui ne mènent nulle part ne sont pas là. L'écran web en
/// comptait quatre — « vider le cache » sans gestionnaire, un interrupteur
/// WhatsApp en texte figé, et deux liens vers des routes inexistantes
/// (rapport § 4.15). Ce qui n'est pas écrit n'est pas affiché.
class EcranProfil extends ConsumerWidget {
  const EcranProfil({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      enfant: switch (profil) {
        AsyncData(:final value) when value != null => _Contenu(profil: value),
        AsyncData() => Padding(
          padding: const EdgeInsets.all(Espaces.ecran),
          child: EtatVide(
            icone: Icons.person_outline,
            titre: Fr.inscription.titre,
            action: Bouton(
              libelle: Fr.commun.continuer,
              icone: Icons.arrow_forward,
              onTap: () => context.go(Chemins.inscription),
            ),
          ),
        ),
        AsyncError(:final error) => Padding(
          padding: const EdgeInsets.all(Espaces.ecran),
          child: EtatVide(
            icone: Icons.cloud_off,
            titre: Fr.erreurs.chargementImpossible,
            description: '$error',
            action: Bouton(
              libelle: Fr.commun.reessayer,
              icone: Icons.refresh,
              onTap: () => ref.invalidate(profilProvider),
            ),
          ),
        ),
        _ => const Chargement.liste(),
      },
    );
  }
}

class _Contenu extends ConsumerWidget {
  const _Contenu({required this.profil});

  final Profil profil;

  Future<void> _deconnecter(BuildContext context, WidgetRef ref) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogue) => AlertDialog(
        backgroundColor: Couleurs.carte,
        title: Text(Fr.profil.confirmerDeconnexion, style: Typo.headlineMd),
        content: Text(
          Fr.profil.confirmerDeconnexionDetail,
          style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogue).pop(false),
            child: Text(Fr.commun.annuler),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogue).pop(true),
            child: Text(
              Fr.profil.deconnexion,
              style: TextStyle(color: Couleurs.danger),
            ),
          ),
        ],
      ),
    );

    if (confirme != true) return;

    // Le compte Google choisi est oublié **avant** la session Reviz. Sans
    // cela, « me déconnecter » puis « continuer avec Google » reconnecte le
    // même compte instantanément, sans laisser le choix : sur un téléphone
    // partagé — courant dans le public visé — la personne suivante se
    // retrouverait dans le compte de la précédente. Silencieux : une
    // déconnexion ne doit jamais échouer à cause de Google.
    await const ConnexionGoogle().oublier();

    // Le routeur écoute `onAuthStateChange` : la redirection vers l'écran de
    // connexion se fait d'elle-même, aucun `go` n'est nécessaire ici.
    await supabase.auth.signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animationsReduites = ref.watch(animationsReduitesProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaces.ecran,
        vertical: Espaces.x16,
      ),
      children: [
        // --- Identité
        Carte(
          enfants: [
            Row(
              children: [
                // Le même avatar s'envole vers l'écran de choix, et en revient.
                Hero(
                  tag: 'avatar-profil',
                  child: AvatarInitiale(
                    prenom: profil.prenom,
                    cleAvatar: profil.avatar,
                    taille: 64,
                  ),
                ),
                const SizedBox(width: Espaces.x16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        profil.prenom ?? Fr.profil.titre,
                        style: Typo.headlineLg,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (profil.faculteNom != null)
                        Text(
                          profil.faculteNom!,
                          style: Typo.labelMd.copyWith(
                            color: Couleurs.attenue,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (profil.universiteNom != null ||
                          profil.anneeEtude != null)
                        Text(
                          [
                            if (profil.universiteNom != null)
                              profil.universiteNom!,
                            if (profil.anneeEtude != null)
                              Fr.profil.annee(profil.anneeEtude!),
                          ].join(' · '),
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
        const SizedBox(height: Espaces.x16),

        // --- Vérification de la carte étudiante
        //
        // C'est la seule barrière « un compte par personne » depuis que le
        // téléphone est facultatif : l'écran le dit, et ne prétend pas que le
        // compte est vérifié quand il ne l'est pas.
        Carte(
          enfants: [
            Row(
              children: [
                Icon(
                  profil.verifie
                      ? Icons.verified_user
                      : profil.verificationEnCours
                      ? Icons.hourglass_top
                      : Icons.badge_outlined,
                  size: 24,
                  color: profil.verifie
                      ? Couleurs.texteAccent
                      : Couleurs.orange,
                ),
                const SizedBox(width: Espaces.x8),
                Expanded(
                  child: Text(
                    profil.verifie
                        ? Fr.profil.verifie
                        : profil.verificationEnCours
                        ? Fr.profil.verificationEnCours
                        : Fr.profil.nonVerifie,
                    style: Typo.headlineMd,
                  ),
                ),
              ],
            ),
            Text(
              profil.verifie
                  ? Fr.profil.verifieDetail
                  : profil.verificationEnCours
                  ? Fr.profil.verificationEnCoursDetail
                  : Fr.profil.nonVerifieDetail,
              style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
            ),
            if (!profil.verifie && !profil.verificationEnCours)
              Bouton(
                libelle: Fr.profil.ajouterCarte,
                icone: Icons.photo_camera,
                variante: VarianteBouton.secondaire,
                onTap: () => context.descendre(Chemins.carte),
              ),
          ],
        ),
        const SizedBox(height: Espaces.x16),

        // --- Chiffres
        Carte(
          enfants: [
            Text(Fr.profil.mesChiffres, style: Typo.headlineMd),
            Wrap(
              spacing: Espaces.x8,
              runSpacing: Espaces.x8,
              children: [
                Puce(
                  libelle: Fr.profil.xp(profil.xpTotal),
                  ton: TonPuce.jaune,
                  icone: Icons.bolt,
                ),
                Puce(
                  libelle: Fr.profil.serie(profil.serieCourante),
                  ton: TonPuce.orange,
                  icone: Icons.local_fire_department,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: Espaces.x16),

        // --- Avatar
        Bouton(
          libelle: Fr.profil.changerAvatar,
          icone: Icons.face_retouching_natural,
          variante: VarianteBouton.secondaire,
          onTap: () => context.descendre(Chemins.avatar),
        ),
        const SizedBox(height: Espaces.x12),

        // --- Aide
        //
        // `Fr.profil.aide` était une ligne d'i18n sans écran derrière : un
        // étudiant payait 2 000 F sans pouvoir vérifier nulle part qu'il ne
        // serait pas prélevé le mois suivant.
        Bouton(
          libelle: Fr.profil.aide,
          icone: Icons.help_outline,
          variante: VarianteBouton.secondaire,
          onTap: () => context.descendre(Chemins.aide),
        ),
        const SizedBox(height: Espaces.x12),

        // --- Accès
        Bouton(
          libelle: Fr.profil.voirLesPacks,
          icone: Icons.shopping_bag_outlined,
          variante: VarianteBouton.secondaire,
          onTap: () => context.descendre(Chemins.boutique),
        ),
        const SizedBox(height: Espaces.x16),

        // --- Réglages
        Carte(
          enfants: [
            Text(Fr.profil.reglages, style: Typo.headlineMd),
            // Une ligne et un `Switch`, et non un `SwitchListTile` : ce
            // dernier peint son fond et ses ondes sur le `Material` le plus
            // proche, que la carte — un `DecoratedBox` coloré — masque. Le
            // framework le signale par une assertion, attrapée au test.
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(Fr.profil.animationsReduites, style: Typo.labelLg),
                      Text(
                        Fr.profil.animationsReduitesAide,
                        style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Espaces.x8),
                Switch(
                  value: animationsReduites,
                  onChanged: (_) =>
                      ref.read(animationsReduitesProvider.notifier).basculer(),
                  activeTrackColor: Couleurs.jaune,
                  activeThumbColor: Couleurs.carte,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: Espaces.x16),

        Bouton(
          libelle: Fr.profil.deconnexion,
          icone: Icons.logout,
          variante: VarianteBouton.secondaire,
          onTap: () => _deconnecter(context, ref),
        ),
        const SizedBox(height: Espaces.x12),

        // En dernier, et en rouge : c'est la seule action irréversible de
        // l'application. L'écran qui suit dit ce qui part et ce qui reste.
        TextButton.icon(
          onPressed: () => context.descendre(Chemins.suppression),
          icon: const Icon(Icons.delete_outline, size: 20),
          label: Text(Fr.suppression.entree),
          style: TextButton.styleFrom(
            foregroundColor: Couleurs.danger,
            minimumSize: const Size(0, Mesures.zoneTactile),
          ),
        ),
        const SizedBox(height: Espaces.x32),
      ],
    );
  }
}
