import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/metier/matieres.dart';

/// Chaque matière de la graine (`20260908130000_seed.sql`) doit tomber dans
/// sa famille : c'est l'illustration que voit l'étudiant sur l'accueil.
void main() {
  const graine = {
    'Microéconomie': FamilleMatiere.economie,
    'Macroéconomie': FamilleMatiere.economie,
    'Comptabilité générale': FamilleMatiere.economie,
    'Statistiques descriptives': FamilleMatiere.maths,
    'Droit constitutionnel': FamilleMatiere.droit,
    'Droit civil des obligations': FamilleMatiere.droit,
    'Droit administratif': FamilleMatiere.droit,
    'Introduction à la science politique': FamilleMatiere.droit,
    'Analyse mathématique': FamilleMatiere.maths,
    'Chimie générale': FamilleMatiere.sciences,
    'Physique mécanique': FamilleMatiere.sciences,
    'Biologie cellulaire': FamilleMatiere.sciences,
    'Littérature africaine': FamilleMatiere.lettres,
    'Linguistique générale': FamilleMatiere.lettres,
    'Histoire de l\'Afrique précoloniale': FamilleMatiere.lettres,
    'Géographie humaine': FamilleMatiere.lettres,
    'Anatomie humaine': FamilleMatiere.sante,
    'Physiologie': FamilleMatiere.sante,
    'Biochimie médicale': FamilleMatiere.sante,
    'Sémiologie médicale': FamilleMatiere.sante,
    'Résistance des matériaux': FamilleMatiere.sciences,
    'Électrotechnique': FamilleMatiere.sciences,
    'Dessin technique': FamilleMatiere.sciences,
    'Thermodynamique appliquée': FamilleMatiere.sciences,
    'Transferts thermiques': FamilleMatiere.sciences,
    'Mécanique des fluides': FamilleMatiere.sciences,
    'Énergies renouvelables': FamilleMatiere.sciences,
    'Génie des procédés': FamilleMatiere.sciences,
    'Algèbre linéaire': FamilleMatiere.maths,
    'Probabilités et statistiques': FamilleMatiere.maths,
    'Analyse numérique': FamilleMatiere.maths,
    'Modélisation mathématique': FamilleMatiere.maths,
    'Pédagogie générale': FamilleMatiere.education,
    'Didactique des sciences': FamilleMatiere.education,
    'Technologie de l\'éducation': FamilleMatiere.education,
    'Psychologie de l\'apprentissage': FamilleMatiere.education,
    'Microbiologie appliquée': FamilleMatiere.sciences,
    'Biochimie structurale': FamilleMatiere.sciences,
    'Génie fermentaire': FamilleMatiere.sciences,
    'Biotechnologie végétale': FamilleMatiere.agronomie,
    'Économie générale': FamilleMatiere.economie,
    'Comptabilité analytique': FamilleMatiere.economie,
    'Gestion financière': FamilleMatiere.economie,
    'Marketing fondamental': FamilleMatiere.economie,
    'Droit pénal général': FamilleMatiere.droit,
    'Droit international public': FamilleMatiere.droit,
    'Institutions administratives': FamilleMatiere.droit,
    'Agronomie générale': FamilleMatiere.agronomie,
    'Zootechnie': FamilleMatiere.agronomie,
    'Phytotechnie': FamilleMatiere.agronomie,
    'Économie rurale': FamilleMatiere.economie,
    'Histologie': FamilleMatiere.sante,
    'Pharmacologie': FamilleMatiere.sante,
    'Pathologie générale': FamilleMatiere.sante,
    'Expression écrite et orale': FamilleMatiere.lettres,
    'Sociologie générale': FamilleMatiere.lettres,
    'Histoire contemporaine': FamilleMatiere.lettres,
    'Géographie du Bénin': FamilleMatiere.lettres,
  };

  test('chaque matière de la graine a sa famille', () {
    for (final MapEntry(key: nom, value: famille) in graine.entries) {
      expect(familleDe(nom), famille, reason: nom);
    }
  });

  test('« politique » ne fait pas d’une économie un cours de droit', () {
    expect(familleDe('Économie politique'), FamilleMatiere.economie);
    expect(familleDe('Introduction à la science politique'), FamilleMatiere.droit);
    expect(familleDe('Introduction à l’étude du droit'), FamilleMatiere.droit);
  });

  test('les noms saisis par un étudiant aussi, sans accent ni casse', () {
    expect(familleDe('DROIT DES AFFAIRES'), FamilleMatiere.droit);
    expect(familleDe('Programmation en C'), FamilleMatiere.informatique);
    expect(familleDe('algorithmique'), FamilleMatiere.informatique);
  });

  test('un nom inconnu, vide ou absent donne le cahier', () {
    expect(familleDe('Atelier du mercredi'), FamilleMatiere.generique);
    expect(familleDe(''), FamilleMatiere.generique);
    expect(familleDe(null), FamilleMatiere.generique);
  });

  test('chaque famille a son illustration', () {
    for (final f in FamilleMatiere.values) {
      expect(f.image, 'assets/matieres/${f.name}.webp');
    }
  });
}
