import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/items_repository.dart';
import '../data/models/item.dart';
import '../data/models/item_kind.dart';
import 'providers.dart';

class ItemsNotifier extends Notifier<List<Item>> {
  late ItemsRepository _repo;

  @override
  List<Item> build() {
    _repo = ref.watch(itemsRepoProvider);
    final sub = _repo.watch().listen((_) {
      state = _repo.all();
    });
    ref.onDispose(sub.cancel);
    return _repo.all();
  }
}

final itemsProvider = NotifierProvider<ItemsNotifier, List<Item>>(
  ItemsNotifier.new,
);

final itemsByKindProvider = Provider.family<List<Item>, ItemKind>((ref, kind) {
  final all = ref.watch(itemsProvider);
  final filtered = all.where((item) => item.kind == kind).toList();
  filtered.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
  return filtered;
});
