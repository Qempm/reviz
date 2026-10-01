/// Les rappels du téléphone : quand, et quoi dire.
///
/// Trois moments où l'étudiant décroche, et où un mot au bon moment le fait
/// revenir :
///
///  - **sa série va tomber** : à 20 h (ou l'heure qu'il a choisie), s'il n'a
///    pas encore fait sa journée ;
///  - **son examen approche** : trois jours avant, puis la veille, à 18 h ;
///  - **son pack se termine demain** : à 10 h la veille, pour réactiver sans
///    perdre une journée.
///
/// Fonction pure, testée ; `donnees/rappels.dart` ne fait que programmer ce
/// qu'elle rend. Les rappels sont reprogrammés à chaque ouverture : un
/// rappel « série en danger » n'a plus lieu d'être une fois la journée faite.
///
/// Chacun se coupe dans les réglages (`OptionsRappels`), et chacun mène à
/// un écran quand on le touche (`Rappel.lien`).
library;

class Rappel {
  const Rappel({
    required this.id,
    required this.quand,
    required this.titre,
    required this.texte,
    required this.lien,
  });

  /// Stable par nature de rappel : reprogrammer remplace, sans doublon.
  final int id;
  final DateTime quand;
  final String titre;
  final String texte;

  /// L'écran que le rappel ouvre (`routage.dart`).
  final String lien;
}

/// Un examen à venir : le cours, son titre et sa date (jour, sans heure).
typedef ExamenAVenir = ({String? coursId, String titre, DateTime jour});

/// Ce que l'étudiant a choisi dans ses réglages.
class OptionsRappels {
  const OptionsRappels({
    this.serie = true,
    this.heureSerie = heureSerieParDefaut,
    this.examens = true,
    this.finPack = true,
  });

  final bool serie;

  /// De [heureSerieMin] à [heureSerieMax].
  final int heureSerie;
  final bool examens;
  final bool finPack;

  OptionsRappels copier({
    bool? serie,
    int? heureSerie,
    bool? examens,
    bool? finPack,
  }) => OptionsRappels(
    serie: serie ?? this.serie,
    heureSerie: heureSerie ?? this.heureSerie,
    examens: examens ?? this.examens,
    finPack: finPack ?? this.finPack,
  );

  @override
  bool operator ==(Object other) =>
      other is OptionsRappels &&
      other.serie == serie &&
      other.heureSerie == heureSerie &&
      other.examens == examens &&
      other.finPack == finPack;

  @override
  int get hashCode => Object.hash(serie, heureSerie, examens, finPack);
}

const heureSerieParDefaut = 20;

/// Pas de rappel au milieu de la nuit : de 6 h à 23 h.
const heureSerieMin = 6;
const heureSerieMax = 23;

/// Les identifiants des rappels vont de 1 à 99 : au-delà, ce sont des
/// notifications affichées (un push reçu application ouverte), que
/// reprogrammer les rappels ne doit pas effacer.
const idRappelMax = 99;

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
  OptionsRappels options = const OptionsRappels(),
}) {
  final rappels = <Rappel>[];
  final aujourdhui = DateTime(
    maintenant.year,
    maintenant.month,
    maintenant.day,
  );

  // La série : ce soir s'il reste à faire, sinon demain soir. Aussi pour qui
  // n'a pas de série : c'est le rappel qui en lance une.
  if (options.serie) {
    final heure = options.heureSerie.clamp(heureSerieMin, heureSerieMax);
    final ceSoir = _a(aujourdhui, heure);
    final soir = !journeeFaite && ceSoir.isAfter(maintenant)
        ? ceSoir
        : _a(aujourdhui.add(const Duration(days: 1)), heure);
    rappels.add(
      Rappel(
        id: idSerie,
        quand: soir,
        titre: titreSerie(serie),
        texte: texteSerie,
        lien: '/',
      ),
    );
  }

  // Les examens : J-3 et J-1 à 18 h, s'ils sont encore devant nous.
  final tries = options.examens
      ? ([...examens]..sort((a, b) => a.jour.compareTo(b.jour)))
      : const <ExamenAVenir>[];
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
          lien: e.coursId == null ? '/reviser' : '/cours/${e.coursId}',
        ),
      );
    }
  }

  // Le pack : la veille de la fin, à 10 h.
  if (finPack != null && options.finPack) {
    final veille = finPack.toLocal().subtract(const Duration(days: 1));
    final quand = _a(veille, 10);
    if (quand.isAfter(maintenant)) {
      rappels.add(
        Rappel(
          id: idPackFin,
          quand: quand,
          titre: titrePack,
          texte: textePack,
          lien: '/boutique',
        ),
      );
    }
  }

  return rappels;
}
