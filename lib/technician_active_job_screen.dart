import 'dart:async';

import 'package:flutter/material.dart';

import 'firebase_service.dart';
import 'technician_receipt_screen.dart';

const Color _syanatBlue = Color(0xFF3C21C8);

class TechnicianActiveJobScreen extends StatefulWidget {
  final Map<String, dynamic> job;
  final String technicianId;

  const TechnicianActiveJobScreen({
    super.key,
    required this.job,
    required this.technicianId,
  });

  @override
  State<TechnicianActiveJobScreen> createState() =>
      _TechnicianActiveJobScreenState();
}

class _TechnicianActiveJobScreenState
    extends State<TechnicianActiveJobScreen> {
  bool _loading = false;

  String _t(bool isEn, String en, String ar) => isEn ? en : ar;

  Future<void> _acceptAssignment() async {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    setState(() => _loading = true);
    try {
      await FirebaseService.acceptAssignment(
        widget.job['id'] as String? ?? '',
        widget.technicianId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEn ? 'Error: $e' : 'خطأ: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markArrived() async {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    setState(() => _loading = true);
    try {
      await FirebaseService.markTechnicianArrived(
        widget.job['id'] as String? ?? '',
        widget.technicianId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEn ? 'Error: $e' : 'خطأ: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markWorkFinished() async {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    setState(() => _loading = true);
    try {
      await FirebaseService.markWorkFinished(
        widget.job['id'] as String? ?? '',
        widget.technicianId,
      );
      if (!mounted) return;
      // Navigate immediately to receipt screen after work is confirmed finished
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TechnicianReceiptScreen(
            jobId: widget.job['id'] as String? ?? '',
            technicianId: widget.technicianId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEn ? 'Error: $e' : 'خطأ: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openReceiptScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TechnicianReceiptScreen(
          jobId: widget.job['id'] as String? ?? '',
          technicianId: widget.technicianId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final status = widget.job['status'] as String? ?? '';
    final serviceCategory =
        (widget.job['serviceCategory'] as String?)?.trim();
    final serviceKey =
        (widget.job['serviceKey'] as String?)?.trim() ?? '';
    final address =
        (widget.job['locationAddress'] as String?)?.trim() ?? '';

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7FB),
        appBar: AppBar(
          backgroundColor: _syanatBlue,
          foregroundColor: Colors.white,
          title: Text(
            serviceCategory?.isNotEmpty == true
                ? serviceCategory!
                : serviceKey,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _addressCard(address, isEn),
            const SizedBox(height: 24),

            // ── Step 1: Accept Assignment ────────────────────────────
            _StepCard(
              stepNumber: 1,
              title: _t(isEn, 'Accept Assignment', 'قبول المهمة'),
              subtitle: _t(isEn,
                  'Confirm you have received and accepted this assignment.',
                  'أكّد استلامك وقبولك لهذه المهمة.'),
              status: _stepStatus(status, 'active', [
                'technician_accepted',
                'technician_arrived',
                'work_finished',
                'awaiting_customer_approval',
                'completed',
              ]),
              child: _stepStatus(status, 'active', []) == _StepStatus.active
                  ? _SlideToConfirmBar(
                      label: _t(isEn, 'Slide to accept', 'اسحب للقبول'),
                      onConfirmed:
                          _loading ? () async {} : _acceptAssignment,
                      enabled: !_loading,
                    )
                  : null,
            ),

            const SizedBox(height: 16),

            // ── Step 2: Arrived ─────────────────────────────────────
            _StepCard(
              stepNumber: 2,
              title: _t(isEn, 'Arrived at Location', 'الوصول للموقع'),
              subtitle: _t(isEn,
                  'Confirm you have arrived at the customer\'s location.',
                  'أكّد وصولك إلى موقع العميل.'),
              status: _stepStatus(status, 'technician_accepted', [
                'technician_arrived',
                'work_finished',
                'awaiting_customer_approval',
                'completed',
              ]),
              child:
                  _stepStatus(status, 'technician_accepted', []) ==
                          _StepStatus.active
                      ? _SlideToConfirmBar(
                          label:
                              _t(isEn, 'Slide to confirm arrival',
                                  'اسحب لتأكيد الوصول'),
                          onConfirmed:
                              _loading ? () async {} : _markArrived,
                          enabled: !_loading,
                        )
                      : null,
            ),

            const SizedBox(height: 16),

            // ── Step 3: Finished Work ────────────────────────────────
            _StepCard(
              stepNumber: 3,
              title: _t(isEn, 'Work Finished', 'اكتمال العمل'),
              subtitle: _t(isEn,
                  'Confirm the physical work on site is done. You will then fill the receipt.',
                  'أكّد انتهاء العمل الفعلي. ستقوم بعدها بملء الإيصال.'),
              status: _stepStatus(status, 'technician_arrived', [
                'work_finished',
                'awaiting_customer_approval',
                'completed',
              ]),
              child:
                  _stepStatus(status, 'technician_arrived', []) ==
                          _StepStatus.active
                      ? _SlideToConfirmBar(
                          label: _t(isEn, 'Slide to confirm work done',
                              'اسحب لتأكيد انتهاء العمل'),
                          onConfirmed:
                              _loading ? () async {} : _markWorkFinished,
                          enabled: !_loading,
                        )
                      : null,
            ),

            // ── Post-step states ─────────────────────────────────────
            if (status == 'work_finished') ...[
              const SizedBox(height: 24),
              _fillReceiptCard(isEn),
            ],

            if (status == 'awaiting_customer_approval') ...[
              const SizedBox(height: 24),
              _waitingForApprovalCard(isEn),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Determines the visual state of a step given the current job status.
  _StepStatus _stepStatus(
    String currentStatus,
    String activeStatus,
    List<String> doneStatuses,
  ) {
    if (currentStatus == activeStatus) return _StepStatus.active;
    if (doneStatuses.contains(currentStatus)) return _StepStatus.done;
    return _StepStatus.pending;
  }

  Widget _addressCard(String address, bool isEn) {
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0x143C21C8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.location_on, color: _syanatBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t(true, 'Service Address', 'عنوان الخدمة'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  address.isEmpty
                      ? _t(true, 'Address unavailable',
                          'العنوان غير متاح')
                      : address,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fillReceiptCard(bool isEn) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: _syanatBlue, size: 22),
              const SizedBox(width: 10),
              Text(
                isEn ? 'Fill in the Receipt' : 'أدخل بيانات الإيصال',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isEn
                ? 'Work is done. Please fill in the receipt with the services and parts used so the customer can review and approve.'
                : 'اكتمل العمل. يرجى ملء الإيصال بالخدمات وقطع الغيار المستخدمة ليتمكن العميل من المراجعة والموافقة.',
            style: TextStyle(
                fontSize: 13, color: Colors.grey.shade600, height: 1.5),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _openReceiptScreen,
              icon: const Icon(Icons.edit_note),
              label: Text(
                isEn ? 'Fill Receipt Now' : 'أدخل الإيصال الآن',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _syanatBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _waitingForApprovalCard(bool isEn) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: _syanatBlue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              isEn
                  ? 'Receipt submitted. Waiting for the customer to review and approve.'
                  : 'تم إرسال الإيصال. في انتظار مراجعة العميل وموافقته.',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step status enum
// ─────────────────────────────────────────────────────────────────────────────

enum _StepStatus { pending, active, done }

// ─────────────────────────────────────────────────────────────────────────────
// Step card widget
// ─────────────────────────────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  final int stepNumber;
  final String title;
  final String subtitle;
  final _StepStatus status;
  final Widget? child;

  const _StepCard({
    required this.stepNumber,
    required this.title,
    required this.subtitle,
    required this.status,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = status == _StepStatus.done;
    final isActive = status == _StepStatus.active;
    final isPending = status == _StepStatus.pending;

    final Color borderColor = isDone
        ? const Color(0xFF10B981)
        : isActive
            ? _syanatBlue
            : Colors.grey.shade200;

    final Color bgColor = isDone
        ? const Color(0xFFF0FDF4)
        : isActive
            ? const Color(0xFFF3F0FF)
            : Colors.white;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isDone || isActive ? 1.5 : 1),
        boxShadow: isActive
            ? [
                BoxShadow(
                    color: _syanatBlue.withOpacity(0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ]
            : [
                const BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 6,
                    offset: Offset(0, 2))
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Step number circle
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? const Color(0xFF10B981)
                      : isActive
                          ? _syanatBlue
                          : Colors.grey.shade200,
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check,
                          size: 18, color: Colors.white)
                      : Text(
                          '$stepNumber',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? Colors.white
                                : Colors.grey.shade500,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isPending
                            ? Colors.grey.shade400
                            : Colors.black87,
                      ),
                    ),
                    if (!isPending) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
              if (isDone)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    Localizations.localeOf(context).languageCode == 'en'
                        ? 'Done'
                        : 'تم',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981)),
                  ),
                ),
            ],
          ),
          if (isActive && child != null) ...[
            const SizedBox(height: 16),
            child!,
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slide-to-confirm bar (reused from original screen)
// ─────────────────────────────────────────────────────────────────────────────

class _SlideToConfirmBar extends StatefulWidget {
  final String label;
  final Future<void> Function() onConfirmed;
  final bool enabled;

  const _SlideToConfirmBar({
    required this.label,
    required this.onConfirmed,
    required this.enabled,
  });

  @override
  State<_SlideToConfirmBar> createState() => _SlideToConfirmBarState();
}

class _SlideToConfirmBarState extends State<_SlideToConfirmBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Animation<double>? _resetAnimation;
  double _progress = 0;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
        if (_resetAnimation != null) {
          setState(() => _progress = _resetAnimation!.value);
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragUpdate(
    DragUpdateDetails details,
    double maxTravel,
    bool isRtl,
  ) {
    if (!widget.enabled || _confirmed) return;
    _controller.stop();
    final delta =
        isRtl ? -(details.primaryDelta ?? 0) : (details.primaryDelta ?? 0);
    final next =
        (_progress * maxTravel + delta).clamp(0.0, maxTravel);
    final progress = maxTravel == 0 ? 0.0 : next / maxTravel;

    if (progress >= 1.0) {
      setState(() {
        _progress = 1.0;
        _confirmed = true;
      });
      unawaited(widget.onConfirmed().catchError((_) {
        if (mounted) {
          setState(() {
            _confirmed = false;
            _progress = 0.0;
          });
        }
      }));
      return;
    }
    setState(() => _progress = progress);
  }

  void _handleDragEnd() {
    if (!widget.enabled || _confirmed || _progress >= 1.0) return;
    _resetAnimation = Tween<double>(begin: _progress, end: 0)
        .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return LayoutBuilder(
      builder: (context, constraints) {
        const thumbSize = 56.0;
        final maxTravel =
            (constraints.maxWidth - thumbSize - 8).clamp(0.0, double.infinity).toDouble();
        final thumbLeft = 4 + (maxTravel * _progress);

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            final rtl = Directionality.of(context) == TextDirection.rtl;
            _handleDragUpdate(details, maxTravel, rtl);
          },
          onHorizontalDragEnd: (_) => _handleDragEnd(),
          onHorizontalDragCancel: _handleDragEnd,
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: _syanatBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Center(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 72),
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _syanatBlue,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: isRtl ? null : thumbLeft,
                  right: isRtl ? thumbLeft : null,
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 8,
                            offset: Offset(0, 3)),
                      ],
                    ),
                    child: Icon(
                      _confirmed ? Icons.check : Icons.arrow_forward,
                      color: _syanatBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
