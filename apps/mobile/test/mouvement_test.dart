import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/composants/chargement.dart';
import 'package:reviz/composants/chiffre_anime.dart';
import 'package:reviz/composants/mouvement_reduit.dart';
import 'package:reviz/donnees/reglages.dart';

/// Le réglage du profil, forcé à une valeur.
class _Reglage extends AnimationsReduites {
  _Reglage(this.valeur);
  final bool valeur;

  @override
  bool build() => valeur;
}

Widget _app(Widget enfant, {bool reglage = false, bool systeme = false}) {
  return ProviderScope(
    overrides: [
      animationsReduitesProvider.overrideWith(() => _Reglage(reglage)),
    ],
    child: MediaQuery(
      data: MediaQueryData(disableAnimations: systeme),
      child: MaterialApp(
        home: MouvementReduit(child: Scaffold(body: enfant)),
      ),
    ),
  );
}

/// Lit ce que voient les composants sous le relais.
class _Sonde extends StatelessWidget {
  const _Sonde();

  @override
  Widget build(BuildContext context) =>
      Text(MediaQuery.disableAnimationsOf(context) ? 'réduit' : 'normal');
}

void main() {
  group('le relais du mouvement réduit', () {
    testWidgets('fait entendre le réglage du profil', (tester) async {
      await tester.pumpWidget(_app(const _Sonde(), reglage: true));
      expect(find.text('réduit'), findsOneWidget);
    });

    testWidgets('garde la préférence du téléphone', (tester) async {
      await tester.pumpWidget(_app(const _Sonde(), systeme: true));
      expect(find.text('réduit'), findsOneWidget);
    });

    testWidgets('ne réduit rien quand personne ne l’a demandé', (tester) async {
      await tester.pumpWidget(_app(const _Sonde()));
      expect(find.text('normal'), findsOneWidget);
    });
  });

  group('le chargement', () {
    testWidgets('se dit au lecteur d’écran', (tester) async {
      final semantique = tester.ensureSemantics();
      await tester.pumpWidget(_app(const Chargement.liste()));
      expect(find.bySemanticsLabel('Un instant…'), findsOneWidget);
      semantique.dispose();
    });

    testWidgets('reste immobile en mouvement réduit', (tester) async {
      await tester.pumpWidget(_app(const Chargement.liste(), reglage: true));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('fait passer un reflet sinon', (tester) async {
      await tester.pumpWidget(_app(const Chargement.bloc()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('le chiffre animé', () {
    Widget chiffre(int n, {bool depuisZero = false}) => ChiffreAnime(
      valeur: n,
      depuisZero: depuisZero,
      construire: (v) => Text('$v XP'),
    );

    testWidgets('est posé tel quel au premier affichage', (tester) async {
      await tester.pumpWidget(_app(chiffre(1280)));
      expect(find.text('1280 XP'), findsOneWidget);
    });

    testWidgets('défile vers la nouvelle valeur', (tester) async {
      await tester.pumpWidget(_app(chiffre(1280)));
      await tester.pumpWidget(_app(chiffre(1340)));
      await tester.pump(const Duration(milliseconds: 300));

      // En chemin : ni l'ancienne valeur, ni déjà la nouvelle.
      expect(find.text('1280 XP'), findsNothing);
      expect(find.text('1340 XP'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('1340 XP'), findsOneWidget);
    });

    testWidgets('part de zéro quand on le lui demande', (tester) async {
      await tester.pumpWidget(_app(chiffre(7, depuisZero: true)));
      expect(find.text('0 XP'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('7 XP'), findsOneWidget);
    });

    testWidgets('saute à la valeur en mouvement réduit', (tester) async {
      await tester.pumpWidget(
        _app(chiffre(7, depuisZero: true), reglage: true),
      );
      expect(find.text('7 XP'), findsOneWidget);
    });
  });
}
