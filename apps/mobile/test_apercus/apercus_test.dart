// Banc d'aperçu : chaque écran rendu en PNG, pour être **regardé**.
//
//   flutter test test_apercus --update-goldens
//
// Les images sortent dans `test_apercus/goldens/`, ignoré par git. Ce n'est
// pas un test de non-régression — les rendus de police diffèrent d'une
// machine à l'autre —, c'est un appareil photo : il permet de juger un design
// sans téléphone, et sans compte, puisque les données sont factices.
//
// Hors de `test/` exprès : `flutter test` ne le lance pas.

import 'dart:async';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/theme/jetons.dart';
import 'package:reviz/i18n/fr.dart';
import 'package:reviz/composants/bandeau.dart';
import 'package:reviz/composants/bouton.dart';
import 'package:reviz/composants/carte.dart';
import 'package:reviz/composants/etat_vide.dart';
import 'package:reviz/composants/mascotte.dart';
import 'package:reviz/composants/coquille.dart';
import 'package:reviz/donnees/depots.dart';
import 'package:reviz/donnees/modeles.dart';
import 'package:reviz/ecrans/accueil.dart';
import 'package:reviz/ecrans/connexion.dart';
import 'package:reviz/ecrans/cours.dart';
import 'package:reviz/ecrans/ligue.dart';
import 'package:reviz/ecrans/correction.dart';
import 'package:reviz/ecrans/session.dart';
import 'package:reviz/metier/selection.dart';
import 'package:reviz/metier/maitrise.dart';
import 'package:reviz/ecrans/galerie.dart';
import 'package:reviz/ecrans/profil.dart';
import 'package:reviz/ecrans/reviser.dart';
import 'package:reviz/etat/fournisseurs.dart';
import 'package:reviz/theme/theme.dart';

/// La police des icônes Material, livrée avec le SDK Flutter. Sans elle, les
/// icônes sortent en carrés vides dans un rendu de test.
const _policeIcones =
    'C:/src/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf';

Future<void> _chargerPolices() async {
  final nunito = FontLoader('Nunito Sans')
    ..addFont(rootBundle.load('assets/polices/NunitoSans.ttf'));
  await nunito.load();

  final fichier = File(_policeIcones);
  if (fichier.existsSync()) {
    final icones = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(fichier.readAsBytesSync())));
    await icones.load();
  }
}

String get _hier {
  final d = DateTime.now().toUtc().subtract(const Duration(days: 1));
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final _profil = Profil(
  id: 'u1',
  prenom: 'Awa',
  xpTotal: 1280,
  serieCourante: 4,
  dernierJourValide: _hier,
  faculteId: 'f1',
  universiteNom: 'UAC',
  faculteNom: 'FADESP',
  codeParrain: 'ABC123',
  avatar: 'ton-01',
  statutVerification: 'verified',
  anneeEtude: 2,
);

const _semaine = [
  JourSerie(
    jourSemaine: 1,
    questions: 12,
    xp: 120,
    valide: true,
    aujourdhui: false,
  ),
  JourSerie(
    jourSemaine: 2,
    questions: 10,
    xp: 100,
    valide: true,
    aujourdhui: false,
  ),
  JourSerie(
    jourSemaine: 3,
    questions: 11,
    xp: 110,
    valide: true,
    aujourdhui: false,
  ),
  JourSerie(
    jourSemaine: 4,
    questions: 10,
    xp: 100,
    valide: true,
    aujourdhui: false,
  ),
  JourSerie(
    jourSemaine: 5,
    questions: 6,
    xp: 60,
    valide: false,
    aujourdhui: true,
  ),
  JourSerie(
    jourSemaine: 6,
    questions: 0,
    xp: 0,
    valide: false,
    aujourdhui: false,
  ),
  JourSerie(
    jourSemaine: 7,
    questions: 0,
    xp: 0,
    valide: false,
    aujourdhui: false,
  ),
];

const _matieres = [
  StatMatiere(
    matiereId: 'm1',
    matiereNom: 'Droit constitutionnel',
    questionsFaites: 20,
    scoreMoyen: 0.65,
    aRevoir: false,
  ),
  StatMatiere(
    matiereId: 'm2',
    matiereNom: 'Introduction à l’étude du droit',
    questionsFaites: 14,
    scoreMoyen: 0.35,
    aRevoir: true,
  ),
  StatMatiere(
    matiereId: 'm3',
    matiereNom: 'Économie politique',
    questionsFaites: 8,
    scoreMoyen: 0.8,
    aRevoir: false,
  ),
];

const _cours = [
  ApercuCours(
    id: 'c1',
    titre: 'Droit constitutionnel — introduction',
    statut: 'ready',
    demo: true,
    matiereNom: 'Droit constitutionnel',
    dateExamen: null,
    nbChapitres: 3,
    nbQuestions: 20,
    nbFiches: 12,
    nbTentees: 7,
  ),
  ApercuCours(
    id: 'c2',
    titre: 'Économie politique — chapitres 1 à 4',
    statut: 'ready',
    demo: false,
    matiereNom: 'Économie politique',
    dateExamen: null,
    nbChapitres: 4,
    nbQuestions: 16,
    nbFiches: 16,
    nbTentees: 13,
  ),
  ApercuCours(
    id: 'c3',
    titre: 'Droit administratif',
    statut: 'processing',
    demo: false,
    matiereNom: 'Droit administratif',
    dateExamen: null,
    nbChapitres: 2,
    nbQuestions: 8,
    nbFiches: 0,
    nbTentees: 0,
  ),
];

/// Un écran d'onglet posé sur la vraie barre du bas, comme dans l'app.
Widget _surOnglet(Widget ecran, int onglet) => Scaffold(
  body: ecran,
  bottomNavigationBar: NavBasse(indexActif: onglet, onChoisir: (_) {}),
);

Future<void> _photographier(
  WidgetTester tester,
  String nom,
  Widget ecran, {
  List<Override> remplacements = const [],
  Size taille = const Size(390, 844),
}) async {
  tester.view.physicalSize = taille * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: remplacements,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: themeReviz,
        home: RepaintBoundary(key: const ValueKey('photo'), child: ecran),
      ),
    ),
  );

  // D'abord laisser les fournisseurs factices se résoudre : une image posée
  // par un écran encore en chargement n'est pas dans l'arbre, et ne serait
  // donc pas préchargée.
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }

  // Les images (avatars, mascotte) se décodent pour de vrai, hors du temps
  // simulé : sans cela elles sortent vides.
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      await precacheImage(image.image, element);
    }
  });

  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }

  await expectLater(
    find.byKey(const ValueKey('photo')),
    matchesGoldenFile('goldens/$nom.png'),
  );
}

ChapitreDuChemin _etape(
  int index,
  String titre,
  EtatChapitre etat, {
  int couronnes = 0,
  int total = 6,
  int tentees = 0,
  int justes = 0,
}) => ChapitreDuChemin(
  chapitre: ApercuChapitre(
    id: 'ch$index',
    index: index,
    titre: titre,
    nbQuestions: total,
    nbFiches: 4,
    nbTentees: tentees,
    taux: null,
    aRevoir: etat == EtatChapitre.aRevoir,
  ),
  maitrise: Maitrise(
    etat: etat,
    couronnes: couronnes,
    total: total,
    tentees: tentees,
    justes: justes,
  ),
);

void main() {
  setUpAll(_chargerPolices);

  final accueil = DonneesAccueil(
    profil: _profil,
    semaine: _semaine,
    objectif: 10,
    matieres: _matieres,
    dernierCours: _cours[1],
    // Dans cinq jours, quel que soit le jour où l'on rend l'aperçu.
    prochainExamen: ApercuCours(
      id: 'c4',
      titre: 'Droit des obligations',
      statut: 'ready',
      demo: false,
      matiereNom: 'Droit civil',
      dateExamen: DateTime.now().add(const Duration(days: 5)).toIso8601String(),
      nbChapitres: 5,
      nbQuestions: 30,
      nbFiches: 20,
      nbTentees: 4,
    ),
  );

  testWidgets('accueil', (tester) async {
    await _photographier(
      tester,
      'accueil',
      _surOnglet(const EcranAccueil(), 0),
      remplacements: [
        accueilProvider.overrideWith((_) async => accueil),
        profilProvider.overrideWith((_) async => _profil),
      ],
    );
  });

  testWidgets('chargement', (tester) async {
    // Des données qui n'arrivent jamais : on photographie l'attente.
    await _photographier(
      tester,
      'chargement',
      _surOnglet(const EcranAccueil(), 0),
      remplacements: [
        accueilProvider.overrideWith(
          (_) => Completer<DonneesAccueil?>().future,
        ),
        profilProvider.overrideWith((_) async => _profil),
      ],
    );
  });

  testWidgets('reviser', (tester) async {
    await _photographier(
      tester,
      'reviser',
      _surOnglet(const EcranReviser(), 1),
      remplacements: [
        coursProvider.overrideWith((_) async => _cours),
        profilProvider.overrideWith((_) async => _profil),
      ],
    );
  });

  testWidgets('profil', (tester) async {
    await _photographier(
      tester,
      'profil',
      _surOnglet(const EcranProfil(), 4),
      taille: const Size(390, 1500),
      remplacements: [
        profilProvider.overrideWith((_) async => _profil),
        accueilProvider.overrideWith((_) async => accueil),
      ],
    );
  });

  testWidgets('chemin', (tester) async {
    final chemin = [
      _etape(
        1,
        'Introduction au droit constitutionnel',
        EtatChapitre.couronne,
        couronnes: 3,
        tentees: 6,
        justes: 6,
      ),
      _etape(
        2,
        'La notion de Constitution',
        EtatChapitre.couronne,
        couronnes: 2,
        tentees: 6,
        justes: 5,
      ),
      _etape(
        3,
        'Le contrôle de constitutionnalité',
        EtatChapitre.couronne,
        couronnes: 1,
        tentees: 6,
        justes: 3,
      ),
      _etape(
        4,
        'La séparation des pouvoirs',
        EtatChapitre.aDecouvrir,
        tentees: 2,
        justes: 2,
      ),
      _etape(5, 'Annexes et textes', EtatChapitre.sansQcm, total: 0),
      _etape(6, 'Le Parlement', EtatChapitre.verrouille),
      _etape(7, 'Le pouvoir exécutif', EtatChapitre.verrouille),
    ];
    await _photographier(
      tester,
      'chemin',
      const EcranCours(coursId: 'c2'),
      taille: const Size(390, 1900),
      remplacements: [
        unCoursProvider('c2').overrideWith((_) async => _cours[1]),
        cheminProvider('c2').overrideWith((_) async => chemin),
      ],
    );
  });

  testWidgets('ligue', (tester) async {
    const prenoms = [
      'Koffi',
      'Aïcha',
      'Mawuli',
      'Awa',
      'Sèna',
      'Ibrahim',
      'Fifamè',
      'Yao',
      'Rokia',
      'Edem',
      'Nafi',
      'Kossi',
      'Adjoa',
      'Moussa',
    ];
    await _photographier(
      tester,
      'ligue',
      const EcranLigue(),
      taille: const Size(390, 1400),
      remplacements: [
        ligueProvider.overrideWith(
          (_) async => DonneesLigue(
            division: 2,
            fin: DateTime.now().add(const Duration(days: 3, hours: 4)),
            derniere: BilanLigue(
              semaine: DateTime.now()
                  .add(const Duration(days: 3, hours: 4))
                  .subtract(const Duration(days: 14))
                  .toUtc()
                  .toIso8601String()
                  .substring(0, 10),
              rang: 5,
              issue: 'monte',
              division: 1,
            ),
            membres: [
              for (var i = 0; i < prenoms.length; i++)
                LigneClassement(
                  rang: i + 1,
                  prenom: prenoms[i],
                  avatar: 'ton-0${(i % 9) + 1}',
                  xp: 620 - i * 37,
                  estMoi: i == 3,
                ),
            ],
          ),
        ),
      ],
    );
  });

  testWidgets('session', (tester) async {
    await _photographier(
      tester,
      'session',
      const EcranSession(coursId: 'c2'),
      remplacements: [
        questionsProvider((
          cours: 'c2',
          chapitre: null,
          mode: ModeSession.normal,
        )).overrideWith(
          (_) async => const [
            QuestionQcm(
              id: 'q1',
              enonce:
                  'Selon ton cours, qu’est-ce qui distingue le contrôle de '
                  'constitutionnalité a priori du contrôle a posteriori ?',
              options: [
                'Le moment : avant ou après la promulgation de la loi',
                'L’organe qui contrôle : Parlement ou juge',
                'La procédure : écrite ou orale',
                'Le type de loi : organique ou ordinaire',
              ],
              reponse: 'Le moment : avant ou après la promulgation de la loi',
              explication:
                  'Le chapitre 3 le dit : a priori, avant la promulgation ; '
                  'a posteriori, à l’occasion d’un procès.',
              probabilite: 'high',
            ),
            QuestionQcm(
              id: 'q2',
              enonce: 'Qui peut saisir la Cour constitutionnelle ?',
              options: ['Tout citoyen', 'Le seul Président', 'Le Sénat', 'Personne'],
              reponse: 'Tout citoyen',
              explication: null,
              probabilite: 'medium',
            ),
          ],
        ),
      ],
    );
  });

  testWidgets('correction', (tester) async {
    await _photographier(
      tester,
      'correction',
      const EcranCorrection(correctionId: 'k1'),
      taille: const Size(390, 1500),
      remplacements: [
        correctionProvider('k1').overrideWith(
          (_) async => Correction(
            id: 'k1',
            coursId: 'c2',
            statut: 'ready',
            note: 27.5,
            bareme: 40,
            lignes: const [
              LigneBareme(
                critere: 'Compréhension du sujet',
                points: 9,
                maximum: 10,
                commentaire: 'Tu as bien situé la question dans le cours.',
              ),
              LigneBareme(
                critere: 'Maîtrise des notions du cours',
                points: 10.5,
                maximum: 16,
                commentaire:
                    'Le contrôle a posteriori est confondu avec l’exception '
                    'd’inconstitutionnalité : revois le chapitre 3.',
              ),
              LigneBareme(
                critere: 'Plan et argumentation',
                points: 8,
                maximum: 14,
                commentaire: null,
              ),
            ],
            retour: const RetourCorrection(
              resume:
                  'Bonne copie de L1 : le plan tient, les définitions sont '
                  'justes. Il manque les articles du cours pour convaincre.',
              pointsForts: ['Définitions exactes', 'Plan clair'],
              aTravailler: ['Citer les articles', 'Conclusion trop courte'],
              chapitres: [('ch3', 'Le contrôle de constitutionnalité')],
              notions: ['Contrôle a posteriori', 'Saisine citoyenne'],
            ),
            modele: null,
            creeLe: null,
            motifIllisible: null,
          ),
        ),
      ],
    );
  });

  testWidgets('connexion', (tester) async {
    await _photographier(tester, 'connexion', const EcranConnexion());
  });

  testWidgets('mascotte', (tester) async {
    await _photographier(
      tester,
      'mascotte',
      Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(Espaces.ecran),
            children: [
              Carte(
                enfants: [
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: Espaces.x8,
                    runSpacing: Espaces.x8,
                    children: [
                      for (final etat in EtatMascotte.values)
                        Mascotte(etat: etat, taille: 104),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: Espaces.x16),
              Carte(
                enfants: [
                  EtatVide(
                    mascotte: EtatMascotte.curieux,
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
            ],
          ),
        ),
      ),
    );
  });

  testWidgets('etats', (tester) async {
    // Hors ligne, et une page qui n'a pas pu se charger : les deux états
    // qui portaient encore une icône par défaut.
    await _photographier(
      tester,
      'etats',
      Scaffold(
        body: Column(
          children: [
            const BandeauHorsLigne(),
            Expanded(
              child: Center(
                child: EtatVide(
                  mascotte: EtatMascotte.oups,
                  titre: Fr.erreurs.chargementImpossible,
                  action: Bouton(
                    libelle: Fr.commun.reessayer,
                    icone: Icons.refresh,
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  });

  testWidgets('entretien', (tester) async {
    await _photographier(
      tester,
      'entretien',
      const Scaffold(
        body: Center(child: Mascotte(etat: EtatMascotte.chantier, taille: 160)),
      ),
    );
  });

  testWidgets('galerie', (tester) async {
    await _photographier(
      tester,
      'galerie',
      const Galerie(),
      taille: const Size(390, 1600),
    );
  });
}
