import 'package:catchline/data/models/item_kind.dart';
import 'package:catchline/data/models/tag_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('kDefaultTagDefs integrity', () {
    test('ids are unique', () {
      final ids = kDefaultTagDefs.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('ids are lowercase and contain no spaces', () {
      for (final t in kDefaultTagDefs) {
        expect(t.id, t.id.toLowerCase(), reason: 'tag id should be lowercase');
        expect(
          t.id.contains(' '),
          isFalse,
          reason: 'tag id should not contain spaces',
        );
      }
    });

    test('labels are non-empty', () {
      for (final t in kDefaultTagDefs) {
        expect(t.label.trim(), isNotEmpty);
      }
    });

    test('every tag has a unique color', () {
      final colors = kDefaultTagDefs.map((t) => t.color.toARGB32()).toList();
      expect(colors.toSet().length, colors.length);
    });

    test('design canvas mood set is present', () {
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
      expect(kDefaultTagDefs.map((t) => t.id).toSet(), expected);
    });

    test('every default tag belongs to at least one kind', () {
      for (final t in kDefaultTagDefs) {
        expect(t.kinds, isNotEmpty, reason: '${t.id} has no kinds');
      }
    });

    test('per-kind seed sets match the original design curation', () {
      Set<String> idsFor(ItemKind kind) => kDefaultTagDefs
          .where((t) => t.kinds.contains(kind))
          .map((t) => t.id)
          .toSet();
      expect(idsFor(ItemKind.phrase), {
        'serious',
        'funny',
        'dark',
        'romantic',
        'hopeful',
        'lyric',
        'rant',
        'prayer',
        'observation',
      });
      expect(idsFor(ItemKind.poem), {
        'lyric',
        'observation',
        'romantic',
        'serious',
        'hopeful',
        'dark',
      });
      expect(idsFor(ItemKind.lyric), {
        'serious',
        'funny',
        'dark',
        'romantic',
        'prayer',
      });
      expect(idsFor(ItemKind.journal), {
        'hopeful',
        'serious',
        'observation',
        'dark',
      });
    });
  });

  group('TagDescriptor', () {
    test('copyWith overrides only specified fields', () {
      const original = TagDescriptor(
        id: 'foo',
        label: 'foo',
        color: Color(0xFF112233),
        kinds: {ItemKind.phrase},
      );
      final renamed = original.copyWith(label: 'bar');
      expect(renamed.id, 'foo');
      expect(renamed.label, 'bar');
      expect(renamed.color.toARGB32(), 0xFF112233);
      expect(renamed.kinds, {ItemKind.phrase});
    });

    test('equality compares id/label/color/kinds', () {
      const a = TagDescriptor(
        id: 'foo',
        label: 'foo',
        color: Color(0xFF112233),
        kinds: {ItemKind.phrase, ItemKind.poem},
      );
      const b = TagDescriptor(
        id: 'foo',
        label: 'foo',
        color: Color(0xFF112233),
        kinds: {ItemKind.poem, ItemKind.phrase},
      );
      const c = TagDescriptor(
        id: 'foo',
        label: 'bar',
        color: Color(0xFF112233),
        kinds: {ItemKind.phrase, ItemKind.poem},
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
