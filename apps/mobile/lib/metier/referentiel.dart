/// Ce qui rend deux noms d'école, de filière ou de matière « le même ».
///
/// Port de `lib/metier/referentiel.ts` : la recherche de l'écran doit trouver
/// ce que le serveur jugera identique — sinon l'étudiant verrait « Ajouter
/// FSEG » alors que la FSEG existe, et le serveur lui rendrait l'existante
/// sans qu'il comprenne pourquoi. Mêmes cas de test des deux côtés.
library;

const _accents = {
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'á': 'a',
  'ã': 'a',
  'å': 'a',
  'ç': 'c',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'î': 'i',
  'ï': 'i',
  'í': 'i',
  'ì': 'i',
  'ô': 'o',
  'ö': 'o',
  'ó': 'o',
  'ò': 'o',
  'õ': 'o',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ú': 'u',
  'ÿ': 'y',
  'ñ': 'n',
  'œ': 'oe',
  'æ': 'ae',
};

/// Lettres et chiffres, sans accents ni casse ; un sigle écrit « F S E G »
/// ou « F.S.E.G » devient « fseg ».
String normaliserNom(String nom) {
  final minuscule = nom.toLowerCase();
  final sansAccents = StringBuffer();
  for (final r in minuscule.runes) {
    final c = String.fromCharCode(r);
    sansAccents.write(_accents[c] ?? c);
  }
  final mots = sansAccents
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .split(RegExp(r'\s+'))
      .where((m) => m.isNotEmpty)
      .toList();

  // Des lettres isolées qui se suivent forment un sigle : « f s e g » →
  // « fseg ». Comme côté serveur, seules les lettres isolées se recollent,
  // jamais un vrai mot.
  final sortie = <String>[];
  var sigleEnCours = false;
  for (final m in mots) {
    if (m.length == 1 && sigleEnCours) {
      sortie[sortie.length - 1] = sortie.last + m;
    } else {
      sortie.add(m);
      sigleEnCours = m.length == 1;
    }
  }
  return sortie.join(' ');
}

/// L'élément de `entrees` dont le nom est « le même » que `saisie`.
T? trouverParNom<T>(List<T> entrees, String Function(T) nom, String saisie) {
  final cible = normaliserNom(saisie);
  for (final e in entrees) {
    if (normaliserNom(nom(e)) == cible) return e;
  }
  return null;
}

/// Les entrées dont le nom contient la saisie, au sens de `normaliserNom`.
List<T> filtrerParNom<T>(
  List<T> entrees,
  String Function(T) nom,
  String saisie,
) {
  final cible = normaliserNom(saisie);
  if (cible.isEmpty) return entrees;
  return [
    for (final e in entrees)
      if (normaliserNom(nom(e)).contains(cible)) e,
  ];
}
