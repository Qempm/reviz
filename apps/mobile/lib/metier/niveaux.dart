/// Les niveaux de compte : l'XP cumulée, découpée en paliers qui s'allongent.
///
/// Palier `n` atteint à `25·n·(n+3) − 100` XP : 150 pour le niveau 2, 350
/// pour le 3, 900 pour le 5, 3 150 pour le 10, 11 400 pour le 20. Une série de
/// dix questions rapporte de 100 à 150 XP : le niveau 2 tombe le premier
/// jour, le 5 en une semaine d'assiduité, le 10 en un mois — assez tôt pour
/// accrocher, assez loin pour durer toute une année universitaire.
library;

/// XP totale nécessaire pour atteindre le niveau `n` (1 au départ).
int seuilNiveau(int n) => n <= 1 ? 0 : 25 * n * (n + 3) - 100;

class Niveau {
  const Niveau({
    required this.numero,
    required this.xpDebut,
    required this.xpSuivant,
    required this.xp,
  });

  final int numero;

  /// XP totale à laquelle ce niveau a été atteint.
  final int xpDebut;

  /// XP totale du niveau suivant.
  final int xpSuivant;

  /// XP totale de l'étudiant.
  final int xp;

  /// Avancée dans le niveau, de 0 à 1.
  double get progression => (xp - xpDebut) / (xpSuivant - xpDebut);

  /// Ce qui manque pour le niveau suivant.
  int get xpRestants => xpSuivant - xp;
}

Niveau niveauDepuisXp(int xp) {
  final total = xp < 0 ? 0 : xp;
  var n = 1;
  while (seuilNiveau(n + 1) <= total) {
    n++;
  }
  return Niveau(
    numero: n,
    xpDebut: seuilNiveau(n),
    xpSuivant: seuilNiveau(n + 1),
    xp: total,
  );
}
