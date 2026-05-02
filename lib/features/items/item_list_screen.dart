import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/item.dart';
import '../../data/models/item_kind.dart';
import '../../state/items_notifier.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../util/id.dart';
import '../../util/instant_page_route.dart';
import '../../util/journal_date.dart';
import '../../util/text_preview.dart';
import 'item_edit_screen.dart';
import 'list_filter.dart';
import 'widgets/calendar_jump_sheet.dart';
import 'widgets/empty_state.dart';
import 'widgets/item_tile.dart';
import 'widgets/list_header.dart';
import 'widgets/tag_filter_sheet.dart';

class ItemListScreen extends ConsumerStatefulWidget {
  const ItemListScreen({super.key, required this.kind});

  final ItemKind kind;

  @override
  ConsumerState<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends ConsumerState<ItemListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final List<GlobalKey> _itemKeys = [];
  String _query = '';
  bool _searchOpen = false;
  Set<String> _tagFilter = const {};

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allItems = ref.watch(itemsByKindProvider(widget.kind));
    final allItemsForCounts = ref.watch(itemsProvider);
    final items = _filter(allItems, _query, _tagFilter);
    final hasFilter = _tagFilter.isNotEmpty;

    while (_itemKeys.length < items.length) {
      _itemKeys.add(GlobalKey());
    }

    final supportsTagFilter = widget.kind != ItemKind.journal;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            ListHeader(
              title: widget.kind.label,
              subtitle: hasFilter
                  ? 'Filtered · ${_tagFilter.length} ${_tagFilter.length == 1 ? 'tag' : 'tags'}'
                  : null,
              onSearch: () => setState(() {
                _searchOpen = !_searchOpen;
                if (!_searchOpen) {
                  _searchController.clear();
                  _query = '';
                }
              }),
              onFilter: supportsTagFilter
                  ? () => _openFilterSheet(context)
                  : null,
              filterActive: hasFilter,
              searchActive: _searchOpen,
              onCalendar: () => _openCalendarSheet(context, allItemsForCounts),
            ),
            if (_searchOpen)
              _SearchField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                onClear: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
            if (hasFilter)
              _ActiveFilterStrip(
                tagIds: _tagFilter.toList(),
                onClear: () => setState(_tagFilter.clear),
              ),
            Expanded(
              child: items.isEmpty
                  ? (_query.trim().isNotEmpty
                        ? _NoMatches(query: _query)
                        : (hasFilter
                              ? const _NoFilterMatches()
                              : EmptyState(kind: widget.kind)))
                  : ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        thickness: 1,
                        indent: 20,
                        endIndent: 20,
                        color: AppColors.textPrimary.withAlpha(12),
                      ),
                      itemBuilder: (context, i) {
                        final item = items[i];
                        return KeyedSubtree(
                          key: _itemKeys[i],
                          child: ItemTile(
                            item: item,
                            onTap: () => _open(context, item),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_${widget.kind.name}',
        onPressed: () => _create(context, ref),
        child: const Icon(LucideIcons.plus, size: 18),
      ),
    );
  }

  Future<void> _openFilterSheet(BuildContext context) async {
    final allItems = ref.read(itemsByKindProvider(widget.kind));
    final result = await TagFilterSheet.show(
      context,
      kind: widget.kind,
      initialSelection: _tagFilter,
      totalCount: allItems.length,
    );
    if (result == null) return;
    setState(() => _tagFilter = result);
  }

  Future<void> _openCalendarSheet(
    BuildContext context,
    List<Item> allItems,
  ) async {
    final counts = dayCountsFromItems(allItems);
    final scopedItems = ref.read(itemsByKindProvider(widget.kind));
    String? previewFor(DateTime day) {
      final key = day.year * 10000 + day.month * 100 + day.day;
      for (final item in scopedItems) {
        if (dayKey(item.createdAtMs) == key) {
          final preview = textPreview(item.textBody);
          if (preview.isNotEmpty) return preview;
          if (item.title.trim().isNotEmpty) return item.title;
          return null;
        }
      }
      return null;
    }

    final picked = await CalendarJumpSheet.show(
      context,
      scope: widget.kind.label,
      counts: counts,
      preview: (d) => previewFor(d) ?? '',
    );
    if (picked == null) return;
    if (!context.mounted) return;
    _navigateToDay(context, picked);
  }

  void _navigateToDay(BuildContext context, DateTime day) {
    final key = day.year * 10000 + day.month * 100 + day.day;
    final items = ref.read(itemsByKindProvider(widget.kind));
    final filtered = _filter(items, _query, _tagFilter);
    final matchIndex = filtered.indexWhere(
      (item) => dayKey(item.createdAtMs) == key,
    );
    if (matchIndex >= 0 && matchIndex < _itemKeys.length) {
      final ctx = _itemKeys[matchIndex].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.05,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
        return;
      }
    }
    if (widget.kind == ItemKind.journal) {
      final existing = items.firstWhere(
        (item) => dayKey(item.createdAtMs) == key,
        orElse: () => _emptyJournalForDay(day),
      );
      _open(context, existing);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'No ${widget.kind.singular} on ${formatItemDate(day.toUtc().millisecondsSinceEpoch)}',
        ),
      ),
    );
  }

  Item _emptyJournalForDay(DateTime day) {
    final ms = DateTime(
      day.year,
      day.month,
      day.day,
      9,
    ).toUtc().millisecondsSinceEpoch;
    return Item(
      id: '__placeholder__',
      kind: ItemKind.journal,
      title: '',
      textBody: '',
      audioClips: const [],
      createdAtMs: ms,
      updatedAtMs: ms,
    );
  }

  List<Item> _filter(List<Item> items, String query, Set<String> tagFilter) =>
      filterItems(items, query: query, tagFilter: tagFilter);

  void _open(BuildContext context, Item item) {
    if (item.id == '__placeholder__') {
      _createForDate(
        context,
        DateTime.fromMillisecondsSinceEpoch(item.createdAtMs),
      );
      return;
    }
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

  Future<void> _createForDate(BuildContext context, DateTime day) async {
    final ms = DateTime(
      day.year,
      day.month,
      day.day,
      9,
    ).toUtc().millisecondsSinceEpoch;
    final item = Item(
      id: newId(),
      kind: ItemKind.journal,
      title: '',
      textBody: '',
      audioClips: const [],
      createdAtMs: ms,
      updatedAtMs: ms,
    );
    await ref.read(itemsRepoProvider).put(item);
    if (!context.mounted) return;
    Navigator.of(context).push(
      InstantPageRoute<void>(
        builder: (_) => ItemEditScreen(itemId: item.id, kind: ItemKind.journal),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0x0AFFDCDC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x14FFDCDC)),
        ),
        child: Row(
          children: [
            const Icon(
              LucideIcons.search,
              size: 16,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'Search',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            if (controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(LucideIcons.x, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: onClear,
              ),
          ],
        ),
      ),
    );
  }
}

class _ActiveFilterStrip extends StatelessWidget {
  const _ActiveFilterStrip({required this.tagIds, required this.onClear});
  final List<String> tagIds;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: Row(
        children: [
          const Text(
            'Filtered:',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final id in tagIds) ...[
                    _ActiveTag(id: id),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _ActiveTag extends StatelessWidget {
  const _ActiveTag({required this.id});
  final String id;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x2EF7C4C0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        id,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.searchX,
            size: 44,
            color: AppColors.textMuted.withAlpha(180),
          ),
          const SizedBox(height: 18),
          Text(
            'No matches',
            style: serifStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Nothing found for “${query.trim()}”.',
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NoFilterMatches extends StatelessWidget {
  const _NoFilterMatches();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.listFilter,
            size: 44,
            color: AppColors.textMuted.withAlpha(180),
          ),
          const SizedBox(height: 18),
          Text(
            'No matching tags',
            style: serifStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'No items in this tab match the active tag filter.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
