import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/composants/niveau.dart';
import 'package:reviz/theme/theme.dart';

Widget _dans(Widget enfant) => MaterialApp(
  theme: themeReviz,
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: enfant),
  ),
);

void main() {
  testWidgets('la barre dit le niveau et ce qui manque', (tester) async {
    await tester.pumpWidget(
      _dans(const BarreNiveau(xpAvant: 100, xpApres: 200)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Niveau 2 · Débutant'), findsOneWidget);
    expect(find.text('150 XP avant le niveau 3'), findsOneWidget);
  });

  testWidgets('un niveau franchi se fête, puis se ferme', (tester) async {
    await tester.pumpWidget(
      _dans(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => montrerNiveauSuperieur(context, 3),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Niveau supérieur !'), findsOneWidget);
    // Le niveau 3 change de nom : on le dit.
    expect(find.text('Tu es maintenant « Curieux ».'), findsOneWidget);

    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(find.text('Niveau supérieur !'), findsNothing);
  });
}
