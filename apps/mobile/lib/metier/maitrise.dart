/// La maîtrise d'un chapitre : de « à découvrir » à trois couronnes.
///
/// La règle précédente (vue `chapter_stats`) avait trois défauts vérifiés
/// le 30 septembre 2026 :
///  - « À revoir » exigeait cinq questions tentées, or un chapitre en porte
///    quatre : jamais vrai ;
///  - le taux se calculait sur les questions **tentées** : une seule bonne
///    réponse sur quatre questions faisait 100 % ;
///  - les questions de secours, sans réponse possible, comptaient dans le
///    total.
///
/// Ici, **sur les seuls QCM** et la **dernière réponse** à chacun :
///  - tant que tous les QCM n'ont pas été tentés : « à découvrir » (ou « à
///    revoir » si la moitié est tentée et moins de la moitié juste) ;
///  - tous tentés : 1 couronne à 50 % de justes, 2 à 80 %, 3 à 100 % **et**
///    chaque question juste deux jours différents — retenu, pas bachoté la
///    veille ;
///  - une couronne se perd si la dernière réponse devient fausse.
///
/// Même règle, mêmes cas de test : `lib/metier/maitrise.ts`.
library;

enum EtatChapitre {
  /// Le chapitre précédent n'a pas encore de couronne.
  verrouille,

  /// Ouvert, pas encore tous les QCM tentés.
  aDecouvrir,

  /// Au moins la moitié tentée, moins de la moitié juste.
  aRevoir,

  /// Tous les QCM tentés, au moins la moitié juste : 1 à 3 couronnes.
  couronne,

  /// Aucun QCM jouable : ne bloque pas la suite.
  sansQcm,
}

/// Une réponse de l'étudiant.
class Tentative {
  const Tentative({
    required this.questionId,
    required this.juste,
    required this.le,
  });

  final String questionId;
  final bool juste;
  final DateTime le;
}

class Maitrise {
  const Maitrise({
    required this.etat,
    required this.couronnes,
    required this.total,
    required this.tentees,
    required this.justes,
  });

  final EtatChapitre etat;

  /// 0 à 3.
  final int couronnes;

  /// Nombre de QCM du chapitre.
  final int total;

  /// QCM déjà répondus au moins une fois.
  final int tentees;

  /// QCM justes à la dernière réponse.
  final int justes;

  /// Part tentée, de 0 à 1.
  double get couverture => total == 0 ? 0 : tentees / total;

  /// Part juste sur l'ensemble du chapitre, de 0 à 1.
  double get reussite => total == 0 ? 0 : justes / total;

  Maitrise verrouiller() => Maitrise(
    etat: EtatChapitre.verrouille,
    couronnes: 0,
    total: total,
    tentees: tentees,
    justes: justes,
  );
}

/// Le jour calendaire d'une réponse, en UTC : le même pour le serveur et
/// pour le téléphone.
String _jour(DateTime d) {
  final u = d.toUtc();
  return '${u.year}-${u.month}-${u.day}';
}

/// La maîtrise d'un chapitre, à partir de ses QCM et de toutes les réponses
/// de l'étudiant à ces QCM (dans n'importe quel ordre).
Maitrise maitriseChapitre({
  required List<String> qcm,
  required List<Tentative> tentatives,
}) {
  final total = qcm.length;
  if (total == 0) {
    return const Maitrise(
      etat: EtatChapitre.sansQcm,
      couronnes: 0,
      total: 0,
      tentees: 0,
      justes: 0,
    );
  }

  final ids = qcm.toSet();
  final derniere = <String, Tentative>{};
  final joursJustes = <String, Set<String>>{};
  for (final t in tentatives) {
    if (!ids.contains(t.questionId)) continue;
    final d = derniere[t.questionId];
    if (d == null || t.le.isAfter(d.le)) derniere[t.questionId] = t;
    if (t.juste) {
      (joursJustes[t.questionId] ??= <String>{}).add(_jour(t.le));
    }
  }

  final tentees = derniere.length;
  final justes = derniere.values.where((t) => t.juste).length;

  Maitrise avec(EtatChapitre etat, [int couronnes = 0]) => Maitrise(
    etat: etat,
    couronnes: couronnes,
    total: total,
    tentees: tentees,
    justes: justes,
  );

  if (tentees < total) {
    final aRevoir = tentees * 2 >= total && justes * 2 < tentees;
    return avec(aRevoir ? EtatChapitre.aRevoir : EtatChapitre.aDecouvrir);
  }

  // Tous tentés.
  if (justes * 2 < total) return avec(EtatChapitre.aRevoir);
  if (justes == total &&
      qcm.every((id) => (joursJustes[id]?.length ?? 0) >= 2)) {
    return avec(EtatChapitre.couronne, 3);
  }
  if (justes * 5 >= total * 4) return avec(EtatChapitre.couronne, 2);
  return avec(EtatChapitre.couronne, 1);
}

/// Le chemin d'un cours : chaque chapitre s'ouvre quand le précédent a au
/// moins une couronne. Le premier est toujours ouvert ; un chapitre sans QCM
/// ne bloque pas la suite ; et un chapitre **déjà commencé ne se referme
/// jamais** — perdre la couronne du chapitre 1 ne doit pas reverrouiller le
/// chapitre 4 sur lequel l'étudiant travaille.
List<Maitrise> cheminDuCours(List<Maitrise> chapitresDansLOrdre) {
  final sortie = <Maitrise>[];
  var precedentCouronne = true;
  for (final m in chapitresDansLOrdre) {
    if (m.etat == EtatChapitre.sansQcm) {
      sortie.add(m);
      continue;
    }
    final ouvert = precedentCouronne || m.tentees > 0;
    sortie.add(ouvert ? m : m.verrouiller());
    precedentCouronne = m.couronnes >= 1;
  }
  return sortie;
}
