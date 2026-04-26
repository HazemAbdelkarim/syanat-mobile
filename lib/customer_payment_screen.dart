import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';

import 'firebase_service.dart';

const Color _syanatBlue = Color(0xFF3C21C8);

/// Customer-side screen shown when a job is in `awaiting_payment`.
/// Product reality: no online payment gateway is integrated yet — the
/// customer pays the technician in cash in person. This screen exists to
/// capture the customer's confirmation that they paid, after which the
/// technician taps to confirm receipt and closes the job.
class CustomerPaymentScreen extends StatefulWidget {
  final String jobId;
  final String customerId;
  final Map<String, dynamic> job;

  const CustomerPaymentScreen({
    super.key,
    required this.jobId,
    required this.customerId,
    required this.job,
  });

  @override
  State<CustomerPaymentScreen> createState() =>
      _CustomerPaymentScreenState();
}

class _CustomerPaymentScreenState extends State<CustomerPaymentScreen> {
  bool _submitting = false;

  bool get _isEn => Localizations.localeOf(context).languageCode == 'en';
  String _t(String en, String ar) => _isEn ? en : ar;

  double get _receiptTotal {
    final top = (widget.job['receiptTotal'] as num?)?.toDouble();
    if (top != null) return top;
    final receipt = widget.job['receipt'] as Map<String, dynamic>?;
    return (receipt?['grandTotal'] as num?)?.toDouble() ?? 0.0;
  }

  Future<void> _markPaid() async {
    if (_submitting) return;
    final total = _receiptTotal;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_t('Confirm payment sent', 'تأكيد إرسال الدفع')),
        content: Text(_t(
            'Confirm you paid the technician ${total.toStringAsFixed(0)} EGP in cash. They will verify and complete the job.',
            'أكد أنك دفعت للفني ${total.toStringAsFixed(0)} جنيه نقداً. سيقوم بالتأكيد وإكمال المهمة.')),
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

    setState(() => _submitting = true);
    try {
      await FirebaseService.initiatePayment(widget.jobId, widget.customerId);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t(
            'Payment recorded. Waiting for the technician to confirm.',
            'تم تسجيل الدفع. في انتظار تأكيد الفني.')),
        backgroundColor: Colors.green,
      ));
    } on FirebaseException catch (e) {
      debugPrint('initiatePayment firebase error: ${e.code} – ${e.message}');
      if (!mounted) return;
      final detail =
          (e.message ?? '').trim().isEmpty ? e.code : e.message!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${_t('Could not record payment.', 'تعذر تسجيل الدفع.')}  [$detail]'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 6),
      ));
    } catch (e) {
      debugPrint('initiatePayment error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t(
            'Could not record payment. Please try again.',
            'تعذر تسجيل الدفع. يرجى المحاولة مرة أخرى.')),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = _isEn;
    final total = _receiptTotal;

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7FB),
        appBar: AppBar(
          backgroundColor: _syanatBlue,
          foregroundColor: Colors.white,
          title: Text(_t('Pay Technician', 'ادفع للفني')),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _totalDueCard(isEn, total),
                  const SizedBox(height: 20),
                  _instructionsCard(isEn),
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

  Widget _totalDueCard(bool isEn, double total) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF7C4DFF),
            Color(0xFF6C3CE1),
            _syanatBlue,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        // Pre-computed 0x33 alpha over _syanatBlue (0xFF3C21C8) — honors the
        // Phase-6 "no new withOpacity / no withValues" rule while keeping
        // the decorative shadow.
        boxShadow: const [
          BoxShadow(
              color: Color(0x333C21C8),
              blurRadius: 16,
              offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payments_outlined,
                  color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                isEn ? 'Total Due' : 'المبلغ المستحق',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${total.toStringAsFixed(0)} EGP',
            style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _instructionsCard(bool isEn) {
    return Container(
      padding: const EdgeInsets.all(18),
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
              const Icon(Icons.info_outline, color: _syanatBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                isEn ? 'How to pay' : 'كيفية الدفع',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isEn
                ? 'Pay the technician in cash for the exact amount above. Once you\'ve paid, tap the button below. The technician will then confirm receipt and complete the job.'
                : 'ادفع للفني نقداً بالمبلغ المحدد أعلاه. بعد الدفع، اضغط الزر أدناه. سيقوم الفني بتأكيد الاستلام وإكمال المهمة.',
            style: TextStyle(
                fontSize: 13, color: Colors.grey.shade700, height: 1.5),
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
          child: ElevatedButton.icon(
            onPressed: _submitting ? null : _markPaid,
            icon: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(
              _t('I\'ve paid the technician', 'لقد دفعت للفني'),
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
      ),
    );
  }
}
