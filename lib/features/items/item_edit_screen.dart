import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/ai_service.dart';
import '../../data/models/ai_favorite.dart';
import '../../data/models/audio_clip_meta.dart';
import '../../data/models/item.dart';
import '../../data/models/item_kind.dart';
import '../../data/models/tag_palette.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../util/journal_date.dart';
import '../home/home_shell.dart' show kMaxContentWidth;
import 'list_filter.dart' show appendBody;
import 'widgets/ai_actions.dart';
import 'widgets/ai_favorites_section.dart';
import 'widgets/ai_rephrase_button.dart';
import 'widgets/ai_synopsis_card.dart';
import 'widgets/audio_clip_tile.dart';
import 'widgets/audio_recorder.dart';
import 'widgets/tag_picker.dart';

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
  String? _tag;
  String? _aiSynopsis;
  Map<String, String>? _aiRephrasings;
  List<AiFavorite> _aiFavorites = const [];
  bool _generatingSynopsis = false;
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
    _tag = item.tag;
    _aiSynopsis = item.aiSynopsis;
    _aiRephrasings = item.aiRephrasings == null
        ? null
        : Map<String, String>.from(item.aiRephrasings!);
    _aiFavorites = item.aiFavorites == null
        ? const []
        : List<AiFavorite>.from(item.aiFavorites!);
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

  bool get _supportsTag => widget.kind != ItemKind.journal;

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
    item.tag = _tag;
    item.aiSynopsis = _aiSynopsis;
    item.aiRephrasings = _aiRephrasings;
    item.aiFavorites = _aiFavorites.isEmpty
        ? null
        : List<AiFavorite>.from(_aiFavorites);
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
      await ref.read(itemsRepoProvider).delete(item.id);
      if (mounted) Navigator.of(context).pop();
      return;
    }

    item.title = newTitle;
    item.textBody = newBody;
    item.audioClips = List<AudioClipMeta>.from(_clips);
    item.createdAtMs = _createdAtMs;
    item.tag = _tag;
    item.aiSynopsis = _aiSynopsis;
    item.aiRephrasings = _aiRephrasings;
    item.aiFavorites = _aiFavorites.isEmpty
        ? null
        : List<AiFavorite>.from(_aiFavorites);
    item.updatedAtMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    await ref.read(itemsRepoProvider).put(item);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _generateSynopsis() async {
    final body = _body.text.trim();
    if (body.isEmpty) {
      _showSnack('Write something in the entry first.');
      return;
    }
    setState(() => _generatingSynopsis = true);
    try {
      final apiKey = await ref
          .read(secureSettingsProvider)
          .getAnthropicApiKey();
      if (apiKey == null) {
        _showSnack('Add your Anthropic API key in Settings first.');
        return;
      }
      final synopsis = await ref
          .read(aiServiceProvider)
          .generateJournalSynopsis(apiKey: apiKey, entryBody: body);
      if (!mounted) return;
      setState(() => _aiSynopsis = synopsis);
      await _persistInlineChange();
    } on AiException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Failed to generate synopsis: $e');
    } finally {
      if (mounted) setState(() => _generatingSynopsis = false);
    }
  }

  Future<void> _clearSynopsis() async {
    setState(() => _aiSynopsis = null);
    await _persistInlineChange();
  }

  Future<void> _toggleFavorite(String style, String text) async {
    final existingIndex = _aiFavorites.indexWhere(
      (f) => f.style == style && f.text == text,
    );
    setState(() {
      if (existingIndex >= 0) {
        _aiFavorites = [..._aiFavorites]..removeAt(existingIndex);
      } else {
        _aiFavorites = [
          ..._aiFavorites,
          AiFavorite(
            style: style,
            text: text,
            createdAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
          ),
        ];
      }
    });
    await _persistInlineChange();
  }

  Future<void> _removeFavorite(AiFavorite favorite) async {
    setState(() {
      _aiFavorites = _aiFavorites
          .where((f) => !(f.style == favorite.style && f.text == favorite.text))
          .toList();
    });
    await _persistInlineChange();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

  void _appendToBody(String addition) {
    setState(() => _body.text = appendBody(_body.text, addition));
  }

  @override
  Widget build(BuildContext context) {
    final item = _readItem();
    if (item == null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(title: Text(widget.kind.label)),
            body: const Center(child: Text('Item not found.')),
          ),
        ),
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
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                LucideIcons.chevronDown,
                size: 14,
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
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              leading: _isDirty
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: Material(
                        color: colorScheme.primary,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: _saveAndPop,
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(
                              LucideIcons.check,
                              size: 18,
                              color: colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    )
                  : null,
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
                      horizontal: 22,
                      vertical: 8,
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
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          style: serifStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                      if (_supportsTag) ...[
                        const SizedBox(height: 6),
                        Consumer(
                          builder: (context, ref, _) => _TagAndDateRow(
                            tag: _tag,
                            tagDescriptor:
                                ref.watch(tagsProvider).value
                                    ?.where((t) => t.id == _tag)
                                    .firstOrNull,
                            createdAtMs: _createdAtMs,
                            onTagPressed: _showTagPickerSheet,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Container(
                        height: 1,
                        color: colorScheme.outlineVariant.withAlpha(120),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _body,
                        decoration: InputDecoration(
                          hintText: _bodyHint(widget.kind),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 6,
                          ),
                        ),
                        style: _bodyStyle(widget.kind),
                        minLines: 6,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setState(() {}),
                      ),
                      if (widget.kind == ItemKind.journal) ...[
                        const SizedBox(height: 22),
                        AiSynopsisCard(
                          synopsis: _aiSynopsis,
                          isGenerating: _generatingSynopsis,
                          onGenerate: _generateSynopsis,
                          onClear: _clearSynopsis,
                        ),
                      ],
                      if (widget.kind == ItemKind.phrase) ...[
                        const SizedBox(height: 22),
                        AiRephraseButton(
                          phraseText: _body.text,
                          cachedRephrasings: _aiRephrasings,
                          favorites: _aiFavorites,
                          onSaveResults: (results) async {
                            setState(() => _aiRephrasings = results);
                            await _persistInlineChange();
                          },
                          onToggleFavorite: _toggleFavorite,
                        ),
                        if (_aiFavorites.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          AiFavoritesSection(
                            favorites: _aiFavorites,
                            onRemove: _removeFavorite,
                          ),
                        ],
                      ],
                      if (widget.kind == ItemKind.poem) ...[
                        const SizedBox(height: 22),
                        PoemAiActions(
                          titleController: _title,
                          bodyController: _body,
                          onAcceptTitle: (t) {
                            setState(() => _title.text = t);
                          },
                          onAppendBody: _appendToBody,
                        ),
                      ],
                      if (widget.kind == ItemKind.lyric) ...[
                        const SizedBox(height: 22),
                        LyricAiActions(
                          bodyController: _body,
                          onAppendBody: _appendToBody,
                        ),
                      ],
                      const SizedBox(height: 26),
                      _SectionLabel('AUDIO'),
                      const SizedBox(height: 12),
                      AudioRecorderButton(onClipRecorded: _onClipRecorded),
                      const SizedBox(height: 12),
                      if (_clips.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'No clips yet. Tap Record to capture audio.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showTagPickerSheet() async {
    final result = await showModalBottomSheet<_TagPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TagPickerSheet(kind: widget.kind, current: _tag),
    );
    if (result == null) return;
    setState(() => _tag = result.tag);
    await _persistInlineChange();
  }

  String _bodyHint(ItemKind kind) => switch (kind) {
    ItemKind.journal => 'What\'s on your mind?',
    ItemKind.poem => 'Write the poem…',
    ItemKind.lyric => 'Write the lyric…',
    ItemKind.phrase => 'Capture the phrase…',
  };

  TextStyle _bodyStyle(ItemKind kind) {
    return switch (kind) {
      ItemKind.poem || ItemKind.lyric => serifStyle(
        fontSize: 16,
        height: 1.7,
        color: AppColors.textPrimary,
      ),
      ItemKind.phrase => serifStyle(
        fontSize: 18,
        height: 1.45,
        color: AppColors.textPrimary,
      ),
      ItemKind.journal => serifStyle(
        fontSize: 16,
        height: 1.55,
        color: AppColors.textPrimary,
      ),
    };
  }
}

class _TagAndDateRow extends StatelessWidget {
  const _TagAndDateRow({
    required this.tag,
    required this.tagDescriptor,
    required this.createdAtMs,
    required this.onTagPressed,
  });
  final String? tag;
  final TagDescriptor? tagDescriptor;
  final int createdAtMs;
  final VoidCallback onTagPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (tag != null)
          _AssignedTag(
            tagId: tag!,
            descriptor: tagDescriptor,
            onPressed: onTagPressed,
          )
        else
          _AddTagButton(onPressed: onTagPressed),
        const Spacer(),
        Text(
          formatItemDate(createdAtMs),
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _AssignedTag extends StatelessWidget {
  const _AssignedTag({
    required this.tagId,
    required this.descriptor,
    required this.onPressed,
  });
  final String tagId;
  final TagDescriptor? descriptor;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final color = descriptor?.color ?? AppColors.textMuted;
    final label = descriptor?.label ?? tagId;
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0x0AFFDCDC),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: color.withAlpha(120)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFE8D8D8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: const Color(0x2EFFDCDC),
                  style: BorderStyle.solid,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.pencil,
                    size: 10,
                    color: AppColors.textMuted,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'change',
                    style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddTagButton extends StatelessWidget {
  const _AddTagButton({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x2EFFDCDC)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.plus, size: 11, color: AppColors.textMuted),
              SizedBox(width: 5),
              Text(
                'add tag',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
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

class _TagPickerResult {
  const _TagPickerResult(this.tag);
  final String? tag;
}

class _TagPickerSheet extends StatefulWidget {
  const _TagPickerSheet({required this.kind, required this.current});
  final ItemKind kind;
  final String? current;

  @override
  State<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends State<_TagPickerSheet> {
  late String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
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
                  'Choose a tag',
                  style: serifStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(_TagPickerResult(_selected)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TagPicker(
              kind: widget.kind,
              selected: _selected,
              onChanged: (id) => setState(() => _selected = id),
              label: 'DEFAULTS',
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}
