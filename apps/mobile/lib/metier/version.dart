// Faut-il mettre l'application à jour ?
//
// Cette question n'avait jamais reçu de réponse juste. Côté web,
// `lib/hooks/useVersionCheck.ts` lisait `version`, `minimumVersion` et
// `latestVersion` **du même fichier distant**, puis comparait les deux
// premiers : la comparaison était auto-référentielle, aucune version locale
// n'entrait dans le calcul, et l'état « mise à jour exigée » était donc
// structurellement inatteignable. Le composant qui l'utilisait n'était de
// toute façon monté nulle part.
//
// Ici, la version locale vient du paquet installé (`package_info_plus`) et les
// seuils viennent de `/version.json`. Ce sont deux sources différentes, ce qui
// est la condition pour que la comparaison veuille dire quelque chose.
//
// Fonctions pures : aucun accès réseau, pour que la règle soit testable et
// tienne en un seul endroit.

library;

/// Ce que `/version.json` publie.
class VersionDistante {
  const VersionDistante({
    required this.minimum,
    required this.derniere,
    this.notes,
    this.lien,
    this.maintenance = false,
  });

  /// En dessous, l'application refuse de fonctionner.
  final String minimum;

  /// La version publiée. Au-dessus de la locale, on propose la mise à jour.
  final String derniere;

  final String? notes;

  /// Où télécharger. Le champ pointait vers le Play Store, qui n'existe pas.
  final String? lien;

  /// Coupure annoncée : on bloque, mais ce n'est pas la faute de la version.
  final bool maintenance;

  static VersionDistante? depuis(Map<String, dynamic> l) {
    final minimum = l['minimumVersion'] as String?;
    if (minimum == null) return null;

    return VersionDistante(
      minimum: minimum,
      // `latestVersion` d'abord, `version` en repli : les deux existent dans
      // le fichier actuel et disent la même chose.
      derniere:
          (l['latestVersion'] as String?) ??
          (l['version'] as String?) ??
          minimum,
      notes: l['releaseNotes'] as String?,
      lien: l['updateUrl'] as String?,
      maintenance: l['maintenance'] as bool? ?? false,
    );
  }
}

enum ExigenceVersion {
  /// Rien à faire.
  aJour,

  /// Une version plus récente existe : on le signale sans bloquer.
  conseillee,

  /// En dessous du minimum : l'application ne peut plus servir.
  exigee,

  /// Coupure annoncée côté serveur.
  maintenance,
}

/// Compare deux versions « 1.2.3 ».
///
/// Rend un nombre négatif si `a` précède `b`, zéro si elles se valent, positif
/// sinon. Tolérant par construction : un suffixe de compilation (`2.0.0+2`) ou
/// de pré-publication (`2.0.0-beta`) est ignoré, un segment absent vaut zéro,
/// et un segment illisible vaut zéro aussi — une chaîne mal formée dans
/// `/version.json` ne doit pas bloquer une application qui marche.
int comparerVersions(String a, String b) {
  final ga = _segments(a);
  final gb = _segments(b);
  final longueur = ga.length > gb.length ? ga.length : gb.length;

  for (var i = 0; i < longueur; i++) {
    final x = i < ga.length ? ga[i] : 0;
    final y = i < gb.length ? gb[i] : 0;
    if (x != y) return x < y ? -1 : 1;
  }

  return 0;
}

List<int> _segments(String version) {
  // Tout ce qui suit un `+` ou un `-` ne participe pas à l'ordre : le numéro
  // de compilation d'Android n'est pas une version.
  final noyau = version.trim().split(RegExp(r'[+\-\s]')).first;

  return noyau
      .split('.')
      .map((s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
}

/// Ce qu'il faut faire, d'après la version installée et les seuils publiés.
///
/// L'ordre des tests n'est pas indifférent : la maintenance passe **avant**
/// le minimum, parce qu'un étudiant à jour ne doit pas être invité à
/// télécharger une version qu'il a déjà.
ExigenceVersion etatVersion({
  required String locale,
  required VersionDistante distante,
}) {
  if (distante.maintenance) return ExigenceVersion.maintenance;

  if (comparerVersions(locale, distante.minimum) < 0) {
    return ExigenceVersion.exigee;
  }

  if (comparerVersions(locale, distante.derniere) < 0) {
    return ExigenceVersion.conseillee;
  }

  return ExigenceVersion.aJour;
}
