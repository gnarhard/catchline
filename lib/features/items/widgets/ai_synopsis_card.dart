import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AiSynopsisCard extends StatelessWidget {
  const AiSynopsisCard({
    super.key,
    required this.synopsis,
    required this.isGenerating,
    required this.onGenerate,
    required this.onClear,
  });

  final String? synopsis;
  final bool isGenerating;
  final Future<void> Function() onGenerate;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasSynopsis = synopsis != null && synopsis!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Synopsis',
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (hasSynopsis && !isGenerating)
              IconButton(
                tooltip: 'Regenerate',
                onPressed: onGenerate,
                icon: const Icon(LucideIcons.refreshCw, size: 18),
              ),
            if (hasSynopsis && !isGenerating)
              IconButton(
                tooltip: 'Clear',
                onPressed: onClear,
                icon: const Icon(LucideIcons.x, size: 18),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (isGenerating)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withAlpha(120),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  'Generating…',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else if (!hasSynopsis)
          OutlinedButton.icon(
            onPressed: onGenerate,
            icon: const Icon(LucideIcons.sparkles, size: 16),
            label: const Text('Generate synopsis'),
          )
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withAlpha(120),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant.withAlpha(120)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectableText(
                  synopsis!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: synopsis!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Synopsis copied.')),
                      );
                    },
                    icon: const Icon(LucideIcons.copy, size: 14),
                    label: const Text('Copy'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
