import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_projects/job_status.dart';

void main() {
  group('isSameDay', () {
    final now = DateTime(2026, 4, 28, 12, 0, 0);

    test('null scheduledTime → true (urgent jobs are same-day)', () {
      expect(isSameDay(null, now), isTrue);
    });

    test('scheduledTime today (same Y/M/D) → true', () {
      final scheduled = DateTime(2026, 4, 28, 9, 30, 0);
      expect(isSameDay(scheduled, now), isTrue);
    });

    test('scheduledTime tomorrow (different D) → false', () {
      final scheduled = DateTime(2026, 4, 29, 9, 30, 0);
      expect(isSameDay(scheduled, now), isFalse);
    });

    test('scheduledTime yesterday → false', () {
      final scheduled = DateTime(2026, 4, 27, 23, 59, 0);
      expect(isSameDay(scheduled, now), isFalse);
    });

    test('scheduledTime 23:59 today vs now 00:01 today → true', () {
      final earlyNow = DateTime(2026, 4, 28, 0, 1, 0);
      final lateScheduled = DateTime(2026, 4, 28, 23, 59, 0);
      expect(isSameDay(lateScheduled, earlyNow), isTrue);
    });

    test('scheduledTime 00:01 tomorrow vs now 23:59 today → false', () {
      final lateNow = DateTime(2026, 4, 28, 23, 59, 0);
      final earlyTomorrow = DateTime(2026, 4, 29, 0, 1, 0);
      expect(isSameDay(earlyTomorrow, lateNow), isFalse);
    });

    test('scheduledTime in different month → false', () {
      final scheduled = DateTime(2026, 5, 28, 12, 0, 0);
      expect(isSameDay(scheduled, now), isFalse);
    });

    test('scheduledTime in different year → false', () {
      final scheduled = DateTime(2027, 4, 28, 12, 0, 0);
      expect(isSameDay(scheduled, now), isFalse);
    });
  });
}
