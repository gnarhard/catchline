import 'package:catchline/util/journal_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Build a fixed local-time DateTime so the formatters' .toLocal() conversion
  // produces deterministic output regardless of the host's timezone.
  // 2026-05-01 (Friday) at noon local.
  final fixedLocal = DateTime(2026, 5, 1, 12, 0);
  final fixedMs = fixedLocal.millisecondsSinceEpoch;

  group('formatItemDate', () {
    test('formats as Month Day, Year', () {
      expect(formatItemDate(fixedMs), 'May 1, 2026');
    });

    test('handles all twelve months', () {
      for (var m = 1; m <= 12; m++) {
        final ms = DateTime(2026, m, 15, 12).millisecondsSinceEpoch;
        final out = formatItemDate(ms);
        expect(out, contains('15, 2026'));
        expect(out.split(' ').first, isNotEmpty);
      }
    });
  });

  group('formatJournalTitle', () {
    test('includes weekday, month, day, year', () {
      // 2026-05-01 is a Friday.
      expect(formatJournalTitle(fixedMs), 'Friday, May 1, 2026');
    });

    test('produces a non-empty weekday for every day of a week', () {
      // 2026-05-04..2026-05-10 covers Monday..Sunday.
      for (var d = 4; d <= 10; d++) {
        final ms = DateTime(2026, 5, d, 12).millisecondsSinceEpoch;
        final out = formatJournalTitle(ms);
        expect(out.split(',').first.trim(), isNotEmpty);
      }
    });
  });

  group('dayKey', () {
    test('packs year/month/day into yyyymmdd', () {
      final ms = DateTime(2026, 5, 1, 12).millisecondsSinceEpoch;
      expect(dayKey(ms), 20260501);
    });

    test('changes when the day rolls over (local time)', () {
      final monday = DateTime(2026, 5, 4, 23, 59).millisecondsSinceEpoch;
      final tuesday = DateTime(2026, 5, 5, 0, 1).millisecondsSinceEpoch;
      expect(dayKey(monday), isNot(dayKey(tuesday)));
    });

    test('is stable for two timestamps on the same day', () {
      final morning = DateTime(2026, 5, 1, 7, 30).millisecondsSinceEpoch;
      final evening = DateTime(2026, 5, 1, 22, 45).millisecondsSinceEpoch;
      expect(dayKey(morning), dayKey(evening));
    });
  });

  group('todayKey', () {
    test('matches dayKey of now', () {
      final now = DateTime.now();
      // Stamp dayKey from a millisecond timestamp built from `now` so both
      // helpers see the same wall-clock date.
      final fromNow = dayKey(now.millisecondsSinceEpoch);
      expect(todayKey(), fromNow);
    });
  });
}
