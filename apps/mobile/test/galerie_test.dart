import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/composants/bouton.dart';
import 'package:reviz/composants/option_qcm.dart';
import 'package:reviz/ecrans/galerie.dart';
import 'package:reviz/theme/theme.dart';

/// Rendu de la galerie à la largeur réelle du public cible.
///
/// CLAUDE.md fixe le mobile d'abord à 390 px ; on teste à **375**, la largeur
/// des écrans les plus étroits encore répandus. Un débordement horizontal est
/// un défaut, pas une approximation : Flutter le signale par une exception de
/// peinture, que `takeException()` attrape.
///
/// Ce test remplace le coup d'œil au serveur de développement, qui a déjà
/// trompé deux fois côté web — une feuille de style vide y faisait croire à un
/// bug de mise en page.
void main() {
  Future<void> poser(WidgetTester tester, Size taille) async {
    tester.view.physicalSize = taille;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(theme: themeReviz, home: const Galerie()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('se rend à 375 × 812 sans déborder', (tester) async {
    await poser(tester, const Size(375, 812));

    expect(tester.takeException(), isNull);
    expect(find.text('Galerie'), findsOneWidget);
  });

  testWidgets('se rend aussi à 320 px, sans déborder', (tester) async {
    // La largeur des très vieux appareils. Si cela tient ici, cela tient
    // partout ailleurs.
    await poser(tester, const Size(320, 640));

    expect(tester.takeException(), isNull);
  });

  testWidgets('défile de bout en bout sans erreur de peinture', (tester) async {
    await poser(tester, const Size(375, 812));

    final liste = find.byType(Scrollable).first;
    for (var i = 0; i < 12; i++) {
      await tester.drag(liste, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'débordement après ${(i + 1) * 400} px de défilement',
      );
    }
  });

  testWidgets('la boucle du QCM montre juste et faux', (tester) async {
    await poser(tester, const Size(375, 812));

    // `scrollUntilVisible` s'arrête dès que l'élément entre dans la fenêtre,
    // parfois à moitié masqué : `ensureVisible` le centre pour de bon avant
    // qu'on tape dessus.
    final liste = find.byType(Scrollable).first;
    final mauvaise = find.text('Le 2 décembre 1990');

    await tester.scrollUntilVisible(mauvaise, 300, scrollable: liste);
    await tester.ensureVisible(mauvaise);
    await tester.pumpAndSettle();

    await tester.tap(mauvaise);
    await tester.pumpAndSettle();

    final valider = find.widgetWithText(Bouton, 'Valider');
    await tester.ensureVisible(valider);
    await tester.pumpAndSettle();
    await tester.tap(valider);
    await tester.pumpAndSettle();

    final options = tester
        .widgetList<OptionQcm>(find.byType(OptionQcm))
        .toList();

    // La bonne réponse se célèbre en jaune, la mauvaise en rouge — et il y a
    // exactement une de chaque.
    expect(
      options.where((o) => o.etat == EtatOption.juste).length,
      1,
      reason: 'une seule bonne réponse doit être marquée juste',
    );
    expect(
      options.where((o) => o.etat == EtatOption.fausse).length,
      1,
      reason: 'seule l’option choisie à tort doit être marquée fausse',
    );
    expect(tester.takeException(), isNull);
  });
}
