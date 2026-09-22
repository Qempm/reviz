/// Barème d'expérience.
///
/// Port de `lib/xp/attribution.ts`. Côté Flutter, ce barème sert **à
/// l'affichage** : annoncer « +30 XP » sans attendre l'aller-retour. C'est le
/// serveur qui écrit, parce que `xp_events` n'a volontairement aucune
/// politique d'insertion cliente — un étudiant qui pourrait y insérer
/// s'offrirait la première place du classement.
library;

/// Motifs de `xp_events.reason`, tels que l'énumération Postgres les nomme.
enum MotifXp {
  correctAnswer('correct_answer'),
  quizCompleted('quiz_completed'),
  dailyGoal('daily_goal'),
  streakBonus('streak_bonus'),
  courseAdded('course_added'),
  correctionDone('correction_done'),
  referral('referral'),
  adjustment('adjustment');

  const MotifXp(this.sql);

  /// La valeur telle qu'elle existe dans l'énumération Postgres.
  final String sql;

  static MotifXp? depuisSql(String valeur) {
    for (final m in MotifXp.values) {
      if (m.sql == valeur) return m;
    }
    return null;
  }
}

class GainXp {
  const GainXp(this.motif, this.montant, {this.referenceId});

  final MotifXp motif;
  final int montant;

  /// Ligne d'origine — question, cours, correction, filleul.
  final String? referenceId;

  @override
  bool operator ==(Object other) =>
      other is GainXp &&
      other.motif == motif &&
      other.montant == montant &&
      other.referenceId == referenceId;

  @override
  int get hashCode => Object.hash(motif, montant, referenceId);

  @override
  String toString() => 'GainXp(${motif.sql}, $montant)';
}

/// Points par événement.
///
/// Une bonne réponse vaut peu et une journée validée vaut beaucoup : c'est la
/// régularité qu'on récompense, pas le volume. Un étudiant qui enchaîne
/// 300 questions un dimanche ne doit pas dépasser celui qui en fait dix par
/// jour toute la semaine.
const Map<MotifXp, int> bareme = {
  MotifXp.correctAnswer: 10,
  MotifXp.quizCompleted: 20,
  MotifXp.dailyGoal: 30,
  MotifXp.courseAdded: 25,
  MotifXp.correctionDone: 40,
  MotifXp.referral: 500,
};

/// Plafond du bonus de série, atteint à dix jours.
const int bonusSerieMax = 50;

/// Bonus de série : 5 points par jour consécutif, plafonné.
///
/// Sans plafond, une série de six mois vaudrait 900 points par jour et le
/// classement se figerait sur les premiers inscrits.
int bonusSerie(int jours) {
  if (jours <= 1) return 0;
  final brut = jours * 5;
  return brut > bonusSerieMax ? bonusSerieMax : brut;
}

/// Gains d'une session terminée.
///
/// Une seule ligne par motif, jamais une par bonne réponse : le journal doit
/// rester lisible, et `xp_events` sert aussi à l'audit d'un litige de
/// classement.
///
/// [objectifAtteint] se lit sur `daily_activity.is_validated`, posé par le
/// trigger `track_attempt()`, et non recalculé ici : la base a le compte exact
/// des questions du jour, l'écran n'a que celles de sa session.
List<GainXp> gainsDeSession({
  required int bonnes,
  required int total,
  required bool objectifAtteint,
  int serie = 0,
}) {
  final gains = <GainXp>[];

  final b = bonnes < 0 ? 0 : bonnes;
  final t = total < 0 ? 0 : total;

  if (b > 0) {
    gains.add(GainXp(MotifXp.correctAnswer, b * bareme[MotifXp.correctAnswer]!));
  }

  // Une session vide ne se « termine » pas : sans quoi ouvrir puis quitter
  // l'écran rapporterait 20 points.
  if (t > 0) {
    gains.add(GainXp(MotifXp.quizCompleted, bareme[MotifXp.quizCompleted]!));
  }

  if (objectifAtteint) {
    gains.add(GainXp(MotifXp.dailyGoal, bareme[MotifXp.dailyGoal]!));

    final bonus = bonusSerie(serie);
    if (bonus > 0) gains.add(GainXp(MotifXp.streakBonus, bonus));
  }

  return gains;
}

/// Total d'une liste de gains, pour l'afficher d'un chiffre.
int totalGains(Iterable<GainXp> gains) =>
    gains.fold(0, (somme, g) => somme + g.montant);
