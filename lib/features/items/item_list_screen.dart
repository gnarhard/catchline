import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/item.dart';
import '../../data/models/item_kind.dart';
import '../../state/items_notifier.dart';
import '../../state/providers.dart';
import '../../util/id.dart';
import '../../util/instant_page_route.dart';
import '../settings/settings_screen.dart';
import 'item_edit_screen.dart';
import 'widgets/empty_state.dart';
import 'widgets/item_tile.dart';

class ItemListScreen extends ConsumerWidget {
  const ItemListScreen({super.key, required this.kind});

  final ItemKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itemsByKindProvider(kind));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(kind.label),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              InstantPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: items.isEmpty
              ? EmptyState(kind: kind)
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return ItemTile(
                      item: item,
                      onTap: () => _open(context, item),
                    );
                  },
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_${kind.name}',
        onPressed: () => _create(context, ref),
        icon: const Icon(LucideIcons.plus, size: 18),
        label: const Text('New'),
      ),
    );
  }

  void _open(BuildContext context, Item item) {
    Navigator.of(context).push(
      InstantPageRoute<void>(
        builder: (_) => ItemEditScreen(itemId: item.id, kind: item.kind),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final item = Item(
      id: newId(),
      kind: kind,
      title: '',
      textBody: '',
      audioClips: [],
      createdAtMs: nowMs,
      updatedAtMs: nowMs,
    );
    await ref.read(itemsRepoProvider).put(item);
    if (!context.mounted) return;
    Navigator.of(context).push(
      InstantPageRoute<void>(
        builder: (_) => ItemEditScreen(itemId: item.id, kind: kind),
      ),
    );
  }
}
