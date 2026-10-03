/// La famille d'une matière, pour son illustration.
///
/// Une matière n'a pas de type en base : `subjects` porte un nom libre, que
/// l'étudiant peut même saisir lui-même. La famille se déduit donc du nom,
/// par mots-clés, sur sa forme normalisée (sans accents ni casse,
/// `normaliserNom`). Les noms de la graine (`supabase/migrations/
/// 20260908130000_seed.sql`) tombent tous dans la bonne famille —
/// `test/matieres_test.dart` le vérifie un par un ; un nom inconnu donne
/// [FamilleMatiere.generique], un cahier, jamais une erreur.
library;

import 'referentiel.dart' show normaliserNom;

enum FamilleMatiere {
  droit,
  economie,
  sante,
  maths,
  sciences,
  agronomie,
  lettres,
  informatique,
  education,
  generique;

  /// L'illustration 3D de la famille (`scripts/matieres.mjs`).
  String get image => 'assets/matieres/$name.webp';
}

/// Les mots-clés de chaque famille, **dans l'ordre où on les essaie**.
///
/// L'ordre tranche les noms ambigus : « Didactique des sciences » est de
/// l'éducation avant d'être des sciences, « Biochimie médicale » de la santé
/// avant la chimie, « Statistiques descriptives » des maths avant
/// l'économie, « Biotechnologie végétale » de l'agronomie avant la biologie.
const List<(FamilleMatiere, List<String>)> _motsCles = [
  (
    FamilleMatiere.education,
    ['pedagog', 'didactique', 'education', 'apprentissage', 'enseignement'],
  ),
  (
    FamilleMatiere.droit,
    [
      'droit',
      'juridique',
      'institution',
      'politique',
      'constitution',
      'penal',
      'contentieux',
    ],
  ),
  (
    FamilleMatiere.sante,
    [
      'anatom',
      'physiolog',
      'medic',
      'medecin',
      'semiolog',
      'histolog',
      'pharmaco',
      'patholog',
      'sante',
      'infirm',
      'soins',
      'chirurg',
      'embryolog',
    ],
  ),
  (
    FamilleMatiere.informatique,
    [
      'informatique',
      'programm',
      'algorithm',
      'reseau',
      'logiciel',
      'donnees',
      'web',
      'numerique appliqu',
    ],
  ),
  (
    FamilleMatiere.maths,
    [
      'math',
      'algebre',
      'analyse',
      'probabil',
      'statist',
      'geometr',
      'calcul',
    ],
  ),
  (
    FamilleMatiere.economie,
    [
      'econom',
      'comptab',
      'gestion',
      'marketing',
      'financ',
      'management',
      'commerce',
      'fiscal',
    ],
  ),
  (
    FamilleMatiere.agronomie,
    [
      'agronom',
      'zootechn',
      'phytotechn',
      'vegetal',
      'agricol',
      'agricult',
      'elevage',
      'pedolog',
    ],
  ),
  (
    FamilleMatiere.sciences,
    [
      'chimie',
      'physique',
      'biolog',
      'biochim',
      'biotech',
      'mecanique',
      'thermo',
      'electr',
      'materiaux',
      'energie',
      'genie',
      'dessin technique',
      'fluides',
      'transferts',
      'fermentaire',
    ],
  ),
  (
    FamilleMatiere.lettres,
    [
      'litterat',
      'linguisti',
      'histoire',
      'geograph',
      'expression',
      'sociolog',
      'philosoph',
      'anglais',
      'francais',
      'langue',
      'communication',
      'psycholog',
      'anthropolog',
    ],
  ),
];

/// La famille d'une matière d'après son nom.
FamilleMatiere familleDe(String? nom) {
  if (nom == null || nom.trim().isEmpty) return FamilleMatiere.generique;
  final n = normaliserNom(nom);
  for (final (famille, mots) in _motsCles) {
    if (mots.any(n.contains)) return famille;
  }
  return FamilleMatiere.generique;
}
