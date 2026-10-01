import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/i18n/fr.dart';

void main() {
  test('les montants s’écrivent avec une espace fine entre les milliers', () {
    expect(milliers(0), '0');
    expect(milliers(500), '500');
    expect(milliers(3000), '3 000');
    expect(milliers(1234567), '1 234 567');
    expect(milliers(-2500), '-2 500');
  });
}
