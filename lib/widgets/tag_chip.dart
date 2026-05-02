import 'package:flutter/material.dart';

import '../data/models/tag_palette.dart';

/// Pill-shaped tag chip used across the app — list rows, detail screens,
/// filter sheets, the tag picker.
///
/// `filled` paints a solid color background (selected / starred state).
/// Otherwise the chip is a translucent pill with a colored leading dot and
/// a tinted border, matching the design.
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.tag,
    this.filled = false,
    this.size = TagChipSize.medium,
    this.onTap,
    this.trailing,
    this.uppercase = false,
  });

  /// Convenience for rendering by id alone — returns an empty box if the
  /// id is unknown so callers don't need to null-check.
  static Widget byId(
    String? id, {
    Key? key,
    bool filled = false,
    TagChipSize size = TagChipSize.medium,
    VoidCallback? onTap,
    bool uppercase = false,
  }) {
    final tag = tagById(id);
    if (tag == null) return const SizedBox.shrink();
    return TagChip(
      key: key,
      tag: tag,
      filled: filled,
      size: size,
      onTap: onTap,
      uppercase: uppercase,
    );
  }

  final TagDescriptor tag;
  final bool filled;
  final TagChipSize size;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    final padding = switch (size) {
      TagChipSize.tiny => const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 2,
      ),
      TagChipSize.small => const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 4,
      ),
      TagChipSize.medium => const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 7,
      ),
    };
    final fontSize = switch (size) {
      TagChipSize.tiny => 10.0,
      TagChipSize.small => 11.0,
      TagChipSize.medium => 13.0,
    };
    final dotSize = switch (size) {
      TagChipSize.tiny => 5.0,
      TagChipSize.small => 6.0,
      TagChipSize.medium => 7.0,
    };

    final label = uppercase ? tag.label.toUpperCase() : tag.label;
    final letterSpacing = uppercase ? 0.4 : 0.1;

    final background = filled
        ? tag.color.withAlpha(uppercase ? 40 : 255)
        : Colors.transparent;
    final foreground = filled
        ? (uppercase ? tag.color : const Color(0xFF3A1018))
        : const Color(0xFFE8D8D8);

    final child = Padding(
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!filled || uppercase)
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: tag.color,
                shape: BoxShape.circle,
              ),
            ),
          if (!filled || uppercase) SizedBox(width: dotSize),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: letterSpacing,
              color: foreground,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 6), trailing!],
        ],
      ),
    );

    final decoration = BoxDecoration(
      color: filled ? background : const Color(0x0DFFEAEA),
      borderRadius: BorderRadius.circular(999),
      border: filled
          ? null
          : Border.all(color: tag.color.withAlpha(110), width: 1),
    );

    final wrapped = DecoratedBox(decoration: decoration, child: child);

    if (onTap == null) return wrapped;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: wrapped,
      ),
    );
  }
}

enum TagChipSize { tiny, small, medium }
