import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_service.dart';

const Color _syanatBlue = Color(0xFF3C21C8);

class TechnicianReceiptScreen extends StatefulWidget {
  final String jobId;
  final String technicianId;

  const TechnicianReceiptScreen({
    super.key,
    required this.jobId,
    required this.technicianId,
  });

  @override
  State<TechnicianReceiptScreen> createState() =>
      _TechnicianReceiptScreenState();
}

class _TechnicianReceiptScreenState extends State<TechnicianReceiptScreen> {
  // Each service item: {titleCtrl, priceCtrl}
  final List<_LineItem> _services = [];
  final List<_LineItem> _parts = [];
  final TextEditingController _notesCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Start with one empty service row
    _services.add(_LineItem());
  }

  @override
  void dispose() {
    for (final item in _services) {
      item.dispose();
    }
    for (final item in _parts) {
      item.dispose();
    }
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _isEn => Localizations.localeOf(context).languageCode == 'en';

  String _t(String en, String ar) => _isEn ? en : ar;

  double _parsePrice(String text) {
    final v = double.tryParse(text.trim()) ?? 0.0;
    return v < 0 ? 0.0 : v;
  }

  double get _servicesSubtotal =>
      _services.fold(0.0, (s, item) => s + _parsePrice(item.priceCtrl.text));

  double get _partsSubtotal =>
      _parts.fold(0.0, (s, item) => s + _parsePrice(item.priceCtrl.text));

  double get _grandTotal => _servicesSubtotal + _partsSubtotal;

  Future<void> _submit() async {
    // Validate: at least one service with a title
    final filledServices =
        _services.where((i) => i.titleCtrl.text.trim().isNotEmpty).toList();
    if (filledServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t(
            'Please add at least one service.', 'أضف خدمة واحدة على الأقل.')),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _submitting = true);
    try {
      final services = filledServices
          .map((i) => {
                'title': i.titleCtrl.text.trim(),
                'price': _parsePrice(i.priceCtrl.text),
              })
          .toList();

      final filledParts =
          _parts.where((i) => i.titleCtrl.text.trim().isNotEmpty).toList();
      final parts = filledParts
          .map((i) => {
                'name': i.titleCtrl.text.trim(),
                'price': _parsePrice(i.priceCtrl.text),
              })
          .toList();

      await FirebaseService.submitReceipt(
        jobId: widget.jobId,
        technicianId: widget.technicianId,
        services: services,
        parts: parts,
        servicesSubtotal: _servicesSubtotal,
        partsSubtotal: _partsSubtotal,
        grandTotal: _grandTotal,
        notes: _notesCtrl.text.trim(),
      );

      if (!mounted) return;
      // Pop back to home — the stream will show "awaiting approval" state
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t(
            'Receipt submitted. Awaiting customer approval.',
            'تم إرسال الإيصال. في انتظار موافقة العميل.')),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      debugPrint('Receipt submit error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t('Failed to submit receipt. Please try again.', 'فشل إرسال الإيصال. يرجى المحاولة مرة أخرى.')),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = _isEn;
    return PopScope(
      canPop: false,
      child: Directionality(
        textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFFF7F7FB),
          appBar: AppBar(
            backgroundColor: _syanatBlue,
            foregroundColor: Colors.white,
            automaticallyImplyLeading: false,
            title: Text(_t('Submit Receipt', 'تقديم الإيصال')),
          ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Services section ──────────────────────────────────
                  _sectionHeader(
                    icon: Icons.build_circle_outlined,
                    title: _t('Services / Work Performed',
                        'الخدمات / الأعمال المنجزة'),
                  ),
                  const SizedBox(height: 10),
                  ..._services.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    return _lineItemRow(
                      item: item,
                      titleHint: _t('e.g. Flush tank repair',
                          'مثال: إصلاح خزان السيفون'),
                      onRemove: _services.length > 1
                          ? () => setState(() {
                                _services.removeAt(i).dispose();
                              })
                          : null,
                      key: ValueKey('svc_$i'),
                    );
                  }),
                  _addRowButton(
                    label: _t('+ Add Service', '+ إضافة خدمة'),
                    onTap: () => setState(() => _services.add(_LineItem())),
                  ),

                  const SizedBox(height: 24),

                  // ── Parts section ─────────────────────────────────────
                  _sectionHeader(
                    icon: Icons.hardware_outlined,
                    title: _t('Parts / Materials Used',
                        'قطع الغيار / المواد المستخدمة'),
                    subtitle: _t('Optional', 'اختياري'),
                  ),
                  const SizedBox(height: 10),
                  if (_parts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _t('No parts used — tap below to add.',
                            'لا قطع مستخدمة — اضغط أدناه للإضافة.'),
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade500),
                      ),
                    ),
                  ..._parts.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    return _lineItemRow(
                      item: item,
                      titleHint:
                          _t('e.g. Flush valve', 'مثال: صمام السيفون'),
                      onRemove: () => setState(() {
                        _parts.removeAt(i).dispose();
                      }),
                      key: ValueKey('part_$i'),
                    );
                  }),
                  _addRowButton(
                    label: _t('+ Add Part', '+ إضافة قطعة'),
                    onTap: () => setState(() => _parts.add(_LineItem())),
                  ),

                  const SizedBox(height: 24),

                  // ── Totals section ────────────────────────────────────
                  _totalsCard(isEn),

                  const SizedBox(height: 24),

                  // ── Notes section ─────────────────────────────────────
                  _sectionHeader(
                    icon: Icons.notes_outlined,
                    title: _t('Notes', 'ملاحظات'),
                    subtitle: _t('Optional', 'اختياري'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText:
                          _t('Any additional notes...', 'أي ملاحظات إضافية...'),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),

            // ── Submit bar ────────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x0F000000),
                      blurRadius: 10,
                      offset: Offset(0, -3))
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _t('Total', 'الإجمالي'),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_grandTotal.toStringAsFixed(0)} EGP',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _syanatBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _syanatBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(
                                _t('Submit Receipt to Customer',
                                    'إرسال الإيصال للعميل'),
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _syanatBlue),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ),
        ],
      ],
    );
  }

  Widget _lineItemRow({
    required _LineItem item,
    required String titleHint,
    required VoidCallback? onRemove,
    required Key key,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: TextField(
              controller: item.titleCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: titleHint,
                hintStyle:
                    TextStyle(fontSize: 13, color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: item.priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d+\.?\d{0,2}')),
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle:
                    TextStyle(fontSize: 13, color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                suffixText: 'EGP',
                suffixStyle: TextStyle(
                    fontSize: 11, color: Colors.grey.shade500),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 6),
            IconButton(
              onPressed: onRemove,
              icon: Icon(Icons.remove_circle_outline,
                  color: Colors.red.shade300, size: 22),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ] else
            const SizedBox(width: 28),
        ],
      ),
    );
  }

  Widget _addRowButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: _syanatBlue.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: _syanatBlue.withOpacity(0.2), style: BorderStyle.solid),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
                color: _syanatBlue,
                fontWeight: FontWeight.w600,
                fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget _totalsCard(bool isEn) {
    final svcSub = _servicesSubtotal;
    final partsSub = _partsSubtotal;
    final grand = _grandTotal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          _totalRow(isEn ? 'Services Subtotal' : 'إجمالي الخدمات',
              svcSub, false),
          if (_parts.isNotEmpty)
            _totalRow(isEn ? 'Parts Subtotal' : 'إجمالي القطع', partsSub,
                false),
          const Divider(height: 20),
          _totalRow(isEn ? 'Grand Total' : 'الإجمالي الكلي', grand, true),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double amount, bool bold) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: bold ? 16 : 14,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                  color: bold ? Colors.black87 : Colors.black54)),
          Text(
            '${amount.toStringAsFixed(0)} EGP',
            style: TextStyle(
              fontSize: bold ? 18 : 14,
              fontWeight: FontWeight.bold,
              color: bold ? _syanatBlue : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

/// Holds a pair of controllers for one line item (title + price).
class _LineItem {
  final TextEditingController titleCtrl = TextEditingController();
  final TextEditingController priceCtrl = TextEditingController();

  void dispose() {
    titleCtrl.dispose();
    priceCtrl.dispose();
  }
}
