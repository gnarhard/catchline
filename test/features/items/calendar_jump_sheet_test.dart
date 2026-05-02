import 'package:catchline/data/models/item.dart';
import 'package:catchline/data/models/item_kind.dart';
import 'package:catchline/features/items/widgets/calendar_jump_sheet.dart';
import 'package:catchline/util/journal_date.dart';
import 'package:flutter_test/flutter_test.dart';

Item _item(ItemKind kind, DateTime created) => Item(
  id: 'i-${kind.name}-${created.toIso8601String()}',
  kind: kind,
  title: '',
  textBody: '',
  audioClips: const [],
  createdAtMs: created.toUtc().millisecondsSinceEpoch,
  updatedAtMs: created.toUtc().millisecondsSinceEpoch,
);

void main() {
  group('DayCounts.add', () {
    Matcher hasCounts({int j = 0, int p = 0, int l = 0, int q = 0}) =>
        isA<DayCounts>()
            .having((d) => d.journal, 'journal', j)
            .having((d) => d.poem, 'poem', p)
            .having((d) => d.lyric, 'lyric', l)
            .having((d) => d.phrase, 'phrase', q);

    test('increments the matching kind only', () {
      const start = DayCounts(journal: 1, poem: 2, lyric: 3, phrase: 4);
      expect(start.add(ItemKind.journal), hasCounts(j: 2, p: 2, l: 3, q: 4));
      expect(start.add(ItemKind.poem), hasCounts(j: 1, p: 3, l: 3, q: 4));
      expect(start.add(ItemKind.lyric), hasCounts(j: 1, p: 2, l: 4, q: 4));
      expect(start.add(ItemKind.phrase), hasCounts(j: 1, p: 2, l: 3, q: 5));
    });

    test('does not mutate the receiver', () {
      const start = DayCounts(journal: 1);
      final next = start.add(ItemKind.journal);
      expect(start.journal, 1);
      expect(next.journal, 2);
    });
  });

  group('DayCounts.isEmpty', () {
    test('true for the const default', () {
      expect(const DayCounts().isEmpty, isTrue);
    });

    test('false once any kind has at least one entry', () {
      expect(const DayCounts(journal: 1).isEmpty, isFalse);
      expect(const DayCounts(poem: 1).isEmpty, isFalse);
      expect(const DayCounts(lyric: 1).isEmpty, isFalse);
      expect(const DayCounts(phrase: 1).isEmpty, isFalse);
    });
  });

  group('dayCountsFromItems', () {
    test('counts each kind in its own bucket per day', () {
      final day = DateTime(2026, 5, 1, 9);
      final counts = dayCountsFromItems([
        _item(ItemKind.journal, day),
        _item(ItemKind.journal, day.add(const Duration(hours: 4))),
        _item(ItemKind.phrase, day),
        _item(ItemKind.phrase, day),
        _item(ItemKind.phrase, day),
        _item(ItemKind.lyric, day),
      ]);
      final key = dayKey(day.toUtc().millisecondsSinceEpoch);
      expect(counts[key]!.journal, 2);
      expect(counts[key]!.phrase, 3);
      expect(counts[key]!.lyric, 1);
      expect(counts[key]!.poem, 0);
      expect(counts[key]!.isEmpty, isFalse);
    });

    test('separates entries from different days', () {
      final day1 = DateTime(2026, 5, 1, 9);
      final day2 = DateTime(2026, 5, 2, 9);
      final counts = dayCountsFromItems([
        _item(ItemKind.journal, day1),
        _item(ItemKind.poem, day2),
      ]);
      expect(counts.length, 2);
      expect(counts[dayKey(day1.toUtc().millisecondsSinceEpoch)]!.journal, 1);
      expect(counts[dayKey(day2.toUtc().millisecondsSinceEpoch)]!.poem, 1);
    });

    test('groups times within the same calendar day', () {
      final morning = DateTime(2026, 5, 1, 6);
      final evening = DateTime(2026, 5, 1, 22);
      final counts = dayCountsFromItems([
        _item(ItemKind.phrase, morning),
        _item(ItemKind.phrase, evening),
      ]);
      expect(counts.length, 1);
      expect(counts.values.single.phrase, 2);
    });

    test('returns empty map for no items', () {
      expect(dayCountsFromItems(const []), isEmpty);
    });
  });
}
