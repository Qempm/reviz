import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/composants/champ_recherche.dart';
import 'package:reviz/donnees/api.dart';
import 'package:reviz/theme/theme.dart';

void main() {
  const ecoles = [('u1', 'UAC'), ('u2', 'Université de Parakou'), ('u3', 'FSEG')];

  Future<(String, String)?> poser(
    WidgetTester tester, {
    Future<Reponse<(String, String)>> Function(String)? onAjouter,
  }) async {
    (String, String)? choisi;
    await tester.pumpWidget(
      MaterialApp(
        theme: themeReviz,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ChampRecherche(
              libelle: 'Ton université',
              marqueur: 'Cherche ou ajoute ton école',
              valeur: choisi?.$1,
              entrees: ecoles,
              onChoisir: (id, nom) => setState(() => choisi = (id, nom)),
              onAjouter: onAjouter,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Cherche ou ajoute ton école'));
    await tester.pumpAndSettle();
    return choisi;
  }

  testWidgets('filtre en ignorant accents et casse, et choisit', (tester) async {
    await poser(tester);
    await tester.enterText(find.byType(TextField), 'universite');
    await tester.pump();

    expect(find.text('Université de Parakou'), findsOneWidget);
    expect(find.text('UAC'), findsNothing);

    await tester.tap(find.text('Université de Parakou'));
    await tester.pumpAndSettle();
    // La feuille se ferme et le champ affiche le choix.
    expect(find.text('Université de Parakou'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('ne propose pas d’ajouter ce qui existe sous une autre écriture', (
    tester,
  ) async {
    await poser(tester, onAjouter: (_) async => const Reponse.succes(('x', 'x')));
    await tester.enterText(find.byType(TextField), 'f.s.e.g');
    await tester.pump();

    expect(find.text('FSEG'), findsOneWidget);
    expect(find.textContaining('Ajouter'), findsNothing);
  });

  testWidgets('ajoute ce qui manque, et le choisit', (tester) async {
    String? demande;
    await poser(
      tester,
      onAjouter: (nom) async {
        demande = nom;
        return const Reponse.succes(('u9', 'ENEAM'));
      },
    );
    await tester.enterText(find.byType(TextField), 'ENEAM');
    await tester.pump();

    await tester.tap(find.text('Ajouter « ENEAM »'));
    await tester.pumpAndSettle();

    expect(demande, 'ENEAM');
    expect(find.text('ENEAM'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('dit pourquoi un ajout échoue, sans fermer', (tester) async {
    await poser(
      tester,
      onAjouter: (_) async => const Reponse.echec('On n’a pas pu ajouter ton école.'),
    );
    await tester.enterText(find.byType(TextField), 'ENEAM');
    await tester.pump();
    await tester.tap(find.text('Ajouter « ENEAM »'));
    await tester.pumpAndSettle();

    expect(find.text('On n’a pas pu ajouter ton école.'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('sans ajout possible, ne le propose pas', (tester) async {
    await poser(tester);
    await tester.enterText(find.byType(TextField), 'ENEAM');
    await tester.pump();
    expect(find.textContaining('Ajouter'), findsNothing);
  });
}
