import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'job_status.dart' show jobStatusTechLabel;
import 'widgets/receipt_summary_card.dart';

const Color _syanatBlue = Color(0xFF3C21C8);

/// Read-only job detail surface for the technician — used when the job is in
/// a passive-wait status (`awaiting_customer_approval`, `awaiting_payment`,
/// `receipt_disputed`) where the tech has nothing to do but wait for the
/// customer or admin. Renders customer name, location, scheduled time, the
/// status label, and the submitted receipt (via the shared
/// `ReceiptSummaryCard`). No phone (Phase 5 product rule). No actions, no
/// controls — purely informational.
///
/// The screen accepts the full job map rather than streaming the doc itself.
/// The home screen's plural active-jobs stream is the source of truth and
/// will pop this screen out of the active list as soon as the job leaves a
/// passive-wait status. If the tech needs the latest, they back out and
/// re-tap the tile.
class TechnicianJobDetailReadonlyScreen extends StatelessWidget {
  final Map<String, dynamic> job;
  const TechnicianJobDetailReadonlyScreen({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final status = (job['status'] as String?) ?? '';
    final customerName = ((job['customerName'] as String?)?.trim() ?? '');
    final address = ((job['locationAddress'] as String?)?.trim() ?? '');
    final dynamic scheduled = job['scheduledTime'];
    final receipt = job['receipt'] as Map<String, dynamic>?;

    final String scheduledLabel = scheduled is Timestamp
        ? _formatScheduled(scheduled.toDate())
        : (isEn ? 'No scheduled time' : 'بدون موعد محدد');

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7FB),
        appBar: AppBar(
          backgroundColor: _syanatBlue,
          foregroundColor: Colors.white,
          title: Text(isEn ? 'Job Details' : 'تفاصيل المهمة'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _statusBanner(isEn, status),
            const SizedBox(height: 16),
            _detailCard(
              isEn,
              customerName:
                  customerName.isEmpty ? (isEn ? 'Customer' : 'العميل') : customerName,
              address: address.isEmpty ? '—' : address,
              scheduledLabel: scheduledLabel,
            ),
            if (receipt != null && receipt.isNotEmpty) ...[
              const SizedBox(height: 16),
              ReceiptSummaryCard(
                receiptData: receipt,
                isEn: isEn,
                showSubtotals: true,
                showGrandTotal: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatScheduled(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year}  $hh:$mm';
  }

  Widget _statusBanner(bool isEn, String status) {
    final isDisputed = status == 'receipt_disputed';
    final color = isDisputed ? Colors.red.shade400 : _syanatBlue;
    final IconData icon;
    if (isDisputed) {
      icon = Icons.gavel;
    } else if (status == 'awaiting_payment') {
      icon = Icons.payments_outlined;
    } else {
      icon = Icons.hourglass_top;
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              jobStatusTechLabel(status, isEn: isEn),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailCard(
    bool isEn, {
    required String customerName,
    required String address,
    required String scheduledLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(Icons.person_outline,
              isEn ? 'Customer' : 'العميل', customerName),
          const SizedBox(height: 10),
          _row(Icons.location_on_outlined,
              isEn ? 'Location' : 'الموقع', address),
          const SizedBox(height: 10),
          _row(Icons.schedule, isEn ? 'Scheduled' : 'الموعد', scheduledLabel),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 14, color: Colors.black87)),
        ),
      ],
    );
  }
}
