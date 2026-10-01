import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/composants/cloche.dart';
import 'package:reviz/donnees/api.dart';
import 'package:reviz/donnees/depots.dart';
import 'package:reviz/donnees/rappels.dart';
import 'package:reviz/ecrans/notifications.dart';
import 'package:reviz/ecrans/notifications_reglages.dart';
import 'package:reviz/etat/fournisseurs.dart';
import 'package:reviz/metier/notifications.dart';
import 'package:reviz/theme/theme.dart';

final _maintenant = DateTime(2026, 10, 1, 18);

NotificationReviz _n(
  String id,
  String kind, {
  Map<String, dynamic> data = const {},
  bool lue = false,
  Duration il = const Duration(minutes: 5),
}) => NotificationReviz(
  id: id,
  kind: kind,
  referenceId: 'r-$id',
  data: data,
  lue: lue,
  creeLe: _maintenant.subtract(il),
);

final _liste = [
  _n('1', 'cours_pret', data: {'titre': 'Droit constitutionnel'}),
  _n('2', 'correction_prete', data: {'note': 27.5, 'bareme': 40}),
  _n(
    '3',
    'commission_recue',
    data: {'montant': 375},
    lue: true,
    il: const Duration(hours: 3),
  ),
  _n(
    '4',
    'ligue_cloturee',
    data: {'issue': 'monte', 'rang': 2, 'division': 3},
    lue: true,
    il: const Duration(days: 2),
  ),
];

class _DepotFactice extends DepotNotifications {
  _DepotFactice();
  final lues = <List<String>?>[];
  PrefsPush? enregistrees;

  @override
  Future<void> marquerLues([List<String>? ids]) async => lues.add(ids);

  @override
  Future<Reponse<PrefsPush>> changerPrefs(ApiReviz api, PrefsPush prefs) async {
    enregistrees = prefs;
    return ReponseSucces(prefs);
  }
}

class _RappelsFactices extends ServiceRappels {
  _RappelsFactices({this.permises});
  final bool? permises;

  @override
  Future<bool?> autorisees() async => permises;
}

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

void main() {
  group('centre de notifications', () {
    testWidgets('montre chaque événement, les non lues d’abord marquées', (
      tester,
    ) async {
      await _poser(
        tester,
        EcranNotifications(maintenant: _maintenant),
        remplacements: [
          notificationsProvider.overrideWith((_) async => _liste),
        ],
      );

      expect(find.text('Ton cours est prêt'), findsOneWidget);
      expect(
        find.text(
          '« Droit constitutionnel » : tes QCM et tes fiches t’attendent.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Ta note : 27,5 / 40. Le détail t’attend.'),
        findsOneWidget,
      );
      expect(find.text('+375 F de commission'), findsOneWidget);
      expect(find.text('Tu montes en Ligue Or !'), findsOneWidget);
      expect(find.text('Il y a 5 min'), findsNWidgets(2));
      expect(find.text('Il y a 2 jours'), findsOneWidget);
      // Deux non lues : le bouton « tout marquer comme lu » est là.
      expect(find.byTooltip('Tout marquer comme lu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tout marquer comme lu appelle le serveur une fois', (
      tester,
    ) async {
      final depot = _DepotFactice();
      await _poser(
        tester,
        EcranNotifications(maintenant: _maintenant),
        remplacements: [
          notificationsProvider.overrideWith((_) async => _liste),
          depotNotificationsProvider.overrideWithValue(depot),
        ],
      );
      await tester.tap(find.byTooltip('Tout marquer comme lu'));
      await tester.pumpAndSettle();
      expect(depot.lues, [null]);
    });

    testWidgets('vide : le panthéreau, et pas de bouton inutile', (
      tester,
    ) async {
      await _poser(
        tester,
        EcranNotifications(maintenant: _maintenant),
        remplacements: [
          notificationsProvider.overrideWith(
            (_) async => const <NotificationReviz>[],
          ),
        ],
      );
      expect(find.text('Rien de neuf pour l’instant'), findsOneWidget);
      expect(find.byTooltip('Tout marquer comme lu'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ne déborde pas à 320 px', (tester) async {
      await _poser(
        tester,
        EcranNotifications(maintenant: _maintenant),
        taille: const Size(320, 640),
        remplacements: [
          notificationsProvider.overrideWith((_) async => _liste),
        ],
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('cloche', () {
    testWidgets('sans non lue, pas de pastille', (tester) async {
      await _poser(
        tester,
        const Scaffold(body: Center(child: Cloche(nonLues: 0))),
      );
      expect(find.text('0'), findsNothing);
      expect(find.bySemanticsLabel('Ouvrir les notifications'), findsOneWidget);
    });

    testWidgets('la pastille compte, et plafonne à 9+', (tester) async {
      await _poser(
        tester,
        const Scaffold(body: Center(child: Cloche(nonLues: 3))),
      );
      expect(find.text('3'), findsOneWidget);
      await _poser(
        tester,
        const Scaffold(body: Center(child: Cloche(nonLues: 14))),
      );
      expect(find.text('9+'), findsOneWidget);
    });
  });

  group('réglages des notifications', () {
    List<Override> base({bool? permises = true, bool push = true}) => [
      serviceRappelsProvider.overrideWithValue(
        _RappelsFactices(permises: permises),
      ),
      pushDisponibleProvider.overrideWith((_) async => push),
      prefsPushProvider.overrideWith(
        (_) async => const PrefsPush(ligue: false),
      ),
    ];

    testWidgets('rappels et catégories de push, avec l’heure du soir', (
      tester,
    ) async {
      await _poser(
        tester,
        const EcranReglagesNotifications(),
        remplacements: base(),
      );
      expect(find.text('Ma série'), findsOneWidget);
      expect(find.text('Heure du rappel'), findsOneWidget);
      expect(find.text('20 h'), findsOneWidget);
      expect(find.text('Mes examens'), findsOneWidget);
      expect(find.text('La fin de mon pack'), findsOneWidget);
      expect(find.text('Cours et copies'), findsOneWidget);
      expect(find.text('Ligue de la semaine'), findsOneWidget);
      // Pas d'alerte quand les notifications sont permises.
      expect(find.text('Autoriser les notifications'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('couper la série retire le choix de l’heure', (tester) async {
      await _poser(
        tester,
        const EcranReglagesNotifications(),
        remplacements: base(),
      );
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(find.text('Heure du rappel'), findsNothing);
    });

    testWidgets('une catégorie coupée part au serveur', (tester) async {
      final depot = _DepotFactice();
      await _poser(
        tester,
        const EcranReglagesNotifications(),
        remplacements: [
          ...base(),
          depotNotificationsProvider.overrideWithValue(depot),
        ],
      );
      // L'interrupteur de la ligne « Paiements et gains », sous le pli : la
      // liste se construit à la demande, on la fait défiler jusqu'à lui.
      final ligne = find.ancestor(
        of: find.text('Paiements et gains'),
        matching: find.byType(Row),
      );
      await tester.scrollUntilVisible(
        find.text('Paiements et gains'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final interrupteur = find.descendant(
        of: ligne.first,
        matching: find.byType(Switch),
      );
      await tester.ensureVisible(interrupteur);
      await tester.pumpAndSettle();
      await tester.tap(interrupteur);
      await tester.pumpAndSettle();
      expect(depot.enregistrees?.argent, isFalse);
      expect(depot.enregistrees?.ligue, isFalse);
      expect(depot.enregistrees?.cours, isTrue);
    });

    testWidgets('notifications bloquées : on le dit, et on propose', (
      tester,
    ) async {
      await _poser(
        tester,
        const EcranReglagesNotifications(),
        remplacements: base(permises: false),
      );
      expect(
        find.text('Les notifications sont coupées sur ce téléphone.'),
        findsOneWidget,
      );
      expect(find.text('Autoriser les notifications'), findsOneWidget);
    });

    testWidgets('sans Firebase, pas de section push', (tester) async {
      await _poser(
        tester,
        const EcranReglagesNotifications(),
        remplacements: base(push: false),
      );
      expect(find.text('Cours et copies'), findsNothing);
      expect(find.text('Ma série'), findsOneWidget);
    });

    testWidgets('ne déborde pas à 320 px', (tester) async {
      await _poser(
        tester,
        const EcranReglagesNotifications(),
        taille: const Size(320, 640),
        remplacements: base(permises: false),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
