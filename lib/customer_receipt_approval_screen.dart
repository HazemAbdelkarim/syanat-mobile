import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';

import 'firebase_service.dart';
import 'widgets/receipt_summary_card.dart';

const Color _syanatBlue = Color(0xFF3C21C8);

/// Customer-side screen shown when a job is in `awaiting_customer_approval`.
/// The customer reviews the itemized receipt and either approves (→
/// awaiting_payment) or disputes (stub until the dispute flow lands).
///
/// Approving does NOT mark the job paid — the customer still has to pay the
/// technician in person via `customer_payment_screen.dart`, which then hands
/// off to the tech for tap-to-confirm verification.
class CustomerReceiptApprovalScreen extends StatefulWidget {
  final String jobId;
  final String customerId;
  final Map<String, dynamic> job;

  const CustomerReceiptApprovalScreen({
    super.key,
    required this.jobId,
    required this.customerId,
    required this.job,
  });

  @override
  State<CustomerReceiptApprovalScreen> createState() =>
      _CustomerReceiptApprovalScreenState();
}

class _CustomerReceiptApprovalScreenState
    extends State<CustomerReceiptApprovalScreen> {
  bool _approving = false;

  bool get _isEn => Localizations.localeOf(context).languageCode == 'en';
  String _t(String en, String ar) => _isEn ? en : ar;

  Map<String, dynamic>? get _receipt =>
      widget.job['receipt'] as Map<String, dynamic>?;

  double get _grandTotal {
    final top = (widget.job['receiptTotal'] as num?)?.toDouble();
    if (top != null) return top;
    return (_receipt?['grandTotal'] as num?)?.toDouble() ?? 0.0;
  }

  Future<void> _approve() async {
    if (_approving) return;
    final total = _grandTotal;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_t('Approve receipt?', 'الموافقة على الفاتورة؟')),
        content: Text(_t(
            'Approving confirms the amount ${total.toStringAsFixed(0)} EGP. You will then pay the technician and they will verify.',
            'الموافقة تؤكد المبلغ ${total.toStringAsFixed(0)} جنيه. ستقوم بعد ذلك بالدفع للفني وسيقوم بالتأكيد.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('Cancel', 'إلغاء')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: _syanatBlue),
            child: Text(_t('Approve', 'موافق')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _approving = true);
    try {
      await FirebaseService.approveReceipt(widget.jobId, widget.customerId);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t(
            'Receipt approved. Please pay the technician next.',
            'تمت الموافقة. يرجى الدفع للفني في الخطوة التالية.')),
        backgroundColor: Colors.green,
      ));
    } on FirebaseException catch (e) {
      debugPrint('approveReceipt firebase error: ${e.code} – ${e.message}');
      if (!mounted) return;
      final detail =
          (e.message ?? '').trim().isEmpty ? e.code : e.message!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${_t('Could not approve receipt.', 'تعذر الموافقة على الفاتورة.')}  [$detail]'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 6),
      ));
    } catch (e) {
      debugPrint('approveReceipt error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t(
            'Could not approve receipt. Please try again.',
            'تعذر الموافقة على الفاتورة. يرجى المحاولة مرة أخرى.')),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _approving = false);
    }
  }

  void _disputeStub() {
    // Dispute flow is a deferred follow-up — see Phase 6 deferral list.
    // Stubbing as a SnackBar (no state change, no network call).
    final isEn = _isEn;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isEn
          ? 'Dispute flow coming soon'
          : 'ميزة النزاع قريباً'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isEn = _isEn;
    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7FB),
        appBar: AppBar(
          backgroundColor: _syanatBlue,
          foregroundColor: Colors.white,
          title: Text(_t('Review Receipt', 'راجع الفاتورة')),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _importantNotice(isEn),
                  const SizedBox(height: 16),
                  ReceiptSummaryCard(
                    receiptData: _receipt,
                    isEn: isEn,
                    showSubtotals: true,
                    showGrandTotal: true,
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
            _actionBar(isEn),
          ],
        ),
      ),
    );
  }

  Widget _importantNotice(bool isEn) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6A817)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFCC8400), size: 18),
              const SizedBox(width: 8),
              Text(
                isEn ? 'Important Notice' : 'تنبيه مهم',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF7A4F00),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isEn
                ? 'Make sure the prices listed here match what you will pay. These are the official reference for any complaint or dispute.'
                : 'تأكد من أن الأسعار المدرجة هنا تطابق ما ستدفعه. هذه هي المرجع الرسمي لأي شكوى أو نزاع.',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF7A4F00),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBar(bool isEn) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 10,
              offset: Offset(0, -3)),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _approving ? null : _approve,
                icon: _approving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _t('Approve', 'موافق'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _syanatBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _approving ? null : _disputeStub,
                icon: const Icon(Icons.report_gmailerrorred_outlined,
                    size: 18),
                label: Text(
                  _t('Dispute', 'اعتراض'),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                  side: BorderSide(color: Colors.red.shade300),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
