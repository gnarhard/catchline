import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/models/item_kind.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.kind});

  final ItemKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_iconFor(kind), size: 48, color: color.withAlpha(180)),
          const SizedBox(height: 20),
          Text(
            _titleFor(kind),
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _iconFor(ItemKind kind) => switch (kind) {
    ItemKind.journal => LucideIcons.notebookPen,
    ItemKind.poem => LucideIcons.feather,
    ItemKind.lyric => LucideIcons.music,
    ItemKind.phrase => LucideIcons.quote,
  };

  String _titleFor(ItemKind kind) => switch (kind) {
    ItemKind.journal => 'No journal entries yet',
    ItemKind.poem => 'No poems yet',
    ItemKind.lyric => 'No lyrics yet',
    ItemKind.phrase => 'No phrases yet',
  };
}
