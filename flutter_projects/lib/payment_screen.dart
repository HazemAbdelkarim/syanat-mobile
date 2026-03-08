import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'firebase_service.dart';
import 'models/payment.dart';

const Color _syanatBlue = Color(0xFF3C21C8);

/// Result returned from this screen on successful payment submission.
class PaymentResult {
  final String paymentId;
  final PaymentMethod method;

  const PaymentResult({required this.paymentId, required this.method});
}

/// Screen shown after the user confirms a service booking.
/// Returns a [PaymentResult] via Navigator.pop on success, or null on cancel.
class PaymentScreen extends StatefulWidget {
  final double amount;
  final String serviceKey;
  final String serviceLabel;

  const PaymentScreen({
    super.key,
    required this.amount,
    required this.serviceKey,
    required this.serviceLabel,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  PaymentMethod? _selectedMethod;
  final _refController = TextEditingController();
  XFile? _screenshot;
  bool _submitting = false;

  @override
  void dispose() {
    _refController.dispose();
    super.dispose();
  }

  bool get _isEn => Localizations.localeOf(context).languageCode == 'en';

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    if (_selectedMethod == null) return;

    final user = FirebaseService.getCurrentUser();
    if (user == null) return;

    // Validate for digital methods
    if (_selectedMethod != PaymentMethod.cash) {
      if (_refController.text.trim().isEmpty) {
        _showSnack(_isEn
            ? 'Please enter the transaction reference'
            : 'من فضلك ادخل رقم العملية');
        return;
      }
      if (_screenshot == null) {
        _showSnack(_isEn
            ? 'Please upload a payment screenshot'
            : 'من فضلك ارفع صورة إيصال الدفع');
        return;
      }
    }

    setState(() => _submitting = true);

    try {
      // 1. Create payment record (orderId will be updated after job creation)
      final paymentId = await FirebaseService.createPayment(
        orderId: '', // linked later by caller
        userId: user.uid,
        amount: widget.amount,
        method: Payment.methodToString(_selectedMethod!),
        transactionReference: _refController.text.trim(),
      );

      // 2. Upload screenshot if provided
      if (_screenshot != null) {
        final url =
            await FirebaseService.uploadPaymentProof(_screenshot!, paymentId);
        await FirebaseService.updatePaymentScreenshot(paymentId, url);
      }

      if (!mounted) return;
      Navigator.pop(
        context,
        PaymentResult(paymentId: paymentId, method: _selectedMethod!),
      );
    } catch (e) {
      debugPrint('Payment error: $e');
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickScreenshot() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (file != null) setState(() => _screenshot = file);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isEn = _isEn;

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: _syanatBlue,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            isEn ? 'Payment' : 'الدفع',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: _submitting
            ? const Center(
                child: CircularProgressIndicator(color: _syanatBlue))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildOrderSummary(isEn),
                    const SizedBox(height: 24),
                    _buildMethodSelector(isEn),
                    if (_selectedMethod != null) ...[
                      const SizedBox(height: 24),
                      _buildMethodDetails(isEn),
                    ],
                    const SizedBox(height: 30),
                    _buildSubmitButton(isEn),
                  ],
                ),
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Order summary card
  // ---------------------------------------------------------------------------

  Widget _buildOrderSummary(bool isEn) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDFF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEn ? 'Order Summary' : 'ملخص الطلب',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _syanatBlue,
            ),
          ),
          const SizedBox(height: 12),
          _summaryRow(
            icon: Icons.home_repair_service,
            label: isEn ? 'Service' : 'الخدمة',
            value: widget.serviceLabel,
          ),
          const SizedBox(height: 8),
          _summaryRow(
            icon: Icons.payments_outlined,
            label: isEn ? 'Amount' : 'المبلغ',
            value: widget.amount > 0
                ? '${widget.amount.toStringAsFixed(0)} EGP'
                : (isEn ? 'To be determined' : 'سيُحدد لاحقاً'),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
      {required IconData icon, required String label, required String value}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _syanatBlue),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(fontSize: 14, color: Colors.black54)),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Payment method selector
  // ---------------------------------------------------------------------------

  Widget _buildMethodSelector(bool isEn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isEn ? 'Choose Payment Method' : 'اختر طريقة الدفع',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        _methodTile(
          method: PaymentMethod.cash,
          icon: Icons.money,
          color: Colors.green,
          title: isEn ? 'Cash on Service' : 'الدفع كاش عند الخدمة',
          subtitle: isEn
              ? 'Pay the technician directly'
              : 'ادفع للفني مباشرة',
        ),
        const SizedBox(height: 10),
        _methodTile(
          method: PaymentMethod.vodafoneCash,
          icon: Icons.phone_android,
          color: Colors.red,
          title: isEn ? 'Vodafone Cash' : 'فودافون كاش',
          subtitle: isEn
              ? 'Transfer via Vodafone Cash wallet'
              : 'حوّل عن طريق محفظة فودافون كاش',
        ),
        const SizedBox(height: 10),
        _methodTile(
          method: PaymentMethod.instaPay,
          icon: Icons.account_balance,
          color: Colors.blue,
          title: 'InstaPay',
          subtitle: isEn
              ? 'Transfer via InstaPay'
              : 'حوّل عن طريق انستاباي',
        ),
      ],
    );
  }

  Widget _methodTile({
    required PaymentMethod method,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    final selected = _selectedMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? _syanatBlue.withOpacity(0.07) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _syanatBlue : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: _syanatBlue, size: 24),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Method-specific details
  // ---------------------------------------------------------------------------

  Widget _buildMethodDetails(bool isEn) {
    switch (_selectedMethod!) {
      case PaymentMethod.cash:
        return _buildCashDetails(isEn);
      case PaymentMethod.vodafoneCash:
        return _buildVodafoneDetails(isEn);
      case PaymentMethod.instaPay:
        return _buildInstaPayDetails(isEn);
    }
  }

  Widget _buildCashDetails(bool isEn) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.green.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEn
                  ? 'Pay the technician in cash when the service is completed. No advance payment needed.'
                  : 'ادفع للفني كاش لما الخدمة تخلص. مش محتاج تدفع مقدم.',
              style: TextStyle(fontSize: 13, color: Colors.green.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVodafoneDetails(bool isEn) {
    return _buildDigitalPaymentDetails(
      isEn: isEn,
      color: Colors.red,
      icon: Icons.phone_android,
      instructionTitle:
          isEn ? 'Vodafone Cash Wallet' : 'محفظة فودافون كاش',
      instructionBody: isEn
          ? 'Transfer to this number:\n\n01XXXXXXXXX\n\nThen upload a screenshot and enter the transaction reference.'
          : 'حوّل على الرقم ده:\n\n01XXXXXXXXX\n\nوبعدين ارفع صورة الإيصال واكتب رقم العملية.',
    );
  }

  Widget _buildInstaPayDetails(bool isEn) {
    return _buildDigitalPaymentDetails(
      isEn: isEn,
      color: Colors.blue,
      icon: Icons.account_balance,
      instructionTitle: isEn ? 'InstaPay Transfer' : 'تحويل انستاباي',
      instructionBody: isEn
          ? 'Transfer to:\n\nPhone: 01XXXXXXXXX\nName: Syanat App\n\nThen upload a screenshot and enter the transaction reference.'
          : 'حوّل على:\n\nالموبايل: 01XXXXXXXXX\nالاسم: تطبيق صيانات\n\nوبعدين ارفع صورة الإيصال واكتب رقم العملية.',
    );
  }

  Widget _buildDigitalPaymentDetails({
    required bool isEn,
    required MaterialColor color,
    required IconData icon,
    required String instructionTitle,
    required String instructionBody,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Instructions card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(instructionTitle,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color.shade700,
                          fontSize: 14)),
                ],
              ),
              const SizedBox(height: 10),
              Text(instructionBody,
                  style: TextStyle(fontSize: 13, color: color.shade800)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Transaction reference field
        TextField(
          controller: _refController,
          decoration: InputDecoration(
            labelText: isEn ? 'Transaction Reference' : 'رقم العملية',
            hintText: isEn ? 'e.g. 1234567890' : 'مثال: 1234567890',
            prefixIcon: const Icon(Icons.receipt_long, color: _syanatBlue),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _syanatBlue, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Screenshot upload
        GestureDetector(
          onTap: _pickScreenshot,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _screenshot != null
                    ? Colors.green.shade400
                    : Colors.grey.shade300,
                width: _screenshot != null ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _screenshot != null
                      ? Icons.check_circle
                      : Icons.cloud_upload_outlined,
                  size: 40,
                  color: _screenshot != null
                      ? Colors.green
                      : Colors.grey.shade400,
                ),
                const SizedBox(height: 8),
                Text(
                  _screenshot != null
                      ? (isEn ? 'Screenshot selected' : 'تم اختيار الصورة')
                      : (isEn
                          ? 'Tap to upload payment screenshot'
                          : 'اضغط لرفع صورة إيصال الدفع'),
                  style: TextStyle(
                    fontSize: 13,
                    color: _screenshot != null
                        ? Colors.green.shade700
                        : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_screenshot != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _screenshot!.name,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Submit button
  // ---------------------------------------------------------------------------

  Widget _buildSubmitButton(bool isEn) {
    final enabled = _selectedMethod != null;
    return ElevatedButton(
      onPressed: enabled ? _submit : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: _syanatBlue,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade300,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Text(
        isEn ? 'Confirm Payment' : 'تأكيد الدفع',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
