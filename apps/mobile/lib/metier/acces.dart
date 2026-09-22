/// Packs, accès et plafonds.
///
/// Port de `lib/payments/subscriptions.ts`. Côté Flutter, cela sert à
/// l'affichage — « 3 corrections restantes », « accès actif encore 12 jours »
/// — sans aller-retour. Le serveur revérifie avant d'écrire : un écran ne
/// protège rien.
///
/// Règle métier 1 : paiement unique par pack, **aucun prélèvement
/// récurrent**. À l'expiration, l'accès s'arrête, point.
library;

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

enum CodePack {
  decouverte('decouverte'),
  controle('controle'),
  partiel('partiel'),
  semestre('semestre'),
  rattrapage('rattrapage');

  const CodePack(this.sql);
  final String sql;

  static CodePack? depuisSql(String valeur) {
    for (final c in CodePack.values) {
      if (c.sql == valeur) return c;
    }
    return null;
  }
}

enum SourceAbonnement { paiement, achatClasse, bonus }

class Pack {
  const Pack({
    required this.code,
    required this.dureeJours,
    required this.correctionsIncluses,
    required this.plafondMatieres,
  });

  final CodePack code;
  final int dureeJours;
  final int correctionsIncluses;

  /// `null` vaut illimité.
  final int? plafondMatieres;
}

class Abonnement {
  const Abonnement({
    required this.code,
    required this.debut,
    required this.fin,
    required this.correctionsRestantes,
    required this.plafondMatieres,
  });

  final CodePack code;
  final DateTime debut;
  final DateTime fin;
  final int correctionsRestantes;
  final int? plafondMatieres;
}

/// Valeurs d'une nouvelle ligne `subscriptions` à l'activation d'un pack.
///
/// Un nouvel achat ne prolonge pas l'accès en cours : il crée une ligne qui
/// démarre maintenant. Les packs se cumulent donc, et l'accès effectif est
/// l'union des lignes actives — ce qui évite d'avoir à fusionner des plafonds
/// de matières hétérogènes en une seule ligne.
Abonnement activerPack({
  required Pack pack,
  required SourceAbonnement source,
  DateTime? maintenant,
}) {
  final debut = maintenant ?? DateTime.now();

  // Arithmétique de calendrier : « la même heure, N jours plus tard ». Un
  // pack de 7 jours acheté à 08:00 expire à 08:00.
  final fin = _decaler(debut, jours: pack.dureeJours);

  return Abonnement(
    code: pack.code,
    debut: debut,
    fin: fin,
    correctionsRestantes: pack.correctionsIncluses,
    plafondMatieres: pack.plafondMatieres,
  );
}

bool estActif(Abonnement a, [DateTime? maintenant]) {
  final n = maintenant ?? DateTime.now();
  return !a.debut.isAfter(n) && a.fin.isAfter(n);
}

/// État d'accès d'un étudiant.
sealed class EtatAcces {
  const EtatAcces();
}

/// Au moins un pack en cours : tout est ouvert.
class AccesActif extends EtatAcces {
  const AccesActif({
    required this.fin,
    required this.joursRestants,
    required this.correctionsRestantes,
    required this.plafondMatieres,
    required this.packs,
  });

  /// Fin de l'accès la plus lointaine.
  final DateTime fin;

  /// Jours entiers restants, arrondis au plus proche par le bas.
  final int joursRestants;
  final int correctionsRestantes;

  /// `null` vaut illimité.
  final int? plafondMatieres;
  final List<CodePack> packs;
}

/// Des packs ont existé mais aucun n'est en cours : lecture seule.
class AccesExpire extends EtatAcces {
  const AccesExpire(this.expireLe);
  final DateTime expireLe;
}

/// Aucun pack n'a jamais été acheté.
class AucunAcces extends EtatAcces {
  const AucunAcces();
}

const int _jourMs = 24 * 60 * 60 * 1000;

/// État d'accès à partir des lignes d'abonnement.
///
/// Les plafonds se cumulent : le plafond de matières effectif est le plus
/// généreux des packs actifs, et illimité l'emporte sur tout. Les corrections
/// restantes s'additionnent.
EtatAcces etatAcces(List<Abonnement> abonnements, [DateTime? maintenant]) {
  if (abonnements.isEmpty) return const AucunAcces();

  final n = maintenant ?? DateTime.now();
  final actifs = abonnements.where((a) => estActif(a, n)).toList();

  if (actifs.isEmpty) {
    // Lecture seule : on garde la date de fin la plus récente pour l'écran
    // « pack expiré ».
    final expireLe = abonnements
        .map((a) => a.fin)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    return AccesExpire(expireLe);
  }

  final fin = actifs.map((a) => a.fin).reduce((a, b) => a.isAfter(b) ? a : b);

  // Illimité l'emporte : une seule ligne à null suffit.
  final illimite = actifs.any((a) => a.plafondMatieres == null);
  final plafond = illimite
      ? null
      : actifs.map((a) => a.plafondMatieres ?? 0).reduce((a, b) => a > b ? a : b);

  final restant = fin.difference(n).inMilliseconds ~/ _jourMs;

  return AccesActif(
    fin: fin,
    joursRestants: restant < 0 ? 0 : restant,
    correctionsRestantes: actifs.fold(0, (t, a) => t + a.correctionsRestantes),
    plafondMatieres: plafond,
    packs: actifs.map((a) => a.code).toList(),
  );
}

/// Plafond de corrections par jour, tous packs confondus (règle métier 5).
const int correctionsParJour = 5;

enum RefusCorrection { packExpire, aucunPack, creditEpuise, plafondJournalier }

sealed class DroitCorrection {
  const DroitCorrection();
}

class CorrectionAutorisee extends DroitCorrection {
  const CorrectionAutorisee(this.restantesAujourdhui);
  final int restantesAujourdhui;
}

class CorrectionRefusee extends DroitCorrection {
  const CorrectionRefusee(this.motif);
  final RefusCorrection motif;
}

/// L'étudiant peut-il demander une correction maintenant ?
///
/// Le plafond journalier s'applique **même en pack illimité** : c'est une
/// protection de coût, pas une limite commerciale.
DroitCorrection peutCorriger({
  required EtatAcces acces,
  required int correctionsAujourdhui,
}) {
  switch (acces) {
    case AucunAcces():
      return const CorrectionRefusee(RefusCorrection.aucunPack);
    case AccesExpire():
      return const CorrectionRefusee(RefusCorrection.packExpire);
    case AccesActif(:final correctionsRestantes):
      if (correctionsAujourdhui >= correctionsParJour) {
        return const CorrectionRefusee(RefusCorrection.plafondJournalier);
      }
      if (correctionsRestantes <= 0) {
        return const CorrectionRefusee(RefusCorrection.creditEpuise);
      }
      return CorrectionAutorisee(correctionsParJour - correctionsAujourdhui);
  }
}

/// L'étudiant peut-il ajouter une matière de plus ?
bool peutAjouterMatiere({
  required EtatAcces acces,
  required int matieresActives,
}) {
  if (acces is! AccesActif) return false;
  if (acces.plafondMatieres == null) return true;
  return matieresActives < acces.plafondMatieres!;
}
