import 'dart:io';

import 'package:catchline/data/items_repository.dart';
import 'package:catchline/data/models/item.dart';
import 'package:catchline/data/models/item_kind.dart';
import 'package:catchline/hive_registrar.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

Item _item({
  required String id,
  ItemKind kind = ItemKind.journal,
  int updatedAtMs = 1,
}) => Item(
  id: id,
  kind: kind,
  title: id,
  textBody: '',
  audioClips: const [],
  createdAtMs: updatedAtMs,
  updatedAtMs: updatedAtMs,
);

void main() {
  late Directory tempDir;
  late Box<Item> box;
  late ItemsRepository repo;
  var adaptersRegistered = false;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('catchline_repo_test_');
    Hive.init(tempDir.path);
    if (!adaptersRegistered) {
      Hive.registerAdapters();
      adaptersRegistered = true;
    }
    box = await Hive.openBox<Item>('items_repo_test');
    repo = ItemsRepository(box);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('all() filters tombstones', () async {
    await repo.put(_item(id: 'a'));
    await repo.put(_item(id: 'b'));
    expect(repo.all().length, 2);

    await repo.delete('a');
    final visible = repo.all();
    expect(visible.length, 1);
    expect(visible.single.id, 'b');
  });

  test('byKind() filters tombstones', () async {
    await repo.put(_item(id: 'p1', kind: ItemKind.poem));
    await repo.put(_item(id: 'p2', kind: ItemKind.poem));
    await repo.put(_item(id: 'j1', kind: ItemKind.journal));
    await repo.delete('p1');

    final poems = repo.byKind(ItemKind.poem);
    expect(poems.length, 1);
    expect(poems.single.id, 'p2');

    expect(repo.byKind(ItemKind.journal).length, 1);
  });

  test('get() returns null for tombstoned items', () async {
    await repo.put(_item(id: 'x'));
    expect(repo.get('x'), isNotNull);
    await repo.delete('x');
    expect(repo.get('x'), isNull);
  });

  test('rawGet() and rawValues() expose tombstones for sync', () async {
    await repo.put(_item(id: 'x'));
    await repo.delete('x');
    final raw = repo.rawGet('x');
    expect(raw, isNotNull);
    expect(raw!.deletedAtMs, isNotNull);
    expect(repo.rawValues().length, 1);
  });

  test('delete() is idempotent on missing ids', () async {
    await repo.delete('nope'); // should not throw
    expect(repo.all(), isEmpty);
  });
}
