import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/item_kind.dart';
import '../../../data/models/tag_palette.dart';
import '../../../state/providers.dart';
import '../../../theme/app_theme.dart';

/// Inline tag picker — a labeled `TAG` row with a wrap of selectable chips.
///
/// Chip-on-chip selection per the design's "PhraseCapture" / "TagPickerInline"
/// mockup: the selected chip fills with the tag color; unselected chips show
/// a small colored dot + label on a neutral pill.
class TagPicker extends ConsumerWidget {
  const TagPicker({
    super.key,
    required this.kind,
    required this.selected,
    required this.onChanged,
    this.label = 'TAG',
    this.allowClear = true,
  });

  final ItemKind kind;
  final String? selected;
  final ValueChanged<String?> onChanged;
  final String label;
  final bool allowClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagsForKindProvider(kind));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 10),
        if (tags.isEmpty)
          const Text(
            'No tags assigned to this kind. Add one in Settings.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in tags)
                _PickerChip(
                  tag: t,
                  selected: t.id == selected,
                  onTap: () =>
                      onChanged(allowClear && selected == t.id ? null : t.id),
                ),
            ],
          ),
      ],
    );
  }
}

class _PickerChip extends StatelessWidget {
  const _PickerChip({
    required this.tag,
    required this.selected,
    required this.onTap,
  });

  final TagDescriptor tag;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? tag.color : const Color(0x08FFDCDC);
    final border = selected ? tag.color : const Color(0x14FFDCDC);
    final fg = selected ? const Color(0xFF3A1018) : AppColors.textDim;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!selected) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: tag.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                tag.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
