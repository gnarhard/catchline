import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/audio_clip_meta.dart';
import '../../data/models/item.dart';
import '../../data/models/item_kind.dart';
import '../../state/providers.dart';
import '../../util/journal_date.dart';
import 'widgets/audio_clip_tile.dart';
import 'widgets/audio_recorder.dart';

class ItemEditScreen extends ConsumerStatefulWidget {
  const ItemEditScreen({super.key, required this.itemId, required this.kind});

  final String itemId;
  final ItemKind kind;

  @override
  ConsumerState<ItemEditScreen> createState() => _ItemEditScreenState();
}

class _ItemEditScreenState extends ConsumerState<ItemEditScreen> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late List<AudioClipMeta> _clips;
  late String _initialTitle;
  late String _initialBody;
  late int _createdAtMs;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _body = TextEditingController();
    _clips = [];
  }

  void _initFrom(Item item) {
    _title.text = item.title;
    _body.text = item.textBody;
    _clips = List<AudioClipMeta>.from(item.audioClips);
    _initialTitle = item.title;
    _initialBody = item.textBody;
    _createdAtMs = item.createdAtMs;
    _initialized = true;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  bool get _hasTitle =>
      widget.kind != ItemKind.phrase && widget.kind != ItemKind.journal;

  bool get _isDirty =>
      (_hasTitle && _title.text != _initialTitle) || _body.text != _initialBody;

  Item? _readItem() => ref.read(itemsRepoProvider).get(widget.itemId);

  Future<void> _persistInlineChange() async {
    final item = _readItem();
    if (item == null) return;
    item.title = _title.text;
    item.textBody = _body.text;
    item.audioClips = List<AudioClipMeta>.from(_clips);
    item.createdAtMs = _createdAtMs;
    item.updatedAtMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    await ref.read(itemsRepoProvider).put(item);
    _initialTitle = _title.text;
    _initialBody = _body.text;
  }

  Future<void> _saveAndPop() async {
    final item = _readItem();
    if (item == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final newTitle = _hasTitle ? _title.text : '';
    final newBody = _body.text;
    final hasMeaningfulContent =
        newTitle.trim().isNotEmpty ||
        newBody.trim().isNotEmpty ||
        _clips.isNotEmpty;

    if (!hasMeaningfulContent) {
      // Brand-new empty item — drop it instead of leaving an "Untitled" stub.
      await ref.read(itemsRepoProvider).delete(item.id);
      if (mounted) Navigator.of(context).pop();
      return;
    }

    item.title = newTitle;
    item.textBody = newBody;
    item.audioClips = List<AudioClipMeta>.from(_clips);
    item.createdAtMs = _createdAtMs;
    item.updatedAtMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    await ref.read(itemsRepoProvider).put(item);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickJournalDate() async {
    final current = DateTime.fromMillisecondsSinceEpoch(_createdAtMs).toLocal();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    final newLocal = DateTime(
      picked.year,
      picked.month,
      picked.day,
      current.hour,
      current.minute,
      current.second,
      current.millisecond,
    );
    final newMs = newLocal.toUtc().millisecondsSinceEpoch;
    if (newMs == _createdAtMs) return;
    setState(() => _createdAtMs = newMs);
    await _persistInlineChange();
  }

  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: Text(
          _hasTitle
              ? 'You have unsaved changes to the title or body. Discard them?'
              : 'You have unsaved changes. Discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<bool> _confirmDeleteItem() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: Text(
          'This permanently removes the ${widget.kind.singular} and all its audio clips.',
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
    return result ?? false;
  }

  Future<bool> _confirmDeleteClip(int index) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete clip ${index + 1}?'),
        content: const Text('This permanently removes the audio recording.'),
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
    return result ?? false;
  }

  Future<void> _deleteItem() async {
    final ok = await _confirmDeleteItem();
    if (!ok) return;
    final audioRepo = ref.read(audioRepoProvider);
    for (final clip in _clips) {
      await audioRepo.delete(clip);
    }
    await ref.read(itemsRepoProvider).delete(widget.itemId);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _deleteClip(int index) async {
    final ok = await _confirmDeleteClip(index);
    if (!ok) return;
    final clip = _clips[index];
    await ref.read(audioRepoProvider).delete(clip);
    setState(() => _clips.removeAt(index));
    await _persistInlineChange();
  }

  Future<void> _onClipRecorded(AudioClipMeta meta) async {
    setState(() => _clips.add(meta));
    await _persistInlineChange();
  }

  @override
  Widget build(BuildContext context) {
    final item = _readItem();
    if (item == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(widget.kind.label)),
        body: const Center(child: Text('Item not found.')),
      );
    }

    if (!_initialized) {
      _initFrom(item);
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isJournal = widget.kind == ItemKind.journal;
    final Widget appBarTitle;
    if (isJournal) {
      appBarTitle = InkWell(
        onTap: _pickJournalDate,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  formatJournalTitle(_createdAtMs),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                LucideIcons.chevronDown,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      );
    } else {
      final singular = widget.kind.singular;
      final label = singular[0].toUpperCase() + singular.substring(1);
      appBarTitle = Text(label);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _confirmDiscard();
        if (!ok) return;
        await _saveAndPop();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: appBarTitle,
          actions: [
            IconButton(
              tooltip: 'Delete',
              onPressed: _deleteItem,
              icon: const Icon(LucideIcons.trash2, size: 20),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                children: [
                  if (_hasTitle) ...[
                    TextField(
                      controller: _title,
                      decoration: const InputDecoration(
                        hintText: 'Title',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                    ),
                    Container(
                      height: 1,
                      color: colorScheme.outlineVariant.withAlpha(140),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _body,
                    decoration: const InputDecoration(
                      hintText: 'Write something…',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                      height: 1.6,
                    ),
                    minLines: 6,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 1,
                    color: colorScheme.outlineVariant.withAlpha(140),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Audio',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AudioRecorderButton(onClipRecorded: _onClipRecorded),
                  const SizedBox(height: 12),
                  if (_clips.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No clips yet. Tap Record to capture audio.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    for (var i = 0; i < _clips.length; i++)
                      AudioClipTile(
                        key: ValueKey(_clips[i].id),
                        clip: _clips[i],
                        index: i,
                        onDelete: () => _deleteClip(i),
                      ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saveAndPop,
                    icon: const Icon(LucideIcons.check, size: 18),
                    label: const Text('Save'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
