import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/metier/maitrise.dart';

/// Mêmes cas que `lib/metier/maitrise.test.ts`.
void main() {
  final huit = [for (var i = 1; i <= 8; i++) 'q$i'];

  Tentative t(String id, bool juste, int jour, [int heure = 10]) => Tentative(
    questionId: id,
    juste: juste,
    le: DateTime.utc(2026, 9, jour, heure),
  );

  Maitrise m(List<Tentative> ts) => maitriseChapitre(qcm: huit, tentatives: ts);

  test('rien de tenté : à découvrir', () {
    final r = m([]);
    expect(r.etat, EtatChapitre.aDecouvrir);
    expect(r.couronnes, 0);
  });

  test('une seule bonne réponse ne fait pas un chapitre maîtrisé', () {
    // Le défaut d'origine : 1 juste sur 1 tentée = 100 %.
    final r = m([t('q1', true, 1)]);
    expect(r.etat, EtatChapitre.aDecouvrir);
    expect(r.couronnes, 0);
    expect(r.reussite, closeTo(1 / 8, 1e-9));
  });

  test('la moitié tentée et presque tout faux : à revoir', () {
    final r = m([
      t('q1', false, 1),
      t('q2', false, 1),
      t('q3', false, 1),
      t('q4', true, 1),
    ]);
    expect(r.etat, EtatChapitre.aRevoir);
  });

  test('tout tenté : 1, 2 couronnes selon les justes', () {
    final quatreJustes = [for (var i = 1; i <= 8; i++) t('q$i', i <= 4, 1)];
    expect(m(quatreJustes).couronnes, 1);

    final septJustes = [for (var i = 1; i <= 8; i++) t('q$i', i <= 7, 1)];
    expect(m(septJustes).couronnes, 2);
  });

  test('tout tenté, moins de la moitié juste : à revoir', () {
    final r = m([for (var i = 1; i <= 8; i++) t('q$i', i <= 3, 1)]);
    expect(r.etat, EtatChapitre.aRevoir);
    expect(r.couronnes, 0);
  });

  test('8 sur 8 le même jour : 2 couronnes, pas 3 — bachoté', () {
    final r = m([for (final id in huit) t(id, true, 1)]);
    expect(r.couronnes, 2);
  });

  test(
    '8 sur 8, chaque question juste deux jours différents : 3 couronnes',
    () {
      final r = m([
        for (final id in huit) t(id, true, 1),
        for (final id in huit) t(id, true, 3),
      ]);
      expect(r.couronnes, 3);
    },
  );

  test('deux fois juste le même jour ne compte que pour un jour', () {
    final r = m([
      for (final id in huit) t(id, true, 1, 9),
      for (final id in huit) t(id, true, 1, 20),
    ]);
    expect(r.couronnes, 2);
  });

  test('une couronne se perd si la dernière réponse devient fausse', () {
    final avant = [
      for (final id in huit) t(id, true, 1),
      for (final id in huit) t(id, true, 3),
    ];
    expect(m(avant).couronnes, 3);
    final apres = [...avant, t('q1', false, 5), t('q2', false, 5)];
    // 6 sur 8 à la dernière réponse : 75 %, une couronne.
    expect(m(apres).couronnes, 1);
  });

  test('les réponses à des questions hors du chapitre sont ignorées', () {
    final r = m([t('autre', true, 1)]);
    expect(r.tentees, 0);
  });

  test('un chapitre sans QCM ne se mesure pas', () {
    final r = maitriseChapitre(qcm: const [], tentatives: const []);
    expect(r.etat, EtatChapitre.sansQcm);
  });

  group('le chemin', () {
    Maitrise c(int couronnes) => Maitrise(
      etat: couronnes > 0 ? EtatChapitre.couronne : EtatChapitre.aDecouvrir,
      couronnes: couronnes,
      total: 8,
      tentees: couronnes > 0 ? 8 : 0,
      justes: 0,
    );
    const vide = Maitrise(
      etat: EtatChapitre.sansQcm,
      couronnes: 0,
      total: 0,
      tentees: 0,
      justes: 0,
    );

    test('le premier est ouvert, la suite s’ouvre couronne après couronne', () {
      final chemin = cheminDuCours([c(1), c(0), c(0)]);
      expect(chemin[0].etat, EtatChapitre.couronne);
      expect(chemin[1].etat, EtatChapitre.aDecouvrir);
      expect(chemin[2].etat, EtatChapitre.verrouille);
    });

    test(
      'un chapitre commencé reste ouvert si le précédent perd sa couronne',
      () {
        const commence = Maitrise(
          etat: EtatChapitre.aDecouvrir,
          couronnes: 0,
          total: 8,
          tentees: 3,
          justes: 3,
        );
        final chemin = cheminDuCours([c(0), commence, c(0)]);
        expect(chemin[1].etat, EtatChapitre.aDecouvrir);
        expect(chemin[2].etat, EtatChapitre.verrouille);
      },
    );

    test('un chapitre sans QCM ne bloque pas la suite', () {
      final chemin = cheminDuCours([c(2), vide, c(0)]);
      expect(chemin[1].etat, EtatChapitre.sansQcm);
      expect(chemin[2].etat, EtatChapitre.aDecouvrir);
    });
  });
}
