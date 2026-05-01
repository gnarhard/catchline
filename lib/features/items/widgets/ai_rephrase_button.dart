import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/ai_service.dart';
import '../../../data/models/ai_favorite.dart';
import '../../../state/providers.dart';

class AiRephraseButton extends ConsumerWidget {
  const AiRephraseButton({
    super.key,
    required this.phraseText,
    required this.cachedRephrasings,
    required this.favorites,
    required this.onSaveResults,
    required this.onToggleFavorite,
  });

  final String phraseText;
  final Map<String, String>? cachedRephrasings;
  final List<AiFavorite> favorites;
  final Future<void> Function(Map<String, String> results) onSaveResults;
  final Future<void> Function(String style, String text) onToggleFavorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasCache = cachedRephrasings != null && cachedRephrasings!.isNotEmpty;
    return OutlinedButton.icon(
      onPressed: () => _open(context, ref),
      icon: const Icon(LucideIcons.sparkles, size: 16),
      label: Text(hasCache ? 'View rephrasings' : 'Rephrase in styles'),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    if (phraseText.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Write a phrase first.')));
      return;
    }
    final styles = ref.read(appSettingsRepoProvider).phraseStyles;
    if (styles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one style in Settings.')),
      );
      return;
    }
    final apiKey = await ref.read(secureSettingsProvider).getAnthropicApiKey();
    if (!context.mounted) return;
    if (apiKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add your Anthropic API key in Settings first.'),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RephraseSheet(
        apiKey: apiKey,
        phrase: phraseText,
        styles: styles,
        initialResults: cachedRephrasings,
        favorites: favorites,
        onSaveResults: onSaveResults,
        onToggleFavorite: onToggleFavorite,
      ),
    );
  }
}

class _RephraseSheet extends ConsumerStatefulWidget {
  const _RephraseSheet({
    required this.apiKey,
    required this.phrase,
    required this.styles,
    required this.initialResults,
    required this.favorites,
    required this.onSaveResults,
    required this.onToggleFavorite,
  });

  final String apiKey;
  final String phrase;
  final List<String> styles;
  final Map<String, String>? initialResults;
  final List<AiFavorite> favorites;
  final Future<void> Function(Map<String, String> results) onSaveResults;
  final Future<void> Function(String style, String text) onToggleFavorite;

  @override
  ConsumerState<_RephraseSheet> createState() => _RephraseSheetState();
}

class _RephraseSheetState extends ConsumerState<_RephraseSheet> {
  late bool _loading;
  String? _error;
  late Map<String, String> _results;

  @override
  void initState() {
    super.initState();
    final cached = widget.initialResults;
    if (cached != null && cached.isNotEmpty) {
      _results = Map<String, String>.from(cached);
      _loading = false;
    } else {
      _results = {};
      _loading = true;
      _run();
    }
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await ref
          .read(aiServiceProvider)
          .rephraseInStyles(
            apiKey: widget.apiKey,
            phrase: widget.phrase,
            styles: widget.styles,
          );
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
      await widget.onSaveResults(results);
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Rephrasings',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  if (!_loading)
                    IconButton(
                      tooltip: 'Regenerate',
                      onPressed: _run,
                      icon: const Icon(LucideIcons.refreshCw, size: 18),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withAlpha(100),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.phrase,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
            Flexible(child: _body(theme)),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _body(ThemeData theme) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.circleAlert, color: theme.colorScheme.error),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _run, child: const Text('Retry')),
          ],
        ),
      );
    }
    final entries = _results.entries.toList();
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final entry = entries[i];
        final isStarred = widget.favorites.any(
          (f) => f.style == entry.key && f.text == entry.value,
        );
        return _RephrasingTile(
          style: entry.key,
          text: entry.value,
          isStarred: isStarred,
          onToggleStar: () => widget.onToggleFavorite(entry.key, entry.value),
        );
      },
    );
  }
}

class _RephrasingTile extends StatelessWidget {
  const _RephrasingTile({
    required this.style,
    required this.text,
    required this.isStarred,
    required this.onToggleStar,
  });

  final String style;
  final String text;
  final bool isStarred;
  final Future<void> Function() onToggleStar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              style,
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.primary,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: SelectableText(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Copied "$style" rephrasing.')),
                  );
                },
                icon: const Icon(LucideIcons.copy, size: 14),
                label: const Text('Copy'),
              ),
              IconButton(
                tooltip: isStarred ? 'Unstar' : 'Star',
                onPressed: onToggleStar,
                icon: Icon(
                  isStarred ? Icons.star : LucideIcons.star,
                  size: 18,
                  color: isStarred ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
