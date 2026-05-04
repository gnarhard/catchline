import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/models/item.dart';
import '../../../data/models/item_kind.dart';
import '../../../theme/app_theme.dart';
import '../../../util/journal_date.dart';

/// Counts of items per kind on a single calendar day.
class DayCounts {
  const DayCounts({
    this.journal = 0,
    this.poem = 0,
    this.lyric = 0,
    this.phrase = 0,
  });

  final int journal;
  final int poem;
  final int lyric;
  final int phrase;

  bool get isEmpty => journal == 0 && poem == 0 && lyric == 0 && phrase == 0;

  DayCounts add(ItemKind kind) => switch (kind) {
    ItemKind.journal => DayCounts(
      journal: journal + 1,
      poem: poem,
      lyric: lyric,
      phrase: phrase,
    ),
    ItemKind.poem => DayCounts(
      journal: journal,
      poem: poem + 1,
      lyric: lyric,
      phrase: phrase,
    ),
    ItemKind.lyric => DayCounts(
      journal: journal,
      poem: poem,
      lyric: lyric + 1,
      phrase: phrase,
    ),
    ItemKind.phrase => DayCounts(
      journal: journal,
      poem: poem,
      lyric: lyric,
      phrase: phrase + 1,
    ),
  };
}

/// Reduces a flat item list into a Map keyed by [dayKey].
Map<int, DayCounts> dayCountsFromItems(Iterable<Item> items) {
  final out = <int, DayCounts>{};
  for (final item in items) {
    final key = dayKey(item.createdAtMs);
    out[key] = (out[key] ?? const DayCounts()).add(item.kind);
  }
  return out;
}

/// Bottom-sheet calendar that lets the user jump to a day. The list-screen
/// caller passes the precomputed [counts] so the sheet stays purely visual.
class CalendarJumpSheet extends StatefulWidget {
  const CalendarJumpSheet({
    super.key,
    required this.scope,
    required this.counts,
    required this.initialMonth,
    this.preview,
  });

  final String scope;
  final Map<int, DayCounts> counts;
  final DateTime initialMonth;
  final String Function(DateTime day)? preview;

  static Future<DateTime?> show(
    BuildContext context, {
    required String scope,
    required Map<int, DayCounts> counts,
    DateTime? initialMonth,
    String Function(DateTime day)? preview,
  }) {
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withAlpha(140),
      builder: (_) => CalendarJumpSheet(
        scope: scope,
        counts: counts,
        initialMonth: initialMonth ?? DateTime.now(),
        preview: preview,
      ),
    );
  }

  @override
  State<CalendarJumpSheet> createState() => _CalendarJumpSheetState();
}

class _CalendarJumpSheetState extends State<CalendarJumpSheet> {
  late DateTime _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.initialMonth.year, widget.initialMonth.month);
    final today = DateTime.now();
    _selected = DateTime(today.year, today.month, today.day);
    if (_selected.year != _month.year || _selected.month != _month.month) {
      _selected = DateTime(_month.year, _month.month, 1);
    }
  }

  void _stepMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  void _selectYear(int year) {
    setState(() {
      _month = DateTime(year, _month.month);
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthName = _monthLong(_month.month);
    final preview = widget.preview?.call(_selected);
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A1018), Color(0xFF1A080E)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0x14FFDCDC))),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 6, bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0x33FFDCDC),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'JUMP TO DAY · ${widget.scope.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$monthName ${_month.year}',
                        style: serifStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                _RoundIconButton(
                  icon: LucideIcons.chevronLeft,
                  onPressed: () => _stepMonth(-1),
                ),
                const SizedBox(width: 6),
                _RoundIconButton(
                  icon: LucideIcons.chevronRight,
                  onPressed: () => _stepMonth(1),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _YearStrip(selected: _month.year, onPick: _selectYear),
            const SizedBox(height: 12),
            _MonthGrid(
              month: _month,
              counts: widget.counts,
              selected: _selected,
              onPick: (d) => setState(() => _selected = d),
            ),
            if (preview != null) ...[
              const SizedBox(height: 14),
              _DayPreview(day: _selected, text: preview),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: Text(
                      'Open ${_monthShort(_selected.month)} ${_selected.day}',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _YearStrip extends StatelessWidget {
  const _YearStrip({required this.selected, required this.onPick});

  final int selected;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final years = [
      now.year - 4,
      now.year - 3,
      now.year - 2,
      now.year - 1,
      now.year,
    ];
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: years.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final y = years[i];
          final on = y == selected;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onPick(y),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: on ? AppColors.accent : const Color(0x0AFFDCDC),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: on ? AppColors.accent : const Color(0x14FFDCDC),
                  ),
                ),
                child: Text(
                  '$y',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: on ? AppColors.accentText : AppColors.textDim,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.counts,
    required this.selected,
    required this.onPick,
  });

  final DateTime month;
  final Map<int, DayCounts> counts;
  final DateTime selected;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final firstDow = DateTime(month.year, month.month, 1).weekday % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cells = <int?>[];
    for (var i = 0; i < firstDow; i++) {
      cells.add(null);
    }
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add(d);
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return Column(
      children: [
        Row(
          children: [
            for (final s in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
              Expanded(
                child: Center(
                  child: Text(
                    s,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var row = 0; row < cells.length / 7; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: _DayCell(
                      day: cells[row * 7 + col],
                      month: month,
                      counts: cells[row * 7 + col] == null
                          ? null
                          : counts[_dayKey(month, cells[row * 7 + col]!)],
                      selected:
                          cells[row * 7 + col] != null &&
                          _isSameDay(
                            DateTime(
                              month.year,
                              month.month,
                              cells[row * 7 + col]!,
                            ),
                            selected,
                          ),
                      onTap: cells[row * 7 + col] == null
                          ? null
                          : () => onPick(
                              DateTime(
                                month.year,
                                month.month,
                                cells[row * 7 + col]!,
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  static int _dayKey(DateTime m, int d) {
    return m.year * 10000 + m.month * 100 + d;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.month,
    required this.counts,
    required this.selected,
    required this.onTap,
  });

  final int? day;
  final DateTime month;
  final DayCounts? counts;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (day == null) {
      return const SizedBox(height: 52);
    }
    final markerColor = selected ? AppColors.accentText : AppColors.accent;
    final hasMarkers = counts != null && !counts!.isEmpty;
    return Material(
      color: selected ? AppColors.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? AppColors.accentText
                        : AppColors.textPrimary,
                    height: 1.1,
                  ),
                ),
                if (hasMarkers) ...[
                  const SizedBox(height: 3),
                  _Markers(counts: counts!, color: markerColor),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Markers extends StatelessWidget {
  const _Markers({required this.counts, required this.color});
  final DayCounts counts;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[
      if (counts.journal > 0)
        _MarkerCell(
          icon: LucideIcons.notebookPen,
          count: counts.journal,
          color: color,
        ),
      if (counts.poem > 0)
        _MarkerCell(
          icon: LucideIcons.feather,
          count: counts.poem,
          color: color,
        ),
      if (counts.lyric > 0)
        _MarkerCell(icon: LucideIcons.music, count: counts.lyric, color: color),
      if (counts.phrase > 0)
        _MarkerCell(
          icon: LucideIcons.quote,
          count: counts.phrase,
          color: color,
        ),
    ];
    if (cells.isEmpty) return const SizedBox.shrink();
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.4,
      mainAxisSpacing: 1,
      crossAxisSpacing: 4,
      padding: EdgeInsets.zero,
      children: cells,
    );
  }
}

class _MarkerCell extends StatelessWidget {
  const _MarkerCell({
    required this.icon,
    required this.count,
    required this.color,
  });
  final IconData icon;
  final int count;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 7, color: color),
        const SizedBox(width: 1),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 7,
            fontWeight: FontWeight.w600,
            color: color,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _DayPreview extends StatelessWidget {
  const _DayPreview({required this.day, required this.text});
  final DateTime day;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x80261319),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14FFDCDC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_weekdayShort(day.weekday).toUpperCase()} · ${_monthShort(day.month).toUpperCase()} ${day.day}, ${day.year}',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: serifStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x10FFDCDC),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 14, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

String _weekdayShort(int wd) => switch (wd) {
  DateTime.monday => 'Mon',
  DateTime.tuesday => 'Tue',
  DateTime.wednesday => 'Wed',
  DateTime.thursday => 'Thu',
  DateTime.friday => 'Fri',
  DateTime.saturday => 'Sat',
  DateTime.sunday => 'Sun',
  _ => '',
};

String _monthShort(int m) => const [
  '',
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][m];

String _monthLong(int m) => const [
  '',
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
][m];
