import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/item.dart';
import '../../data/models/item_kind.dart';
import '../../state/items_notifier.dart';
import '../../state/providers.dart';
import '../../util/id.dart';
import '../../util/instant_page_route.dart';
import '../../util/journal_date.dart';
import 'item_edit_screen.dart';
import 'widgets/empty_state.dart';
import 'widgets/item_tile.dart';

class ItemListScreen extends ConsumerStatefulWidget {
  const ItemListScreen({super.key, required this.kind});

  final ItemKind kind;

  @override
  ConsumerState<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends ConsumerState<ItemListScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allItems = ref.watch(itemsByKindProvider(widget.kind));
    final items = _filter(allItems, _query);
    final isSearching = _query.trim().isNotEmpty;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Icon(
              LucideIcons.search,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                style: theme.textTheme.bodyLarge,
                decoration: const InputDecoration(
                  hintText: 'Search',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (isSearching)
              IconButton(
                icon: const Icon(LucideIcons.x, size: 18),
                tooltip: 'Clear search',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: items.isEmpty
              ? (isSearching
                    ? _NoMatches(query: _query)
                    : EmptyState(kind: widget.kind))
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
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_${widget.kind.name}',
        onPressed: () => _create(context, ref),
        child: const Icon(LucideIcons.plus, size: 18),
      ),
    );
  }

  List<Item> _filter(List<Item> items, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((item) {
      if (item.title.toLowerCase().contains(q)) return true;
      if (item.textBody.toLowerCase().contains(q)) return true;
      if (item.kind == ItemKind.journal &&
          formatJournalTitle(item.createdAtMs).toLowerCase().contains(q)) {
        return true;
      }
      return false;
    }).toList();
  }

  void _open(BuildContext context, Item item) {
    Navigator.of(context).push(
      InstantPageRoute<void>(
        builder: (_) => ItemEditScreen(itemId: item.id, kind: item.kind),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    if (widget.kind == ItemKind.journal) {
      final today = todayKey();
      final existing = ref
          .read(itemsByKindProvider(ItemKind.journal))
          .where((i) => dayKey(i.createdAtMs) == today)
          .firstOrNull;
      if (existing != null) {
        Navigator.of(context).push(
          InstantPageRoute<void>(
            builder: (_) =>
                ItemEditScreen(itemId: existing.id, kind: ItemKind.journal),
          ),
        );
        return;
      }
    }

    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final item = Item(
      id: newId(),
      kind: widget.kind,
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
        builder: (_) => ItemEditScreen(itemId: item.id, kind: widget.kind),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.searchX, size: 48, color: color.withAlpha(180)),
          const SizedBox(height: 20),
          Text(
            'No matches',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Nothing found for “${query.trim()}”.',
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
