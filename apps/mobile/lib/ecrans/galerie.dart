import 'package:flutter/material.dart';
import '../composants/bouton.dart';
import '../composants/carte.dart';
import '../composants/etat_vide.dart';
import '../composants/option_qcm.dart';
import '../composants/progression.dart';
import '../composants/puce.dart';
import '../i18n/fr.dart';
import '../metier/serie.dart';
import '../theme/jetons.dart';
import '../theme/typographie.dart';

/// Galerie des composants — l'équivalent Flutter du kitchen-sink web.
///
/// Sa raison d'être : valider le rendu **à 375 px** avant d'écrire le premier
/// écran métier. Les deux fois où le rendu a été jugé sur un serveur de
/// développement plutôt que sur un build réel, côté web, une feuille de style
/// vide a fait croire à un bug de mise en page. On regarde ici, et on regarde
/// pour de vrai.
class Galerie extends StatefulWidget {
  const Galerie({super.key});

  @override
  State<Galerie> createState() => _GalerieState();
}

class _GalerieState extends State<Galerie> {
  int? _choix;
  bool _corrige = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Couleurs.cream,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Mesures.largeurApp),
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: Espaces.ecran,
                vertical: Espaces.x24,
              ),
              children: [
                Text('Galerie', style: Typo.headlineXl),
                const SizedBox(height: Espaces.x4),
                Text(
                  'Les composants du design system, à valider avant les '
                  'écrans. Référence : docs/DESIGN.md.',
                  style: Typo.bodyMd.copyWith(color: Couleurs.attenue),
                ),
                const SizedBox(height: Espaces.x32),

                _Section(
                  titre: 'Palette',
                  enfant: Wrap(
                    spacing: Espaces.x8,
                    runSpacing: Espaces.x8,
                    children: const [
                      _Pastille('cream', Couleurs.cream),
                      _Pastille('jaune', Couleurs.jaune),
                      _Pastille('jaune doux', Couleurs.jauneDoux),
                      _Pastille('orange', Couleurs.orange),
                      _Pastille('orange doux', Couleurs.orangeDoux),
                      _Pastille('bleu', Couleurs.bleu),
                      _Pastille('encre', Couleurs.encre),
                      _Pastille('atténué', Couleurs.attenue),
                      _Pastille('danger', Couleurs.danger),
                      _Pastille('bordure', Couleurs.bordure),
                    ],
                  ),
                ),

                _Section(
                  titre: 'Typographie',
                  enfant: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('1 280 XP', style: Typo.displayHerosMobile),
                      Text('Titre d’écran', style: Typo.headlineXl),
                      Text('Titre de section', style: Typo.headlineLg),
                      Text('Titre de carte', style: Typo.headlineMd),
                      const SizedBox(height: Espaces.x8),
                      Text(
                        'Corps de texte : l’étudiant ouvre l’application la '
                        'nuit avant un contrôle, sur une connexion instable.',
                        style: Typo.bodyMd,
                      ),
                      const SizedBox(height: Espaces.x8),
                      Text('Label large', style: Typo.labelLg),
                      Text('Label moyen', style: Typo.labelMd),
                      Text(
                        'CAPTION, LE SEUL NIVEAU EN MAJUSCULES',
                        style: Typo.caption.copyWith(color: Couleurs.attenue),
                      ),
                    ],
                  ),
                ),

                _Section(
                  titre: 'Boutons',
                  enfant: Column(
                    children: [
                      Bouton(
                        libelle: Fr.reviser.ajouterCours,
                        icone: Icons.add,
                        onTap: () {},
                      ),
                      const SizedBox(height: Espaces.x8),
                      Bouton(
                        libelle: Fr.commun.retour,
                        variante: VarianteBouton.secondaire,
                        icone: Icons.arrow_back,
                        onTap: () {},
                      ),
                      const SizedBox(height: Espaces.x8),
                      const Bouton(
                        libelle: 'Supprimer mon compte',
                        variante: VarianteBouton.danger,
                        icone: Icons.delete_outline,
                      ),
                      const SizedBox(height: Espaces.x4),
                      Text(
                        'Le troisième est désactivé : appuie sur les deux '
                        'premiers pour voir l’arête tactile se réduire.',
                        style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                _Section(
                  titre: 'Pilules',
                  enfant: Wrap(
                    spacing: Espaces.x8,
                    runSpacing: Espaces.x8,
                    children: [
                      Puce(
                        libelle: Fr.reviser.exemple,
                        ton: TonPuce.jaune,
                        icone: Icons.auto_awesome,
                      ),
                      Puce(
                        libelle: Fr.reviser.enTraitement,
                        ton: TonPuce.orange,
                        icone: Icons.hourglass_top,
                      ),
                      const Puce(libelle: 'J−3', ton: TonPuce.bleu),
                      const Puce(libelle: 'À revoir', ton: TonPuce.danger),
                      const Puce(libelle: 'Neutre'),
                    ],
                  ),
                ),

                _Section(
                  titre: 'Cartes et progression',
                  enfant: Column(
                    children: [
                      Carte(
                        enfants: [
                          Text('Droit constitutionnel', style: Typo.headlineMd),
                          Text(
                            Fr.reviser.decompte(3, 20, 12),
                            style: Typo.labelSm.copyWith(
                              color: Couleurs.attenue,
                            ),
                          ),
                          const BarreProgression(
                            valeur: 0.35,
                            libelle: '7 / 20 questions',
                          ),
                        ],
                      ),
                      const SizedBox(height: Espaces.x12),
                      Carte(
                        petite: true,
                        enfants: [
                          Row(
                            children: [
                              JaugeCirculaire(
                                valeur: 0.6,
                                taille: 72,
                                centre: Text('60 %', style: Typo.labelLg),
                              ),
                              const SizedBox(width: Espaces.x16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Maîtrise', style: Typo.labelLg),
                                    Text(
                                      'Calculée sur la dernière tentative de '
                                      'chaque question.',
                                      style: Typo.labelSm.copyWith(
                                        color: Couleurs.attenue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: Espaces.x12),
                      const BarreSegmentee(
                        segments: [
                          EtatSegment.juste,
                          EtatSegment.juste,
                          EtatSegment.faux,
                          EtatSegment.juste,
                          EtatSegment.aVenir,
                          EtatSegment.aVenir,
                        ],
                      ),
                      const SizedBox(height: Espaces.x4),
                      Text(
                        'Juste en jaune, faux en rouge — aucun vert dans la '
                        'palette (docs/DESIGN.md § 11).',
                        style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                      ),
                    ],
                  ),
                ),

                _Section(
                  titre: 'Question de QCM',
                  enfant: Column(
                    children: [
                      Carte(
                        enfants: [
                          Text(
                            'À quelle date la Constitution béninoise '
                            'actuellement en vigueur a-t-elle été promulguée ?',
                            style: Typo.headlineMd,
                          ),
                        ],
                      ),
                      const SizedBox(height: Espaces.x8),
                      for (var i = 0; i < _options.length; i++) ...[
                        if (i > 0) const SizedBox(height: Espaces.x8),
                        OptionQcm(
                          lettre: _lettres[i],
                          libelle: _options[i],
                          etat: _etatDe(i),
                          onTap: _corrige
                              ? null
                              : () => setState(() => _choix = i),
                        ),
                      ],
                      const SizedBox(height: Espaces.x12),
                      Bouton(
                        libelle: _corrige
                            ? Fr.session.suivante
                            : Fr.session.valider,
                        icone: _corrige ? Icons.arrow_forward : Icons.check,
                        onTap: _choix == null
                            ? null
                            : () => setState(() {
                                if (_corrige) {
                                  _corrige = false;
                                  _choix = null;
                                } else {
                                  _corrige = true;
                                }
                              }),
                      ),
                    ],
                  ),
                ),

                _Section(
                  titre: 'État vide',
                  enfant: Carte(
                    enfants: [
                      EtatVide(
                        icone: Icons.upload_file,
                        titre: Fr.reviser.aucunCours,
                        description: Fr.reviser.aucunCoursDetail,
                        action: Bouton(
                          libelle: Fr.reviser.ajouterCours,
                          icone: Icons.add,
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                ),

                _Section(
                  titre: 'Métier porté, vérifié par 87 tests',
                  enfant: Carte(
                    petite: true,
                    enfants: [
                      Text(
                        'Série et objectif du jour',
                        style: Typo.labelLg,
                      ),
                      ..._apercuSerie(),
                    ],
                  ),
                ),

                const SizedBox(height: Espaces.x48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const _lettres = ['A', 'B', 'C', 'D'];
  static const _options = [
    'Le 2 décembre 1990',
    'Le 11 décembre 1990',
    'Le 28 février 1990',
    'Le 1er août 1960',
  ];

  /// La deuxième est la bonne, comme dans le cours de démonstration.
  static const _bonne = 1;

  EtatOption _etatDe(int i) {
    if (!_corrige) return _choix == i ? EtatOption.choisie : EtatOption.repos;
    if (i == _bonne) return EtatOption.juste;
    if (i == _choix) return EtatOption.fausse;
    return EtatOption.repos;
  }

  /// Rend visible ce que les fonctions portées calculent — un écran qui
  /// affiche « 5 jours de flamme » alors que la série est morte depuis une
  /// semaine était exactement le défaut § 4.1 du rapport.
  List<Widget> _apercuSerie() {
    final cas = <(String, EtatSerie)>[
      (
        'validée aujourd’hui',
        etatSerie(current: 6, lastValidatedOn: jourUtc()),
      ),
      (
        'en jeu (hier validé)',
        etatSerie(
          current: 3,
          lastValidatedOn: veille(jourUtc()),
        ),
      ),
      (
        'rompue (il y a huit jours)',
        etatSerie(current: 5, lastValidatedOn: '2026-01-01'),
      ),
    ];

    return [
      for (final (libelle, etat) in cas)
        Padding(
          padding: const EdgeInsets.only(top: Espaces.x4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  libelle,
                  style: Typo.labelSm.copyWith(color: Couleurs.attenue),
                ),
              ),
              Puce(
                libelle: etat.rompue
                    ? 'éteinte'
                    : '${etat.jours} j${etat.enJeu ? ' · à entretenir' : ''}',
                ton: etat.rompue ? TonPuce.neutre : TonPuce.jaune,
                icone: Icons.local_fire_department,
              ),
            ],
          ),
        ),
      const SizedBox(height: Espaces.x8),
      BarreProgression(
        valeur: progressionDuJour(6, 10),
        libelle: '6 / 10 questions aujourd’hui',
      ),
      Text(
        'Encore ${resteAvantObjectif(6, 10)} questions et ta série tient un '
        'jour de plus.',
        style: Typo.labelSm.copyWith(color: Couleurs.attenue),
      ),
    ];
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.titre, required this.enfant});

  final String titre;
  final Widget enfant;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Espaces.x32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            titre.toUpperCase(),
            style: Typo.caption.copyWith(color: Couleurs.attenue),
          ),
          const SizedBox(height: Espaces.x12),
          enfant,
        ],
      ),
    );
  }
}

class _Pastille extends StatelessWidget {
  const _Pastille(this.nom, this.couleur);

  final String nom;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 40,
          decoration: BoxDecoration(
            color: couleur,
            borderRadius: BorderRadius.circular(Rayons.moyen),
            border: Border.all(color: Couleurs.bordure),
          ),
        ),
        const SizedBox(height: Espaces.x2),
        SizedBox(
          width: 56,
          child: Text(
            nom,
            style: Typo.caption.copyWith(color: Couleurs.attenue),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
