import 'package:flutter/material.dart';

import 'firebase_service.dart';

const Color _syanatBlue = Color(0xFF3C21C8);

class TechnicianPaymentScreen extends StatefulWidget {
  final String jobId;
  final String technicianId;

  const TechnicianPaymentScreen({
    super.key,
    required this.jobId,
    required this.technicianId,
  });

  @override
  State<TechnicianPaymentScreen> createState() => _TechnicianPaymentScreenState();
}

class _TechnicianPaymentScreenState extends State<TechnicianPaymentScreen> {
  final TextEditingController _amountController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || !amount.isFinite || amount <= 0 || amount > 50000) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEn
                ? 'Enter a valid amount greater than 0 and not more than 50000.'
                : 'أدخل مبلغًا صحيحًا أكبر من 0 ولا يزيد عن 50000.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await FirebaseService.submitTechnicianPayment(
        widget.jobId,
        widget.technicianId,
        amount,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEn ? 'Error: $e' : 'خطأ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7FB),
        appBar: AppBar(
          backgroundColor: _syanatBlue,
          foregroundColor: Colors.white,
          title: Text(isEn ? 'Payment Entry' : 'إدخال المدفوعات'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _fieldCard(
                icon: Icons.payments_outlined,
                label: isEn ? 'Amount paid (EGP)' : 'المبلغ المدفوع (جنيه)',
                controller: _amountController,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _syanatBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isEn ? 'Submit' : 'إرسال'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldCard({
    required IconData icon,
    required String label,
    required TextEditingController controller,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0x143C21C8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _syanatBlue, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              decoration: InputDecoration(
                labelText: label,
                border: InputBorder.none,
                suffixIcon: const Icon(Icons.edit, size: 16, color: _syanatBlue),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
