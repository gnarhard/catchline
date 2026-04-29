import 'package:hive_ce/hive.dart';

import 'models/item.dart';
import 'models/item_kind.dart';

class ItemsRepository {
  ItemsRepository(this._box);

  final Box<Item> _box;

  List<Item> all() => _box.values.toList();

  List<Item> byKind(ItemKind kind) {
    final list = _box.values.where((e) => e.kind == kind).toList();
    list.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return list;
  }

  Item? get(String id) {
    for (final item in _box.values) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> put(Item item) async {
    await _box.put(item.id, item);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Stream<BoxEvent> watch() => _box.watch();
}
