import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/models/item.dart';
import '../../../data/models/item_kind.dart';
import '../../../util/journal_date.dart';
import '../../../util/text_preview.dart';

class ItemTile extends StatelessWidget {
  const ItemTile({super.key, required this.item, required this.onTap});

  final Item item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = textPreview(item.textBody);
    final hasBody = preview.isNotEmpty;
    final hasClips = item.audioClips.isNotEmpty;
    final dateLabel = formatItemDate(item.createdAtMs);
    final mutedStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final String titleText;
    final TextStyle? titleStyle;
    Widget? subtitle;

    switch (item.kind) {
      case ItemKind.journal:
        titleText = formatJournalTitle(item.createdAtMs);
        titleStyle = theme.textTheme.titleMedium;
        if (hasBody) {
          subtitle = Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
      case ItemKind.phrase:
        titleText = hasBody ? preview : 'Empty phrase';
        titleStyle = theme.textTheme.titleMedium?.copyWith(
          fontStyle: hasBody ? FontStyle.normal : FontStyle.italic,
          color: hasBody ? null : theme.colorScheme.onSurfaceVariant,
        );
        subtitle = Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(dateLabel, style: mutedStyle),
        );
      case ItemKind.poem:
      case ItemKind.lyric:
        final hasTitle = item.title.trim().isNotEmpty;
        titleText = hasTitle ? item.title : 'Untitled';
        titleStyle = theme.textTheme.titleMedium?.copyWith(
          fontStyle: hasTitle ? FontStyle.normal : FontStyle.italic,
          color: hasTitle ? null : theme.colorScheme.onSurfaceVariant,
        );
        subtitle = Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dateLabel, style: mutedStyle),
              if (hasBody) ...[
                const SizedBox(height: 4),
                Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        );
    }

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      title: Text(
        titleText,
        style: titleStyle,
        maxLines: item.kind == ItemKind.phrase ? 2 : 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle,
      trailing: hasClips ? _ClipBadge(count: item.audioClips.length) : null,
    );
  }
}

class _ClipBadge extends StatelessWidget {
  const _ClipBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withAlpha(40),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.mic, size: 12, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
