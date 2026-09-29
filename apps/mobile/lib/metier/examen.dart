/// Jours restants avant un examen.
///
/// Sorti de l'écran du cours quand l'accueil a eu besoin du même compte à
/// rebours : deux écrans qui calculent « J−3 » chacun à leur façon finissent
/// par ne plus dire la même chose.
library;

/// Jours restants avant l'examen, `null` s'il est passé ou illisible.
///
/// Arithmétique de calendrier, pas de millisecondes : « demain » doit rester
/// « demain » quelle que soit l'heure qu'il est.
int? joursAvant(String iso, {DateTime? maintenant}) {
  final p = iso.split('T').first.split('-');
  if (p.length < 3) return null;
  final a = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  final j = int.tryParse(p[2]);
  if (a == null || m == null || j == null) return null;

  final examen = DateTime(a, m, j);
  final n = maintenant ?? DateTime.now();
  final aujourdhui = DateTime(n.year, n.month, n.day);

  final jours = examen.difference(aujourdhui).inDays;
  return jours < 0 ? null : jours;
}
