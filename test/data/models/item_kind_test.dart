import 'package:catchline/data/models/item_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ItemKind.label', () {
    test('returns the plural human label for each kind', () {
      expect(ItemKind.journal.label, 'Journal');
      expect(ItemKind.poem.label, 'Poems');
      expect(ItemKind.lyric.label, 'Lyrics');
      expect(ItemKind.phrase.label, 'Phrases');
    });

    test('every enum value has a non-empty label', () {
      for (final k in ItemKind.values) {
        expect(k.label, isNotEmpty, reason: '${k.name} has no label');
      }
    });
  });

  group('ItemKind.singular', () {
    test('returns the singular noun for each kind', () {
      expect(ItemKind.journal.singular, 'journal entry');
      expect(ItemKind.poem.singular, 'poem');
      expect(ItemKind.lyric.singular, 'lyric');
      expect(ItemKind.phrase.singular, 'phrase');
    });

    test('every enum value has a non-empty singular', () {
      for (final k in ItemKind.values) {
        expect(k.singular, isNotEmpty, reason: '${k.name} has no singular');
      }
    });
  });

  test('values list has the expected ordering', () {
    expect(ItemKind.values, [
      ItemKind.journal,
      ItemKind.poem,
      ItemKind.lyric,
      ItemKind.phrase,
    ]);
  });
}
