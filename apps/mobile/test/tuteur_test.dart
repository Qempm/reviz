import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/donnees/api.dart';
import 'package:reviz/donnees/tuteur.dart';
import 'package:reviz/ecrans/tuteur.dart';
import 'package:reviz/etat/fournisseurs.dart';
import 'package:reviz/i18n/fr.dart';
import 'package:reviz/metier/acces.dart';
import 'package:reviz/metier/tuteur.dart';
import 'package:reviz/theme/theme.dart';

/// Une fausse source : trois questions, puis le bilan.
class _FauxTuteur implements SourceTuteur {
  _FauxTuteur({this.refus, this.essai = false, this.niveaux});

  /// Un refus au démarrage, comme le serveur le rendrait.
  final ReponseEchec<DemarrageTuteur>? refus;
  final bool essai;
  final List<NiveauReponse>? niveaux;
  final reponsesRecues = <String>[];

  @override
  Future<Reponse<DemarrageTuteur>> demarrer({
    required String coursId,
    required String chapitreId,
  }) async {
    if (refus != null) return refus!;
    return Reponse.succes(
      DemarrageTuteur(
        sessionId: 's1',
        essai: essai,
        question: const QuestionTuteur(
          texte: 'Quand intervient le contrôle a priori ?',
          numero: 1,
          total: 3,
        ),
      ),
    );
  }

  @override
  Future<Reponse<TourTuteur>> repondre({
    required String sessionId,
    required String reponse,
  }) async {
    reponsesRecues.add(reponse);
    final n = reponsesRecues.length;
    final niveau = (niveaux ?? const [
      NiveauReponse.juste,
      NiveauReponse.partiel,
      NiveauReponse.juste,
    ])[n - 1];
    final evaluation = EvaluationTuteur(
      niveau: niveau,
      retour: 'Retour sur la réponse $n.',
    );
    if (n < 3) {
      return Reponse.succes(
        TourTuteur(
          evaluation: evaluation,
          suite: QuestionTuteur(
            texte: 'Question numéro ${n + 1} ?',
            numero: n + 1,
            total: 3,
          ),
        ),
      );
    }
    final maitrise = estMaitrise([
      ...?niveaux?.take(3),
      if (niveaux == null) ...const [
        NiveauReponse.juste,
        NiveauReponse.partiel,
        NiveauReponse.juste,
      ],
    ]);
    return Reponse.succes(
      TourTuteur(
        evaluation: evaluation,
        suite: FinTuteur(
          maitrise: maitrise,
          score: 2,
          bilan: 'Bon travail sur ce chapitre.',
          aRevoir: maitrise ? const [] : const ['Le contrôle a posteriori'],
        ),
      ),
    );
  }
}

Future<void> _poser(
  WidgetTester tester,
  SourceTuteur source, {
  Size taille = const Size(375, 812),
}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [depotTuteurProvider.overrideWithValue(source)],
      child: MaterialApp(
        theme: themeReviz,
        // Le mouvement réduit fige la respiration du panthéreau qui lit :
        // `pumpAndSettle` peut alors s'arrêter.
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: EcranTuteur(coursId: 'c1', chapitreId: 'ch1'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _repondre(WidgetTester tester, String texte) async {
  await tester.enterText(find.byType(TextField), texte);
  await tester.pump();
  await tester.tap(find.text(Fr.tuteur.envoyer));
  await tester.pumpAndSettle();
}

void main() {
  group('règles du tuteur', () {
    test('ouvre avec un pack, puis l’essai, une seule fois', () {
      final actif = AccesActif(
        fin: DateTime(2026, 11, 1),
        joursRestants: 20,
        correctionsRestantes: 3,
        plafondMatieres: 5,
        packs: const [CodePack.partiel],
      );
      expect(droitTuteur(acces: actif, essaiUtilise: true), DroitTuteur.pack);
      expect(
        droitTuteur(acces: const AucunAcces(), essaiUtilise: false),
        DroitTuteur.essai,
      );
      expect(
        droitTuteur(acces: const AucunAcces(), essaiUtilise: true),
        DroitTuteur.essaiUtilise,
      );
    });

    test('maîtrisé à deux points sur trois, comme le serveur', () {
      expect(
        estMaitrise(const [
          NiveauReponse.juste,
          NiveauReponse.juste,
          NiveauReponse.faux,
        ]),
        isTrue,
      );
      expect(
        estMaitrise(const [
          NiveauReponse.juste,
          NiveauReponse.partiel,
          NiveauReponse.faux,
        ]),
        isFalse,
      );
    });
  });

  group('écran du tuteur', () {
    for (final largeur in [375.0, 320.0]) {
      testWidgets('mène trois questions jusqu’au bilan à $largeur px', (
        tester,
      ) async {
        final source = _FauxTuteur();
        await _poser(tester, source, taille: Size(largeur, 812));

        expect(find.text('Quand intervient le contrôle a priori ?'), findsOneWidget);
        expect(find.text(Fr.tuteur.question(1, 3)), findsOneWidget);

        await _repondre(tester, 'Avant la promulgation de la loi.');
        expect(find.text(Fr.tuteur.juste), findsOneWidget);
        expect(find.text('Question numéro 2 ?'), findsOneWidget);

        await _repondre(tester, 'Pendant un procès.');
        expect(find.text(Fr.tuteur.partiel), findsOneWidget);

        await _repondre(tester, 'Le Conseil constitutionnel.');
        expect(source.reponsesRecues, hasLength(3));
        expect(find.text(Fr.tuteur.maitriseTitre), findsOneWidget);
        expect(find.text(Fr.tuteur.xp), findsOneWidget);
        // Plus de champ une fois le bilan rendu.
        expect(find.byType(TextField), findsNothing);
      });
    }

    testWidgets('dit « à revoir » et liste les notions', (tester) async {
      await _poser(
        tester,
        _FauxTuteur(
          niveaux: const [
            NiveauReponse.faux,
            NiveauReponse.partiel,
            NiveauReponse.faux,
          ],
        ),
      );
      await _repondre(tester, 'Je ne sais pas.');
      await _repondre(tester, 'Peut-être.');
      await _repondre(tester, 'Aucune idée.');
      expect(find.text(Fr.tuteur.aRevoirTitre), findsOneWidget);
      expect(find.text('Le contrôle a posteriori'), findsOneWidget);
      expect(find.text(Fr.tuteur.xp), findsNothing);
    });

    testWidgets('annonce l’essai gratuit', (tester) async {
      await _poser(tester, _FauxTuteur(essai: true));
      expect(find.text(Fr.tuteur.essai), findsOneWidget);
    });

    testWidgets('renvoie vers les packs quand l’essai est pris', (
      tester,
    ) async {
      await _poser(
        tester,
        _FauxTuteur(
          refus: const ReponseEchec(
            'Essai utilisé.',
            motif: 'essai-utilise',
            statut: 402,
          ),
        ),
        taille: const Size(320, 640),
      );
      expect(find.text(Fr.tuteur.packTitre), findsOneWidget);
      expect(find.text(Fr.tuteur.voirPacks), findsOneWidget);
    });

    testWidgets('dit qu’il faut du réseau, et propose de réessayer', (
      tester,
    ) async {
      await _poser(
        tester,
        _FauxTuteur(
          refus: const ReponseEchec('Pas de connexion.', motif: 'reseau'),
        ),
      );
      expect(find.text(Fr.tuteur.reseau), findsOneWidget);
      expect(find.text(Fr.tuteur.reessayer), findsOneWidget);
    });
  });
}
