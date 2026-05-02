import 'dart:io';

import 'package:catchline/data/boxes.dart';
import 'package:catchline/data/models/audio_clip_meta.dart';
import 'package:catchline/data/models/item.dart';
import 'package:catchline/data/models/item_kind.dart';
import 'package:catchline/hive_registrar.g.dart';
import 'package:catchline/state/items_notifier.dart';
import 'package:catchline/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

Item _item({
  required String id,
  ItemKind kind = ItemKind.journal,
  int createdAtMs = 1,
  int? updatedAtMs,
  List<AudioClipMeta> clips = const [],
}) => Item(
  id: id,
  kind: kind,
  title: id,
  textBody: '',
  audioClips: clips,
  createdAtMs: createdAtMs,
  updatedAtMs: updatedAtMs ?? createdAtMs,
);

void main() {
  late Directory tempDir;
  late Boxes boxes;
  late ProviderContainer container;
  var adaptersRegistered = false;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('catchline_notifier_');
    Hive.init(tempDir.path);
    if (!adaptersRegistered) {
      Hive.registerAdapters();
      adaptersRegistered = true;
    }
    final items = await Hive.openBox<Item>('items_notifier_test');
    final syncMeta = await Hive.openBox<dynamic>('sync_meta_notifier_test');
    final appSettings = await Hive.openBox<dynamic>(
      'app_settings_notifier_test',
    );
    boxes = Boxes(items: items, syncMeta: syncMeta, appSettings: appSettings);
    container = ProviderContainer(
      overrides: [boxesProvider.overrideWithValue(boxes)],
    );
  });

  tearDown(() async {
    container.dispose();
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  // The notifier subscribes to box.watch() and pushes new state on every event.
  // Hive emits BoxEvents on a microtask, so we drain pending microtasks before
  // re-reading the provider.
  Future<void> flush() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('initial state contains items already in the box', () async {
    final repo = container.read(itemsRepoProvider);
    await repo.put(_item(id: 'a'));
    await repo.put(_item(id: 'b'));

    final initial = container.read(itemsProvider);
    expect(initial.map((i) => i.id).toSet(), {'a', 'b'});
  });

  test('reacts to puts by re-reading the repository', () async {
    container.read(itemsProvider); // build the notifier.
    final repo = container.read(itemsRepoProvider);

    await repo.put(_item(id: 'x'));
    await flush();

    final after = container.read(itemsProvider);
    expect(after.map((i) => i.id), contains('x'));
  });

  test('reacts to deletes by dropping tombstones', () async {
    final repo = container.read(itemsRepoProvider);
    await repo.put(_item(id: 'x'));
    container.read(itemsProvider);
    await flush();

    await repo.delete('x');
    await flush();

    expect(container.read(itemsProvider), isEmpty);
  });

  group('itemsByKindProvider', () {
    test('filters by kind', () async {
      final repo = container.read(itemsRepoProvider);
      await repo.put(_item(id: 'p1', kind: ItemKind.poem));
      await repo.put(_item(id: 'l1', kind: ItemKind.lyric));
      await flush();

      final poems = container.read(itemsByKindProvider(ItemKind.poem));
      expect(poems.map((i) => i.id), ['p1']);
    });

    test('sorts newest-first by createdAtMs', () async {
      final repo = container.read(itemsRepoProvider);
      await repo.put(_item(id: 'old', kind: ItemKind.poem, createdAtMs: 1));
      await repo.put(_item(id: 'new', kind: ItemKind.poem, createdAtMs: 100));
      await repo.put(_item(id: 'mid', kind: ItemKind.poem, createdAtMs: 50));
      await flush();

      final poems = container.read(itemsByKindProvider(ItemKind.poem));
      expect(poems.map((i) => i.id).toList(), ['new', 'mid', 'old']);
    });
  });
}
