import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'firebase_service.dart';
import 'widgets/receipt_summary_card.dart';

const Color _syanatBlue = Color(0xFF3C21C8);

/// Technician-side screen shown when a job is in
/// `awaiting_payment_verification`. The tech uploads a photo of the cash/bill
/// they received and confirms the full amount. Server-side rule gates:
///   - caller is `assignedTechnicianId`
///   - `paymentProofUrl is string`
///   - `amountPaid >= receiptTotal`, `amountPaid <= 50000 EGP`
/// See firestore.rules "SECURITY INVARIANT" above the verification branch.
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
  final _picker = ImagePicker();

  /// Download URL of the uploaded proof photo. Null until upload succeeds.
  String? _proofUrl;
  bool _uploading = false;
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

  Future<void> _pickAndUploadProof() async {
    if (_uploading || _confirming) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: _syanatBlue),
              title: Text(_t('Take a photo', 'التقاط صورة')),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: _syanatBlue),
              title: Text(_t('Choose from gallery', 'اختر من المعرض')),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 4096,
        maxHeight: 4096,
      );
      if (picked == null || !mounted) return;

      setState(() => _uploading = true);
      final url =
          await FirebaseService.uploadJobPaymentProof(picked, widget.jobId);
      if (!mounted) return;
      setState(() {
        _proofUrl = url;
        _uploading = false;
      });
    } on FirebaseException catch (e) {
      debugPrint(
          'uploadJobPaymentProof firebase error: ${e.code} – ${e.message}');
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t('Upload failed: ', 'فشل الرفع: ') +
            (e.message ?? e.code)),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ));
    } catch (e) {
      debugPrint('uploadJobPaymentProof error: $e');
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t('Upload failed. Please try again.',
            'فشل الرفع. يرجى المحاولة مرة أخرى.')),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _removeProof() {
    if (_confirming) return;
    setState(() => _proofUrl = null);
  }

  Future<void> _confirmPayment() async {
    if (_proofUrl == null || _uploading || _confirming) return;
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
      await FirebaseService.verifyPaymentWithProof(
        jobId: widget.jobId,
        technicianId: widget.technicianId,
        paymentProofUrl: _proofUrl!,
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
          'verifyPaymentWithProof firebase error: ${e.code} – ${e.message}');
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
      debugPrint('verifyPaymentWithProof error: $e');
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
                  const SizedBox(height: 16),
                  _proofTile(isEn),
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
        color: _syanatBlue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _syanatBlue.withOpacity(0.3)),
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

  Widget _proofTile(bool isEn) {
    if (_uploading) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: _syanatBlue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                isEn ? 'Uploading proof…' : 'جاري رفع الإثبات...',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    if (_proofUrl != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _syanatBlue.withOpacity(0.3)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 8,
                offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                _proofUrl!,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 64,
                  height: 64,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image,
                      color: Colors.black45),
                ),
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : SizedBox(
                        width: 64,
                        height: 64,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _syanatBlue.withOpacity(0.6)),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEn ? 'Proof uploaded' : 'تم رفع الإثبات',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEn
                        ? 'Tap replace to pick a different photo.'
                        : 'اضغط استبدال لاختيار صورة أخرى.',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                TextButton(
                  onPressed: _confirming ? null : _pickAndUploadProof,
                  style: TextButton.styleFrom(
                    foregroundColor: _syanatBlue,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 32),
                  ),
                  child: Text(
                    isEn ? 'Replace' : 'استبدال',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: _confirming ? null : _removeProof,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 32),
                  ),
                  child: Text(
                    isEn ? 'Remove' : 'إزالة',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _confirming ? null : _pickAndUploadProof,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _syanatBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.camera_alt, color: _syanatBlue, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEn ? 'Upload payment proof' : 'رفع إثبات الدفع',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEn
                        ? 'Take a photo of the cash or bill you received.'
                        : 'التقط صورة للمبلغ النقدي الذي استلمته.',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _confirmBar(bool isEn) {
    final canConfirm =
        _proofUrl != null && !_uploading && !_confirming;

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
            onPressed: canConfirm ? _confirmPayment : null,
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
