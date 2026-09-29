import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reviz/composants/coquille.dart';
import 'package:reviz/routage.dart';

/// Tests de la navigation.
///
/// Deux défauts signalés par le propriétaire, et que ces tests tiennent :
///
///  1. **La barre du bas changeait avec la page.** Chaque onglet construisait
///     sa propre barre ; en changer détruisait l'une et en reconstruisait une
///     autre. Elle doit être le **même** objet d'un onglet à l'autre.
///  2. **Le bouton retour sortait de l'application depuis n'importe où.** Il
///     n'y avait que des `context.go`, donc une pile d'une seule page. Il doit
///     remonter écran par écran, revenir à Accueil depuis la racine d'un
///     autre onglet, et ne sortir que depuis Accueil.
///
/// Le routeur de test reprend la **structure** du vrai (`routage.dart`) avec
/// des pages factices : le vrai a besoin de Supabase pour sa garde d'accès.
/// Ce qui est éprouvé est bien le code de production — `CoquilleOnglets`, son
/// `PopScope`, la `NavBasse`, et les verbes `descendre` / `remonter`.
void main() {
  late List<String> appelsSysteme;

  setUp(() {
    appelsSysteme = [];
  });

  /// Monte l'application de test, et intercepte `SystemNavigator.pop` —
  /// l'appel par lequel Flutter demande à Android de quitter l'application.
  Future<GoRouter> monter(WidgetTester tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (appel) async {
        appelsSysteme.add(appel.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final routeur = routeurDeTest();
    addTearDown(routeur.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: routeur));
    await tester.pumpAndSettle();
    return routeur;
  }

  /// Le bouton retour d'Android, tel que le système l'envoie.
  Future<void> retour(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  bool aQuitte() => appelsSysteme.contains('SystemNavigator.pop');

  group('la barre du bas', () {
    testWidgets('reste le même objet d’un onglet à l’autre', (tester) async {
      await monter(tester);

      final barreAvant = tester.element(find.byType(NavBasse));
      final pilule = tester.state(find.byType(AnimatedPositioned));

      await tester.tap(find.text('Réviser'));
      await tester.pumpAndSettle();

      expect(find.text('page réviser'), findsOneWidget);

      // Même élément, même état d'animation : la barre n'a pas été
      // reconstruite, et c'est **la même** pilule qui a glissé — pas une
      // nouvelle qui serait apparue sous l'onglet choisi.
      expect(identical(tester.element(find.byType(NavBasse)), barreAvant), isTrue);
      expect(identical(tester.state(find.byType(AnimatedPositioned)), pilule), isTrue);
    });

    testWidgets('fait glisser la pilule sous l’onglet choisi', (tester) async {
      await monter(tester);

      final pilule = find.byKey(const ValueKey('nav-pilule'));
      final xAccueil = tester.getCenter(pilule).dx;

      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();

      final xProfil = tester.getCenter(pilule).dx;

      // Profil est le dernier onglet : la pilule est partie vers la droite,
      // et s'est posée sous son icône.
      expect(xProfil, greaterThan(xAccueil));
      expect(
        (xProfil - tester.getCenter(find.text('Profil')).dx).abs(),
        lessThan(1),
      );
    });

    testWidgets('disparaît sur un écran plein, et revient au retour', (
      tester,
    ) async {
      final routeur = await monter(tester);

      await tester.tap(find.text('Réviser'));
      await tester.pumpAndSettle();
      routeur.push('/cours/c1');
      await tester.pumpAndSettle();
      routeur.push('/cours/c1/session');
      await tester.pumpAndSettle();

      // Une session de QCM prend tout l'écran : une question à la fois.
      expect(find.text('page session'), findsOneWidget);
      expect(find.byType(NavBasse), findsNothing);

      await retour(tester);

      expect(find.text('page cours'), findsOneWidget);
      expect(find.byType(NavBasse), findsOneWidget);
    });
  });

  group('le bouton retour', () {
    testWidgets('remonte écran par écran, puis sort depuis Accueil', (
      tester,
    ) async {
      await monter(tester);

      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ouvrir avatar'));
      await tester.pumpAndSettle();
      expect(find.text('page avatar'), findsOneWidget);

      // 1. Au fond d'un onglet : on remonte d'un cran.
      await retour(tester);
      expect(find.text('page profil'), findsOneWidget);
      expect(aQuitte(), isFalse);

      // 2. À la racine d'un onglet autre qu'Accueil : on revient à Accueil.
      await retour(tester);
      expect(find.text('page accueil'), findsOneWidget);
      expect(aQuitte(), isFalse);

      // 3. Sur Accueil : là, et là seulement, on sort.
      await retour(tester);
      expect(aQuitte(), isTrue);
    });

    testWidgets('ne sort jamais depuis la racine d’un autre onglet', (
      tester,
    ) async {
      await monter(tester);

      for (final onglet in ['Réviser', 'Corriger', 'Gains', 'Profil']) {
        await tester.tap(find.text(onglet));
        await tester.pumpAndSettle();

        await retour(tester);

        expect(find.text('page accueil'), findsOneWidget, reason: onglet);
        expect(aQuitte(), isFalse, reason: onglet);
      }
    });
  });

  group('les verbes', () {
    testWidgets('remonter va au repli quand rien n’est dessous', (
      tester,
    ) async {
      final routeur = await monter(tester);

      // Ouvert directement, comme par un lien : aucune page dessous.
      routeur.go('/classement');
      await tester.pumpAndSettle();
      expect(find.text('page classement'), findsOneWidget);

      await tester.tap(find.text('remonter'));
      await tester.pumpAndSettle();

      expect(find.text('page gains'), findsOneWidget);
    });

    testWidgets('toucher l’onglet actif ramène à sa racine', (tester) async {
      await monter(tester);

      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ouvrir avatar'));
      await tester.pumpAndSettle();
      expect(find.text('page avatar'), findsOneWidget);

      // Le geste de l'iPhone pour remonter d'un coup du fond d'une pile.
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();

      expect(find.text('page profil'), findsOneWidget);
    });

    testWidgets('un onglet garde sa page quand on en revient', (tester) async {
      await monter(tester);

      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ouvrir avatar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gains'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();

      // Un navigateur par onglet, gardés en vie : on retrouve l'avatar là
      // où on l'avait laissé.
      expect(find.text('page avatar'), findsOneWidget);
    });
  });
}

/// Un routeur de même structure que celui de `routage.dart`.
GoRouter routeurDeTest() {
  final racine = GlobalKey<NavigatorState>(debugLabel: 'racine-test');

  GoRoute page(
    String chemin,
    String nom, {
    GlobalKey<NavigatorState>? parent,
    List<RouteBase> routes = const [],
  }) {
    return GoRoute(
      path: chemin,
      parentNavigatorKey: parent,
      routes: routes,
      builder: (_, _) => _Page(nom),
    );
  }

  return GoRouter(
    navigatorKey: racine,
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, coquille) => CoquilleOnglets(coquille: coquille),
        branches: [
          StatefulShellBranch(routes: [page('/', 'accueil')]),
          StatefulShellBranch(
            routes: [
              page('/reviser', 'réviser'),
              page(
                '/cours/:id',
                'cours',
                routes: [page('session', 'session', parent: racine)],
              ),
            ],
          ),
          StatefulShellBranch(routes: [page('/corriger', 'corriger')]),
          StatefulShellBranch(
            routes: [page('/gains', 'gains'), page('/classement', 'classement')],
          ),
          StatefulShellBranch(
            routes: [
              page('/profil', 'profil', routes: [page('avatar', 'avatar')]),
            ],
          ),
        ],
      ),
    ],
  );
}

class _Page extends StatelessWidget {
  const _Page(this.nom);

  final String nom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('page $nom'),
          TextButton(
            onPressed: () => context.descendre('/profil/avatar'),
            child: const Text('ouvrir avatar'),
          ),
          TextButton(
            onPressed: () => context.remonter('/gains'),
            child: const Text('remonter'),
          ),
        ],
      ),
    );
  }
}
