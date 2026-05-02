import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/ai_service.dart';
import '../../../state/providers.dart';
import '../../../theme/app_theme.dart';

/// Idle-state pill button for an AI action — matches the design's collapsed
/// "AIButton" style: outlined rose pill with sparkles icon + label.
class AiActionPill extends StatelessWidget {
  const AiActionPill({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final Future<void> Function() onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: const Icon(LucideIcons.sparkles, size: 14),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: BorderSide(color: AppColors.accent.withAlpha(102)),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

/// Expanded-state container — matches the design's "AIButton expanded" card:
/// rose-tinted background, SPARKLES eyebrow, custom body slot, optional
/// regenerate / clear / accept actions.
class AiActionCard extends StatelessWidget {
  const AiActionCard({
    super.key,
    required this.eyebrow,
    required this.child,
    this.onRegenerate,
    this.onClear,
    this.acceptLabel,
    this.onAccept,
  });

  final String eyebrow;
  final Widget child;
  final Future<void> Function()? onRegenerate;
  final VoidCallback? onClear;
  final String? acceptLabel;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withAlpha(56)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.sparkles,
                size: 13,
                color: AppColors.accent,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  eyebrow.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.accent,
                  ),
                ),
              ),
              if (onRegenerate != null)
                TextButton(
                  onPressed: onRegenerate,
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Regenerate',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ),
              if (onClear != null)
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(LucideIcons.x, size: 14),
                  color: AppColors.textMuted,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 4),
          child,
          if (onAccept != null && acceptLabel != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onAccept,
                icon: const Icon(LucideIcons.check, size: 12),
                label: Text(acceptLabel!, style: const TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentDeep,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tiny rose-tinted "Generating…" placeholder used while the request is in
/// flight.
class AiActionLoading extends StatelessWidget {
  const AiActionLoading({super.key, this.label = 'Generating…'});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withAlpha(56)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textDim),
          ),
        ],
      ),
    );
  }
}

/// AI affordances on the poem editor.
///
/// - "Suggest a title" → fills the title field via [onAcceptTitle].
/// - "Continue this poem" → appends the lines to the body via [onAppendBody].
class PoemAiActions extends ConsumerStatefulWidget {
  const PoemAiActions({
    super.key,
    required this.titleController,
    required this.bodyController,
    required this.onAcceptTitle,
    required this.onAppendBody,
  });

  final TextEditingController titleController;
  final TextEditingController bodyController;
  final ValueChanged<String> onAcceptTitle;
  final ValueChanged<String> onAppendBody;

  @override
  ConsumerState<PoemAiActions> createState() => _PoemAiActionsState();
}

class _PoemAiActionsState extends ConsumerState<PoemAiActions> {
  String? _title;
  String? _continuation;
  bool _busyTitle = false;
  bool _busyContinue = false;

  Future<String?> _resolveKey() async {
    final apiKey = await ref.read(secureSettingsProvider).getAnthropicApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      _snack('Add your Anthropic API key in Settings first.');
      return null;
    }
    return apiKey;
  }

  Future<void> _suggestTitle() async {
    final body = widget.bodyController.text.trim();
    if (body.isEmpty) {
      _snack('Write some of the poem first.');
      return;
    }
    setState(() => _busyTitle = true);
    try {
      final apiKey = await _resolveKey();
      if (apiKey == null) return;
      final out = await ref
          .read(aiServiceProvider)
          .suggestPoemTitle(apiKey: apiKey, poemBody: body);
      if (!mounted) return;
      setState(() => _title = out);
    } on AiException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Failed to suggest a title: $e');
    } finally {
      if (mounted) setState(() => _busyTitle = false);
    }
  }

  Future<void> _continuePoem() async {
    final body = widget.bodyController.text.trim();
    if (body.isEmpty) {
      _snack('Write some of the poem first.');
      return;
    }
    setState(() => _busyContinue = true);
    try {
      final apiKey = await _resolveKey();
      if (apiKey == null) return;
      final out = await ref
          .read(aiServiceProvider)
          .continuePoem(
            apiKey: apiKey,
            poemBody: body,
            title: widget.titleController.text,
          );
      if (!mounted) return;
      setState(() => _continuation = out);
    } on AiException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Failed to continue the poem: $e');
    } finally {
      if (mounted) setState(() => _busyContinue = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_busyTitle)
          const AiActionLoading(label: 'Suggesting a title…')
        else if (_title != null)
          AiActionCard(
            eyebrow: 'Title',
            onRegenerate: _suggestTitle,
            onClear: () => setState(() => _title = null),
            acceptLabel: 'Use this title',
            onAccept: () {
              widget.onAcceptTitle(_title!);
              setState(() => _title = null);
            },
            child: Text(
              _title!,
              style: serifStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          )
        else
          AiActionPill(label: 'Suggest a title', onPressed: _suggestTitle),
        const SizedBox(height: 10),
        if (_busyContinue)
          const AiActionLoading(label: 'Continuing…')
        else if (_continuation != null)
          AiActionCard(
            eyebrow: 'Continuation',
            onRegenerate: _continuePoem,
            onClear: () => setState(() => _continuation = null),
            acceptLabel: 'Append to poem',
            onAccept: () {
              widget.onAppendBody(_continuation!);
              setState(() => _continuation = null);
            },
            child: SelectableText(
              _continuation!,
              style: serifStyle(
                fontSize: 14,
                color: const Color(0xFFE8D8D8),
                height: 1.55,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          AiActionPill(label: 'Continue this poem', onPressed: _continuePoem),
      ],
    );
  }
}

/// AI affordances on the lyric editor.
///
/// - "Find rhymes for…" → opens a small dialog asking for a word, then shows
///   the rhymes as tap-to-copy chips.
/// - "Suggest the next line" → appends the line to the body.
class LyricAiActions extends ConsumerStatefulWidget {
  const LyricAiActions({
    super.key,
    required this.bodyController,
    required this.onAppendBody,
  });

  final TextEditingController bodyController;
  final ValueChanged<String> onAppendBody;

  @override
  ConsumerState<LyricAiActions> createState() => _LyricAiActionsState();
}

class _LyricAiActionsState extends ConsumerState<LyricAiActions> {
  String? _rhymeWord;
  List<String>? _rhymes;
  String? _nextLine;
  bool _busyRhymes = false;
  bool _busyNextLine = false;

  Future<String?> _resolveKey() async {
    final apiKey = await ref.read(secureSettingsProvider).getAnthropicApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      _snack('Add your Anthropic API key in Settings first.');
      return null;
    }
    return apiKey;
  }

  Future<void> _findRhymes() async {
    final word = await _askForWord();
    if (word == null || word.trim().isEmpty) return;
    setState(() {
      _busyRhymes = true;
      _rhymeWord = word.trim();
    });
    try {
      final apiKey = await _resolveKey();
      if (apiKey == null) return;
      final out = await ref
          .read(aiServiceProvider)
          .findRhymes(apiKey: apiKey, word: word.trim());
      if (!mounted) return;
      setState(() => _rhymes = out);
    } on AiException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Failed to find rhymes: $e');
    } finally {
      if (mounted) setState(() => _busyRhymes = false);
    }
  }

  Future<void> _suggestNextLine() async {
    final body = widget.bodyController.text.trim();
    if (body.isEmpty) {
      _snack('Write some of the lyric first.');
      return;
    }
    setState(() => _busyNextLine = true);
    try {
      final apiKey = await _resolveKey();
      if (apiKey == null) return;
      final out = await ref
          .read(aiServiceProvider)
          .suggestNextLine(apiKey: apiKey, lyricBody: body);
      if (!mounted) return;
      setState(() => _nextLine = out);
    } on AiException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Failed to suggest a line: $e');
    } finally {
      if (mounted) setState(() => _busyNextLine = false);
    }
  }

  Future<String?> _askForWord() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Find rhymes for…'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'word'),
            textInputAction: TextInputAction.done,
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('Find'),
            ),
          ],
        );
      },
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_busyRhymes)
          const AiActionLoading(label: 'Finding rhymes…')
        else if (_rhymes != null && _rhymeWord != null)
          AiActionCard(
            eyebrow: 'Rhymes for "${_rhymeWord!}"',
            onRegenerate: _findRhymes,
            onClear: () => setState(() {
              _rhymes = null;
              _rhymeWord = null;
            }),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final r in _rhymes!) _RhymeChip(word: r)],
            ),
          )
        else
          AiActionPill(label: 'Find rhymes for…', onPressed: _findRhymes),
        const SizedBox(height: 10),
        if (_busyNextLine)
          const AiActionLoading(label: 'Writing the next line…')
        else if (_nextLine != null)
          AiActionCard(
            eyebrow: 'Next line',
            onRegenerate: _suggestNextLine,
            onClear: () => setState(() => _nextLine = null),
            acceptLabel: 'Append',
            onAccept: () {
              widget.onAppendBody(_nextLine!);
              setState(() => _nextLine = null);
            },
            child: Text(
              _nextLine!,
              style: serifStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                height: 1.55,
              ),
            ),
          )
        else
          AiActionPill(
            label: 'Suggest the next line',
            onPressed: _suggestNextLine,
          ),
      ],
    );
  }
}

class _RhymeChip extends StatelessWidget {
  const _RhymeChip({required this.word});
  final String word;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          Clipboard.setData(ClipboardData(text: word));
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Copied "$word"')));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0x0AFFDCDC),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.accent.withAlpha(76)),
          ),
          child: Text(
            word,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
