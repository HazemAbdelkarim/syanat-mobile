import 'package:flutter/material.dart';

const Color _syanatBlue = Color(0xFF3C21C8);

/// Read-only receipt summary card shared by the customer's receipt-review
/// screen and the technician's approve-payment screen. Centralising the
/// rendering prevents the two surfaces from drifting apart on formatting,
/// subtotal math display, or Arabic-label choices.
///
/// The `receiptData` argument is the `receipt` map on the job document as
/// written by `FirebaseService.submitReceipt` — shape:
///   { services: [{title, price}], parts: [{name, price}],
///     servicesSubtotal: num, partsSubtotal: num, grandTotal: num,
///     notes: string }
/// Any missing field renders as an empty section; the widget never throws
/// on legacy or partial documents.
class ReceiptSummaryCard extends StatelessWidget {
  final Map<String, dynamic>? receiptData;
  final bool isEn;

  /// When true, appends a "Services Subtotal" / "Parts Subtotal" line at
  /// the end of each section. The customer's review screen uses `true`;
  /// the tech's approve-payment screen keeps `false` and shows a dedicated
  /// amount-due card above this one.
  final bool showSubtotals;

  /// When true, renders a prominent "Grand Total" row after the sections.
  /// Customer review: `true`. Tech approve-payment: `false`.
  final bool showGrandTotal;

  const ReceiptSummaryCard({
    super.key,
    required this.receiptData,
    required this.isEn,
    this.showSubtotals = false,
    this.showGrandTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    final data = receiptData ?? const <String, dynamic>{};
    final services = (data['services'] as List?)?.cast<dynamic>() ?? const [];
    final parts = (data['parts'] as List?)?.cast<dynamic>() ?? const [];
    final servicesSubtotal =
        (data['servicesSubtotal'] as num?)?.toDouble() ?? 0.0;
    final partsSubtotal =
        (data['partsSubtotal'] as num?)?.toDouble() ?? 0.0;
    final grandTotal = (data['grandTotal'] as num?)?.toDouble() ?? 0.0;
    final notes = (data['notes'] as String?)?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 8,
              offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: _syanatBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                isEn ? 'Receipt Summary' : 'ملخص الإيصال',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (services.isNotEmpty) ...[
            _sectionHeader(isEn ? 'Services' : 'الخدمات'),
            const SizedBox(height: 6),
            ...services.map(
              (s) => _lineRow(
                (s is Map) ? (s['title']?.toString() ?? '') : s.toString(),
                (s is Map) ? (s['price'] as num?)?.toDouble() ?? 0 : 0,
              ),
            ),
            if (showSubtotals) ...[
              const SizedBox(height: 4),
              _subtotalRow(
                  isEn ? 'Services Subtotal' : 'إجمالي الخدمات',
                  servicesSubtotal),
            ],
            const SizedBox(height: 10),
          ],
          if (parts.isNotEmpty) ...[
            _sectionHeader(isEn ? 'Parts' : 'القطع'),
            const SizedBox(height: 6),
            ...parts.map(
              (p) => _lineRow(
                (p is Map) ? (p['name']?.toString() ?? '') : p.toString(),
                (p is Map) ? (p['price'] as num?)?.toDouble() ?? 0 : 0,
              ),
            ),
            if (showSubtotals) ...[
              const SizedBox(height: 4),
              _subtotalRow(
                  isEn ? 'Parts Subtotal' : 'إجمالي القطع',
                  partsSubtotal),
            ],
            const SizedBox(height: 10),
          ],
          if (showGrandTotal) ...[
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEn ? 'Grand Total' : 'الإجمالي الكلي',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${grandTotal.toStringAsFixed(0)} EGP',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _syanatBlue),
                ),
              ],
            ),
          ],
          if (notes.isNotEmpty) ...[
            if (showGrandTotal)
              const SizedBox(height: 14)
            else
              const Divider(height: 20),
            Text(
              isEn ? 'Notes' : 'ملاحظات',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700),
            ),
            const SizedBox(height: 4),
            Text(
              notes,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700),
    );
  }

  Widget _lineRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${amount.toStringAsFixed(0)} EGP',
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _subtotalRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500)),
        Text(
          '${amount.toStringAsFixed(0)} EGP',
          style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
