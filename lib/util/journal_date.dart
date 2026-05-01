String formatItemDate(int msSinceEpoch) {
  final dt = DateTime.fromMillisecondsSinceEpoch(msSinceEpoch).toLocal();
  return '${_monthName(dt.month)} ${dt.day}, ${dt.year}';
}

String formatJournalTitle(int msSinceEpoch) {
  final dt = DateTime.fromMillisecondsSinceEpoch(msSinceEpoch).toLocal();
  return '${_weekdayName(dt.weekday)}, ${_monthName(dt.month)} ${dt.day}, ${dt.year}';
}

int dayKey(int msSinceEpoch) {
  final dt = DateTime.fromMillisecondsSinceEpoch(msSinceEpoch).toLocal();
  return dt.year * 10000 + dt.month * 100 + dt.day;
}

int todayKey() {
  final now = DateTime.now();
  return now.year * 10000 + now.month * 100 + now.day;
}

String _weekdayName(int wd) => switch (wd) {
  DateTime.monday => 'Monday',
  DateTime.tuesday => 'Tuesday',
  DateTime.wednesday => 'Wednesday',
  DateTime.thursday => 'Thursday',
  DateTime.friday => 'Friday',
  DateTime.saturday => 'Saturday',
  DateTime.sunday => 'Sunday',
  _ => '',
};

String _monthName(int m) => switch (m) {
  DateTime.january => 'January',
  DateTime.february => 'February',
  DateTime.march => 'March',
  DateTime.april => 'April',
  DateTime.may => 'May',
  DateTime.june => 'June',
  DateTime.july => 'July',
  DateTime.august => 'August',
  DateTime.september => 'September',
  DateTime.october => 'October',
  DateTime.november => 'November',
  DateTime.december => 'December',
  _ => '',
};
