import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';

import 'firebase_service.dart';
import 'widgets/receipt_summary_card.dart';

const Color _syanatBlue = Color(0xFF3C21C8);

// TODO(BLAZE): restore photo proof upload — see firestore.rules branch 5
//
/// Technician-side screen shown when a job is in
/// `awaiting_payment_verification`. The tech taps a single button to confirm
/// the cash they received from the customer; no photo proof is uploaded
/// (Storage is not initialized on the Spark plan). Server-side rule gate that
/// preserves payment integrity:
///   - caller is `assignedTechnicianId`
///   - `amountPaid >= receiptTotal`, `amountPaid <= 50000 EGP`
/// The rule still rejects under-payment, so the customer's approved receipt
/// total remains the floor even without a proof photo. See firestore.rules
/// "SECURITY INVARIANT" above the verification branch.
class TechnicianApprovePaymentScreen extends StatefulWidget {
  final String jobId;
  final String technicianId;

  /// Snapshot of the job document. Used to render the read-only receipt
  /// summary and to read `receiptTotal` (the canonical amount). Passing the
  /// whole map — instead of a separate `receiptTotal` param — keeps the
  /// caller lean and lets the screen render the full line-item summary.
  final Map<String, dynamic> job;

  const TechnicianApprovePaymentScreen({
    super.key,
    required this.jobId,
    required this.technicianId,
    required this.job,
  });

  @override
  State<TechnicianApprovePaymentScreen> createState() =>
      _TechnicianApprovePaymentScreenState();
}

class _TechnicianApprovePaymentScreenState
    extends State<TechnicianApprovePaymentScreen> {
  bool _confirming = false;

  bool get _isEn => Localizations.localeOf(context).languageCode == 'en';
  String _t(String en, String ar) => _isEn ? en : ar;

  /// Canonical amount due. Release-006 writes a top-level `receiptTotal`
  /// field; falls back to `receipt.grandTotal` for pre-release-006 jobs so
  /// the screen still renders an amount for historical rows.
  double get _receiptTotal {
    final top = (widget.job['receiptTotal'] as num?)?.toDouble();
    if (top != null) return top;
    final receipt = widget.job['receipt'] as Map<String, dynamic>?;
    return (receipt?['grandTotal'] as num?)?.toDouble() ?? 0.0;
  }

  Map<String, dynamic>? get _receipt =>
      widget.job['receipt'] as Map<String, dynamic>?;

  Future<void> _confirmPayment() async {
    if (_confirming) return;
    final total = _receiptTotal;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_t('Confirm payment received', 'تأكيد استلام الدفع')),
        content: Text(_t(
            'Confirm you received ${total.toStringAsFixed(0)} EGP from the customer. This cannot be undone.',
            'أكد استلام ${total.toStringAsFixed(0)} جنيه من العميل. لا يمكن التراجع.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('Cancel', 'إلغاء')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: _syanatBlue),
            child: Text(_t('Confirm', 'تأكيد')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _confirming = true);
    try {
      await FirebaseService.verifyPayment(
        jobId: widget.jobId,
        technicianId: widget.technicianId,
        amountPaid: total,
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t('Payment confirmed — job completed',
            'تم تأكيد الدفع — اكتملت المهمة')),
        backgroundColor: Colors.green,
      ));
    } on FirebaseException catch (e) {
      debugPrint(
          'verifyPayment firebase error: ${e.code} – ${e.message}');
      if (!mounted) return;
      final detail =
          (e.message ?? '').trim().isEmpty ? e.code : e.message!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${_t('Could not confirm payment.', 'تعذر تأكيد الدفع.')}  [$detail]'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 6),
      ));
    } catch (e) {
      debugPrint('verifyPayment error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t(
            'Could not confirm payment. Please try again.',
            'تعذر تأكيد الدفع. يرجى المحاولة مرة أخرى.')),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
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
          title: Text(_t('Approve Payment', 'تأكيد الدفع')),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ReceiptSummaryCard(
                    receiptData: _receipt,
                    isEn: isEn,
                    // Subtotals + grand total are off here because the
                    // amount-due card below renders the canonical total.
                  ),
                  const SizedBox(height: 16),
                  _amountDueCard(isEn),
                  const SizedBox(height: 100),
                ],
              ),
            ),
            _confirmBar(isEn),
          ],
        ),
      ),
    );
  }

  // ── Sub-builders ──────────────────────────────────────────────────────────

  Widget _amountDueCard(bool isEn) {
    final total = _receiptTotal;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _syanatBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _syanatBlue.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isEn ? 'Amount Due' : 'المبلغ المستحق',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          Text(
            '${total.toStringAsFixed(0)} EGP',
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _syanatBlue),
          ),
        ],
      ),
    );
  }

  Widget _confirmBar(bool isEn) {
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
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _confirming ? null : _confirmPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: _syanatBlue,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade600,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _confirming
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    isEn
                        ? 'Confirm payment received'
                        : 'تأكيد استلام الدفع',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }
}
