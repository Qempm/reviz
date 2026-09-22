/// Commissions de parrainage (CLAUDE.md, règle métier 2).
///
/// Port de `lib/payments/commission.ts`. 25 % du montant de chaque paiement du
/// filleul, 35 % si **le parrain** est ambassadeur, pendant 12 mois à partir
/// du premier paiement.
///
/// Un filleul ne compte que s'il est vérifié et a payé au moins une fois : le
/// premier paiement est donc celui qui ouvre la fenêtre, et il est lui-même
/// commissionné.
///
/// Côté Flutter, cela sert à expliquer un montant à l'écran. Le crédit réel
/// est écrit par le webhook serveur, dans `wallet_ledger`.
library;

const double tauxStandard = 0.25;
const double tauxAmbassadeur = 0.35;

/// Seuil de retrait, en FCFA (règle métier 2).
const int seuilRetraitFcfa = 3000;

/// Durée de la fenêtre de commission après le premier paiement.
const int fenetreMois = 12;

/// Arithmétique de calendrier qui **préserve le caractère UTC**.
///
/// Différence réelle entre Dart et JavaScript : un `DateTime` sait s'il est
/// local ou UTC, alors qu'un `Date` n'a pas cette saveur. Reconstruire avec
/// `DateTime(...)` à partir d'une date UTC la ramènerait en heure locale, et
/// une fenêtre de 12 mois calculée depuis un horodatage serveur se
/// décalerait du fuseau de l'appareil.
DateTime _decaler(DateTime base, {int jours = 0, int mois = 0}) {
  final construire = base.isUtc ? DateTime.utc : DateTime.new;
  return construire(
    base.year,
    base.month + mois,
    base.day + jours,
    base.hour,
    base.minute,
    base.second,
    base.millisecond,
    base.microsecond,
  );
}

enum StatutVerification { aucun, enAttente, verifie, rejete }

class Parrainage {
  const Parrainage({
    required this.parrainId,
    required this.filleulId,
    this.premierPaiement,
  });

  final String parrainId;
  final String filleulId;

  /// `null` tant que le filleul n'a jamais payé.
  final DateTime? premierPaiement;
}

class EtatParrain {
  const EtatParrain({required this.id, required this.estAmbassadeur});
  final String id;
  final bool estAmbassadeur;
}

class EtatFilleul {
  const EtatFilleul({required this.id, required this.verification});
  final String id;
  final StatutVerification verification;
}

enum MotifRefusCommission {
  filleulNonVerifie,
  fenetreExpiree,
  parrainEstLeFilleul,
  montantNul,
}

sealed class Commission {
  const Commission();
}

class CommissionDue extends Commission {
  const CommissionDue({
    required this.parrainId,
    required this.taux,
    required this.montantFcfa,
    required this.expireLe,
    required this.ouvreLaFenetre,
  });

  final String parrainId;

  /// Taux appliqué : 0.25 ou 0.35.
  final double taux;
  final int montantFcfa;

  /// Fin de la fenêtre de 12 mois, telle qu'elle doit être enregistrée.
  final DateTime expireLe;

  /// Vrai si ce paiement est celui qui ouvre la fenêtre.
  final bool ouvreLaFenetre;
}

class CommissionRefusee extends Commission {
  const CommissionRefusee(this.motif);
  final MotifRefusCommission motif;
}

/// Fin de la fenêtre de commission pour un premier paiement donné.
///
/// Arithmétique de calendrier, volontairement : « la même date douze mois plus
/// tard », et non 8 760 heures. Un calcul en millisecondes décalerait la date
/// d'un jour les années bissextiles. Le 29 février bascule au 1er mars,
/// comportement natif de `DateTime`.
DateTime finDeFenetre(DateTime premierPaiement) =>
    _decaler(premierPaiement, mois: fenetreMois);

/// Taux applicable à un parrain.
///
/// DÉCISION : le taux est déterminé par le statut d'ambassadeur **au moment du
/// paiement**, pas figé à la création du parrainage. Devenir ambassadeur
/// améliore donc immédiatement les commissions à venir, sans rétroactivité.
///
/// Et il se lit sur le **parrain**, jamais sur le filleul : le webhook web
/// s'est trompé exactement là (rapport § 4.4).
double tauxParrain(EtatParrain parrain) =>
    parrain.estAmbassadeur ? tauxAmbassadeur : tauxStandard;

/// Commission due au parrain pour un paiement réussi du filleul.
Commission calculerCommission({
  required Parrainage parrainage,
  required EtatParrain parrain,
  required EtatFilleul filleul,
  required int montantFcfa,
  DateTime? maintenant,
}) {
  final n = maintenant ?? DateTime.now();

  // Anti-fraude : on ne se parraine pas soi-même (règle métier 3). La base
  // l'interdit déjà ; on ne verse rien si la ligne existait malgré tout.
  if (parrainage.parrainId == parrainage.filleulId) {
    return const CommissionRefusee(MotifRefusCommission.parrainEstLeFilleul);
  }

  if (filleul.verification != StatutVerification.verifie) {
    return const CommissionRefusee(MotifRefusCommission.filleulNonVerifie);
  }

  if (montantFcfa <= 0) {
    return const CommissionRefusee(MotifRefusCommission.montantNul);
  }

  // Premier paiement : il ouvre la fenêtre et est lui-même commissionné.
  final ouvre = parrainage.premierPaiement == null;
  final debut = parrainage.premierPaiement ?? n;
  final expireLe = finDeFenetre(debut);

  if (!ouvre && !n.isBefore(expireLe)) {
    return const CommissionRefusee(MotifRefusCommission.fenetreExpiree);
  }

  final taux = tauxParrain(parrain);

  return CommissionDue(
    parrainId: parrain.id,
    taux: taux,
    // Le FCFA n'a pas de subdivision : on arrondit à l'unité.
    montantFcfa: (montantFcfa * taux).round(),
    expireLe: expireLe,
    ouvreLaFenetre: ouvre,
  );
}

/// Solde du portefeuille : somme du grand livre, jamais une colonne.
int soldeDepuisGrandLivre(Iterable<int> montants) =>
    montants.fold(0, (total, m) => total + m);

enum RefusRetrait { sousLeSeuil, soldeInsuffisant, montantInvalide }

sealed class Retrait {
  const Retrait();
}

class RetraitAutorise extends Retrait {
  const RetraitAutorise(this.montantFcfa);
  final int montantFcfa;
}

class RetraitRefuse extends Retrait {
  const RetraitRefuse(this.motif, {required this.seuil, required this.solde});
  final RefusRetrait motif;
  final int seuil;
  final int solde;
}

/// Un retrait est-il possible ?
///
/// Deux conditions distinctes : atteindre le seuil de 3 000 F, et disposer du
/// solde. Les distinguer permet d'afficher le bon message — « encore 1 200 F
/// avant de pouvoir retirer » n'est pas « solde insuffisant ». L'écran web les
/// confond aujourd'hui (rapport § 4.12).
Retrait verifierRetrait({required int soldeFcfa, required int montantFcfa}) {
  if (montantFcfa <= 0) {
    return RetraitRefuse(
      RefusRetrait.montantInvalide,
      seuil: seuilRetraitFcfa,
      solde: soldeFcfa,
    );
  }

  if (montantFcfa < seuilRetraitFcfa) {
    return RetraitRefuse(
      RefusRetrait.sousLeSeuil,
      seuil: seuilRetraitFcfa,
      solde: soldeFcfa,
    );
  }

  if (montantFcfa > soldeFcfa) {
    return RetraitRefuse(
      RefusRetrait.soldeInsuffisant,
      seuil: seuilRetraitFcfa,
      solde: soldeFcfa,
    );
  }

  return RetraitAutorise(montantFcfa);
}
