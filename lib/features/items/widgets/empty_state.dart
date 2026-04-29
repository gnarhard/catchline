import 'package:flutter/material.dart';

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
          Icon(_iconFor(kind), size: 56, color: color),
          const SizedBox(height: 16),
          Text(
            _titleFor(kind),
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _bodyFor(kind),
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _iconFor(ItemKind kind) => switch (kind) {
        ItemKind.journal => Icons.menu_book_outlined,
        ItemKind.poem => Icons.auto_stories_outlined,
        ItemKind.lyric => Icons.music_note_outlined,
        ItemKind.phrase => Icons.format_quote_outlined,
      };

  String _titleFor(ItemKind kind) => switch (kind) {
        ItemKind.journal => 'No journal entries yet',
        ItemKind.poem => 'No poems yet',
        ItemKind.lyric => 'No lyrics yet',
        ItemKind.phrase => 'No phrases yet',
      };

  String _bodyFor(ItemKind kind) => switch (kind) {
        ItemKind.journal =>
          'Tap New to write your first entry or record a voice note.',
        ItemKind.poem =>
          'Tap New to capture a poem — words on the page or read aloud.',
        ItemKind.lyric => 'Tap New to save a lyric you want to remember.',
        ItemKind.phrase => 'Tap New to save a phrase you find catchy.',
      };
}
