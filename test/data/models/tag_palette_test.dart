import 'package:catchline/data/models/item_kind.dart';
import 'package:catchline/data/models/tag_palette.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tagById', () {
    test('returns the descriptor for a known id', () {
      final t = tagById('serious');
      expect(t, isNotNull);
      expect(t!.id, 'serious');
      expect(t.label, 'serious');
    });

    test('returns null for unknown / null / empty', () {
      expect(tagById(null), isNull);
      expect(tagById(''), isNull);
      expect(tagById('not-a-real-tag'), isNull);
    });

    test('every default tag is round-trippable through tagById', () {
      for (final t in kDefaultTags) {
        final found = tagById(t.id);
        expect(found, isNotNull, reason: '${t.id} should be lookupable');
        expect(found!.id, t.id);
        expect(found.label, t.label);
        expect(found.color, t.color);
      }
    });
  });

  group('kDefaultTags integrity', () {
    test('ids are unique', () {
      final ids = kDefaultTags.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('ids are lowercase and contain no spaces', () {
      for (final t in kDefaultTags) {
        expect(t.id, t.id.toLowerCase(), reason: 'tag id should be lowercase');
        expect(
          t.id.contains(' '),
          isFalse,
          reason: 'tag id should not contain spaces',
        );
      }
    });

    test('labels are non-empty', () {
      for (final t in kDefaultTags) {
        expect(t.label.trim(), isNotEmpty);
      }
    });

    test('every tag has a unique color', () {
      final colors = kDefaultTags.map((t) => t.color.toARGB32()).toList();
      expect(colors.toSet().length, colors.length);
    });

    test('design canvas mood set is present', () {
      // From catchline-design.html, the design's TAGS map.
      const expected = {
        'serious',
        'funny',
        'dark',
        'romantic',
        'hopeful',
        'lyric',
        'rant',
        'prayer',
        'observation',
      };
      expect(kDefaultTags.map((t) => t.id).toSet(), expected);
    });
  });

  group('defaultTagsFor', () {
    test('phrase gets the full default palette', () {
      final ids = defaultTagsFor(ItemKind.phrase).map((t) => t.id).toSet();
      expect(ids, kDefaultTags.map((t) => t.id).toSet());
    });

    test('poem gets the curated literary subset', () {
      final ids = defaultTagsFor(ItemKind.poem).map((t) => t.id).toSet();
      expect(ids, {
        'lyric',
        'observation',
        'romantic',
        'serious',
        'hopeful',
        'dark',
      });
    });

    test('lyric gets the songwriting-friendly subset', () {
      final ids = defaultTagsFor(ItemKind.lyric).map((t) => t.id).toSet();
      expect(ids, {'serious', 'funny', 'dark', 'romantic', 'prayer'});
    });

    test('journal gets the mood-only subset', () {
      final ids = defaultTagsFor(ItemKind.journal).map((t) => t.id).toSet();
      expect(ids, {'hopeful', 'serious', 'observation', 'dark'});
    });

    test('each kind returns at least one tag', () {
      for (final kind in ItemKind.values) {
        expect(
          defaultTagsFor(kind),
          isNotEmpty,
          reason: 'expected default tags for ${kind.name}',
        );
      }
    });

    test('every kind tag id exists in the default palette', () {
      final defaultIds = kDefaultTags.map((t) => t.id).toSet();
      for (final kind in ItemKind.values) {
        for (final tag in defaultTagsFor(kind)) {
          expect(
            defaultIds.contains(tag.id),
            isTrue,
            reason: '${kind.name} references unknown tag ${tag.id}',
          );
        }
      }
    });

    test(
      'returned descriptors are the same instance as the master palette',
      () {
        // Avoid accidentally cloning descriptors — that would let two paths
        // diverge silently if a color/label is updated.
        for (final kind in ItemKind.values) {
          for (final tag in defaultTagsFor(kind)) {
            final master = tagById(tag.id);
            expect(
              identical(tag, master),
              isTrue,
              reason: 'kind ${kind.name} tag ${tag.id} should be the master',
            );
          }
        }
      },
    );
  });
}
