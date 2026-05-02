import 'package:catchline/data/models/item.dart';
import 'package:catchline/data/models/item_kind.dart';
import 'package:catchline/features/items/list_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void _appendBodyTests() {
  group('appendBody', () {
    test('returns the addition unchanged when current is empty', () {
      expect(appendBody('', 'next'), 'next');
    });

    test('inserts a newline between non-empty current and addition', () {
      expect(appendBody('first', 'second'), 'first\nsecond');
    });

    test('does not double up newlines when current ends in one', () {
      expect(appendBody('first\n', 'second'), 'first\nsecond');
    });

    test('preserves existing whitespace before the join', () {
      expect(appendBody('first ', 'second'), 'first \nsecond');
    });

    test('does nothing special when addition is empty', () {
      expect(appendBody('first', ''), 'first\n');
      expect(appendBody('', ''), '');
    });
  });
}

Item _it({
  required String id,
  required ItemKind kind,
  String title = '',
  String textBody = '',
  String? tag,
  int? createdAtMs,
}) {
  final ms = createdAtMs ?? DateTime(2026, 5, 1).toUtc().millisecondsSinceEpoch;
  return Item(
    id: id,
    kind: kind,
    title: title,
    textBody: textBody,
    audioClips: const [],
    createdAtMs: ms,
    updatedAtMs: ms,
    tag: tag,
  );
}

void main() {
  group('filterItems', () {
    final phrase = _it(
      id: 'p1',
      kind: ItemKind.phrase,
      textBody: 'soft hands, hard truths',
      tag: 'romantic',
    );
    final phraseUntagged = _it(
      id: 'p2',
      kind: ItemKind.phrase,
      textBody: 'big back energy',
    );
    final poem = _it(
      id: 'po1',
      kind: ItemKind.poem,
      title: 'A Thumbprint',
      textBody: 'the moon was a thumbprint',
      tag: 'lyric',
    );
    final journal = _it(
      id: 'j1',
      kind: ItemKind.journal,
      textBody: 'I felt liberated by AI coding.',
      createdAtMs: DateTime(2026, 5, 1).toUtc().millisecondsSinceEpoch,
    );

    final all = [phrase, phraseUntagged, poem, journal];

    test('returns all items unchanged when query and tag filter are empty', () {
      expect(filterItems(all), all);
    });

    test('matches title text case-insensitively', () {
      expect(filterItems(all, query: 'thumbprint'), [poem]);
      expect(filterItems(all, query: 'THUMBPRINT'), [poem]);
    });

    test('matches body text', () {
      final out = filterItems(all, query: 'hard truths');
      expect(out, [phrase]);
    });

    test('matches the formatted weekday title for journal entries', () {
      // formatJournalTitle on 2026-05-01 → "Friday, May 1, 2026"
      final out = filterItems(all, query: 'friday');
      expect(out.map((e) => e.id), ['j1']);
    });

    test('filters by a single tag', () {
      expect(filterItems(all, tagFilter: {'romantic'}), [phrase]);
    });

    test('filters by multiple tags (OR within the set)', () {
      final out = filterItems(all, tagFilter: {'romantic', 'lyric'});
      expect(out.map((e) => e.id).toSet(), {'p1', 'po1'});
    });

    test('drops untagged items when a tag filter is active', () {
      final out = filterItems(all, tagFilter: {'romantic'});
      expect(out.contains(phraseUntagged), isFalse);
    });

    test('combines query and tag filter (AND)', () {
      final out = filterItems(all, query: 'thumb', tagFilter: {'lyric'});
      expect(out, [poem]);
      // Tag matches but query does not -> empty.
      expect(
        filterItems(all, query: 'thumb', tagFilter: {'romantic'}),
        isEmpty,
      );
      // Query matches but tag does not -> empty.
      expect(
        filterItems(all, query: 'soft hands', tagFilter: {'lyric'}),
        isEmpty,
      );
    });

    test('treats whitespace-only query as no query', () {
      expect(filterItems(all, query: '   '), all);
    });

    test('does not modify the input list', () {
      final input = List<Item>.from(all);
      filterItems(input, query: 'soft', tagFilter: {'romantic'});
      expect(input, all);
    });

    test('preserves input order', () {
      final out = filterItems(all);
      expect(out, [phrase, phraseUntagged, poem, journal]);
    });
  });

  _appendBodyTests();
}
