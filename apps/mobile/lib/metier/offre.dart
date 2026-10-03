/// L'offre telle que la boutique la présente : pack conseillé, objectif,
/// prix par jour.
///
/// Port de `lib/metier/offre.ts`, qui sert la page d'accueil publique : la
/// boutique de l'application et le site doivent dire la même chose du même
/// pack (« 50 F par jour », « Pour tes partiels, prends le pack Partiel… »).
/// Les tests de `test/offre_test.dart` reprennent les cas du serveur.
library;

import '../i18n/fr.dart' show milliers;

/// Le pack mis en avant par défaut : le meilleur rapport pour une période
/// d'examens. Même valeur que `PACK_CONSEILLE` côté serveur.
const String packConseille = 'partiel';

/// Ce qu'un étudiant prépare, et la phrase qui le dit.
class Objectif {
  const Objectif(this.bouton, this.phrase);

  /// Le libellé de la pastille : « Mes partiels ».
  final String bouton;

  /// Le complément de « Pour … » : « tes partiels ».
  final String phrase;
}

/// Un pack que cette table ne connaît pas (ajouté en base plus tard) reste
/// proposé, sous son propre nom.
const Map<String, Objectif> objectifs = {
  'controle': Objectif('Un contrôle continu', 'un contrôle continu'),
  'partiel': Objectif('Mes partiels', 'tes partiels'),
  'rattrapage': Objectif('Le rattrapage', 'le rattrapage'),
  'semestre': Objectif('Tout le semestre', 'tout le semestre'),
};

Objectif objectifDe(String code, String libelle) =>
    objectifs[code] ?? Objectif(libelle, libelle.toLowerCase());

/// « 1 semaine », « 1 mois », « 4 mois », « 3 jours ».
String dureeLisible(int jours) {
  if (jours >= 30 && jours % 30 == 0) {
    final mois = jours ~/ 30;
    return '$mois mois';
  }
  if (jours == 7) return '1 semaine';
  return jours <= 1 ? '$jours jour' : '$jours jours';
}

/// « Toutes tes matières », « 1 matière », « 5 matières ».
String matieresLisibles(int? n) {
  if (n == null) return 'Toutes tes matières';
  return n <= 1 ? '$n matière' : '$n matières';
}

/// « 1 correction », « 10 corrections ».
String correctionsLisibles(int n) =>
    n <= 1 ? '$n correction' : '$n corrections';

/// Ce que coûte un jour d'accès : « 50 F par jour », et « ≈ 71 F par jour »
/// quand la division ne tombe pas juste — un prix exact qui serait faux ferait
/// douter de tous les autres.
String prixParJour(int fcfa, int jours) {
  if (jours <= 0) return '';
  final exact = fcfa % jours == 0;
  final arrondi = (fcfa / jours).round();
  return '${exact ? '' : '≈ '}${milliers(arrondi)} F par jour';
}

/// Un pack réduit à ce que les calculs de l'offre regardent.
typedef PackOffre = ({String code, int prixFcfa, int jours});

/// Le pack payant le moins cher par jour, ou `null` s'il n'y en a pas.
String? meilleurPrixParJour(Iterable<PackOffre> packs) {
  PackOffre? meilleur;
  for (final p in packs) {
    if (p.prixFcfa <= 0 || p.jours <= 0) continue;
    if (meilleur == null ||
        p.prixFcfa / p.jours < meilleur.prixFcfa / meilleur.jours) {
      meilleur = p;
    }
  }
  return meilleur?.code;
}

/// « Pour tes partiels, prends le pack Partiel : 1 mois, 5 matières,
/// 10 corrections. »
String phraseConseil({
  required String code,
  required String libelle,
  required int jours,
  required int? matieres,
  required int corrections,
}) =>
    'Pour ${objectifDe(code, libelle).phrase}, prends le pack $libelle : '
    '${dureeLisible(jours)}, ${matieresLisibles(matieres).toLowerCase()}, '
    '${correctionsLisibles(corrections)}.';

/// Le pack à mettre en avant à l'ouverture : le conseillé s'il est en vente,
/// sinon le premier payant.
String? choixInitial(Iterable<PackOffre> payants) {
  final codes = payants.map((p) => p.code).toList();
  if (codes.contains(packConseille)) return packConseille;
  return codes.isEmpty ? null : codes.first;
}
