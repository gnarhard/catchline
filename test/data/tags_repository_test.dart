import 'dart:io';

import 'package:catchline/data/models/item_kind.dart';
import 'package:catchline/data/models/tag_palette.dart';
import 'package:catchline/data/tags_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> box;
  late TagsRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('catchline_tags_');
    Hive.init(tempDir.path);
    box = await Hive.openBox<dynamic>('tags_test');
    repo = TagsRepository(box);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('falls back to seed defaults when nothing is stored', () {
    expect(
      repo.all.map((t) => t.id).toList(),
      kDefaultTagDefs.map((t) => t.id).toList(),
    );
  });

  test('falls back to defaults when stored value is the wrong type', () async {
    await box.put('tags_v1', 'not a list');
    expect(repo.all, isNotEmpty);
    expect(repo.all.first.id, kDefaultTagDefs.first.id);
  });

  test('falls back to defaults when stored list is empty', () async {
    await box.put('tags_v1', <dynamic>[]);
    expect(
      repo.all.map((t) => t.id).toList(),
      kDefaultTagDefs.map((t) => t.id).toList(),
    );
  });

  test('forKind filters and preserves global order', () {
    final phraseIds = repo.forKind(ItemKind.phrase).map((t) => t.id).toList();
    expect(phraseIds, ['serious', 'funny', 'dark', 'romantic', 'hopeful',
      'lyric', 'rant', 'prayer', 'observation']);
    final journalIds = repo.forKind(ItemKind.journal).map((t) => t.id).toList();
    expect(journalIds, ['serious', 'dark', 'hopeful', 'observation']);
  });

  test('byId returns the tag for known ids and null for unknown', () {
    expect(repo.byId('serious')?.label, 'serious');
    expect(repo.byId('not-a-real-tag'), isNull);
    expect(repo.byId(null), isNull);
    expect(repo.byId(''), isNull);
  });

  group('upsert', () {
    test('appends a brand-new tag', () async {
      await repo.upsert(
        const TagDescriptor(
          id: 'wistful',
          label: 'wistful',
          color: Color(0xFFAA8855),
          kinds: {ItemKind.phrase},
        ),
      );
      expect(repo.byId('wistful')?.label, 'wistful');
      expect(repo.all.last.id, 'wistful');
    });

    test('replaces an existing tag in place (preserves order)', () async {
      final originalIds = repo.all.map((t) => t.id).toList();
      await repo.upsert(
        const TagDescriptor(
          id: 'serious',
          label: 'grave',
          color: Color(0xFF223344),
          kinds: {ItemKind.poem, ItemKind.lyric},
        ),
      );
      final newIds = repo.all.map((t) => t.id).toList();
      expect(newIds, originalIds, reason: 'order should not shift on replace');
      final updated = repo.byId('serious')!;
      expect(updated.label, 'grave');
      expect(updated.color.toARGB32(), 0xFF223344);
      expect(updated.kinds, {ItemKind.poem, ItemKind.lyric});
    });

    test('rejects empty id or label', () async {
      expect(
        () => repo.upsert(
          const TagDescriptor(
            id: '',
            label: 'whatever',
            color: Color(0xFF000000),
            kinds: {ItemKind.phrase},
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => repo.upsert(
          const TagDescriptor(
            id: 'foo',
            label: '   ',
            color: Color(0xFF000000),
            kinds: {ItemKind.phrase},
          ),
        ),
        throwsArgumentError,
      );
    });

    test('trims id and label whitespace', () async {
      await repo.upsert(
        const TagDescriptor(
          id: '  trimmed  ',
          label: '  Trimmed Label  ',
          color: Color(0xFF112233),
          kinds: {ItemKind.phrase},
        ),
      );
      final saved = repo.byId('trimmed')!;
      expect(saved.id, 'trimmed');
      expect(saved.label, 'Trimmed Label');
    });
  });

  group('removeFromKind', () {
    test('drops only the requested kind when others remain', () async {
      await repo.removeFromKind('serious', ItemKind.phrase);
      final tag = repo.byId('serious');
      expect(tag, isNotNull);
      expect(tag!.kinds, {ItemKind.poem, ItemKind.lyric, ItemKind.journal});
    });

    test('fully deletes the tag when its last kind is removed', () async {
      // 'rant' seeds with only the phrase kind.
      await repo.removeFromKind('rant', ItemKind.phrase);
      expect(repo.byId('rant'), isNull);
    });

    test('is a no-op for unknown ids', () async {
      final before = repo.all.length;
      await repo.removeFromKind('not-a-real-tag', ItemKind.phrase);
      expect(repo.all.length, before);
    });
  });

  test('delete removes the tag regardless of its kinds', () async {
    await repo.delete('serious');
    expect(repo.byId('serious'), isNull);
    expect(
      repo.all.any((t) => t.id == 'serious'),
      isFalse,
    );
  });

  test('resetToDefaults restores the seed list after edits', () async {
    await repo.delete('serious');
    await repo.upsert(
      const TagDescriptor(
        id: 'wistful',
        label: 'wistful',
        color: Color(0xFFAA8855),
        kinds: {ItemKind.phrase},
      ),
    );
    await repo.resetToDefaults();
    expect(
      repo.all.map((t) => t.id).toList(),
      kDefaultTagDefs.map((t) => t.id).toList(),
    );
  });

  test('persists across repository instances (round-trip via Hive)', () async {
    await repo.upsert(
      const TagDescriptor(
        id: 'wistful',
        label: 'wistful',
        color: Color(0xFFAA8855),
        kinds: {ItemKind.phrase, ItemKind.poem},
      ),
    );
    final repo2 = TagsRepository(box);
    final restored = repo2.byId('wistful')!;
    expect(restored.label, 'wistful');
    expect(restored.color.toARGB32(), 0xFFAA8855);
    expect(restored.kinds, {ItemKind.phrase, ItemKind.poem});
  });

  test('skips malformed entries in a stored list', () async {
    await box.put('tags_v1', <dynamic>[
      {
        'id': 'good',
        'label': 'good',
        'color': 0xFF112233,
        'kinds': ['phrase'],
      },
      // wrong shape — should be silently skipped
      'not a map',
      {'id': 'bad-no-color', 'label': 'bad', 'kinds': []},
    ]);
    final ids = repo.all.map((t) => t.id).toList();
    expect(ids, ['good']);
  });

  test('watch() emits when the tag list mutates', () async {
    final events = <BoxEvent>[];
    final sub = repo.watch().listen(events.add);
    await repo.upsert(
      const TagDescriptor(
        id: 'wistful',
        label: 'wistful',
        color: Color(0xFFAA8855),
        kinds: {ItemKind.phrase},
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(events, isNotEmpty);
    expect(events.first.key, 'tags_v1');
  });
}
