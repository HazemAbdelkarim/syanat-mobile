import 'package:flutter_test/flutter_test.dart';
import 'package:syanat/job_status.dart';

void main() {
  group('calculateCancellationPenalty', () {
    final now = DateTime(2026, 4, 29, 12, 0, 0);

    test('null scheduledTime (urgent) → 200, escalate', () {
      final r = calculateCancellationPenalty(null, now);
      expect(r.penalty, 200);
      expect(r.escalate, isTrue);
    });

    test('scheduledTime in the past → 200, escalate', () {
      final scheduled = now.subtract(const Duration(minutes: 5));
      final r = calculateCancellationPenalty(scheduled, now);
      expect(r.penalty, 200);
      expect(r.escalate, isTrue);
    });

    test('scheduledTime equal to now → 200, escalate', () {
      final r = calculateCancellationPenalty(now, now);
      expect(r.penalty, 200);
      expect(r.escalate, isTrue);
    });

    test('30 min ahead (< 1h) → 200, escalate', () {
      final scheduled = now.add(const Duration(minutes: 30));
      final r = calculateCancellationPenalty(scheduled, now);
      expect(r.penalty, 200);
      expect(r.escalate, isTrue);
    });

    test('exactly 1h ahead (boundary) → 200, no escalate', () {
      final scheduled = now.add(const Duration(hours: 1));
      final r = calculateCancellationPenalty(scheduled, now);
      expect(r.penalty, 200);
      expect(r.escalate, isFalse);
    });

    test('1h 30 min ahead → 200, no escalate', () {
      final scheduled = now.add(const Duration(hours: 1, minutes: 30));
      final r = calculateCancellationPenalty(scheduled, now);
      expect(r.penalty, 200);
      expect(r.escalate, isFalse);
    });

    test('exactly 2h ahead (boundary) → 100', () {
      final scheduled = now.add(const Duration(hours: 2));
      final r = calculateCancellationPenalty(scheduled, now);
      expect(r.penalty, 100);
      expect(r.escalate, isFalse);
    });

    test('2h 59 min ahead → 100', () {
      final scheduled = now.add(const Duration(hours: 2, minutes: 59));
      final r = calculateCancellationPenalty(scheduled, now);
      expect(r.penalty, 100);
      expect(r.escalate, isFalse);
    });

    test('exactly 3h ahead (boundary) → 70', () {
      final scheduled = now.add(const Duration(hours: 3));
      final r = calculateCancellationPenalty(scheduled, now);
      expect(r.penalty, 70);
      expect(r.escalate, isFalse);
    });

    test('exactly 4h ahead (boundary) → 40', () {
      final scheduled = now.add(const Duration(hours: 4));
      final r = calculateCancellationPenalty(scheduled, now);
      expect(r.penalty, 40);
      expect(r.escalate, isFalse);
    });

    test('exactly 5h ahead (boundary) → 20', () {
      final scheduled = now.add(const Duration(hours: 5));
      final r = calculateCancellationPenalty(scheduled, now);
      expect(r.penalty, 20);
      expect(r.escalate, isFalse);
    });

    test('5h 59 min ahead → 20', () {
      final scheduled = now.add(const Duration(hours: 5, minutes: 59));
      final r = calculateCancellationPenalty(scheduled, now);
      expect(r.penalty, 20);
      expect(r.escalate, isFalse);
    });

    test('exactly 6h ahead (boundary) → 0', () {
      final scheduled = now.add(const Duration(hours: 6));
      final r = calculateCancellationPenalty(scheduled, now);
      expect(r.penalty, 0);
      expect(r.escalate, isFalse);
    });

    test('24h ahead → 0', () {
      final scheduled = now.add(const Duration(hours: 24));
      final r = calculateCancellationPenalty(scheduled, now);
      expect(r.penalty, 0);
      expect(r.escalate, isFalse);
    });
  });
}
