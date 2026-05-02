import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/models/item.dart';
import '../../../data/models/item_kind.dart';
import '../../../state/providers.dart';
import '../../../theme/app_theme.dart';
import '../../../util/journal_date.dart';
import '../../../util/text_preview.dart';

/// One row in a list of items. The visual layout differs per [ItemKind]
/// to match the design canvas:
///
/// - Phrase: 2-line wrap of body + tag pill + date underneath
/// - Poem / Lyric: title row + italic excerpt + tag pill
/// - Journal: full date heading + 2-line preview
class ItemTile extends StatelessWidget {
  const ItemTile({super.key, required this.item, required this.onTap});

  final Item item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: switch (item.kind) {
          ItemKind.phrase => _PhraseRow(item: item),
          ItemKind.journal => _JournalRow(item: item),
          ItemKind.poem || ItemKind.lyric => _TitledRow(item: item),
        },
      ),
    );
  }
}

class _PhraseRow extends StatelessWidget {
  const _PhraseRow({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    final preview = textPreview(item.textBody);
    final hasBody = preview.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasBody ? preview : 'Empty phrase',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: serifStyle(
            fontSize: 14.5,
            color: hasBody ? AppColors.textPrimary : AppColors.textMuted,
            fontStyle: hasBody ? FontStyle.normal : FontStyle.italic,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (item.tag != null) ...[
              _TagBadge(tagId: item.tag!),
              const SizedBox(width: 8),
            ],
            Text(
              formatItemDate(item.createdAtMs),
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            if (item.audioClips.isNotEmpty) ...[
              const Spacer(),
              _ClipBadge(count: item.audioClips.length),
            ],
          ],
        ),
      ],
    );
  }
}

class _JournalRow extends StatelessWidget {
  const _JournalRow({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    final preview = textPreview(item.textBody);
    final hasBody = preview.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                formatJournalTitle(item.createdAtMs),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (item.audioClips.isNotEmpty) ...[
              const SizedBox(width: 8),
              _ClipBadge(count: item.audioClips.length),
            ],
          ],
        ),
        if (hasBody) ...[
          const SizedBox(height: 4),
          Text(
            preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: serifStyle(
              fontSize: 13,
              color: AppColors.textDim,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}

class _TitledRow extends StatelessWidget {
  const _TitledRow({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    final preview = textPreview(item.textBody).replaceAll(' / ', ' · ');
    final hasBody = preview.isNotEmpty;
    final hasTitle = item.title.trim().isNotEmpty;
    final isPoem = item.kind == ItemKind.poem;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                hasTitle ? item.title : 'Untitled',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: serifStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: hasTitle ? AppColors.textPrimary : AppColors.textMuted,
                  fontStyle: hasTitle ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatItemDate(item.createdAtMs),
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        if (hasBody) ...[
          const SizedBox(height: 4),
          Text(
            preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: serifStyle(
              fontSize: 12.5,
              color: AppColors.textDim,
              fontStyle: isPoem ? FontStyle.italic : FontStyle.normal,
              height: 1.45,
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              if (item.tag != null) _TagBadge(tagId: item.tag!),
              if (item.audioClips.isNotEmpty) ...[
                const Spacer(),
                _ClipBadge(count: item.audioClips.length),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TagBadge extends ConsumerWidget {
  const _TagBadge({required this.tagId});
  final String tagId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagsProvider).value ?? const [];
    final tag = tags.where((t) => t.id == tagId).firstOrNull;
    if (tag == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.textMuted.withAlpha(30),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          tagId.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: AppColors.textMuted,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: tag.color.withAlpha(40),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tag.label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: tag.color,
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withAlpha(36),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.mic, size: 11, color: theme.colorScheme.primary),
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
