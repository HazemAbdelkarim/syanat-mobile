import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_service.dart';

const Color _syanatBlue = Color(0xFF3C21C8);

// Length caps on free-text receipt fields. Mirrored in firestore.rules so the
// client guard and the rule stay in lockstep.
const int _kItemNameMaxLen = 80;
const int _kNotesMaxLen = 500;
const int _kPriceMaxLen = 10;

class TechnicianReceiptScreen extends StatefulWidget {
  final String jobId;
  final String technicianId;

  /// Optional snapshot of the job document so the first service row can be
  /// prefilled from `serviceCategory` / `serviceKey` without a re-fetch.
  final Map<String, dynamic>? job;

  const TechnicianReceiptScreen({
    super.key,
    required this.jobId,
    required this.technicianId,
    this.job,
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

  // Indices (in _services) whose price is invalid on the last submit attempt.
  // Cleared on successful validation; drives the red border on the row.
  Set<int> _invalidServicePriceIndices = {};

  @override
  void initState() {
    super.initState();
    // Seed the first service row from the job's requested category/key so the
    // tech doesn't have to retype it.
    final seed = _LineItem();
    final job = widget.job;
    if (job != null) {
      final category = (job['serviceCategory'] as String?)?.trim() ?? '';
      final key = (job['serviceKey'] as String?)?.trim() ?? '';
      final subservice = (job['subservice'] as String?)?.trim() ?? '';
      final label = [category, subservice]
          .where((s) => s.isNotEmpty)
          .join(' — ');
      seed.titleCtrl.text = label.isNotEmpty ? label : key;
    }
    _services.add(seed);
  }

  Future<void> _openAddPartSheet() async {
    final isEn = _isEn;
    final picked = await showModalBottomSheet<_PartPick>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: ReceiptAddPartSheet(isEn: isEn),
        );
      },
    );
    if (!mounted || picked == null) return;
    final li = _LineItem();
    li.titleCtrl.text = picked.name;
    if (picked.price > 0) {
      li.priceCtrl.text = picked.price.toStringAsFixed(
          picked.price == picked.price.roundToDouble() ? 0 : 2);
    }
    setState(() => _parts.add(li));
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
    final filledServiceEntries = _services
        .asMap()
        .entries
        .where((e) => e.value.titleCtrl.text.trim().isNotEmpty)
        .toList();
    if (filledServiceEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t(
            'Please add at least one service.', 'أضف خدمة واحدة على الأقل.')),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // Each filled service must have a positive price. Highlight offending rows.
    final invalid = filledServiceEntries
        .where((e) => _parsePrice(e.value.priceCtrl.text) <= 0)
        .map((e) => e.key)
        .toSet();
    if (invalid.isNotEmpty) {
      setState(() => _invalidServicePriceIndices = invalid);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t(
            'Please enter a price for every service.',
            'يرجى إدخال سعر لكل خدمة.')),
        backgroundColor: Colors.red,
      ));
      return;
    }
    if (_invalidServicePriceIndices.isNotEmpty) {
      setState(() => _invalidServicePriceIndices = {});
    }

    setState(() => _submitting = true);
    try {
      final services = filledServiceEntries
          .map((e) => {
                'title': e.value.titleCtrl.text.trim(),
                'price': _parsePrice(e.value.priceCtrl.text),
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
        content: Text(_t(
                'Failed to submit receipt: ', 'فشل إرسال الإيصال: ') +
            e.toString()),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 6),
      ));
    } finally {
      if (mounted) setState(() => _submitting = false);
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
                                _invalidServicePriceIndices = {};
                              })
                          : null,
                      key: ValueKey('svc_$i'),
                      hasError: _invalidServicePriceIndices.contains(i),
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
                    onTap: _openAddPartSheet,
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
                    maxLength: _kNotesMaxLen,
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
    bool hasError = false,
  }) {
    final priceBorderColor =
        hasError ? Colors.red.shade400 : Colors.grey.shade200;
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
              maxLength: _kItemNameMaxLen,
              decoration: InputDecoration(
                hintText: titleHint,
                hintStyle:
                    TextStyle(fontSize: 13, color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                counterText: '',
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
              maxLength: _kPriceMaxLen,
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
                counterText: '',
                suffixText: 'EGP',
                suffixStyle: TextStyle(
                    fontSize: 11, color: Colors.grey.shade500),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: priceBorderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: priceBorderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: hasError ? Colors.red.shade400 : _syanatBlue,
                  ),
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

class _PartPick {
  final String name;
  final double price;
  const _PartPick(this.name, this.price);
}

/// Bottom sheet for adding a custom part to the receipt.
///
/// The inventory picker was removed in the April 2026 technician-inventory
/// retirement (release 006). Parts are now free-form entries only.
///
/// Public (instead of underscored) so widget tests can pump it without
/// needing Firebase initialization — the sheet has no external dependencies.
@visibleForTesting
class ReceiptAddPartSheet extends StatefulWidget {
  final bool isEn;

  const ReceiptAddPartSheet({super.key, required this.isEn});

  @override
  State<ReceiptAddPartSheet> createState() => _ReceiptAddPartSheetState();
}

class _ReceiptAddPartSheetState extends State<ReceiptAddPartSheet> {
  final TextEditingController _customName = TextEditingController();
  final TextEditingController _customPrice = TextEditingController();

  @override
  void dispose() {
    _customName.dispose();
    _customPrice.dispose();
    super.dispose();
  }

  String _t(String en, String ar) => widget.isEn ? en : ar;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.isEn ? TextDirection.ltr : TextDirection.rtl,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.add_box_outlined, color: _syanatBlue),
                  const SizedBox(width: 8),
                  Text(
                    _t('Add Custom Item', 'إضافة عنصر مخصص'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _customName,
                maxLength: _kItemNameMaxLen,
                decoration: InputDecoration(
                  labelText: _t('Item name', 'اسم العنصر'),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  counterText: '',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customPrice,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                maxLength: _kPriceMaxLen,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  labelText: _t('Price (EGP)', 'السعر (ج.م)'),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  counterText: '',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _syanatBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final name = _customName.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(_t('Enter an item name.',
                            'أدخل اسم العنصر.')),
                      ));
                      return;
                    }
                    final price =
                        double.tryParse(_customPrice.text.trim()) ?? 0.0;
                    Navigator.pop(context, _PartPick(name, price));
                  },
                  child: Text(
                    _t('Add to Receipt', 'إضافة إلى الإيصال'),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
