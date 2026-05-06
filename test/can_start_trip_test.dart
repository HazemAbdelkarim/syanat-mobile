import 'package:flutter_test/flutter_test.dart';
import 'package:syanat/job_status.dart';

void main() {
  group('canStartTrip', () {
    final now = DateTime(2026, 4, 28, 12, 0, 0);

    test('null scheduledTime → true (urgent jobs bypass)', () {
      expect(canStartTrip(null, now), isTrue);
    });

    test('scheduledTime 2 hours from now → false', () {
      final scheduled = now.add(const Duration(hours: 2));
      expect(canStartTrip(scheduled, now), isFalse);
    });

    test('scheduledTime 30 minutes from now → true', () {
      final scheduled = now.add(const Duration(minutes: 30));
      expect(canStartTrip(scheduled, now), isTrue);
    });

    test('scheduledTime exactly 60 minutes from now → true (boundary)', () {
      final scheduled = now.add(const Duration(minutes: 60));
      expect(canStartTrip(scheduled, now), isTrue);
    });

    test('scheduledTime in the past → true (starting late is fine)', () {
      final scheduled = now.subtract(const Duration(hours: 3));
      expect(canStartTrip(scheduled, now), isTrue);
    });

    test('scheduledTime 61 minutes from now → false (boundary)', () {
      final scheduled = now.add(const Duration(minutes: 61));
      expect(canStartTrip(scheduled, now), isFalse);
    });

    test('scheduledTime equal to now → true', () {
      expect(canStartTrip(now, now), isTrue);
    });
  });
}
