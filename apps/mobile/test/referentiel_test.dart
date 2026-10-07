import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/metier/referentiel.dart';

/// Mêmes cas que `lib/metier/referentiel.test.ts` : l'écran doit trouver ce
/// que le serveur jugera identique.
void main() {
  test('voit la même filière derrière toutes les façons de l’écrire', () {
    for (final v in [
      'FSEG',
      'fseg',
      'F.S.E.G',
      'F S E G',
      ' F-S-E-G ',
      'F.S.E.G.',
    ]) {
      expect(normaliserNom(v), 'fseg', reason: v);
    }
  });

  test('ignore accents, casse et ponctuation', () {
    expect(
      normaliserNom('Université d’Abomey-Calavi'),
      normaliserNom('universite d abomey calavi'),
    );
    expect(normaliserNom('Économie  Politique'), 'economie politique');
  });

  test('ne confond pas deux noms différents', () {
    expect(normaliserNom('Droit public'), isNot(normaliserNom('Droit privé')));
    expect(normaliserNom('FSEG'), isNot(normaliserNom('FSS')));
  });

  test('retrouve l’existant malgré l’écriture', () {
    final lignes = [('1', 'FSEG'), ('2', 'Faculté de droit')];
    expect(trouverParNom(lignes, (e) => e.$2, 'f.s.e.g')?.$1, '1');
    expect(trouverParNom(lignes, (e) => e.$2, 'FACULTE DE DROIT')?.$1, '2');
    expect(trouverParNom(lignes, (e) => e.$2, 'Faculté de médecine'), isNull);
  });

  test('retrouve une école par son sigle ou son nom sans sigle', () {
    final lignes = [
      ('1', 'Université Cheikh Anta Diop de Dakar (UCAD)'),
      ('2', 'Faculté des Sciences Économiques et de Gestion (FASEG)'),
      ('3', 'Institut National Polytechnique Félix Houphouët-Boigny (INP-HB)'),
    ];
    String n((String, String) e) => e.$2;
    expect(trouverParNom(lignes, n, 'UCAD')?.$1, '1');
    expect(trouverParNom(lignes, n, 'u.c.a.d')?.$1, '1');
    expect(
      trouverParNom(lignes, n, 'Université Cheikh Anta Diop de Dakar')?.$1,
      '1',
    );
    expect(trouverParNom(lignes, n, 'faseg')?.$1, '2');
    expect(trouverParNom(lignes, n, 'INP HB')?.$1, '3');
    expect(trouverParNom(lignes, n, 'Université de Dakar'), isNull);
    expect(trouverParNom(lignes, n, 'FSEG'), isNull);
    // La recherche trouve aussi par le sigle, en cours de frappe.
    expect(filtrerParNom(lignes, n, 'ucad').map((e) => e.$1), ['1']);
  });

  test('ne lit un sigle qu’en fin de nom', () {
    expect(sigleDe('Université de Lomé (UL)'), 'ul');
    expect(sigleDe('Université de Lomé'), isNull);
    expect(sigleDe('Faculté (ancienne) de droit'), isNull);
    expect(memeNom('', 'Université de Lomé (UL)'), isFalse);
  });

  test('filtre en ignorant accents et casse', () {
    final lignes = ['Faculté de médecine', 'FSEG', 'Faculté de droit'];
    expect(filtrerParNom(lignes, (e) => e, 'MEDEC'), ['Faculté de médecine']);
    expect(filtrerParNom(lignes, (e) => e, ''), lignes);
  });
}
