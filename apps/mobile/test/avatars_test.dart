import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/metier/avatars.dart';
import 'package:reviz/theme/jetons.dart';

/// Tests de la palette d'avatars.
///
/// Deux choses comptent : que les douze clés restent celles que la liste
/// blanche du serveur accepte (`lib/profil/avatars.ts`), et qu'une clé
/// inconnue retombe sur une tête au lieu de casser un écran.
void main() {
  group('la palette', () {
    test('compte douze avatars, aux clés attendues', () {
      // Les mêmes clés que `CLES_AVATAR` côté serveur. Un avatar ajouté ici
      // sans l'être là-bas serait refusé par la route au moment du choix.
      expect(avatars.length, 12);
      expect(
        avatars.map((a) => a.cle).toList(),
        const [
          'ton-01',
          'ton-02',
          'ton-03',
          'ton-04',
          'ton-05',
          'ton-06',
          'ton-07',
          'ton-08',
          'ton-09',
          'ton-10',
          'ton-11',
          'ton-12',
        ],
      );
    });

    test('n’a aucune clé en double', () {
      expect(avatars.map((a) => a.cle).toSet().length, avatars.length);
    });

    test('n’a aucun fond en double : douze têtes distinguables', () {
      expect(avatars.map((a) => a.fond.toARGB32()).toSet().length, 12);
    });

    test('n’introduit aucun vert', () {
      // Contrainte de palette : la réussite se fête en jaune, l'échec en
      // rouge (docs/DESIGN.md § 11). Un avatar vert ferait entrer la couleur
      // par la porte de service.
      const interdits = [0xFF22C55E, 0xFFEF4444];

      for (final a in avatars) {
        expect(interdits, isNot(contains(a.fond.toARGB32())), reason: a.cle);
        expect(interdits, isNot(contains(a.encre.toARGB32())), reason: a.cle);
      }
    });

    test('ne tire ses couleurs que des jetons du design system', () {
      final jetons = {
        Couleurs.jaune,
        Couleurs.jauneDoux,
        Couleurs.surJaune,
        Couleurs.orange,
        Couleurs.orangeDoux,
        Couleurs.bleu,
        Couleurs.bleuDoux,
        Couleurs.encre,
        Couleurs.attenue,
        Couleurs.carte,
        Couleurs.dangerDoux,
        Couleurs.surDangerDoux,
        Couleurs.bordure,
        Couleurs.surfaceHaute,
        Couleurs.texteAccent,
        Couleurs.areteJaune,
        Couleurs.areteOrange,
        Couleurs.aretePeche,
      }.map((c) => c.toARGB32()).toSet();

      for (final a in avatars) {
        expect(jetons, contains(a.fond.toARGB32()), reason: '${a.cle} — fond');
        expect(jetons, contains(a.encre.toARGB32()), reason: '${a.cle} — encre');
      }
    });
  });

  group('résolution d’une clé', () {
    test('rend l’avatar demandé', () {
      expect(avatarDe('ton-05').fond, Couleurs.bleu);
    });

    test('retombe sur le défaut sans clé', () {
      expect(avatarDe(null).cle, avatarParDefaut.cle);
    });

    test('retombe sur le défaut sur une clé inconnue', () {
      // Des comptes créés avant la liste blanche portent les clés
      // descriptives de l'ancien écran web. Un classement ne doit pas se
      // casser dessus.
      expect(avatarDe('avatar-1-garcon-sourire').cle, avatarParDefaut.cle);
      expect(avatarDe('').cle, avatarParDefaut.cle);
    });
  });

  group('initiale', () {
    test('prend la première lettre, en majuscule', () {
      expect(initialeDe('awa'), 'A');
      expect(initialeDe('  koffi'), 'K');
      expect(initialeDe('Élodie'), 'É');
    });

    test('rend un point d’interrogation sans prénom', () {
      // Le prénom est facultatif à l'inscription.
      expect(initialeDe(null), '?');
      expect(initialeDe('   '), '?');
    });

    test('ne coupe pas une paire de substitution en deux', () {
      // `substring(0, 1)` rendrait une moitié de paire, affichée en losange.
      expect(initialeDe('👑Awa').runes.length, 1);
    });
  });
}
