import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/models/ai_favorite.dart';

class AiFavoritesSection extends StatelessWidget {
  const AiFavoritesSection({
    super.key,
    required this.favorites,
    required this.onRemove,
  });

  final List<AiFavorite> favorites;
  final Future<void> Function(AiFavorite favorite) onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(LucideIcons.star, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              'Starred',
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final fav in favorites)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FavoriteTile(favorite: fav, onRemove: onRemove),
          ),
      ],
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({required this.favorite, required this.onRemove});

  final AiFavorite favorite;
  final Future<void> Function(AiFavorite favorite) onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              favorite.style,
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.primary,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SelectableText(
              favorite.text,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: favorite.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Copied "${favorite.style}".')),
                  );
                },
                icon: const Icon(LucideIcons.copy, size: 14),
                label: const Text('Copy'),
              ),
              IconButton(
                tooltip: 'Unstar',
                onPressed: () => onRemove(favorite),
                icon: const Icon(LucideIcons.starOff, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
