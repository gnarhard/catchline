import 'package:catchline/util/id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('newId', () {
    test('returns a UUID v4 in canonical 8-4-4-4-12 hex form', () {
      final id = newId();
      final pattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(pattern.hasMatch(id), isTrue, reason: 'got "$id"');
    });

    test('produces unique ids across many calls', () {
      final ids = {for (var i = 0; i < 1000; i++) newId()};
      expect(ids.length, 1000);
    });
  });
}
