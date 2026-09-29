import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/composants/mascotte.dart';

Widget _cadre(Widget enfant, {bool sansAnimation = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: sansAnimation),
    child: Scaffold(body: Center(child: enfant)),
  ),
);

void main() {
  test('chaque état a son dessin dans les assets', () {
    for (final etat in EtatMascotte.values) {
      expect(
        File(etat.chemin).existsSync(),
        isTrue,
        reason: '${etat.chemin} manque : `node scripts/mascotte.mjs`',
      );
    }
  });

  test('le dossier est déclaré dans pubspec.yaml', () {
    // Un asset présent sur le disque mais non déclaré compile, puis s'affiche
    // vide sur le téléphone — l'`errorBuilder` le masquerait sans bruit.
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- assets/mascotte/'),
    );
  });

  testWidgets('se décrit au lecteur d’écran', (tester) async {
    final semantique = tester.ensureSemantics();
    await tester.pumpWidget(_cadre(const Mascotte(etat: EtatMascotte.bravo)));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(EtatMascotte.bravo.description), findsOne);
    semantique.dispose();
  });

  testWidgets('hors attente, finit par se poser', (tester) async {
    // Une respiration sans fin ferait échouer `pumpAndSettle` dans chaque
    // test d'écran qui montre le panthéreau.
    for (final etat in EtatMascotte.values) {
      if (etat == EtatMascotte.reflexion) continue;
      await tester.pumpWidget(
        _cadre(Mascotte(key: ValueKey(etat), etat: etat)),
      );
      await tester.pumpAndSettle();
    }
  });

  testWidgets('en réflexion, respire tant que l’attente dure', (tester) async {
    await tester.pumpWidget(
      _cadre(const Mascotte(etat: EtatMascotte.reflexion)),
    );
    await tester.pump(const Duration(seconds: 20));
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('en mouvement réduit, est posé d’emblée', (tester) async {
    await tester.pumpWidget(
      _cadre(const Mascotte(etat: EtatMascotte.reflexion), sansAnimation: true),
    );
    expect(tester.hasRunningAnimations, isFalse);

    final opacite = tester.widget<Opacity>(
      find.descendant(
        of: find.byType(Mascotte),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacite.opacity, 1);
  });
}
