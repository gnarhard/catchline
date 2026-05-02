import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/item_kind.dart';
import '../../data/models/tag_palette.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../home/home_shell.dart' show kMaxContentWidth;

/// Per-kind tag editor reached from Settings → Tags. Lets the user rename
/// tags, change their color, add new ones, and remove a tag from this kind
/// (or delete it outright). All edits are applied through [TagsRepository]
/// so pickers/badges across the app reflect them live.
class TagEditorScreen extends ConsumerWidget {
  const TagEditorScreen({super.key, required this.kind});

  final ItemKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagsForKindProvider(kind));
    final allTags = ref.watch(tagsProvider).value ?? const [];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text('${_kindAdjective(kind)} tags')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(
                  'Tags appear in the picker when you write a '
                  '${kind.singular}, and as filter chips on the list.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                if (tags.isEmpty)
                  const _EmptyHint()
                else
                  for (final t in tags)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TagRow(
                        tag: t,
                        onEdit: () =>
                            _openEditor(context, ref, kind, existing: t),
                        onRemoveFromKind: () => _removeFromKind(
                          context,
                          ref,
                          tag: t,
                          kind: kind,
                        ),
                      ),
                    ),
                const SizedBox(height: 8),
                _AddTagButton(
                  onPressed: () => _openEditor(
                    context,
                    ref,
                    kind,
                    existingIds: allTags.map((t) => t.id).toSet(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    ItemKind kind, {
    TagDescriptor? existing,
    Set<String> existingIds = const {},
  }) async {
    final existingAll = ref.read(tagsProvider).value ?? const [];
    final result = await showModalBottomSheet<_EditorResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TagEditorSheet(
        kind: kind,
        existing: existing,
        existingIds: existing == null
            ? existingIds
            : existingIds.where((id) => id != existing.id).toSet(),
        existingAll: existingAll,
      ),
    );
    if (result == null) return;
    final repo = ref.read(tagsRepoProvider);
    switch (result.action) {
      case _EditorAction.save:
        await repo.upsert(result.tag!);
      case _EditorAction.delete:
        await repo.delete(result.tag!.id);
    }
  }

  Future<void> _removeFromKind(
    BuildContext context,
    WidgetRef ref, {
    required TagDescriptor tag,
    required ItemKind kind,
  }) async {
    final isOnlyKind = tag.kinds.length == 1 && tag.kinds.contains(kind);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isOnlyKind
              ? 'Delete "${tag.label}"?'
              : 'Remove "${tag.label}" from ${_kindAdjective(kind)}?',
        ),
        content: Text(
          isOnlyKind
              ? 'This is the only kind it belongs to, so the tag will be deleted entirely. Items still tagged with it will keep the id but show as a neutral chip.'
              : 'It will stay available for the other kinds it\'s assigned to.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isOnlyKind ? 'Delete' : 'Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(tagsRepoProvider).removeFromKind(tag.id, kind);
  }

  static String _kindAdjective(ItemKind k) => switch (k) {
    ItemKind.phrase => 'Phrase',
    ItemKind.poem => 'Poem',
    ItemKind.lyric => 'Lyric',
    ItemKind.journal => 'Journal',
  };
}

class _TagRow extends StatelessWidget {
  const _TagRow({
    required this.tag,
    required this.onEdit,
    required this.onRemoveFromKind,
  });
  final TagDescriptor tag;
  final VoidCallback onEdit;
  final VoidCallback onRemoveFromKind;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          decoration: BoxDecoration(
            color: const Color(0x8C14080C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x14FFDCDC)),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: tag.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tag.label,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _kindsSubtitle(tag.kinds),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit tag',
                onPressed: onEdit,
                icon: const Icon(
                  LucideIcons.pencil,
                  size: 14,
                  color: AppColors.textMuted,
                ),
              ),
              IconButton(
                tooltip: 'Remove from this kind',
                onPressed: onRemoveFromKind,
                icon: const Icon(
                  LucideIcons.x,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _kindsSubtitle(Set<ItemKind> kinds) {
    if (kinds.length == ItemKind.values.length) return 'All kinds';
    final names = ItemKind.values
        .where(kinds.contains)
        .map((k) => k.name)
        .toList();
    return names.join(' · ');
  }
}

class _AddTagButton extends StatelessWidget {
  const _AddTagButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(LucideIcons.plus, size: 14),
      label: const Text('Add tag'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accent,
        side: BorderSide(color: AppColors.accent.withAlpha(76)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0x4014080C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14FFDCDC)),
      ),
      child: const Text(
        'No tags yet for this kind. Tap "Add tag" to create one.',
        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
    );
  }
}

enum _EditorAction { save, delete }

class _EditorResult {
  const _EditorResult.save(this.tag) : action = _EditorAction.save;
  const _EditorResult.delete(this.tag) : action = _EditorAction.delete;
  final _EditorAction action;
  final TagDescriptor? tag;
}

class _TagEditorSheet extends StatefulWidget {
  const _TagEditorSheet({
    required this.kind,
    required this.existing,
    required this.existingIds,
    required this.existingAll,
  });

  final ItemKind kind;
  final TagDescriptor? existing;

  /// Ids already in use, excluding the tag being edited (if any). Used to
  /// avoid handing back a duplicate id when the user changes the label.
  final Set<String> existingIds;

  /// Snapshot of the full tag list so duplicate-label detection can match
  /// against the canonical label rather than the slugified id.
  final List<TagDescriptor> existingAll;

  @override
  State<_TagEditorSheet> createState() => _TagEditorSheetState();
}

class _TagEditorSheetState extends State<_TagEditorSheet> {
  late TextEditingController _label;
  late Color _color;
  late Set<ItemKind> _kinds;
  String? _error;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _label = TextEditingController(text: ex?.label ?? '');
    _color = ex?.color ?? kTagColorPresets.first;
    _kinds = ex == null ? {widget.kind} : {...ex.kinds};
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.existing != null;

  void _save() {
    final label = _label.text.trim();
    if (label.isEmpty) {
      setState(() => _error = 'Label is required');
      return;
    }
    if (_kinds.isEmpty) {
      setState(() => _error = 'Pick at least one kind');
      return;
    }
    final id = _isEdit ? widget.existing!.id : _slugifyUnique(label);
    final clashesByLabel = widget.existingAll
        .where(
          (t) =>
              t.id != widget.existing?.id &&
              t.label.toLowerCase() == label.toLowerCase(),
        )
        .isNotEmpty;
    if (clashesByLabel) {
      setState(() => _error = 'Another tag already uses this label');
      return;
    }
    final tag = TagDescriptor(
      id: id,
      label: label,
      color: _color,
      kinds: _kinds,
    );
    Navigator.of(context).pop(_EditorResult.save(tag));
  }

  String _slugifyUnique(String label) {
    final base = label
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final slug = base.isEmpty ? 'tag' : base;
    if (!widget.existingIds.contains(slug)) return slug;
    var n = 2;
    while (widget.existingIds.contains('$slug-$n')) {
      n++;
    }
    return '$slug-$n';
  }

  void _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${widget.existing!.label}"?'),
        content: const Text(
          'Removes the tag from every kind it belongs to. Items already tagged with it keep the id but show as a neutral chip.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    Navigator.of(context).pop(_EditorResult.delete(widget.existing!));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  Text(
                    _isEdit ? 'Edit tag' : 'New tag',
                    style: serifStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _save,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _SectionLabel('LABEL'),
              const SizedBox(height: 8),
              TextField(
                controller: _label,
                autofocus: !_isEdit,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'serious, hopeful, …',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.none,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: 18),
              const _SectionLabel('COLOR'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in kTagColorPresets)
                    _ColorSwatch(
                      color: c,
                      selected: c.toARGB32() == _color.toARGB32(),
                      onTap: () => setState(() => _color = c),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              const _SectionLabel('SHOWS UP IN'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final k in ItemKind.values)
                    _KindToggle(
                      kind: k,
                      selected: _kinds.contains(k),
                      onTap: () => setState(() {
                        if (_kinds.contains(k)) {
                          _kinds.remove(k);
                        } else {
                          _kinds.add(k);
                        }
                      }),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              if (_isEdit) ...[
                const SizedBox(height: 22),
                Container(height: 1, color: const Color(0x14FFDCDC)),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _confirmDelete,
                    icon: Icon(
                      LucideIcons.trash2,
                      size: 14,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    label: Text(
                      'Delete tag',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.textPrimary : Colors.transparent,
            width: 2,
          ),
        ),
        child: selected
            ? const Icon(LucideIcons.check, size: 16, color: Color(0xFF1A080E))
            : null,
      ),
    );
  }
}

class _KindToggle extends StatelessWidget {
  const _KindToggle({
    required this.kind,
    required this.selected,
    required this.onTap,
  });
  final ItemKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent.withAlpha(46) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.accent.withAlpha(140)
                  : const Color(0x2EFFDCDC),
            ),
          ),
          child: Text(
            kind.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: selected ? AppColors.textPrimary : AppColors.textDim,
            ),
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
