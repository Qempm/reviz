import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/metier/acces.dart';

/// Port de `lib/payments/subscriptions.test.ts` — 18 tests.

/// Grille « accessible » arbitrée le 08/09/2026, cf. la migration de seed.
const packs = {
  'decouverte': Pack(
    code: CodePack.decouverte,
    dureeJours: 3,
    correctionsIncluses: 1,
    plafondMatieres: 1,
  ),
  'controle': Pack(
    code: CodePack.controle,
    dureeJours: 7,
    correctionsIncluses: 3,
    plafondMatieres: 2,
  ),
  'partiel': Pack(
    code: CodePack.partiel,
    dureeJours: 30,
    correctionsIncluses: 10,
    plafondMatieres: 5,
  ),
  'semestre': Pack(
    code: CodePack.semestre,
    dureeJours: 120,
    correctionsIncluses: 30,
    plafondMatieres: null,
  ),
};

final t0 = DateTime.utc(2026, 9, 9, 8);

Abonnement sub(int jours, {int corrections = 3, int? plafond = 2}) => Abonnement(
  code: CodePack.controle,
  debut: t0,
  fin: t0.add(Duration(days: jours)),
  correctionsRestantes: corrections,
  plafondMatieres: plafond,
);

void main() {
  group('activation d’un pack', () {
    test('court sur la durée du pack, à partir de maintenant', () {
      final s = activerPack(
        pack: packs['controle']!,
        source: SourceAbonnement.paiement,
        maintenant: t0,
      );

      expect(s.debut, t0);
      expect(s.fin, DateTime.utc(2026, 9, 16, 8));
    });

    test('reporte le crédit de corrections du pack', () {
      final s = activerPack(
        pack: packs['partiel']!,
        source: SourceAbonnement.paiement,
        maintenant: t0,
      );

      expect(s.correctionsRestantes, 10);
      expect(s.plafondMatieres, 5);
    });

    test('n’emporte aucune notion de reconduction', () {
      // Règle métier 1 : à `fin`, l'accès s'arrête, point. Aucun champ ne
      // décrit un renouvellement, et c'est volontaire.
      final s = activerPack(
        pack: packs['decouverte']!,
        source: SourceAbonnement.bonus,
        maintenant: t0,
      );

      expect(s.fin.difference(s.debut).inDays, 3);
      expect(estActif(s, t0.add(const Duration(days: 4))), isFalse);
    });
  });

  group('expiration des packs', () {
    test('est actif pendant la fenêtre, plus après', () {
      final s = sub(7);
      expect(estActif(s, t0), isTrue);
      expect(estActif(s, t0.add(const Duration(days: 6))), isTrue);
      expect(estActif(s, t0.add(const Duration(days: 7))), isFalse);
      expect(estActif(s, t0.subtract(const Duration(hours: 1))), isFalse);
    });

    test('passe en lecture seule à l’expiration, sans se renouveler', () {
      final acces = etatAcces([sub(7)], t0.add(const Duration(days: 30)));
      expect(acces, isA<AccesExpire>());
      expect((acces as AccesExpire).expireLe, t0.add(const Duration(days: 7)));
    });

    test('distingue « jamais payé » de « pack expiré »', () {
      expect(etatAcces([], t0), isA<AucunAcces>());
      expect(
        etatAcces([sub(7)], t0.add(const Duration(days: 30))),
        isA<AccesExpire>(),
      );
    });

    test('compte les jours restants au jour entier', () {
      final acces = etatAcces([sub(7)], t0.add(const Duration(hours: 36)));
      expect(acces, isA<AccesActif>());
      // 7 jours moins 36 heures = 5 jours et 12 heures → 5.
      expect((acces as AccesActif).joursRestants, 5);
    });
  });

  group('cumul de plusieurs packs', () {
    final controle = Abonnement(
      code: CodePack.controle,
      debut: t0,
      fin: DateTime.utc(2026, 9, 16, 8),
      correctionsRestantes: 3,
      plafondMatieres: 2,
    );
    final semestre = Abonnement(
      code: CodePack.semestre,
      debut: t0,
      fin: DateTime.utc(2027, 1, 7, 8),
      correctionsRestantes: 30,
      plafondMatieres: null,
    );

    test('retient la fin la plus lointaine et additionne les corrections', () {
      final acces = etatAcces([controle, semestre], t0);
      expect(acces, isA<AccesActif>());
      final a = acces as AccesActif;
      expect(a.fin, semestre.fin);
      expect(a.correctionsRestantes, 33);
      expect(a.packs, hasLength(2));
    });

    test('laisse l’illimité l’emporter sur un plafond chiffré', () {
      final acces = etatAcces([controle, semestre], t0);
      expect((acces as AccesActif).plafondMatieres, isNull);
    });

    test('prend le plafond le plus généreux entre deux packs limités', () {
      final partiel = Abonnement(
        code: CodePack.partiel,
        debut: controle.debut,
        fin: controle.fin,
        correctionsRestantes: controle.correctionsRestantes,
        plafondMatieres: 5,
      );

      final acces = etatAcces([controle, partiel], t0);
      expect((acces as AccesActif).plafondMatieres, 5);
    });

    test('ignore les lignes expirées dans le calcul', () {
      // Le contrôle est fini, le semestre court toujours.
      final acces = etatAcces([controle, semestre], DateTime.utc(2026, 10, 1, 8));
      final a = acces as AccesActif;
      expect(a.correctionsRestantes, 30);
      expect(a.packs, [CodePack.semestre]);
    });
  });

  group('droit à une correction', () {
    final actif = etatAcces([sub(7, corrections: 3)], t0);

    test('autorise quand le crédit et le quota le permettent', () {
      final d = peutCorriger(acces: actif, correctionsAujourdhui: 0);
      expect(d, isA<CorrectionAutorisee>());
      expect((d as CorrectionAutorisee).restantesAujourdhui, correctionsParJour);
    });

    test('applique le plafond de 5 par jour même en pack illimité', () {
      // C'est une protection de coût, pas une limite commerciale.
      final illimite = etatAcces([
        Abonnement(
          code: CodePack.semestre,
          debut: t0,
          fin: t0.add(const Duration(days: 120)),
          correctionsRestantes: 30,
          plafondMatieres: null,
        ),
      ], t0);

      final d = peutCorriger(
        acces: illimite,
        correctionsAujourdhui: correctionsParJour,
      );
      expect(d, isA<CorrectionRefusee>());
      expect(
        (d as CorrectionRefusee).motif,
        RefusCorrection.plafondJournalier,
      );
    });

    test('refuse quand le crédit du pack est épuisé', () {
      final epuise = etatAcces([sub(7, corrections: 0)], t0);
      final d = peutCorriger(acces: epuise, correctionsAujourdhui: 0);
      expect(d, isA<CorrectionRefusee>());
      expect((d as CorrectionRefusee).motif, RefusCorrection.creditEpuise);
    });

    test('refuse sans pack et sur pack expiré, avec des motifs distincts', () {
      final sansPack = peutCorriger(
        acces: const AucunAcces(),
        correctionsAujourdhui: 0,
      );
      expect((sansPack as CorrectionRefusee).motif, RefusCorrection.aucunPack);

      final expire = peutCorriger(
        acces: etatAcces([sub(7)], t0.add(const Duration(days: 30))),
        correctionsAujourdhui: 0,
      );
      expect((expire as CorrectionRefusee).motif, RefusCorrection.packExpire);
    });
  });

  group('plafond de matières', () {
    final deuxMatieres = etatAcces([sub(7, plafond: 2)], t0);

    test('laisse ajouter sous le plafond et refuse au-delà', () {
      expect(
        peutAjouterMatiere(acces: deuxMatieres, matieresActives: 1),
        isTrue,
      );
      expect(
        peutAjouterMatiere(acces: deuxMatieres, matieresActives: 2),
        isFalse,
      );
    });

    test('ne plafonne jamais un pack illimité', () {
      final illimite = etatAcces([sub(120, plafond: null)], t0);
      expect(peutAjouterMatiere(acces: illimite, matieresActives: 99), isTrue);
    });

    test('refuse dès que l’accès n’est plus actif', () {
      expect(
        peutAjouterMatiere(acces: const AucunAcces(), matieresActives: 0),
        isFalse,
      );
      expect(
        peutAjouterMatiere(
          acces: etatAcces([sub(7)], t0.add(const Duration(days: 30))),
          matieresActives: 0,
        ),
        isFalse,
      );
    });
  });
}
