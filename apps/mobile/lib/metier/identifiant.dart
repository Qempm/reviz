/// Un identifiant aléatoire au format UUID v4, tiré sur le téléphone.
///
/// Sert à reconnaître une série renvoyée depuis la file hors ligne : le
/// serveur ne compte pas deux fois la même. `Random.secure()` plutôt qu'un
/// paquet de plus pour seize octets.
library;

import 'dart:math';

String identifiantAleatoire([Random? hasard]) {
  final r = hasard ?? Random.secure();
  final o = List<int>.generate(16, (_) => r.nextInt(256));
  o[6] = (o[6] & 0x0f) | 0x40; // version 4
  o[8] = (o[8] & 0x3f) | 0x80; // variante RFC 4122
  final h = [for (final b in o) b.toRadixString(16).padLeft(2, '0')].join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}
