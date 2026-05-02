import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/item_kind.dart';
import '../../../data/models/tag_palette.dart';
import '../../../state/providers.dart';
import '../../../theme/app_theme.dart';

/// Bottom sheet for filtering a list of items by one or more tags.
///
/// Returns the selected tag id set when closed (null = filter cleared).
/// Used from the filter icon in non-journal list screen headers.
class TagFilterSheet extends ConsumerStatefulWidget {
  const TagFilterSheet({
    super.key,
    required this.kind,
    required this.initialSelection,
    required this.totalCount,
  });

  final ItemKind kind;
  final Set<String> initialSelection;

  /// Used to label the apply button ("Show N items"). Caller computes the
  /// up-to-date count for the selection so the sheet doesn't need to reach
  /// into Riverpod.
  final int totalCount;

  static Future<Set<String>?> show(
    BuildContext context, {
    required ItemKind kind,
    required Set<String> initialSelection,
    required int totalCount,
  }) {
    return showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withAlpha(140),
      builder: (_) => TagFilterSheet(
        kind: kind,
        initialSelection: initialSelection,
        totalCount: totalCount,
      ),
    );
  }

  @override
  ConsumerState<TagFilterSheet> createState() => _TagFilterSheetState();
}

class _TagFilterSheetState extends ConsumerState<TagFilterSheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initialSelection};
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _clear() => setState(_selected.clear);

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(tagsForKindProvider(widget.kind));
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A1018), Color(0xFF1A080E)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0x14FFDCDC))),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 6, bottom: 18),
                decoration: BoxDecoration(
                  color: const Color(0x33FFDCDC),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    'Filter by tag',
                    style: serifStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _selected.isEmpty ? null : _clear,
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const _SectionLabel('MOOD'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in tags)
                  _FilterTag(
                    tag: t,
                    selected: _selected.contains(t.id),
                    onTap: () => _toggle(t.id),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(_selected.isEmpty ? <String>{} : _selected),
                    child: Text(
                      _selected.isEmpty
                          ? 'Show all (${widget.totalCount})'
                          : 'Apply (${_selected.length} ${_selected.length == 1 ? 'tag' : 'tags'})',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTag extends StatelessWidget {
  const _FilterTag({
    required this.tag,
    required this.selected,
    required this.onTap,
  });

  final TagDescriptor tag;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? tag.color.withAlpha(46) : const Color(0x08FFDCDC);
    final border = selected
        ? tag.color.withAlpha(140)
        : const Color(0x14FFDCDC);
    final fg = selected ? AppColors.textPrimary : AppColors.textDim;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: tag.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                tag.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                Icon(Icons.check, size: 14, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
        color: AppColors.textMuted,
      ),
    );
  }
}
