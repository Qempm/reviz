/// Les rappels du téléphone : quand, et quoi dire.
///
/// Trois moments où l'étudiant décroche, et où un mot au bon moment le fait
/// revenir :
///
///  - **sa série va tomber** : à 20 h, s'il n'a pas encore fait sa journée ;
///  - **son examen approche** : trois jours avant, puis la veille, à 18 h ;
///  - **son pack se termine demain** : à 10 h la veille, pour réactiver sans
///    perdre une journée.
///
/// Fonction pure, testée ; `donnees/rappels.dart` ne fait que programmer ce
/// qu'elle rend. Les rappels sont reprogrammés à chaque ouverture : un
/// rappel « série en danger » n'a plus lieu d'être une fois la journée faite.
library;

class Rappel {
  const Rappel({
    required this.id,
    required this.quand,
    required this.titre,
    required this.texte,
  });

  /// Stable par nature de rappel : reprogrammer remplace, sans doublon.
  final int id;
  final DateTime quand;
  final String titre;
  final String texte;
}

/// Un examen à venir : le titre du cours et sa date (jour, sans heure).
typedef ExamenAVenir = ({String titre, DateTime jour});

/// Identifiants réservés.
const idSerie = 1;
const idPackFin = 2;

/// 10 à 99 : les examens, dans l'ordre de leur date.
const idPremierExamen = 10;

DateTime _a(DateTime jour, int heure) =>
    DateTime(jour.year, jour.month, jour.day, heure);

List<Rappel> planifierRappels({
  required DateTime maintenant,
  required int serie,
  required bool journeeFaite,
  List<ExamenAVenir> examens = const [],
  DateTime? finPack,
  required String Function(int serie) titreSerie,
  required String texteSerie,
  required String Function(String titre, int jours) titreExamen,
  required String texteExamen,
  required String titrePack,
  required String textePack,
}) {
  final rappels = <Rappel>[];
  final aujourdhui = DateTime(
    maintenant.year,
    maintenant.month,
    maintenant.day,
  );

  // La série : ce soir s'il reste à faire, sinon demain soir. Aussi pour qui
  // n'a pas de série : c'est le rappel qui en lance une.
  final ceSoir = _a(aujourdhui, 20);
  final soir = !journeeFaite && ceSoir.isAfter(maintenant)
      ? ceSoir
      : _a(aujourdhui.add(const Duration(days: 1)), 20);
  rappels.add(
    Rappel(
      id: idSerie,
      quand: soir,
      titre: titreSerie(serie),
      texte: texteSerie,
    ),
  );

  // Les examens : J-3 et J-1 à 18 h, s'ils sont encore devant nous.
  final tries = [...examens]..sort((a, b) => a.jour.compareTo(b.jour));
  var n = 0;
  for (final e in tries) {
    for (final jours in const [3, 1]) {
      final quand = _a(e.jour.subtract(Duration(days: jours)), 18);
      if (!quand.isAfter(maintenant)) continue;
      if (n >= 90) break;
      rappels.add(
        Rappel(
          id: idPremierExamen + n++,
          quand: quand,
          titre: titreExamen(e.titre, jours),
          texte: texteExamen,
        ),
      );
    }
  }

  // Le pack : la veille de la fin, à 10 h.
  if (finPack != null) {
    final veille = finPack.toLocal().subtract(const Duration(days: 1));
    final quand = _a(veille, 10);
    if (quand.isAfter(maintenant)) {
      rappels.add(
        Rappel(id: idPackFin, quand: quand, titre: titrePack, texte: textePack),
      );
    }
  }

  return rappels;
}
