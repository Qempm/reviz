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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/composants/coquille.dart';
import 'package:reviz/donnees/depots.dart';
import 'package:reviz/donnees/modeles.dart';
import 'package:reviz/ecrans/accueil.dart';
import 'package:reviz/ecrans/connexion.dart';
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

  // Les images (avatars) se décodent pour de vrai, hors du temps simulé :
  // sans cela elles sortent vides.
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

void main() {
  setUpAll(_chargerPolices);

  final accueil = DonneesAccueil(
    profil: _profil,
    semaine: _semaine,
    objectif: 10,
    matieres: _matieres,
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
      remplacements: [profilProvider.overrideWith((_) async => _profil)],
    );
  });

  testWidgets('connexion', (tester) async {
    await _photographier(tester, 'connexion', const EcranConnexion());
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
