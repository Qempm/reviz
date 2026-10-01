import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../composants/bouton.dart';
import '../composants/carte.dart';
import '../donnees/config.dart';
import '../etat/fournisseurs.dart';
import '../i18n/fr.dart';
import '../metier/plateforme.dart';
import '../routage.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Aide et contact — le dernier écran de la liste du MVP.
///
/// `Fr.profil.aide` existait depuis le début sans écran derrière : une ligne
/// d'i18n morte, et un étudiant qui paie 2 000 F sans savoir s'il sera
/// prélevé le mois suivant.
///
/// Les sept questions sont dans l'ordre où elles se posent vraiment, et
/// l'argent vient en premier : « est-ce que je serai prélevé chaque mois ? »
/// est la crainte qui empêche d'acheter, dans un marché où les abonnements
/// qu'on n'arrive pas à résilier sont une expérience courante. La réponse est
/// non, et elle doit être la première chose lisible.
///
/// Le contact n'apparaît que si `CONTACT_WHATSAPP` est passé au build. Même
/// principe que le bouton Google : un numéro qui ne répond pas est pire que
/// pas de numéro, et l'écran le dit plutôt que de faire semblant.
class EcranAide extends ConsumerWidget {
  const EcranAide({super.key});

  Future<void> _ecrire() async {
    final lien = Uri.https('wa.me', '/${Config.contactWhatsapp}', {
      'text': Fr.aide.contactMessage,
    });

    // WhatsApp peut ne pas être installé : un contact raté n'a pas à remonter
    // en erreur d'écran.
    try {
      await launchUrl(lien, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(miseAJourProvider);

    return Scaffold(
      backgroundColor: Couleurs.fond,
      appBar: AppBar(
        backgroundColor: Couleurs.fond,
        surfaceTintColor: Colors.transparent,
        title: Text(Fr.aide.titre, style: Typo.headlineLg),
        leading: IconButton(
          onPressed: () => context.remonter(Chemins.profil),
          icon: const Icon(Icons.arrow_back, color: Couleurs.encre),
          tooltip: Fr.commun.retour,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Mesures.largeurApp),
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: Espaces.ecran,
                vertical: Espaces.x16,
              ),
              children: [
                Text(
                  Fr.aide.sousTitre,
                  style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
                ),
                const SizedBox(height: Espaces.x20),

                for (final (question, reponse)
                    in achatsDansLApplication
                        ? Fr.aide.questions
                        : Fr.aide.questionsSansAchat) ...[
                  _Question(question: question, reponse: reponse),
                  const SizedBox(height: Espaces.x8),
                ],

                const SizedBox(height: Espaces.x16),

                Carte(
                  enfants: [
                    Text(Fr.aide.contactTitre, style: Typo.headlineMd),
                    if (Config.contactWhatsapp.isEmpty)
                      Text(
                        Fr.aide.contactAbsent,
                        style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
                      )
                    else ...[
                      Text(
                        Fr.aide.contactDetail,
                        style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
                      ),
                      Bouton(
                        libelle: Fr.aide.contactBouton,
                        icone: Icons.chat_bubble_outline,
                        onTap: _ecrire,
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: Espaces.x16),

                // La version installée : c'est la première chose qu'on
                // demandera à l'étudiant quand il écrira.
                Carte(
                  petite: true,
                  enfants: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            Fr.aide.versionTitre,
                            style: Typo.labelMd,
                          ),
                        ),
                        Text(
                          switch (version) {
                            AsyncData(:final value) => value.locale,
                            _ => '…',
                          },
                          style: Typo.labelMd.copyWith(color: Couleurs.attenue),
                        ),
                      ],
                    ),
                  ],
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

/// Une question, dépliable.
///
/// Repliée par défaut : sept réponses ouvertes feraient un mur de texte que
/// personne ne lit, et la liste des questions est elle-même l'information —
/// on y cherche la sienne.
class _Question extends StatefulWidget {
  const _Question({required this.question, required this.reponse});

  final String question;
  final String reponse;

  @override
  State<_Question> createState() => _QuestionState();
}

class _QuestionState extends State<_Question> {
  bool _ouverte = false;

  @override
  Widget build(BuildContext context) {
    return Carte(
      enfants: [
        // `InkWell` sur toute la largeur : la zone tactile fait la hauteur du
        // titre, jamais moins de 48 px.
        InkWell(
          onTap: () => setState(() => _ouverte = !_ouverte),
          borderRadius: BorderRadius.circular(Rayons.moyen),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Espaces.x8),
            child: Row(
              children: [
                Expanded(child: Text(widget.question, style: Typo.labelLg)),
                const SizedBox(width: Espaces.x8),
                Icon(
                  _ouverte ? Icons.expand_less : Icons.expand_more,
                  color: Couleurs.attenue,
                ),
              ],
            ),
          ),
        ),
        if (_ouverte)
          Text(
            widget.reponse,
            style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
          ),
      ],
    );
  }
}
