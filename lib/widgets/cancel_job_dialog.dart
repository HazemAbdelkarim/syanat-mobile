import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../job_status.dart';

/// Result of [showCancelJobDialog]. `confirmed` is true when the tech
/// presses "Cancel job"; `reason` is the trimmed text from the optional
/// reason field (empty when blank or when the dialog was dismissed).
class CancelJobDialogResult {
  final bool confirmed;
  final String reason;
  const CancelJobDialogResult({required this.confirmed, required this.reason});
}

/// Shows the tech-cancel confirmation dialog. Computes the penalty up-front
/// from [scheduledTime] (a Firestore [Timestamp] or null for urgent jobs)
/// and renders the result, the time-until-scheduled label, the optional
/// reason field, and the two action buttons.
///
/// Returns null when the dialog is dismissed (barrier tap, back button) or
/// a [CancelJobDialogResult] when an explicit button is pressed.
Future<CancelJobDialogResult?> showCancelJobDialog({
  required BuildContext context,
  required dynamic scheduledTime,
  required bool isEn,
}) {
  final DateTime? scheduledAt =
      scheduledTime is Timestamp ? scheduledTime.toDate() : null;
  final now = DateTime.now();
  final penalty = calculateCancellationPenalty(scheduledAt, now);
  final reasonCtrl = TextEditingController();

  return showDialog<CancelJobDialogResult>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isEn ? 'Cancel this job?' : 'إلغاء هذه المهمة؟'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ScheduleLine(scheduledAt: scheduledAt, now: now, isEn: isEn),
              const SizedBox(height: 12),
              _PenaltyBadge(penalty: penalty, isEn: isEn),
              if (penalty.escalate) ...[
                const SizedBox(height: 10),
                Text(
                  isEn
                      ? 'Late cancellations require review and may affect your account.'
                      : 'الإلغاء المتأخر يخضع للمراجعة وقد يؤثر على حسابك.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: reasonCtrl,
                maxLength: 500,
                maxLines: 3,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: isEn ? 'Reason (optional)' : 'السبب (اختياري)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              ctx,
              const CancelJobDialogResult(confirmed: false, reason: ''),
            ),
            child: Text(isEn ? 'Keep job' : 'الاحتفاظ بالمهمة'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(
              ctx,
              CancelJobDialogResult(
                confirmed: true,
                reason: reasonCtrl.text.trim(),
              ),
            ),
            child: Text(isEn ? 'Cancel job' : 'إلغاء المهمة'),
          ),
        ],
      );
    },
  );
}

class _ScheduleLine extends StatelessWidget {
  final DateTime? scheduledAt;
  final DateTime now;
  final bool isEn;
  const _ScheduleLine({
    required this.scheduledAt,
    required this.now,
    required this.isEn,
  });

  @override
  Widget build(BuildContext context) {
    final String label;
    if (scheduledAt == null) {
      label = isEn ? 'Urgent (no scheduled time)' : 'عاجل (بدون وقت محدد)';
    } else if (!scheduledAt!.isAfter(now)) {
      label = isEn ? 'Past scheduled time' : 'بعد الوقت المحدد';
    } else {
      final delta = scheduledAt!.difference(now);
      final h = delta.inHours;
      final m = delta.inMinutes.remainder(60);
      if (h >= 1) {
        label = isEn ? 'Scheduled in ${h}h ${m}m' : 'بعد $h س $m د';
      } else {
        label = isEn
            ? 'Scheduled in ${delta.inMinutes}m'
            : 'بعد ${delta.inMinutes} دقيقة';
      }
    }
    return Row(
      children: [
        const Icon(Icons.schedule, size: 18, color: Colors.black54),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

class _PenaltyBadge extends StatelessWidget {
  final CancellationPenalty penalty;
  final bool isEn;
  const _PenaltyBadge({required this.penalty, required this.isEn});

  @override
  Widget build(BuildContext context) {
    final isFree = penalty.penalty == 0;
    final color = isFree ? const Color(0xFF15803D) : Colors.red.shade700;
    final base = isFree ? const Color(0xFF15803D) : Colors.red;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.08),
        border: Border.all(color: base.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            isFree ? Icons.check_circle_outline : Icons.warning_amber_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFree
                      ? (isEn ? 'No penalty' : 'بدون غرامة')
                      : (isEn
                          ? 'Penalty: ${penalty.penalty.toStringAsFixed(0)} EGP'
                          : 'الغرامة: ${penalty.penalty.toStringAsFixed(0)} ج.م'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isFree
                      ? (isEn
                          ? 'More than 6 hours away.'
                          : 'أكثر من 6 ساعات على الموعد.')
                      : (isEn
                          ? 'Computed from time-to-scheduled-time.'
                          : 'محسوبة بناءً على الوقت المتبقي حتى الموعد.'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
