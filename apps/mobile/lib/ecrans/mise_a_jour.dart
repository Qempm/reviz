import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../composants/bouton.dart';
import '../composants/carte.dart';
import '../composants/mascotte.dart';
import '../donnees/version.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../metier/version.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Écran bloquant : la version installée ne peut plus servir, ou le serveur
/// est en entretien.
///
/// Il n'y a **que ces deux cas**. Une mise à jour simplement conseillée passe
/// par un bandeau, pas par un mur : bloquer quelqu'un qui pourrait réviser
/// serait lui coûter sa soirée pour une version mineure.
///
/// Côté web, `app/mise-a-jour-requise/page.tsx` existait mais rien n'y menait,
/// et rien ne pouvait y mener — le calcul qui aurait déclenché cet état
/// comparait deux champs du même fichier distant.
class EcranMiseAJour extends ConsumerWidget {
  const EcranMiseAJour({super.key, required this.etat});

  final EtatMiseAJour etat;

  Future<void> _telecharger(BuildContext context) async {
    final lien = etat.distante?.lien;

    if (lien == null || lien.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(Fr.miseAJour.lienIndisponible)));
      return;
    }

    try {
      await launchUrl(Uri.parse(lien), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(Fr.miseAJour.lienIndisponible)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entretien = etat.exigence == ExigenceVersion.maintenance;

    return Scaffold(
      backgroundColor: Couleurs.fond,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Mesures.largeurApp),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Espaces.ecran),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Mascotte(
                    etat: entretien
                        ? EtatMascotte.chantier
                        : EtatMascotte.salut,
                    taille: 160,
                  ),
                  const SizedBox(height: Espaces.x20),
                  Text(
                    entretien
                        ? Fr.miseAJour.maintenance
                        : Fr.miseAJour.exigee,
                    style: Typo.headlineXl,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Espaces.x12),
                  Text(
                    entretien
                        ? Fr.miseAJour.maintenanceDetail
                        : Fr.miseAJour.exigeeDetail,
                    style: Typo.bodyLg.copyWith(color: Couleurs.attenue),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Espaces.x24),

                  if (etat.distante?.notes != null)
                    Carte(
                      enfants: [
                        Text(
                          etat.distante!.notes!,
                          style: Typo.bodyMd.copyWith(
                            color: Couleurs.attenue,
                          ),
                        ),
                      ],
                    ),

                  if (!entretien) ...[
                    const SizedBox(height: Espaces.x16),
                    Bouton(
                      libelle: Fr.miseAJour.telecharger,
                      icone: Icons.download,
                      onTap: () => _telecharger(context),
                    ),
                  ],

                  const SizedBox(height: Espaces.x12),
                  Bouton(
                    libelle: Fr.miseAJour.reessayer,
                    icone: Icons.refresh,
                    variante: VarianteBouton.secondaire,
                    // Le seul moyen de sortir d'ici sans redémarrer :
                    // l'entretien se termine, et l'écran doit s'effacer tout
                    // seul quand l'étudiant le demande.
                    onTap: () => ref.invalidate(miseAJourProvider),
                  ),
                  const SizedBox(height: Espaces.x16),

                  Text(
                    Fr.miseAJour.versionInstallee(etat.locale),
                    style: Typo.caption.copyWith(color: Couleurs.attenue),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
