import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/metier/commission.dart';

/// Port de `lib/payments/commission.test.ts` — 16 tests.

const parrain = EtatParrain(id: 'a', estAmbassadeur: false);
const ambassadeur = EtatParrain(id: 'a', estAmbassadeur: true);
const filleul = EtatFilleul(id: 'b', verification: StatutVerification.verifie);

Parrainage parrainage([DateTime? premierPaiement]) => Parrainage(
  parrainId: 'a',
  filleulId: 'b',
  premierPaiement: premierPaiement,
);

final janvier = DateTime.utc(2026, 1, 15, 10);

void main() {
  group('calcul des commissions', () {
    test('verse 25 % au parrain standard', () {
      final c = calculerCommission(
        parrainage: parrainage(),
        parrain: parrain,
        filleul: filleul,
        montantFcfa: 2000,
        maintenant: janvier,
      );

      expect(c, isA<CommissionDue>());
      final due = c as CommissionDue;
      expect(due.taux, tauxStandard);
      expect(due.montantFcfa, 500);
      expect(due.parrainId, 'a');
    });

    test('verse 35 % à l’ambassadeur', () {
      final c = calculerCommission(
        parrainage: parrainage(),
        parrain: ambassadeur,
        filleul: filleul,
        montantFcfa: 2000,
        maintenant: janvier,
      );

      expect(c, isA<CommissionDue>());
      final due = c as CommissionDue;
      expect(due.taux, tauxAmbassadeur);
      expect(due.montantFcfa, 700);
    });

    test('commissionne le premier paiement et ouvre la fenêtre de 12 mois', () {
      final c = calculerCommission(
        parrainage: parrainage(),
        parrain: parrain,
        filleul: filleul,
        montantFcfa: 1500,
        maintenant: janvier,
      );

      expect(c, isA<CommissionDue>());
      final due = c as CommissionDue;
      expect(due.ouvreLaFenetre, isTrue);
      expect(due.expireLe, DateTime.utc(2027, 1, 15, 10));
    });

    test('ne verse rien si le filleul n’est pas vérifié', () {
      for (final statut in [
        StatutVerification.aucun,
        StatutVerification.enAttente,
        StatutVerification.rejete,
      ]) {
        final c = calculerCommission(
          parrainage: parrainage(),
          parrain: parrain,
          filleul: EtatFilleul(id: 'b', verification: statut),
          montantFcfa: 2000,
          maintenant: janvier,
        );

        expect(c, isA<CommissionRefusee>(), reason: statut.name);
        expect(
          (c as CommissionRefusee).motif,
          MotifRefusCommission.filleulNonVerifie,
        );
      }
    });

    test('ne verse plus rien passé les 12 mois', () {
      final premier = DateTime.utc(2026, 1, 15, 10);

      Commission a(DateTime quand) => calculerCommission(
        parrainage: parrainage(premier),
        parrain: parrain,
        filleul: filleul,
        montantFcfa: 3500,
        maintenant: quand,
      );

      // Onze mois après : encore dans la fenêtre.
      expect(a(DateTime.utc(2026, 12, 15, 10)), isA<CommissionDue>());

      // Exactement 12 mois : la fenêtre est fermée, borne exclue.
      final pile = a(DateTime.utc(2027, 1, 15, 10));
      expect(pile, isA<CommissionRefusee>());
      expect(
        (pile as CommissionRefusee).motif,
        MotifRefusCommission.fenetreExpiree,
      );

      // Un an et un jour : fermée aussi.
      expect(a(DateTime.utc(2027, 1, 16, 10)), isA<CommissionRefusee>());
    });

    test('refuse un parrainage de soi-même', () {
      final c = calculerCommission(
        parrainage: const Parrainage(parrainId: 'a', filleulId: 'a'),
        parrain: parrain,
        filleul: const EtatFilleul(
          id: 'a',
          verification: StatutVerification.verifie,
        ),
        montantFcfa: 2000,
        maintenant: janvier,
      );

      expect(c, isA<CommissionRefusee>());
      expect(
        (c as CommissionRefusee).motif,
        MotifRefusCommission.parrainEstLeFilleul,
      );
    });

    test('refuse un montant nul ou négatif', () {
      for (final montant in [0, -500]) {
        final c = calculerCommission(
          parrainage: parrainage(),
          parrain: parrain,
          filleul: filleul,
          montantFcfa: montant,
          maintenant: janvier,
        );

        expect(c, isA<CommissionRefusee>(), reason: '$montant');
        expect(
          (c as CommissionRefusee).motif,
          MotifRefusCommission.montantNul,
        );
      }
    });

    test('arrondit à l’unité : le FCFA n’a pas de subdivision', () {
      final c = calculerCommission(
        parrainage: parrainage(),
        parrain: parrain,
        filleul: filleul,
        // 25 % de 501 = 125,25
        montantFcfa: 501,
        maintenant: janvier,
      );

      expect(c, isA<CommissionDue>());
      expect((c as CommissionDue).montantFcfa, 125);
    });

    test('gère le 29 février sans déborder', () {
      // 12 mois après le 29/02/2028 : 2029 n'est pas bissextile.
      final fin = finDeFenetre(DateTime.utc(2028, 2, 29, 10));
      expect(fin.year, 2029);
      // `DateTime` reporte au 1er mars plutôt que de produire une date
      // invalide, exactement comme `Date` côté TypeScript.
      expect(fin.month, 3);
      expect(fin.day, 1);
    });

    test('la grille de prix retenue donne des commissions entières', () {
      // Grille « accessible » arbitrée le 08/09/2026.
      for (final prix in [500, 1500, 3500, 2000]) {
        for (final etat in [parrain, ambassadeur]) {
          final c = calculerCommission(
            parrainage: parrainage(),
            parrain: etat,
            filleul: filleul,
            montantFcfa: prix,
            maintenant: janvier,
          );

          if (c is CommissionDue) {
            expect(c.montantFcfa, (prix * c.taux).round());
          }
        }
      }
    });

    test('le taux se lit sur le parrain, jamais sur le filleul', () {
      // C'est l'inversion exacte du webhook web (rapport § 4.4) : un parrain
      // ambassadeur doit toucher 35 % même si son filleul ne l'est pas.
      expect(tauxParrain(ambassadeur), tauxAmbassadeur);
      expect(tauxParrain(parrain), tauxStandard);
    });
  });

  group('solde du portefeuille', () {
    test('est la somme du grand livre, retraits compris', () {
      expect(
        soldeDepuisGrandLivre([875, 875, 1225, -3000, 500]),
        475,
      );
    });

    test('vaut zéro sur un grand livre vide', () {
      expect(soldeDepuisGrandLivre([]), 0);
    });
  });

  group('demande de retrait', () {
    test('exige le seuil de 3 000 F', () {
      final r = verifierRetrait(soldeFcfa: 5000, montantFcfa: 2999);
      expect(r, isA<RetraitRefuse>());
      final refus = r as RetraitRefuse;
      expect(refus.motif, RefusRetrait.sousLeSeuil);
      expect(refus.seuil, seuilRetraitFcfa);
    });

    test('accepte pile au seuil', () {
      expect(
        verifierRetrait(soldeFcfa: 3000, montantFcfa: 3000),
        isA<RetraitAutorise>(),
      );
    });

    test('distingue le seuil non atteint du solde insuffisant', () {
      // Le message affiché n'est pas le même : « encore 1 200 F avant de
      // pouvoir retirer » n'est pas « solde insuffisant ».
      final r = verifierRetrait(soldeFcfa: 3200, montantFcfa: 4000);
      expect(r, isA<RetraitRefuse>());
      expect((r as RetraitRefuse).motif, RefusRetrait.soldeInsuffisant);
    });

    test('refuse un montant nul ou négatif', () {
      // Le cas « 3000.5 » du TypeScript n'existe pas ici : `int` l'interdit
      // par construction.
      for (final m in [0, -3000]) {
        final r = verifierRetrait(soldeFcfa: 10000, montantFcfa: m);
        expect(r, isA<RetraitRefuse>(), reason: '$m');
        expect((r as RetraitRefuse).motif, RefusRetrait.montantInvalide);
      }
    });
  });
}
