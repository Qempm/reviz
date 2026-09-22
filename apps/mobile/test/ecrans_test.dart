import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` n'est pas dans le baril principal de flutter_riverpod.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/composants/option_qcm.dart';
import 'package:reviz/donnees/depots.dart';
import 'package:reviz/donnees/modeles.dart';
import 'package:reviz/ecrans/accueil.dart';
import 'package:reviz/ecrans/cours.dart';
import 'package:reviz/ecrans/reviser.dart';
import 'package:reviz/ecrans/session.dart';
import 'package:reviz/etat/fournisseurs.dart';
import 'package:reviz/theme/theme.dart';

/// Rendu des écrans avec des données de la **forme réelle** de la base.
///
/// Les fournisseurs sont remplacés par des valeurs fixes : cela vérifie ce
/// qu'aucun banc réseau ne vérifie — que les écrans savent afficher les
/// données qu'ils reçoivent, à 375 px, sans déborder.
///
/// Le parcours réseau complet, lui, a été vérifié séparément contre la
/// production avec un vrai jeton (phase 1) ; ce qui reste à faire sur un
/// appareil est la validation visuelle finale.

// -------------------------------------------------------------- Fixtures

final _profil = Profil(
  id: 'u1',
  prenom: 'Awa',
  xpTotal: 1280,
  serieCourante: 4,
  // Validé hier : la série court, mais elle est en jeu.
  dernierJourValide: _hier,
  faculteId: 'f1',
  universiteNom: 'UAC',
  faculteNom: 'FADESP',
  codeParrain: 'ABC123',
);

String get _hier {
  final d = DateTime.now().toUtc().subtract(const Duration(days: 1));
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

const _semaine = [
  JourSerie(jourSemaine: 1, questions: 12, xp: 120, valide: true, aujourdhui: false),
  JourSerie(jourSemaine: 2, questions: 10, xp: 100, valide: true, aujourdhui: false),
  JourSerie(jourSemaine: 3, questions: 11, xp: 110, valide: true, aujourdhui: false),
  JourSerie(jourSemaine: 4, questions: 10, xp: 100, valide: true, aujourdhui: false),
  JourSerie(jourSemaine: 5, questions: 6, xp: 60, valide: false, aujourdhui: true),
  JourSerie(jourSemaine: 6, questions: 0, xp: 0, valide: false, aujourdhui: false),
  JourSerie(jourSemaine: 7, questions: 0, xp: 0, valide: false, aujourdhui: false),
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
];

const _coursDemo = ApercuCours(
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
);

const _coursEnCours = ApercuCours(
  id: 'c2',
  titre: 'Un cours très long dont le titre déborderait sans précaution',
  statut: 'processing',
  demo: false,
  matiereNom: 'Droit administratif',
  dateExamen: null,
  nbChapitres: 0,
  nbQuestions: 0,
  nbFiches: 0,
  nbTentees: 0,
);

const _chapitres = [
  ApercuChapitre(
    id: 'ch1',
    index: 1,
    titre: 'La notion de Constitution',
    nbQuestions: 7,
    nbFiches: 4,
    nbTentees: 5,
    taux: 0.8,
    aRevoir: false,
  ),
  ApercuChapitre(
    id: 'ch2',
    index: 2,
    titre: 'Le contrôle de constitutionnalité',
    nbQuestions: 7,
    nbFiches: 4,
    nbTentees: 6,
    taux: 0.33,
    aRevoir: true,
  ),
];

const _questions = [
  QuestionQcm(
    id: 'q1',
    enonce:
        'À quelle date la Constitution béninoise actuellement en vigueur '
        'a-t-elle été promulguée ?',
    options: [
      'Le 2 décembre 1990',
      'Le 11 décembre 1990',
      'Le 28 février 1990',
      'Le 1er août 1960',
    ],
    reponse: 'Le 11 décembre 1990',
    explication:
        'Le référendum a eu lieu le 2 décembre 1990 ; la promulgation est du '
        '11 décembre.',
    probabilite: 'high',
  ),
  QuestionQcm(
    id: 'q2',
    enonce: 'Quel événement ouvre le Renouveau démocratique au Bénin ?',
    options: [
      'Le coup d’État de 1972',
      'La Conférence des Forces Vives de la Nation',
      'L’indépendance de 1960',
      'La révision de 2019',
    ],
    reponse: 'La Conférence des Forces Vives de la Nation',
    explication: null,
    probabilite: 'medium',
  ),
];

// ----------------------------------------------------------------- Banc

Future<void> _poser(
  WidgetTester tester,
  Widget ecran, {
  List<Override> remplacements = const [],
  Size taille = const Size(375, 812),
}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: remplacements,
      child: MaterialApp(theme: themeReviz, home: ecran),
    ),
  );
  await tester.pumpAndSettle();
}

/// Tape sur une cible, en la faisant venir à l'écran si besoin.
///
/// Une `ListView` construit paresseusement : un bouton sous le pli n'est pas
/// encore dans l'arbre, et `find` ne le voit donc pas.
Future<void> _taper(WidgetTester tester, Finder cible) async {
  if (tester.widgetList(cible).isEmpty) {
    await tester.scrollUntilVisible(
      cible,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(cible);
  await tester.pumpAndSettle();
  await tester.tap(cible);
  await tester.pumpAndSettle();
}

void main() {
  group('tableau de bord', () {
    final donnees = DonneesAccueil(
      profil: _profil,
      semaine: _semaine,
      objectif: 10,
      matieres: _matieres,
    );

    testWidgets('affiche la série, l’objectif et les matières', (tester) async {
      await _poser(
        tester,
        const EcranAccueil(),
        remplacements: [
          accueilProvider.overrideWith((_) async => donnees),
          profilProvider.overrideWith((_) async => _profil),
        ],
      );

      expect(find.text('Bonjour Awa'), findsOneWidget);
      expect(find.textContaining('4 jours de flamme'), findsOneWidget);
      expect(find.text('6 / 10 questions aujourd’hui'), findsOneWidget);
      expect(find.text('Droit constitutionnel'), findsOneWidget);
      expect(find.text('1280 XP'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dit que la série est en jeu, pas seulement qu’elle existe', (
      tester,
    ) async {
      await _poser(
        tester,
        const EcranAccueil(),
        remplacements: [
          accueilProvider.overrideWith((_) async => donnees),
          profilProvider.overrideWith((_) async => _profil),
        ],
      );

      // Hier validé, aujourd'hui à 6/10 : il reste 4 questions à faire.
      expect(
        find.text('Encore 4 questions et ta série tient un jour de plus.'),
        findsOneWidget,
      );
    });

    testWidgets('montre une série rompue comme éteinte', (tester) async {
      final vieux = Profil(
        id: 'u1',
        prenom: 'Awa',
        xpTotal: 900,
        // La base garde 5, mais le dernier jour validé est ancien.
        serieCourante: 5,
        dernierJourValide: '2026-01-01',
        faculteId: 'f1',
        universiteNom: null,
        faculteNom: null,
        codeParrain: null,
      );

      await _poser(
        tester,
        const EcranAccueil(),
        remplacements: [
          accueilProvider.overrideWith(
            (_) async => DonneesAccueil(
              profil: vieux,
              semaine: _semaine,
              objectif: 10,
              matieres: const [],
            ),
          ),
          profilProvider.overrideWith((_) async => vieux),
        ],
      );

      // C'est le défaut § 4.1 du rapport : « 5 jours de flamme » sur une
      // série morte. Il ne doit pas traverser le portage.
      expect(find.text('Lance ta série'), findsOneWidget);
      expect(find.textContaining('jours de flamme'), findsNothing);
      expect(
        find.text(
          'Ta série s’est arrêtée. Une session aujourd’hui suffit à en '
          'relancer une.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('ne déborde pas à 320 px', (tester) async {
      await _poser(
        tester,
        const EcranAccueil(),
        taille: const Size(320, 640),
        remplacements: [
          accueilProvider.overrideWith((_) async => donnees),
          profilProvider.overrideWith((_) async => _profil),
        ],
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('liste des cours', () {
    testWidgets('épingle la démonstration et marque le traitement', (
      tester,
    ) async {
      await _poser(
        tester,
        const EcranReviser(),
        remplacements: [
          coursProvider.overrideWith((_) async => [_coursDemo, _coursEnCours]),
          profilProvider.overrideWith((_) async => _profil),
        ],
      );

      expect(find.text('Exemple'), findsOneWidget);
      expect(find.text('En préparation'), findsOneWidget);
      expect(find.text('3 chapitres · 20 questions · 12 fiches'), findsOneWidget);
      // 7 tentées sur 20 → 35 %.
      expect(find.text('35 %'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('propose le dépôt quand il n’y a aucun cours', (tester) async {
      await _poser(
        tester,
        const EcranReviser(),
        remplacements: [
          coursProvider.overrideWith((_) async => <ApercuCours>[]),
          profilProvider.overrideWith((_) async => _profil),
        ],
      );

      expect(find.text('Aucun cours déposé'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('page d’un cours', () {
    testWidgets('affiche la progression et les chapitres', (tester) async {
      await _poser(
        tester,
        const EcranCours(coursId: 'c1'),
        remplacements: [
          unCoursProvider('c1').overrideWith((_) async => _coursDemo),
          chapitresProvider('c1').overrideWith((_) async => _chapitres),
        ],
      );

      expect(find.text('Droit constitutionnel — introduction'), findsOneWidget);
      expect(find.text('7 questions sur 20'), findsOneWidget);
      expect(find.text('La notion de Constitution'), findsOneWidget);
      // Le chapitre faible est signalé, l'autre montre son taux.
      expect(find.text('À revoir'), findsOneWidget);
      expect(find.text('80 %'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('montre l’attente plutôt qu’une page vide', (tester) async {
      await _poser(
        tester,
        const EcranCours(coursId: 'c2'),
        remplacements: [
          unCoursProvider('c2').overrideWith((_) async => _coursEnCours),
          chapitresProvider('c2').overrideWith((_) async => <ApercuChapitre>[]),
        ],
      );

      // Un cours déposé n'a ni chapitre ni question : une page vide
      // laisserait croire à une panne.
      expect(find.text('Ton cours est en préparation'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('session de QCM', () {
    testWidgets('marque une bonne et une mauvaise réponse, sans vert', (
      tester,
    ) async {
      await _poser(
        tester,
        const EcranSession(coursId: 'c1'),
        remplacements: [
          questionsProvider('c1').overrideWith((_) async => _questions),
        ],
      );

      expect(find.text('Question 1 sur 2'), findsOneWidget);
      expect(find.text('Souvent posée'), findsOneWidget);

      // Choisir la mauvaise, puis valider.
      await _taper(tester, find.text('Le 2 décembre 1990'));
      await _taper(tester, find.text('Valider'));

      final options = tester.widgetList<OptionQcm>(find.byType(OptionQcm));
      expect(options.where((o) => o.etat == EtatOption.juste).length, 1);
      expect(options.where((o) => o.etat == EtatOption.fausse).length, 1);

      // Le retour immédiat donne la bonne réponse et l'explication.
      await tester.scrollUntilVisible(
        find.text('Ce n’est pas ça'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Ce n’est pas ça'), findsOneWidget);
      expect(
        find.textContaining('La bonne réponse : Le 11 décembre 1990'),
        findsOneWidget,
      );
      expect(find.textContaining('Le référendum a eu lieu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('enchaîne sur la question suivante', (tester) async {
      await _poser(
        tester,
        const EcranSession(coursId: 'c1'),
        remplacements: [
          questionsProvider('c1').overrideWith((_) async => _questions),
        ],
      );

      await _taper(tester, find.text('Le 11 décembre 1990'));
      await _taper(tester, find.text('Valider'));

      expect(find.text('C’est juste'), findsOneWidget);

      await _taper(tester, find.text('Question suivante'));

      expect(find.text('Question 2 sur 2'), findsOneWidget);
      // Dernière question : le bouton annonce le résultat.
      await _taper(
        tester,
        find.text('La Conférence des Forces Vives de la Nation'),
      );
      await _taper(tester, find.text('Valider'));

      await tester.scrollUntilVisible(
        find.text('Voir mon résultat'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Voir mon résultat'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dit quand il n’y a aucune question', (tester) async {
      await _poser(
        tester,
        const EcranSession(coursId: 'c1'),
        remplacements: [
          questionsProvider('c1').overrideWith((_) async => <QuestionQcm>[]),
        ],
      );

      expect(find.text('Aucune question à réviser'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
