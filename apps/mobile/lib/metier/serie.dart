/// État réel d'une série de révision.
///
/// Port de `lib/xp/serie.ts`. `public.refresh_streak()` ne remet jamais
/// `profiles.current_streak` à zéro de lui-même : il n'y a pas de tâche à
/// minuit, et il n'en faut pas — cela réécrirait chaque nuit la ligne de tous
/// les étudiants inactifs. La migration confie donc explicitement cette charge
/// à l'affichage :
///
/// > La série affichée reste celle du dernier jour validé : elle ne se remet
/// > pas à zéro d'elle-même à minuit. C'est à l'affichage de la présenter
/// > comme rompue si last_validated_on est antérieur à hier.
///
/// **Le jour de référence est en UTC**, comme `daily_activity.day` et
/// `streak_week()`, qui tronquent `answered_at at time zone 'UTC'`. Le Bénin
/// est à UTC+1 sans heure d'été : une réponse donnée à 00 h 30 à Cotonou
/// compte donc pour la veille. Le décalage est réel mais cohérent de bout en
/// bout ; le corriger demanderait de changer la base, pas l'affichage.
library;

/// Jour courant en UTC, au format `YYYY-MM-DD`.
String jourUtc([DateTime? maintenant]) {
  final d = (maintenant ?? DateTime.now()).toUtc();
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Jour précédent celui donné, au même format.
String veille(String jour) {
  final p = jour.split('-').map(int.parse).toList();
  final d = DateTime.utc(p[0], p[1], p[2]).subtract(const Duration(days: 1));
  return jourUtc(d);
}

class EtatSerie {
  const EtatSerie({
    required this.jours,
    required this.rompue,
    required this.valideAujourdhui,
    required this.enJeu,
  });

  /// Jours à afficher : 0 dès que la série est rompue.
  final int jours;

  /// Le dernier jour validé est trop ancien : la série ne court plus.
  final bool rompue;

  /// Aujourd'hui est déjà validé.
  final bool valideAujourdhui;

  /// La série court encore mais aujourd'hui n'est pas validé : c'est le seul
  /// moment où il y a quelque chose à perdre, et donc le seul où il vaut la
  /// peine de le dire.
  final bool enJeu;

  @override
  bool operator ==(Object other) =>
      other is EtatSerie &&
      other.jours == jours &&
      other.rompue == rompue &&
      other.valideAujourdhui == valideAujourdhui &&
      other.enJeu == enJeu;

  @override
  int get hashCode => Object.hash(jours, rompue, valideAujourdhui, enJeu);

  @override
  String toString() =>
      'EtatSerie(jours: $jours, rompue: $rompue, '
      'valideAujourdhui: $valideAujourdhui, enJeu: $enJeu)';
}

/// [current] est `profiles.current_streak` tel quel, [lastValidatedOn] est
/// `profiles.last_validated_on` — date nue, ou `null`.
EtatSerie etatSerie({
  required int current,
  required String? lastValidatedOn,
  DateTime? maintenant,
}) {
  final aujourdhui = jourUtc(maintenant);
  final hier = veille(aujourdhui);

  // Un horodatage complet arriverait avec son heure : on ne garde que la
  // date, pour ne pas échouer sur un « T00:00:00+00:00 » de trop.
  final dernier = lastValidatedOn == null
      ? null
      : (lastValidatedOn.length >= 10
            ? lastValidatedOn.substring(0, 10)
            : lastValidatedOn);

  final jours = current < 0 ? 0 : current;

  if (dernier == null || dernier.compareTo(hier) < 0) {
    return const EtatSerie(
      jours: 0,
      rompue: true,
      valideAujourdhui: false,
      enJeu: false,
    );
  }

  if (dernier == aujourdhui) {
    return EtatSerie(
      jours: jours,
      rompue: false,
      valideAujourdhui: true,
      enJeu: false,
    );
  }

  // `dernier == hier` : la série tient, mais elle tombe à minuit UTC si rien
  // n'est répondu aujourd'hui.
  return EtatSerie(
    jours: jours,
    rompue: false,
    valideAujourdhui: false,
    enJeu: true,
  );
}

/// Progression vers l'objectif du jour, bornée à 1.
///
/// Répondre à trente questions ne remplit pas la barre trois fois : au-delà
/// de l'objectif, le jour est validé, point.
double progressionDuJour(int repondues, int objectif) {
  if (objectif <= 0) return 1;
  final r = repondues < 0 ? 0 : repondues;
  final v = r / objectif;
  return v > 1 ? 1 : v;
}

/// Questions restantes avant de valider la journée.
int resteAvantObjectif(int repondues, int objectif) {
  final r = repondues < 0 ? 0 : repondues;
  final reste = objectif - r;
  return reste < 0 ? 0 : reste;
}
