import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../theme/app_theme.dart';

/// Big serif title + a row of right-aligned circular icon buttons.
///
/// Used as the in-content header on every list screen (Journal, Poems,
/// Lyrics, Phrases). The action icons are wired by the parent screen so
/// each kind can decide which actions are relevant (filter is hidden on
/// Journal, for example, until a filter UX exists for it).
class ListHeader extends StatelessWidget {
  const ListHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onSearch,
    this.onFilter,
    this.onCalendar,
    this.filterActive = false,
    this.searchActive = false,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onSearch;
  final VoidCallback? onFilter;
  final VoidCallback? onCalendar;
  final bool filterActive;
  final bool searchActive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 14, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: serifStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onSearch != null)
            _RoundActionButton(
              icon: LucideIcons.search,
              onPressed: onSearch,
              highlight: searchActive,
            ),
          if (onFilter != null) ...[
            const SizedBox(width: 6),
            _RoundActionButton(
              icon: LucideIcons.listFilter,
              onPressed: onFilter,
              highlight: filterActive,
            ),
          ],
          if (onCalendar != null) ...[
            const SizedBox(width: 6),
            _RoundActionButton(
              icon: LucideIcons.calendar,
              onPressed: onCalendar,
            ),
          ],
        ],
      ),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    required this.icon,
    required this.onPressed,
    this.highlight = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlight
          ? AppColors.accent.withAlpha(46)
          : const Color(0x0AFFDCDC),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: highlight
                  ? AppColors.accent.withAlpha(110)
                  : const Color(0x14FFDCDC),
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: highlight ? AppColors.accent : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
