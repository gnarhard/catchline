import 'package:catchline/util/text_preview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('textPreview', () {
    test('returns empty string for empty input', () {
      expect(textPreview(''), '');
    });

    test('trims surrounding whitespace', () {
      expect(textPreview('  hello  '), 'hello');
    });

    test('collapses internal whitespace runs to single spaces', () {
      expect(textPreview('a   b\t\tc\n\nd'), 'a b c d');
    });

    test('passes short input through untouched', () {
      expect(textPreview('short text'), 'short text');
    });

    test('truncates with ellipsis when over maxChars', () {
      final long = 'x' * 200;
      final preview = textPreview(long, maxChars: 50);
      expect(preview.length, 51); // 50 chars + the ellipsis character
      expect(preview.endsWith('…'), isTrue);
      expect(preview.substring(0, 50), 'x' * 50);
    });

    test('does not truncate when length equals maxChars', () {
      final exact = 'a' * 10;
      expect(textPreview(exact, maxChars: 10), exact);
    });

    test('right-trims before adding the ellipsis', () {
      // "abc " is 4 chars; with maxChars=4, the trailing space should be
      // dropped before the ellipsis is appended.
      final preview = textPreview('abc more text', maxChars: 4);
      expect(preview, 'abc…');
    });

    test('whitespace-only collapses to empty string', () {
      expect(textPreview('   \n\t  '), '');
    });
  });
}
