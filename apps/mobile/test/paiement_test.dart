import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/donnees/api.dart';
import 'package:reviz/donnees/depots.dart';
import 'package:reviz/donnees/modeles.dart';
import 'package:reviz/ecrans/paiement.dart';
import 'package:reviz/ecrans/payer.dart';
import 'package:reviz/etat/fournisseurs.dart';
import 'package:reviz/theme/theme.dart';

/// Un dépôt qui rend, à chaque interrogation, le statut suivant de la liste
/// — puis répète le dernier.
class _DepotFaux extends DepotBoutique {
  _DepotFaux({this.statuts = const [], this.ouverture});

  final List<Reponse<String>> statuts;
  final Reponse<String>? ouverture;
  int interrogations = 0;
  final List<(String, String, String)> demandes = [];
  String? numeroPasse;

  @override
  Future<Reponse<String>> suivrePaiement(ApiReviz api, String id) async {
    final i = interrogations < statuts.length
        ? interrogations
        : statuts.length - 1;
    interrogations++;
    return statuts[i];
  }

  @override
  Future<Reponse<String>> ouvrirPaiement(
    ApiReviz api, {
    required String codePack,
    required String operateur,
    required String telephoneE164,
  }) async {
    demandes.add((codePack, operateur, telephoneE164));
    return ouverture!;
  }

  @override
  Future<String?> dernierTelephone() async => numeroPasse;
}

const _enAttente = Reponse<String>.succes('pending');
const _paye = Reponse<String>.succes('success');
const _refuse = Reponse<String>.succes('failed');

Future<void> _poser(
  WidgetTester tester,
  Widget ecran,
  _DepotFaux depot, {
  Size taille = const Size(375, 812),
  List<Override> autres = const [],
}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [depotBoutiqueProvider.overrideWithValue(depot), ...autres],
      child: MaterialApp(theme: themeReviz, home: ecran),
    ),
  );
  await tester.pump();
}

/// Démonte l'écran : son minuteur doit s'arrêter avec lui.
Future<void> _retirer(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

void main() {
  group('le suivi du paiement', () {
    testWidgets('annonce le pack actif dès que le paiement est confirmé', (
      tester,
    ) async {
      final depot = _DepotFaux(statuts: [_enAttente, _enAttente, _paye]);
      await _poser(tester, const EcranPaiement(paiementId: 'p1'), depot);

      expect(find.text('On attend la confirmation'), findsOneWidget);
      expect(find.textContaining('code secret'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      expect(find.text('Ton pack est actif !'), findsOneWidget);
      expect(find.text('Commencer à réviser'), findsOneWidget);

      // L'issue tombée, on n'interroge plus le serveur.
      final apres = depot.interrogations;
      await tester.pump(const Duration(seconds: 20));
      expect(depot.interrogations, apres);

      await _retirer(tester);
    });

    testWidgets('dit l’échec sans laisser croire à un prélèvement', (
      tester,
    ) async {
      await _poser(
        tester,
        const EcranPaiement(paiementId: 'p1'),
        _DepotFaux(statuts: [_refuse]),
      );
      await tester.pump();

      expect(find.text('Le paiement n’est pas passé'), findsOneWidget);
      expect(find.textContaining('Aucun montant'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);

      await _retirer(tester);
    });

    testWidgets('ne prend pas une coupure réseau pour un échec', (
      tester,
    ) async {
      final depot = _DepotFaux(
        statuts: [const Reponse<String>.echec('Pas de réseau.')],
      );
      await _poser(tester, const EcranPaiement(paiementId: 'p1'), depot);
      await tester.pump(const Duration(seconds: 8));

      expect(find.text('On attend la confirmation'), findsOneWidget);
      expect(find.text('Le paiement n’est pas passé'), findsNothing);
      // Et l'écran continue d'interroger.
      expect(depot.interrogations, greaterThan(1));

      await _retirer(tester);
    });

    testWidgets('s’arrête d’interroger au bout de sa patience, puis reprend '
        'sur demande', (tester) async {
      final depot = _DepotFaux(statuts: [_enAttente]);
      await _poser(
        tester,
        const EcranPaiement(paiementId: 'p1', patience: Duration(seconds: 10)),
        depot,
      );

      await tester.pump(const Duration(seconds: 12));
      await tester.pump();
      expect(find.text('Toujours en attente'), findsOneWidget);

      final figees = depot.interrogations;
      await tester.pump(const Duration(seconds: 20));
      expect(depot.interrogations, figees);

      // « Vérifier maintenant » relance vraiment l'attente : l'échéance
      // dépassée ne doit pas la refermer aussitôt.
      await tester.tap(find.text('Vérifier maintenant'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('On attend la confirmation'), findsOneWidget);
      expect(depot.interrogations, greaterThan(figees));

      await _retirer(tester);
    });

    testWidgets('ne déborde pas à 320 px', (tester) async {
      await _poser(
        tester,
        const EcranPaiement(paiementId: 'p1'),
        _DepotFaux(statuts: [_enAttente]),
        taille: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
      await _retirer(tester);
    });
  });

  group('l’écran de paiement', () {
    const pack = PackBoutique(
      code: 'controle',
      libelle: 'Contrôle',
      description: null,
      prixFcfa: 500,
      dureeJours: 7,
      correctionsIncluses: 3,
      plafondMatieres: 2,
    );

    Profil profil({String? telephone}) => Profil(
      id: 'u1',
      prenom: 'Awa',
      xpTotal: 0,
      serieCourante: 0,
      dernierJourValide: null,
      faculteId: 'f1',
      universiteNom: null,
      faculteNom: null,
      codeParrain: null,
      telephone: telephone,
    );

    Future<void> ouvrir(
      WidgetTester tester,
      _DepotFaux depot, {
      String? telephone,
      Size taille = const Size(375, 812),
    }) async {
      await _poser(
        tester,
        const EcranPayer(pack: pack, emailCompte: 'awa@exemple.com'),
        depot,
        taille: taille,
        autres: [
          profilProvider.overrideWith(
            (_) async => profil(telephone: telephone),
          ),
        ],
      );
      await tester.pumpAndSettle();
    }

    testWidgets('pré-remplit le nom, l’e-mail et le numéro du compte', (
      tester,
    ) async {
      await ouvrir(tester, _DepotFaux(), telephone: '+2290197123456');

      expect(find.text('Awa'), findsOneWidget);
      expect(find.text('awa@exemple.com'), findsOneWidget);
      expect(find.text('01 97 12 34 56'), findsOneWidget);
      // Un numéro béninois : les trois réseaux du Bénin.
      expect(find.text('MTN MoMo'), findsOneWidget);
      expect(find.text('Moov Money'), findsOneWidget);
      expect(find.text('Celtiis Cash'), findsOneWidget);
    });

    testWidgets('reprend le numéro du dernier paiement, à défaut du profil', (
      tester,
    ) async {
      await ouvrir(tester, _DepotFaux()..numeroPasse = '+22997123456');
      expect(find.text('97 12 34 56'), findsOneWidget);
    });

    testWidgets('ne propose que les réseaux du pays du numéro', (tester) async {
      await ouvrir(tester, _DepotFaux());

      await tester.enterText(find.byType(TextField), '+225 07 12 34 56 78');
      await tester.pump();

      // Côte d'Ivoire : MTN seul, choisi d'office.
      expect(find.text('MTN MoMo'), findsOneWidget);
      expect(find.text('Moov Money'), findsNothing);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('dit quand un pays ne se paie pas encore dans l’app', (
      tester,
    ) async {
      final depot = _DepotFaux();
      await ouvrir(tester, depot);

      await tester.enterText(find.byType(TextField), '+226 70 12 34 56');
      await tester.pump();

      expect(find.textContaining('Burkina Faso'), findsOneWidget);
      await tester.tap(find.text('Payer 500 F'));
      await tester.pump();
      expect(depot.demandes, isEmpty);
    });

    testWidgets('envoie le pack, l’opérateur et le numéro — rien d’autre', (
      tester,
    ) async {
      final depot = _DepotFaux(
        ouverture: const Reponse.echec(
          'La demande n’a pas pu partir vers ton téléphone.',
        ),
      );
      await ouvrir(tester, depot, telephone: '+2290197123456');

      // Sans opérateur choisi, rien ne part.
      await tester.tap(find.text('Payer 500 F'));
      await tester.pump();
      expect(find.text('Choisis ton opérateur.'), findsOneWidget);
      expect(depot.demandes, isEmpty);

      await tester.tap(find.text('MTN MoMo'));
      await tester.pump();
      await tester.tap(find.text('Payer 500 F'));
      await tester.pumpAndSettle();

      expect(depot.demandes, [('controle', 'mtn', '+2290197123456')]);
      // Le message du serveur, tel quel.
      expect(
        find.text('La demande n’a pas pu partir vers ton téléphone.'),
        findsOneWidget,
      );
    });

    testWidgets('ne déborde pas à 320 px', (tester) async {
      await ouvrir(
        tester,
        _DepotFaux(),
        telephone: '+2290197123456',
        taille: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
