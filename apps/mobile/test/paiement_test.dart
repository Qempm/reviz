import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/donnees/api.dart';
import 'package:reviz/donnees/depots.dart';
import 'package:reviz/donnees/modeles.dart';
import 'package:reviz/ecrans/boutique.dart';
import 'package:reviz/ecrans/paiement.dart';
import 'package:reviz/etat/fournisseurs.dart';
import 'package:reviz/theme/theme.dart';

/// Un dépôt qui rend, à chaque interrogation, le statut suivant de la liste
/// — puis répète le dernier.
class _DepotFaux extends DepotBoutique {
  _DepotFaux({this.statuts = const [], this.ouverture});

  final List<Reponse<String>> statuts;
  final Reponse<PaiementOuvert>? ouverture;
  int interrogations = 0;
  final List<String> packsOuverts = [];

  @override
  Future<Reponse<String>> suivrePaiement(ApiReviz api, String id) async {
    final i = interrogations < statuts.length
        ? interrogations
        : statuts.length - 1;
    interrogations++;
    return statuts[i];
  }

  @override
  Future<Reponse<PaiementOuvert>> ouvrirPaiement(
    ApiReviz api,
    String codePack,
  ) async {
    packsOuverts.add(codePack);
    return ouverture!;
  }
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
      await _poser(
        tester,
        const EcranPaiement(paiementId: 'p1', urlPaiement: 'https://x'),
        depot,
      );

      expect(find.text('On attend la confirmation'), findsOneWidget);

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
      expect(find.text('Revenir aux packs'), findsOneWidget);

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

    testWidgets('ne propose de rouvrir la page que s’il la connaît', (
      tester,
    ) async {
      await _poser(
        tester,
        const EcranPaiement(paiementId: 'p1'),
        _DepotFaux(statuts: [_enAttente]),
      );
      expect(find.text('Rouvrir la page de paiement'), findsNothing);
      await _retirer(tester);

      await _poser(
        tester,
        const EcranPaiement(paiementId: 'p1', urlPaiement: 'https://x'),
        _DepotFaux(statuts: [_enAttente]),
      );
      expect(find.text('Rouvrir la page de paiement'), findsOneWidget);
      await _retirer(tester);
    });

    testWidgets('ne déborde pas à 320 px', (tester) async {
      await _poser(
        tester,
        const EcranPaiement(paiementId: 'p1', urlPaiement: 'https://x'),
        _DepotFaux(statuts: [_enAttente]),
        taille: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
      await _retirer(tester);
    });
  });

  group('le bouton de paiement de la boutique', () {
    const packs = [
      PackBoutique(
        code: 'controle',
        libelle: 'Contrôle',
        description: null,
        prixFcfa: 500,
        dureeJours: 7,
        correctionsIncluses: 3,
        plafondMatieres: 2,
      ),
    ];

    testWidgets('ouvre le paiement du bon pack, et dit pourquoi il échoue', (
      tester,
    ) async {
      final depot = _DepotFaux(
        ouverture: const Reponse.echec(
          'Le paiement Mobile Money n’est pas encore disponible.',
        ),
      );

      await _poser(
        tester,
        const EcranBoutique(),
        depot,
        autres: [
          boutiqueProvider.overrideWith(
            (_) async => const DonneesBoutique(packs: packs, abonnements: []),
          ),
        ],
      );
      await tester.pumpAndSettle();

      // Plus de « bientôt disponible » : le bouton dit ce qu'il fait.
      expect(find.textContaining('bientôt'), findsNothing);

      await tester.tap(find.text('Payer 500 F'));
      await tester.pumpAndSettle();

      expect(depot.packsOuverts, ['controle']);
      // Le message du serveur, tel quel : il sait pourquoi.
      expect(
        find.text('Le paiement Mobile Money n’est pas encore disponible.'),
        findsOneWidget,
      );
    });
  });
}
