import 'package:hive_ce/hive.dart';

import 'models/item.dart';
import 'models/item_kind.dart';

class ItemsRepository {
  ItemsRepository(this._box);

  final Box<Item> _box;

  List<Item> all() => _box.values.where((e) => e.deletedAtMs == null).toList();

  List<Item> byKind(ItemKind kind) {
    final list = _box.values
        .where((e) => e.deletedAtMs == null && e.kind == kind)
        .toList();
    list.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return list;
  }

  Item? get(String id) {
    final item = _box.get(id);
    if (item == null || item.deletedAtMs != null) return null;
    return item;
  }

  /// Internal lookup that returns a tombstoned item if present. Used by sync
  /// when comparing local state against the remote manifest.
  Item? rawGet(String id) => _box.get(id);

  Iterable<Item> rawValues() => _box.values;

  Future<void> put(Item item) async {
    await _box.put(item.id, item);
  }

  /// Soft-delete: marks the item as a tombstone so the deletion can propagate
  /// through Drive sync. Audio file cleanup is the caller's responsibility.
  Future<void> delete(String id) async {
    final existing = _box.get(id);
    if (existing == null) return;
    existing.deletedAtMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _box.put(id, existing);
  }

  Stream<BoxEvent> watch() => _box.watch();
}
