import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` n'est pas dans le baril principal de flutter_riverpod.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/composants/option_qcm.dart';
import 'package:reviz/donnees/depots.dart';
import 'package:reviz/metier/acces.dart';
import 'package:reviz/donnees/modeles.dart';
import 'package:reviz/composants/bouton.dart';
import 'package:reviz/composants/podium.dart';
import 'package:reviz/ecrans/accueil.dart';
import 'package:reviz/ecrans/ajouter_cours.dart';
import 'package:reviz/ecrans/avatar.dart';
import 'package:reviz/metier/avatars.dart';
import 'package:reviz/ecrans/boutique.dart';
import 'package:reviz/ecrans/aide.dart';
import 'package:reviz/i18n/fr.dart';
import 'package:reviz/ecrans/carte.dart';
import 'package:reviz/ecrans/connexion.dart';
import 'package:reviz/ecrans/classement.dart';
import 'package:reviz/ecrans/correction.dart';
import 'package:reviz/ecrans/corriger.dart';
import 'package:reviz/ecrans/cours.dart';
import 'package:reviz/ecrans/fiches.dart';
import 'package:reviz/ecrans/gains.dart';
import 'package:reviz/ecrans/profil.dart';
import 'package:reviz/ecrans/reviser.dart';
import 'package:reviz/composants/bandeau.dart';
import 'package:reviz/donnees/version.dart';
import 'package:reviz/ecrans/mise_a_jour.dart';
import 'package:reviz/ecrans/suppression.dart';
import 'package:reviz/metier/version.dart';
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


// ----------------------------- Fixtures de la seconde moitié des écrans

const _fiches = [
  Fiche(
    id: 'f1',
    recto: 'Qu’est-ce qu’une Constitution rigide ?',
    verso:
        'Une Constitution dont la révision suit une procédure plus lourde '
        'que celle des lois ordinaires.',
    chapitre: 'La notion de Constitution',
  ),
  Fiche(
    id: 'f2',
    recto: 'Qui contrôle la constitutionnalité au Bénin ?',
    verso: 'La Cour constitutionnelle.',
    chapitre: 'Le contrôle de constitutionnalité',
  ),
];

const _packs = [
  PackBoutique(
    code: 'decouverte',
    libelle: 'Découverte',
    description: 'Pour voir ce que Reviz sait faire.',
    prixFcfa: 0,
    dureeJours: 3,
    correctionsIncluses: 1,
    plafondMatieres: 1,
  ),
  PackBoutique(
    code: 'controle',
    libelle: 'Contrôle',
    description: 'La semaine avant le devoir.',
    prixFcfa: 500,
    dureeJours: 7,
    correctionsIncluses: 3,
    plafondMatieres: 2,
  ),
];

/// Deux packs actifs en même temps.
///
/// C'est exactement le cas que l'écran web ratait : il lisait `.limit(1)` et
/// n'affichait donc que les corrections du premier abonnement trouvé
/// (rapport § 4.10). Ici on attend la **somme**, 3 + 2.
List<LigneAbonnement> get _deuxPacksActifs {
  final maintenant = DateTime.now().toUtc();
  return [
    LigneAbonnement(
      code: 'controle',
      debut: maintenant.subtract(const Duration(days: 1)),
      fin: maintenant.add(const Duration(days: 6)),
      correctionsRestantes: 3,
      plafondMatieres: 2,
    ),
    LigneAbonnement(
      code: 'decouverte',
      debut: maintenant.subtract(const Duration(days: 2)),
      fin: maintenant.add(const Duration(days: 1)),
      correctionsRestantes: 2,
      plafondMatieres: 1,
    ),
  ];
}

const _classement = [
  LigneClassement(rang: 1, prenom: 'Awa', avatar: null, xp: 4820, estMoi: false),
  LigneClassement(rang: 2, prenom: 'Koffi', avatar: null, xp: 4310, estMoi: true),
  LigneClassement(
    rang: 3,
    prenom: 'Mahouénan',
    avatar: null,
    xp: 3990,
    estMoi: false,
  ),
  LigneClassement(
    rang: 4,
    prenom: 'Sènankpon',
    avatar: null,
    xp: 3120,
    estMoi: false,
  ),
];


// ------------------------------------------ Fixtures de la correction

/// Une correction prête, de la forme réelle : rubrique en **tableau**, retour
/// avec ses deux listes, et un commentaire long qui doit s'ellipser.
final _corrigee = Correction(
  id: 'k1',
  statut: 'ready',
  note: 13.5,
  bareme: 20,
  lignes: const [
    LigneBareme(
      critere: 'Compréhension du sujet',
      points: 4,
      maximum: 5,
      commentaire: 'Tu as bien cerné la question posée.',
    ),
    LigneBareme(critere: 'Argumentation', points: 3, maximum: 5, commentaire: null),
    LigneBareme(
      critere: 'Exemples et références',
      points: 4.5,
      maximum: 6,
      commentaire:
          'Deux exemples pertinents, mais le troisième est hors sujet et la '
          'référence à la jurisprudence de 2019 n’est pas datée correctement, '
          'ce qui affaiblit l’ensemble du paragraphe.',
    ),
    LigneBareme(critere: 'Expression écrite', points: 2, maximum: 4, commentaire: null),
  ],
  retour: const RetourCorrection(
    resume: 'Copie solide, à resserrer sur l’expression.',
    pointsForts: ['Plan clair', 'Bonnes références'],
    aTravailler: ['Orthographe', 'Conclusion trop courte'],
  ),
  modele: 'deepseek-v4-flash-vision-exp',
  creeLe: null,
  motifIllisible: null,
);

Correction _correctionAuStatut(String statut, {String? motifIllisible}) =>
    Correction(
      id: 'k1',
      statut: statut,
      note: null,
      bareme: null,
      lignes: const [],
      retour: null,
      modele: null,
      creeLe: null,
      motifIllisible: motifIllisible,
    );

/// Un pack actif, avec du crédit — l'état que `etatAcces()` produit.
EtatAcces _accesAvecCredit(int corrections) => AccesActif(
  fin: DateTime.now().toUtc().add(const Duration(days: 5)),
  joursRestants: 5,
  correctionsRestantes: corrections,
  plafondMatieres: 2,
  packs: const [CodePack.controle],
);

// ----------------------------------------------------------------- Banc

Future<void> _poser(
  WidgetTester tester,
  Widget ecran, {
  List<Override> remplacements = const [],
  Size taille = const Size(375, 812),
  /// `false` quand l'écran porte une animation sans fin — une roue de
  /// chargement, des confettis, un minuteur de sondage. `pumpAndSettle`
  /// attendrait alors qu'elle s'arrête, ce qu'elle ne fait jamais, et le test
  /// expirerait au lieu d'échouer sur ce qu'il vérifie.
  bool stabiliser = true,
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

  if (stabiliser) {
    await tester.pumpAndSettle();
  } else {
    // Assez de trames pour que les fournisseurs se résolvent et que l'écran
    // se construise, sans attendre la fin d'une animation perpétuelle.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
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

      // Aucun chapitre encore : on dit ce qui se passe, pas « 0 chapitre ».
      expect(find.text('Lecture du document…'), findsOneWidget);

      // Et surtout, l'écran ne promet plus ce qu'il ne tient pas. L'ancien
      // texte disait « Tu peux fermer l'application : on te prévient dès que
      // c'est prêt » — faux deux fois : il n'y a pas de notification, et
      // c'est le fait de rester ici qui fait avancer la préparation.
      expect(find.textContaining('Reste sur cet écran'), findsOneWidget);
      expect(find.textContaining('on te prévient'), findsNothing);

      expect(tester.takeException(), isNull);
    });

    testWidgets('chiffre l’avancement dès qu’il y en a', (tester) async {
      // Un sablier immobile pendant deux minutes se lit comme une panne.
      const avance = ApercuCours(
        id: 'c3',
        titre: 'Droit administratif — chapitre en cours',
        statut: 'processing',
        demo: false,
        matiereNom: 'Droit administratif',
        dateExamen: null,
        nbChapitres: 3,
        nbQuestions: 12,
        nbFiches: 8,
        nbTentees: 0,
      );

      await _poser(
        tester,
        const EcranCours(coursId: 'c3'),
        remplacements: [
          unCoursProvider('c3').overrideWith((_) async => avance),
          chapitresProvider('c3').overrideWith((_) async => <ApercuChapitre>[]),
        ],
      );

      expect(find.text('3 chapitres · 12 questions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('accorde le singulier', (tester) async {
      const un = ApercuCours(
        id: 'c4',
        titre: 'Un seul chapitre',
        statut: 'processing',
        demo: false,
        matiereNom: 'Droit',
        dateExamen: null,
        nbChapitres: 1,
        nbQuestions: 1,
        nbFiches: 0,
        nbTentees: 0,
      );

      await _poser(
        tester,
        const EcranCours(coursId: 'c4'),
        remplacements: [
          unCoursProvider('c4').overrideWith((_) async => un),
          chapitresProvider('c4').overrideWith((_) async => <ApercuChapitre>[]),
        ],
      );

      expect(find.text('1 chapitre · 1 question'), findsOneWidget);
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

  group('fiches', () {
    testWidgets('retourne la fiche et avance dans le paquet', (tester) async {
      await _poser(
        tester,
        const EcranFiches(coursId: 'c1'),
        remplacements: [fichesProvider('c1').overrideWith((_) async => _fiches)],
      );

      expect(find.text('Fiche 1 sur 2'), findsOneWidget);
      expect(
        find.text('Qu’est-ce qu’une Constitution rigide ?'),
        findsOneWidget,
      );
      // La réponse n'est pas visible avant le retournement : sans cela,
      // l'effort de rappel disparaît et la fiche ne sert plus à rien.
      expect(find.textContaining('procédure plus lourde'), findsNothing);

      await tester.tap(find.text('Qu’est-ce qu’une Constitution rigide ?'));
      await tester.pumpAndSettle();

      expect(find.textContaining('procédure plus lourde'), findsOneWidget);

      await _taper(tester, find.text('Suivante'));

      expect(find.text('Fiche 2 sur 2'), findsOneWidget);
      // La fiche suivante arrive côté question, pas côté réponse.
      expect(find.text('La Cour constitutionnelle.'), findsNothing);
      // Dernière fiche : plus de « Suivante », mais de quoi recommencer.
      expect(find.text('Suivante'), findsNothing);
      expect(find.text('Recommencer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dit qu’il n’y a aucune fiche', (tester) async {
      await _poser(
        tester,
        const EcranFiches(coursId: 'c1'),
        remplacements: [
          fichesProvider('c1').overrideWith((_) async => <Fiche>[]),
        ],
      );

      expect(find.text('Aucune fiche'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ne déborde pas à 320 px', (tester) async {
      await _poser(
        tester,
        const EcranFiches(coursId: 'c1'),
        taille: const Size(320, 640),
        remplacements: [fichesProvider('c1').overrideWith((_) async => _fiches)],
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('boutique', () {
    testWidgets('somme les corrections de tous les packs actifs', (
      tester,
    ) async {
      await _poser(
        tester,
        const EcranBoutique(),
        remplacements: [
          boutiqueProvider.overrideWith(
            (_) async =>
                DonneesBoutique(packs: _packs, abonnements: _deuxPacksActifs),
          ),
        ],
      );

      // 3 + 2, et non 3 : le défaut § 4.10 ne doit pas traverser le portage.
      expect(find.text('5 corrections restantes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dit que Découverte est déjà utilisée', (tester) async {
      await _poser(
        tester,
        const EcranBoutique(),
        remplacements: [
          boutiqueProvider.overrideWith(
            (_) async =>
                DonneesBoutique(packs: _packs, abonnements: _deuxPacksActifs),
          ),
        ],
      );

      // Avant le clic, et non après le refus du serveur.
      expect(find.text('Découverte déjà utilisée'), findsOneWidget);
      expect(find.text('Activer gratuitement'), findsNothing);
    });

    testWidgets('propose Découverte quand rien n’a été acheté', (tester) async {
      await _poser(
        tester,
        const EcranBoutique(),
        remplacements: [
          boutiqueProvider.overrideWith(
            (_) async => const DonneesBoutique(packs: _packs, abonnements: []),
          ),
        ],
      );

      expect(find.text('Activer gratuitement'), findsOneWidget);
      expect(find.text('Gratuit'), findsOneWidget);
      expect(find.text('500 F'), findsOneWidget);
      // Aucun pack acheté n'est pas un pack expiré.
      expect(find.text('Ton pack est arrivé à terme'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('annonce la fin d’accès sans promettre de reconduction', (
      tester,
    ) async {
      final vieux = DateTime.now().toUtc().subtract(const Duration(days: 30));

      await _poser(
        tester,
        const EcranBoutique(),
        remplacements: [
          boutiqueProvider.overrideWith(
            (_) async => DonneesBoutique(
              packs: _packs,
              abonnements: [
                LigneAbonnement(
                  code: 'controle',
                  debut: vieux,
                  fin: vieux.add(const Duration(days: 7)),
                  correctionsRestantes: 0,
                  plafondMatieres: 2,
                ),
              ],
            ),
          ),
        ],
      );

      expect(find.text('Ton pack est arrivé à terme'), findsOneWidget);

      // Le rappel est en pied de liste, donc sous le pli : une `ListView`
      // construit paresseusement, et `find` ne voit pas ce qui n'est pas
      // encore dans l'arbre.
      final rappel = find.text(
        'Aucun prélèvement automatique. À la fin de la période, l’accès '
        's’arrête, tout simplement.',
      );
      await tester.scrollUntilVisible(
        rappel,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(rappel, findsOneWidget);
    });
  });

  group('gains', () {
    testWidgets('dit ce qui reste avant le seuil, et n’ouvre pas le retrait', (
      tester,
    ) async {
      await _poser(
        tester,
        const EcranGains(),
        remplacements: [
          gainsProvider.overrideWith(
            (_) async => const DonneesGains(
              soldeFcfa: 1800,
              codeParrain: 'ABC123',
              filleuls: 2,
              filleulsPayants: 1,
            ),
          ),
          profilProvider.overrideWith((_) async => _profil),
        ],
      );

      expect(find.text('1800 F'), findsOneWidget);
      expect(
        find.text('Encore 1200 F avant de pouvoir retirer.'),
        findsOneWidget,
      );

      // Le bouton existe mais reste inerte : le seuil de 3 000 F est une
      // règle métier, pas une erreur à découvrir après le clic.
      final bouton = tester.widget<Bouton>(
        find.widgetWithText(Bouton, 'Demander un retrait'),
      );
      expect(bouton.onTap, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ouvre la feuille de retrait au-dessus du seuil', (
      tester,
    ) async {
      await _poser(
        tester,
        const EcranGains(),
        remplacements: [
          gainsProvider.overrideWith(
            (_) async => const DonneesGains(
              soldeFcfa: 5200,
              codeParrain: 'ABC123',
              filleuls: 3,
              filleulsPayants: 2,
            ),
          ),
          profilProvider.overrideWith((_) async => _profil),
        ],
      );

      expect(find.text('Tu peux demander un retrait.'), findsOneWidget);
      expect(find.text('2 filleuls actifs'), findsOneWidget);

      await _taper(tester, find.text('Demander un retrait'));

      expect(find.text('Retirer mes gains'), findsOneWidget);
      // Le solde entier est proposé : c'est le retrait le plus probable.
      expect(find.text('5200'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('refuse un numéro qui n’en est pas un', (tester) async {
      await _poser(
        tester,
        const EcranGains(),
        remplacements: [
          gainsProvider.overrideWith(
            (_) async => const DonneesGains(
              soldeFcfa: 5200,
              codeParrain: 'ABC123',
              filleuls: 0,
              filleulsPayants: 0,
            ),
          ),
          profilProvider.overrideWith((_) async => _profil),
        ],
      );

      await _taper(tester, find.text('Demander un retrait'));
      await _taper(tester, find.text('Envoyer la demande'));

      // Aucun appel réseau n'est parti : la vérification locale parle
      // d'abord, et en français.
      expect(
        find.text('Ce numéro ne ressemble pas à un numéro.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('ne déborde pas à 320 px', (tester) async {
      await _poser(
        tester,
        const EcranGains(),
        taille: const Size(320, 640),
        remplacements: [
          gainsProvider.overrideWith(
            (_) async => const DonneesGains(
              soldeFcfa: 5200,
              codeParrain: 'ABC123',
              filleuls: 3,
              filleulsPayants: 2,
            ),
          ),
          profilProvider.overrideWith((_) async => _profil),
        ],
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('classement', () {
    testWidgets('dresse le podium et marque sa propre ligne', (tester) async {
      await _poser(
        tester,
        const EcranClassement(),
        remplacements: [
          classementProvider.overrideWith(
            (_) async =>
                const DonneesClassement(lignes: _classement, monRang: 2),
          ),
        ],
      );

      expect(find.text('Awa'), findsOneWidget);
      // Sa propre ligne dit « Toi » et non son prénom.
      expect(find.text('Toi'), findsOneWidget);
      expect(find.text('Koffi'), findsNothing);
      expect(find.text('Tu es 2ᵉ de ta faculté'), findsOneWidget);
      // Le 4ᵉ est dans la liste, pas sur le podium.
      expect(find.text('Sènankpon'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('invite à jouer quand on n’est pas classé', (tester) async {
      await _poser(
        tester,
        const EcranClassement(),
        remplacements: [
          classementProvider.overrideWith(
            (_) async =>
                const DonneesClassement(lignes: _classement, monRang: null),
          ),
        ],
      );

      expect(
        find.text('Réponds à une question pour entrer au classement'),
        findsOneWidget,
      );
    });

    testWidgets('dit que la faculté est vide plutôt que rien', (tester) async {
      await _poser(
        tester,
        const EcranClassement(),
        remplacements: [
          classementProvider.overrideWith(
            (_) async => const DonneesClassement(lignes: [], monRang: null),
          ),
        ],
      );

      expect(find.text('Personne n’est encore classé'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tient un podium incomplet, et 320 px', (tester) async {
      await _poser(
        tester,
        const EcranClassement(),
        taille: const Size(320, 640),
        remplacements: [
          classementProvider.overrideWith(
            // Une faculté qui démarre : un seul étudiant classé. Les deux
            // marches manquantes ne doivent pas casser la rangée.
            (_) async =>
                DonneesClassement(lignes: [_classement.first], monRang: 1),
          ),
        ],
      );

      expect(find.text('Awa'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('profil', () {
    testWidgets('montre l’identité et les chiffres, et rien de décoratif', (
      tester,
    ) async {
      await _poser(
        tester,
        const EcranProfil(),
        remplacements: [profilProvider.overrideWith((_) async => _profil)],
      );

      expect(find.text('Awa'), findsOneWidget);
      expect(find.text('FADESP'), findsOneWidget);
      expect(find.text('1280 XP gagnés'), findsOneWidget);

      // Les entrées mortes de l'écran web ne sont pas reprises : pas de
      // « Vider le cache » sans effet, pas d'interrupteur WhatsApp figé, et
      // aucun lien vers une route inexistante (rapport § 4.15).
      expect(find.textContaining('Vider le cache'), findsNothing);
      expect(find.textContaining('WhatsApp'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ne prétend pas qu’un compte non vérifié l’est', (
      tester,
    ) async {
      await _poser(
        tester,
        const EcranProfil(),
        remplacements: [profilProvider.overrideWith((_) async => _profil)],
      );

      // La carte étudiante est la seule barrière « un compte par personne »
      // depuis que le téléphone est facultatif : l'écran doit le dire.
      expect(find.text('Compte non vérifié'), findsOneWidget);
      expect(find.text('Compte vérifié'), findsNothing);
    });

    testWidgets('reconnaît une vérification acquise', (tester) async {
      final verifie = Profil(
        id: 'u1',
        prenom: 'Awa',
        xpTotal: 1280,
        serieCourante: 4,
        dernierJourValide: _hier,
        faculteId: 'f1',
        universiteNom: 'UAC',
        faculteNom: 'FADESP',
        codeParrain: 'ABC123',
        statutVerification: 'verified',
        anneeEtude: 2,
      );

      await _poser(
        tester,
        const EcranProfil(),
        remplacements: [profilProvider.overrideWith((_) async => verifie)],
      );

      expect(find.text('Compte vérifié'), findsOneWidget);
      expect(find.text('UAC · 2e année'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ne déborde pas à 320 px', (tester) async {
      await _poser(
        tester,
        const EcranProfil(),
        taille: const Size(320, 640),
        remplacements: [profilProvider.overrideWith((_) async => _profil)],
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('dépôt de copie', () {
    testWidgets('annonce le crédit et propose la photo', (tester) async {
      await _poser(
        tester,
        const EcranCorriger(),
        remplacements: [
          profilProvider.overrideWith((_) async => _profil),
          accesCorrectionProvider.overrideWith(
            (_) async => _accesAvecCredit(3),
          ),
          correctionsProvider.overrideWith((_) async => <Correction>[]),
        ],
      );

      expect(
        find.text('3 corrections restantes dans ton pack'),
        findsOneWidget,
      );
      expect(find.text('Prendre ma copie en photo'), findsOneWidget);
      expect(find.text('Aucune copie corrigée'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dit lequel des quatre refus s’applique', (tester) async {
      // Un seul « accès refusé » ne dirait pas quoi faire. Ici : le crédit est
      // épuisé, donc il faut un pack, pas attendre demain.
      await _poser(
        tester,
        const EcranCorriger(),
        remplacements: [
          profilProvider.overrideWith((_) async => _profil),
          accesCorrectionProvider.overrideWith(
            (_) async => _accesAvecCredit(0),
          ),
          correctionsProvider.overrideWith((_) async => <Correction>[]),
        ],
      );

      expect(
        find.text('Tu n’as plus de correction dans ton pack.'),
        findsOneWidget,
      );
      expect(find.text('Voir les packs'), findsOneWidget);
      // Pas de bouton photo : le refus est dit avant le clic.
      expect(find.text('Prendre ma copie en photo'), findsNothing);
    });

    testWidgets('distingue un pack expiré d’un pack absent', (tester) async {
      await _poser(
        tester,
        const EcranCorriger(),
        remplacements: [
          profilProvider.overrideWith((_) async => _profil),
          accesCorrectionProvider.overrideWith(
            (_) async => AccesExpire(
              DateTime.now().toUtc().subtract(const Duration(days: 3)),
            ),
          ),
          correctionsProvider.overrideWith((_) async => <Correction>[]),
        ],
      );

      expect(
        find.text('Ton pack est arrivé à terme. Réactive-le pour continuer.'),
        findsOneWidget,
      );
    });

    testWidgets('montre l’historique, note comprise', (tester) async {
      await _poser(
        tester,
        const EcranCorriger(),
        remplacements: [
          profilProvider.overrideWith((_) async => _profil),
          accesCorrectionProvider.overrideWith(
            (_) async => _accesAvecCredit(2),
          ),
          correctionsProvider.overrideWith(
            (_) async => [_corrigee, _correctionAuStatut('processing')],
          ),
        ],
      );

      expect(find.text('13,5 / 20'), findsOneWidget);
      expect(find.text('En cours de correction'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ne déborde pas à 320 px', (tester) async {
      await _poser(
        tester,
        const EcranCorriger(),
        taille: const Size(320, 640),
        remplacements: [
          profilProvider.overrideWith((_) async => _profil),
          accesCorrectionProvider.overrideWith(
            (_) async => _accesAvecCredit(2),
          ),
          correctionsProvider.overrideWith((_) async => [_corrigee]),
        ],
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('résultat de correction', () {
    testWidgets('affiche la note, le barème et le retour, sans vert', (
      tester,
    ) async {
      await _poser(
        tester,
        const EcranCorrection(correctionId: 'k1'),
        stabiliser: false,
        remplacements: [
          correctionProvider('k1').overrideWith((_) async => _corrigee),
        ],
      );

      expect(find.text('13,5 / 20'), findsOneWidget);
      expect(find.text('Le barème'), findsOneWidget);
      expect(find.text('Compréhension du sujet'), findsOneWidget);
      // Une ligne à 4,5/6 affiche ses deux nombres, pas un pourcentage.
      expect(find.text('4,5 / 6'), findsOneWidget);
      // 13,5/20 = 67 %, au-dessus du seuil : on fête.
      expect(find.text('Beau travail'), findsOneWidget);

      // Le retour rédigé est sous le pli : une `ListView` construit
      // paresseusement, `find` ne voit pas ce qui n'est pas dans l'arbre.
      await tester.scrollUntilVisible(
        find.text('Plan clair'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Plan clair'), findsOneWidget);
      expect(find.text('Orthographe'), findsOneWidget);

      // Aucun vert nulle part : la réussite se célèbre en jaune, et une
      // mauvaise note en orange ou en rouge (docs/DESIGN.md § 11).
      final icones = tester.widgetList<Icon>(find.byType(Icon));
      for (final i in icones) {
        expect(i.color, isNot(const Color(0xFF22C55E)));
        expect(i.color, isNot(const Color(0xFFEF4444)));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('encourage en dessous du seuil, sans fêter', (tester) async {
      final faible = Correction(
        id: 'k1',
        statut: 'ready',
        note: 6,
        bareme: 20,
        lignes: const [
          LigneBareme(
            critere: 'Argumentation',
            points: 2,
            maximum: 8,
            commentaire: null,
          ),
        ],
        retour: const RetourCorrection(
          resume: 'Il faut reprendre la méthode.',
          pointsForts: [],
          aTravailler: ['Construire un plan'],
        ),
        modele: 'glm-5.3',
        creeLe: null,
        motifIllisible: null,
      );

      await _poser(
        tester,
        const EcranCorrection(correctionId: 'k1'),
        remplacements: [
          correctionProvider('k1').overrideWith((_) async => faible),
        ],
      );

      expect(find.text('6 / 20'), findsOneWidget);
      expect(find.text('Il faut reprendre ça'), findsOneWidget);
      expect(find.text('Beau travail'), findsNothing);
      // Aucune liste de points forts : la carte ne doit pas afficher son
      // titre pour rien.
      expect(find.text('Ce qui va'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sépare la copie illisible de l’échec', (tester) async {
      await _poser(
        tester,
        const EcranCorrection(correctionId: 'k1'),
        remplacements: [
          correctionProvider('k1').overrideWith(
            (_) async => _correctionAuStatut(
              'failed',
              motifIllisible:
                  'La photo est trop floue pour lire ton écriture.',
            ),
          ),
        ],
      );

      // Rien n'a planté : l'étudiant n'a qu'à reprendre la photo.
      expect(find.text('On n’arrive pas à lire ta copie'), findsOneWidget);
      expect(
        find.text('La photo est trop floue pour lire ton écriture.'),
        findsOneWidget,
      );
      expect(find.text('La correction n’a pas abouti'), findsNothing);
      expect(find.text('Reprendre la photo'), findsOneWidget);
    });

    testWidgets('annonce un échec, et que rien n’a été décompté', (
      tester,
    ) async {
      await _poser(
        tester,
        const EcranCorrection(correctionId: 'k1'),
        remplacements: [
          correctionProvider('k1').overrideWith(
            (_) async => _correctionAuStatut('failed'),
          ),
        ],
      );

      expect(find.text('La correction n’a pas abouti'), findsOneWidget);
      expect(find.textContaining('Rien ne t’a été décompté'), findsOneWidget);
    });

    testWidgets('patiente pendant le traitement', (tester) async {
      await _poser(
        tester,
        const EcranCorrection(correctionId: 'k1'),
        stabiliser: false,
        remplacements: [
          correctionProvider('k1').overrideWith(
            (_) async => _correctionAuStatut('processing'),
          ),
        ],
      );

      expect(find.text('On corrige ta copie'), findsOneWidget);
      // L'étudiant peut fermer : le résultat n'est pas perdu.
      expect(find.textContaining('on garde le résultat'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ne déborde pas à 320 px', (tester) async {
      await _poser(
        tester,
        const EcranCorrection(correctionId: 'k1'),
        taille: const Size(320, 640),
        stabiliser: false,
        remplacements: [
          correctionProvider('k1').overrideWith((_) async => _corrigee),
        ],
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('suppression de compte', () {
    DonneesGains gainsAvec(int solde) => DonneesGains(
      soldeFcfa: solde,
      codeParrain: 'ABC123',
      filleuls: 0,
      filleulsPayants: 0,
    );

    testWidgets('dit ce qui part **et** ce qui reste', (tester) async {
      await _poser(
        tester,
        const EcranSuppression(),
        remplacements: [
          profilProvider.overrideWith((_) async => _profil),
          gainsProvider.overrideWith((_) async => gainsAvec(0)),
        ],
      );

      expect(find.text('Ce qui est effacé'), findsOneWidget);
      expect(find.text('Tes cours déposés, avec leurs questions et leurs fiches'), findsOneWidget);

      // La seconde moitié compte autant : cacher que la comptabilité reste
      // serait mentir sur ce que fait le bouton.
      expect(find.text('Ce qui reste, sans ton nom'), findsOneWidget);
      expect(
        find.text('Tes paiements et les lignes de ton portefeuille'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('prévient quand un solde reste à retirer', (tester) async {
      await _poser(
        tester,
        const EcranSuppression(),
        remplacements: [
          profilProvider.overrideWith((_) async => _profil),
          gainsProvider.overrideWith((_) async => gainsAvec(4200)),
        ],
      );

      // Après l'anonymisation, plus personne ne sait à qui verser.
      expect(find.text('Tu as encore un solde'), findsOneWidget);
      expect(find.textContaining('4200 F'), findsOneWidget);
      expect(find.text('Voir mes gains'), findsOneWidget);
    });

    testWidgets('ne prévient pas sous le seuil de retrait', (tester) async {
      // 1 200 F ne sont pas retirables : annoncer « demande ton retrait »
      // enverrait l'étudiant vers un bouton inerte.
      await _poser(
        tester,
        const EcranSuppression(),
        remplacements: [
          profilProvider.overrideWith((_) async => _profil),
          gainsProvider.overrideWith((_) async => gainsAvec(1200)),
        ],
      );

      expect(find.text('Tu as encore un solde'), findsNothing);
    });

    testWidgets('exige le prénom, et refuse autre chose', (tester) async {
      await _poser(
        tester,
        const EcranSuppression(),
        remplacements: [
          profilProvider.overrideWith((_) async => _profil),
          gainsProvider.overrideWith((_) async => gainsAvec(0)),
        ],
      );

      // Le champ est sous le pli : on l'amène à l'écran avant d'y écrire.
      await tester.scrollUntilVisible(
        find.text('Pour confirmer, écris ton prénom'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Écris exactement « Awa ».'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'oui');
      await _taper(tester, find.text('Supprimer définitivement'));

      // Aucun appel réseau n'est parti : la vérification locale parle
      // d'abord.
      expect(find.text('Ce n’est pas ton prénom.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('propose un mot de secours sans prénom', (tester) async {
      // Le prénom est facultatif à l'inscription : un compte sans prénom ne
      // doit pas se retrouver avec un champ impossible à remplir.
      final sansPrenom = Profil(
        id: 'u1',
        prenom: null,
        xpTotal: 0,
        serieCourante: 0,
        dernierJourValide: null,
        faculteId: 'f1',
        universiteNom: null,
        faculteNom: null,
        codeParrain: null,
      );

      await _poser(
        tester,
        const EcranSuppression(),
        remplacements: [
          profilProvider.overrideWith((_) async => sansPrenom),
          gainsProvider.overrideWith((_) async => gainsAvec(0)),
        ],
      );

      final aide = find.text(
        'Ton compte n’a pas de prénom. Écris SUPPRIMER pour confirmer.',
      );
      await tester.scrollUntilVisible(
        aide,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(aide, findsOneWidget);
    });

    testWidgets('ne déborde pas à 320 px', (tester) async {
      await _poser(
        tester,
        const EcranSuppression(),
        taille: const Size(320, 640),
        remplacements: [
          profilProvider.overrideWith((_) async => _profil),
          gainsProvider.overrideWith((_) async => gainsAvec(4200)),
        ],
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('profil, entrée de suppression', () {
    testWidgets('mène à la suppression, en dernier et en rouge', (
      tester,
    ) async {
      await _poser(
        tester,
        const EcranProfil(),
        remplacements: [profilProvider.overrideWith((_) async => _profil)],
      );

      final entree = find.text('Supprimer mon compte');
      await tester.scrollUntilVisible(
        entree,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(entree, findsOneWidget);

      // La déconnexion n'est plus l'action rouge : la suppression l'est.
      final deconnexion = tester.widget<Bouton>(
        find.widgetWithText(Bouton, 'Me déconnecter'),
      );
      expect(deconnexion.variante, VarianteBouton.secondaire);
    });
  });

  group('mise à jour exigée', () {
    const seuils = VersionDistante(
      minimum: '2.0.0',
      derniere: '2.3.0',
      notes: 'Correction de copie, et un classement qui voit sa faculté.',
      lien: 'https://reviz-eight.vercel.app/app',
    );

    testWidgets('dit quoi faire, et quelle version est installée', (
      tester,
    ) async {
      await _poser(
        tester,
        const EcranMiseAJour(
          etat: EtatMiseAJour(
            exigence: ExigenceVersion.exigee,
            locale: '1.4.2',
            distante: seuils,
          ),
        ),
      );

      expect(find.text('Il faut mettre Reviz à jour'), findsOneWidget);
      expect(find.text('Télécharger'), findsOneWidget);
      // La version installée sert au support : « quelle version as-tu ? » a
      // une réponse à l'écran.
      expect(find.text('Version installée : 1.4.2'), findsOneWidget);
      expect(
        find.textContaining('Correction de copie'),
        findsOneWidget,
        reason: 'les notes de version expliquent pourquoi mettre à jour',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('ne propose pas de télécharger pendant un entretien', (
      tester,
    ) async {
      // Un étudiant déjà à jour ne doit pas être envoyé télécharger une
      // version qu'il a : la maintenance n'est pas un problème de version.
      await _poser(
        tester,
        const EcranMiseAJour(
          etat: EtatMiseAJour(
            exigence: ExigenceVersion.maintenance,
            locale: '2.3.0',
            distante: VersionDistante(
              minimum: '2.0.0',
              derniere: '2.3.0',
              maintenance: true,
            ),
          ),
        ),
      );

      expect(find.text('Reviz est en entretien'), findsOneWidget);
      expect(find.textContaining('rien de ce que tu as fait'), findsOneWidget);
      expect(find.text('Télécharger'), findsNothing);
      // Il reste un moyen de sortir sans redémarrer.
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('ne déborde pas à 320 px', (tester) async {
      await _poser(
        tester,
        const EcranMiseAJour(
          etat: EtatMiseAJour(
            exigence: ExigenceVersion.exigee,
            locale: '1.0.0',
            distante: seuils,
          ),
        ),
        taille: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('bandeaux transversaux', () {
    testWidgets('le hors-ligne dit que les QCM chargés restent jouables', (
      tester,
    ) async {
      await _poser(
        tester,
        const Scaffold(body: BandeauHorsLigne()),
      );

      expect(find.text('Pas de connexion'), findsOneWidget);
      // Un bandeau et non une page : couper l'écran serait pire que le
      // manque de réseau.
      expect(
        find.textContaining('restent jouables'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('la version conseillée propose, sans bloquer', (tester) async {
      var demande = 0;

      await _poser(
        tester,
        Scaffold(
          body: BandeauVersion(onTelecharger: () => demande++),
        ),
      );

      expect(find.text('Une nouvelle version est là'), findsOneWidget);
      await tester.tap(find.text('Télécharger'));
      await tester.pumpAndSettle();
      expect(demande, 1);
    });

    testWidgets('les deux tiennent à 320 px', (tester) async {
      await _poser(
        tester,
        Scaffold(
          body: Column(
            children: [
              const BandeauHorsLigne(),
              BandeauVersion(onTelecharger: () {}),
            ],
          ),
        ),
        taille: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('choix de l’avatar', () {
    Profil profilAvec(String? cle) => Profil(
      id: 'u1',
      prenom: 'Awa',
      xpTotal: 100,
      serieCourante: 1,
      dernierJourValide: _hier,
      faculteId: 'f1',
      universiteNom: 'UAC',
      faculteNom: 'FADESP',
      codeParrain: 'ABC123',
      avatar: cle,
    );

    testWidgets('montre les douze couleurs et un aperçu', (tester) async {
      await _poser(
        tester,
        const EcranAvatar(),
        remplacements: [
          profilProvider.overrideWith((_) async => profilAvec('ton-05')),
        ],
      );

      // Douze pastilles, plus l'aperçu en grand.
      expect(find.byType(AvatarInitiale), findsNWidgets(avatars.length + 1));
      // L'initiale du prénom, pas un rond vide ni deux lettres découpées
      // dans la clé comme le faisait l'écran web.
      expect(find.text('A'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('n’enregistre rien tant qu’on n’a rien changé', (tester) async {
      await _poser(
        tester,
        const EcranAvatar(),
        remplacements: [
          profilProvider.overrideWith((_) async => profilAvec('ton-05')),
        ],
      );

      final bouton = find.widgetWithText(Bouton, 'Garder celui-là');
      await tester.scrollUntilVisible(
        bouton,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<Bouton>(bouton).onTap, isNull);
    });

    testWidgets('s’active dès qu’une autre couleur est choisie', (
      tester,
    ) async {
      await _poser(
        tester,
        const EcranAvatar(),
        remplacements: [
          profilProvider.overrideWith((_) async => profilAvec('ton-05')),
        ],
      );

      await _taper(tester, find.byKey(const ValueKey('avatar-ton-09')));

      final bouton = find.widgetWithText(Bouton, 'Garder celui-là');
      await tester.scrollUntilVisible(
        bouton,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<Bouton>(bouton).onTap, isNotNull);
    });

    testWidgets('retombe sur une tête pour un profil sans avatar', (
      tester,
    ) async {
      // Et pour une clé de l'ancien écran web, qui ne fait pas partie des
      // douze : un compte existant ne doit pas se retrouver sans visage.
      for (final cle in [null, 'avatar-1-garcon-sourire']) {
        await _poser(
          tester,
          const EcranAvatar(),
          remplacements: [
            profilProvider.overrideWith((_) async => profilAvec(cle)),
          ],
        );

        expect(find.byType(AvatarInitiale), findsNWidgets(avatars.length + 1));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('ne déborde pas à 320 px', (tester) async {
      // La grille passe de quatre à trois colonnes en dessous de 340 px.
      await _poser(
        tester,
        const EcranAvatar(),
        taille: const Size(320, 640),
        remplacements: [
          profilProvider.overrideWith((_) async => profilAvec('ton-01')),
        ],
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('couleur d’avatar au classement', () {
    testWidgets('deux étudiants aux clés différentes n’ont pas le même fond', (
      tester,
    ) async {
      // La couleur était figée sur `jauneDoux` : tout le monde avait la même
      // tête, et la colonne `avatar_key` ne servait à rien.
      await _poser(
        tester,
        const EcranClassement(),
        remplacements: [
          classementProvider.overrideWith(
            (_) async => const DonneesClassement(
              lignes: [
                LigneClassement(
                  rang: 1,
                  prenom: 'Awa',
                  avatar: 'ton-01',
                  xp: 400,
                  estMoi: false,
                ),
                LigneClassement(
                  rang: 2,
                  prenom: 'Koffi',
                  avatar: 'ton-05',
                  xp: 300,
                  estMoi: false,
                ),
              ],
              monRang: 2,
            ),
          ),
        ],
      );

      final rendus = tester
          .widgetList<AvatarInitiale>(find.byType(AvatarInitiale))
          .map((a) => avatarDe(a.cleAvatar).fond.toARGB32())
          .toSet();

      expect(rendus.length, greaterThan(1));
      expect(tester.takeException(), isNull);
    });
  });

  group('dépôt d’un cours', () {
    const matieres = [
      Matiere(id: 'm1', nom: 'Droit constitutionnel'),
      Matiere(id: 'm2', nom: 'Droit administratif'),
    ];

    testWidgets('demande d’abord le fichier, et rien d’autre', (tester) async {
      await _poser(
        tester,
        const EcranAjouterCours(),
        remplacements: [
          profilProvider.overrideWith((_) async => _profil),
          matieresProvider.overrideWith((_) async => matieres),
        ],
      );

      expect(find.text('Choisir un fichier'), findsOneWidget);
      expect(find.text('Prendre en photo'), findsOneWidget);
      expect(
        find.text('PDF, Word (.docx) ou photo, 25 Mo au plus.'),
        findsOneWidget,
      );

      // Tant qu'aucun fichier n'est choisi, le titre et la matière n'ont rien
      // à décrire : les demander tout de suite serait un formulaire vide.
      expect(find.text('Le titre du cours'), findsNothing);
      expect(find.text('La matière'), findsNothing);

      // Et le bouton de dépôt est inerte.
      final bouton = tester.widget<Bouton>(
        find.widgetWithText(Bouton, 'Déposer ce cours'),
      );
      expect(bouton.onTap, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dit quoi faire quand la faculté n’a aucune matière', (
      tester,
    ) async {
      await _poser(
        tester,
        const EcranAjouterCours(),
        remplacements: [
          profilProvider.overrideWith((_) async => _profil),
          matieresProvider.overrideWith((_) async => <Matiere>[]),
        ],
      );

      // Le formulaire n'apparaît qu'avec un fichier ; l'absence de matière
      // se découvre donc à ce moment-là. Ici on vérifie au moins que l'écran
      // se rend sans exception dans cet état.
      expect(tester.takeException(), isNull);
    });

    testWidgets('ne déborde pas à 320 px', (tester) async {
      await _poser(
        tester,
        const EcranAjouterCours(),
        taille: const Size(320, 640),
        remplacements: [
          profilProvider.overrideWith((_) async => _profil),
          matieresProvider.overrideWith((_) async => matieres),
        ],
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('titre suggéré depuis le nom du fichier', () {
    test('rend lisible un nom de gestionnaire de fichiers', () {
      // Ce que rend Android : « cours_droit-const_L1.pdf ».
      const doc = DocumentChoisi(
        nom: 'cours_droit-const_L1.pdf',
        octets: [],
        typeMime: 'application/pdf',
      );
      expect(doc.titreSuggere, 'cours droit const L1');
    });

    test('retire l’extension, pas le reste du nom', () {
      const doc = DocumentChoisi(
        nom: 'Introduction à l’étude du droit.docx',
        octets: [],
        typeMime: 'application/pdf',
      );
      expect(doc.titreSuggere, 'Introduction à l’étude du droit');
    });

    test('tient un nom sans extension', () {
      const doc = DocumentChoisi(
        nom: 'polycopié',
        octets: [],
        typeMime: 'application/pdf',
      );
      expect(doc.titreSuggere, 'polycopié');
    });

    test('ne rend jamais une chaîne vide', () {
      // Un nom qui n'est qu'une extension — « .pdf » — laisserait un champ
      // vide, donc un cours sans titre dans la liste.
      const doc = DocumentChoisi(
        nom: '.pdf',
        octets: [],
        typeMime: 'application/pdf',
      );
      expect(doc.titreSuggere.trim(), isNotEmpty);
    });
  });

  group('l’écran Réviser mène au dépôt', () {
    testWidgets('le bouton n’annonce plus « bientôt »', (tester) async {
      await _poser(
        tester,
        const EcranReviser(),
        remplacements: [
          coursProvider.overrideWith((_) async => [_coursDemo]),
          profilProvider.overrideWith((_) async => _profil),
        ],
      );

      final bouton = tester.widget<Bouton>(
        find.widgetWithText(Bouton, 'Ajouter un cours'),
      );
      expect(bouton.onTap, isNotNull);
      // La mention « Bientôt disponible » disparaît : elle disait vrai tant
      // que les traitements IA n'existaient pas.
      expect(find.text('Bientôt disponible'), findsNothing);
    });

    testWidgets('l’état vide propose le dépôt', (tester) async {
      await _poser(
        tester,
        const EcranReviser(),
        remplacements: [
          coursProvider.overrideWith((_) async => <ApercuCours>[]),
          profilProvider.overrideWith((_) async => _profil),
        ],
      );

      // C'est là qu'on l'attend le plus : un étudiant sans aucun cours.
      expect(find.text('Aucun cours déposé'), findsOneWidget);
      expect(
        find.widgetWithText(Bouton, 'Ajouter un cours'),
        findsNWidgets(2),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('carte étudiante', () {
    Profil profilAu(String statut) => Profil(
      id: 'u1',
      prenom: 'Awa',
      xpTotal: 1280,
      serieCourante: 4,
      dernierJourValide: _hier,
      faculteId: 'f1',
      universiteNom: 'UAC',
      faculteNom: 'FADESP',
      codeParrain: 'ABC123',
      statutVerification: statut,
    );

    testWidgets('propose le dépôt, et dit pourquoi une carte ne vaut qu’une fois', (
      tester,
    ) async {
      await _poser(
        tester,
        const EcranCarte(),
        remplacements: [
          profilProvider.overrideWith((_) async => profilAu('none')),
        ],
      );

      expect(find.text('Prendre la photo'), findsOneWidget);
      expect(find.text('Choisir dans mes photos'), findsOneWidget);

      // La règle est expliquée, pas subie : c'est ce qui la rend acceptable.
      expect(
        find.textContaining('un seul compte'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('n’offre pas un second dépôt à un compte vérifié', (
      tester,
    ) async {
      // La route refuserait : laisser le bouton mènerait à un 409.
      await _poser(
        tester,
        const EcranCarte(),
        remplacements: [
          profilProvider.overrideWith((_) async => profilAu('verified')),
        ],
      );

      expect(find.text('C’est vérifié'), findsOneWidget);
      expect(find.text('Prendre la photo'), findsNothing);
      expect(find.text('Reprendre la photo'), findsNothing);
    });

    testWidgets('laisse redéposer après un refus', (tester) async {
      // Refusée est le seul état qui rouvre le dépôt : illisible ou périmée,
      // l'étudiant peut y faire quelque chose.
      await _poser(
        tester,
        const EcranCarte(),
        remplacements: [
          profilProvider.overrideWith((_) async => profilAu('rejected')),
        ],
      );

      expect(find.text('Carte non validée'), findsOneWidget);
      expect(find.text('Reprendre la photo'), findsOneWidget);

      await _taper(tester, find.text('Reprendre la photo'));
      expect(find.text('Prendre la photo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ne promet rien pendant qu’une vérification tourne', (
      tester,
    ) async {
      await _poser(
        tester,
        const EcranCarte(),
        remplacements: [
          profilProvider.overrideWith((_) async => profilAu('pending')),
        ],
      );

      expect(find.text('On regarde ta carte'), findsOneWidget);
      expect(find.text('Prendre la photo'), findsNothing);
    });

    testWidgets('ne déborde pas à 320 px', (tester) async {
      await _poser(
        tester,
        const EcranCarte(),
        taille: const Size(320, 640),
        remplacements: [
          profilProvider.overrideWith((_) async => profilAu('none')),
        ],
      );
      expect(tester.takeException(), isNull);
    });
  });


  group('connexion', () {
    testWidgets('propose Google, mais jamais comme une impasse', (tester) async {
      // En test, aucun `--dart-define` : `GOOGLE_WEB_CLIENT_ID` est vide.
      // Le bouton doit alors être visible **et** désactivé, avec la raison.
      // Le masquer ferait croire que l’application ne propose pas Google ;
      // l’activer donnerait une erreur opaque — c’est ce qu’il faisait avant,
      // avec « Connexion Google : à brancher (phase 4 bis) » à l’écran.
      await _poser(tester, const EcranConnexion());

      final google = tester.widget<Bouton>(
        find.widgetWithText(Bouton, 'Continuer avec Google'),
      );
      expect(google.onTap, isNull);

      expect(
        find.text('La connexion Google n’est pas configurée dans cette version.'),
        findsOneWidget,
      );

      // Et la voie qui marche reste là, juste en dessous.
      expect(find.text('Recevoir mon code'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ne déborde pas à 320 px', (tester) async {
      await _poser(
        tester,
        const EcranConnexion(),
        taille: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
    });
  });


  group('aide', () {
    testWidgets('répond d’abord à la question du prélèvement', (tester) async {
      // C'est la crainte qui empêche d'acheter, dans un marché où les
      // abonnements qu'on n'arrive pas à résilier sont une expérience
      // courante. La réponse est non, et elle doit venir en premier.
      await _poser(tester, const EcranAide(), stabiliser: false);

      expect(
        find.text('Est-ce que je serai prélevé chaque mois ?'),
        findsOneWidget,
      );

      // Repliée par défaut : sept réponses ouvertes feraient un mur de texte.
      expect(find.textContaining('Non. Jamais.'), findsNothing);

      await tester.tap(find.text('Est-ce que je serai prélevé chaque mois ?'));
      await tester.pump();

      expect(find.textContaining('Non. Jamais.'), findsOneWidget);
      expect(find.textContaining('aucun abonnement automatique'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('n’offre pas un contact qui ne répondrait pas', (tester) async {
      // En test, `CONTACT_WHATSAPP` est vide : le bouton doit disparaître et
      // l'écran doit le dire, comme le bouton Google sans identifiant.
      await _poser(tester, const EcranAide(), stabiliser: false);

      // Le bloc de contact est sous le pli : une `ListView` construit
      // paresseusement, donc `find` ne le voit pas avant de l'amener à
      // l'écran.
      await tester.scrollUntilVisible(find.text('Nous écrire'), 200);
      await tester.pump();

      expect(find.text('Écrire sur WhatsApp'), findsNothing);
      expect(
        find.textContaining('n’est pas encore dans cette version'),
        findsOneWidget,
      );
    });

    testWidgets('couvre les sept questions, sans déborder à 320 px', (
      tester,
    ) async {
      await _poser(
        tester,
        const EcranAide(),
        taille: const Size(320, 640),
        stabiliser: false,
      );

      expect(Fr.aide.questions, hasLength(7));
      expect(tester.takeException(), isNull);
    });
  });

}
