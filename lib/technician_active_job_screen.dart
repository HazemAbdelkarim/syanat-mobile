import 'dart:async';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
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
  bool _actionInProgress = false;

  String get _status => widget.job['status'] as String? ?? '';
  String get _jobId => widget.job['id'] as String? ?? '';

  String _t(bool isEn, String en, String ar) => isEn ? en : ar;

  /// Returns a user-facing message for a FirebaseException.  If the error is
  /// permission-denied it nudges the user to deploy Firestore rules; otherwise
  /// it falls back to the provided generic message.
  String _permissionMsg(bool isEn, FirebaseException e,
      {required String en, required String ar}) {
    if (e.code == 'permission-denied') {
      return _t(isEn,
          'Permission denied — run: firebase deploy --only firestore:rules',
          'تم رفض الإذن — نفّذ: firebase deploy --only firestore:rules');
    }
    return _t(isEn, en, ar);
  }

  // ── Action handlers ──────────────────────────────────────────────────────
  // All handlers rethrow after showing feedback so the slider can reset its
  // internal _confirmed state via its catchError callback.

  Future<void> _acceptAssignment() async {
    if (_actionInProgress) return;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    setState(() => _actionInProgress = true);
    try {
      if (_jobId.isEmpty) throw Exception('Missing job ID');
      await FirebaseService.acceptAssignment(_jobId, widget.technicianId);
    } on FirebaseException catch (e) {
      debugPrint('Accept assignment Firebase error: ${e.code} – ${e.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_permissionMsg(isEn, e,
            en: 'Could not accept job. Please try again.',
            ar: 'تعذر قبول الطلب. يرجى المحاولة مرة أخرى.')),
      ));
      rethrow;
    } catch (e) {
      debugPrint('Accept assignment error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(isEn, 'Could not accept job. Please try again.',
              'تعذر قبول الطلب. يرجى المحاولة مرة أخرى.')),
        ),
      );
      rethrow;
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _markOnTheWay() async {
    if (_actionInProgress) return;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    setState(() => _actionInProgress = true);
    try {
      if (_jobId.isEmpty) throw Exception('Missing job ID');
      await FirebaseService.markOnTheWay(_jobId, widget.technicianId);
    } on FirebaseException catch (e) {
      debugPrint('Mark on-the-way Firebase error: ${e.code} – ${e.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_permissionMsg(isEn, e,
            en: 'Could not confirm you are on the way. Please try again.',
            ar: 'تعذر تأكيد أنك في الطريق. يرجى المحاولة مرة أخرى.')),
      ));
      rethrow;
    } catch (e) {
      debugPrint('Mark on-the-way error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(isEn,
              'Could not confirm you are on the way. Please try again.',
              'تعذر تأكيد أنك في الطريق. يرجى المحاولة مرة أخرى.')),
        ),
      );
      rethrow;
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _markArrived() async {
    if (_actionInProgress) return;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    setState(() => _actionInProgress = true);
    try {
      if (_jobId.isEmpty) throw Exception('Missing job ID');
      await FirebaseService.markTechnicianArrived(
          _jobId, widget.technicianId);
    } on FirebaseException catch (e) {
      debugPrint('Mark arrived Firebase error: ${e.code} – ${e.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_permissionMsg(isEn, e,
            en: 'Could not confirm arrival. Please try again.',
            ar: 'تعذر تأكيد الوصول. يرجى المحاولة مرة أخرى.')),
      ));
      rethrow;
    } catch (e) {
      debugPrint('Mark arrived error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(isEn,
              'Could not confirm arrival. Please try again.',
              'تعذر تأكيد الوصول. يرجى المحاولة مرة أخرى.')),
        ),
      );
      rethrow;
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _markWorkFinished() async {
    if (_actionInProgress) return;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    setState(() => _actionInProgress = true);
    try {
      if (_jobId.isEmpty) throw Exception('Missing job ID');
      await FirebaseService.markWorkFinished(_jobId, widget.technicianId);
      if (!mounted) return;
      // pushReplacement (not push): once the slider confirms, the tech is
      // committed to filling the receipt — we don't want them swiping back
      // into a slider that would re-fire the (now-stale) transition.
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TechnicianReceiptScreen(
            jobId: _jobId,
            technicianId: widget.technicianId,
            job: Map<String, dynamic>.from(widget.job),
          ),
        ),
      );
    } on FirebaseException catch (e) {
      debugPrint('Mark finished Firebase error: ${e.code} – ${e.message}');
      if (!mounted) return;
      final base = _permissionMsg(isEn, e,
          en: 'Could not complete work.',
          ar: 'تعذر إتمام العمل.');
      final detail = (e.message ?? '').trim().isEmpty ? e.code : e.message!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$base  [$detail]'),
        duration: const Duration(seconds: 6),
      ));
      rethrow;
    } catch (e) {
      debugPrint('Mark work finished error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t(isEn,
                'Could not complete work. ',
                'تعذر إتمام العمل. ') +
            e.toString()),
        duration: const Duration(seconds: 6),
      ));
      rethrow;
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _cancelJob() async {
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_t(isEn, 'Cancel Order?', 'إلغاء الطلب؟')),
        content: Text(_t(
          isEn,
          'Are you sure you want to cancel this assignment? This cannot be undone.',
          'هل أنت متأكد من إلغاء هذه المهمة؟ لا يمكن التراجع عن هذا.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t(isEn, 'No', 'لا')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(_t(isEn, 'Yes, Cancel', 'نعم، إلغاء')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _actionInProgress = true);
    try {
      if (_jobId.isEmpty) throw Exception('Missing job ID');
      if (_status != 'active') {
        throw Exception('Cannot cancel after acceptance');
      }
      await FirebaseService.technicianCancelJob(_jobId, widget.technicianId);
      // After cancel, the stream will clear the active job and return to home.
    } on FirebaseException catch (e) {
      debugPrint('Technician cancel Firebase error: ${e.code} – ${e.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_permissionMsg(isEn, e,
            en: 'Could not cancel order. Please try again.',
            ar: 'تعذر إلغاء الطلب. يرجى المحاولة مرة أخرى.')),
      ));
    } catch (e) {
      debugPrint('Technician cancel error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(isEn,
              'Could not cancel order. Please try again.',
              'تعذر إلغاء الطلب. يرجى المحاولة مرة أخرى.')),
        ),
      );
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  void _openReceiptScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TechnicianReceiptScreen(
          jobId: _jobId,
          technicianId: widget.technicianId,
          job: Map<String, dynamic>.from(widget.job),
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final status = _status;
    final serviceCategory =
        (widget.job['serviceCategory'] as String?)?.trim();
    final serviceKey =
        (widget.job['serviceKey'] as String?)?.trim() ?? '';
    final address =
        (widget.job['locationAddress'] as String?)?.trim() ?? '';

    const lockedStatuses = {
      'active',
      'technician_accepted',
      'on_the_way',
      'technician_arrived',
      'work_finished',
    };
    final isLocked = lockedStatuses.contains(status);

    return PopScope(
      canPop: !isLocked,
      child: Directionality(
        textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFFF7F7FB),
          appBar: AppBar(
            backgroundColor: _syanatBlue,
            foregroundColor: Colors.white,
            automaticallyImplyLeading: !isLocked,
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
              const SizedBox(height: 20),

              // ── Cancel button (before acceptance only) ──────────────
              if (status == 'active') ...[
                _cancelButton(isEn),
                const SizedBox(height: 20),
              ],

              // ── Progress steps ──────────────────────────────────────
              _buildProgressSteps(status, isEn),

              // ── Post-step states ────────────────────────────────────
              if (status == 'work_finished') ...[
                const SizedBox(height: 24),
                _fillReceiptCard(isEn),
              ],

              if (status == 'awaiting_customer_approval') ...[
                const SizedBox(height: 24),
                _waitingForApprovalCard(isEn),
              ],

              if (status == 'awaiting_payment') ...[
                const SizedBox(height: 24),
                _awaitingPaymentCard(isEn),
              ],

              if (status == 'receipt_disputed') ...[
                const SizedBox(height: 24),
                _receiptDisputedCard(isEn),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sequential progress steps ────────────────────────────────────────────

  Widget _buildProgressSteps(String status, bool isEn) {
    // Define the step order and their trigger statuses. Any `done` status
    // indicates this step is behind the current one in the lifecycle — the
    // compact CompletedStepRow renders instead of the full slider card.
    final steps = [
      _StepDef(
        activeStatus: 'active',
        doneStatuses: const [
          'technician_accepted',
          'on_the_way',
          'technician_arrived',
          'work_finished',
          'awaiting_customer_approval',
          'awaiting_payment',
          'awaiting_payment_verification',
          'receipt_disputed',
          'completed',
        ],
        title: _t(isEn, 'Accept Assignment', 'قبول المهمة'),
        subtitle: _t(isEn,
            'Confirm you have received and accepted this assignment.',
            'أكّد استلامك وقبولك لهذه المهمة.'),
        sliderLabel: _t(isEn, 'Slide to accept', 'اسحب للقبول'),
        onConfirmed: _acceptAssignment,
      ),
      _StepDef(
        // Release-006: new step between accept and arrive.
        activeStatus: 'technician_accepted',
        doneStatuses: const [
          'on_the_way',
          'technician_arrived',
          'work_finished',
          'awaiting_customer_approval',
          'awaiting_payment',
          'awaiting_payment_verification',
          'receipt_disputed',
          'completed',
        ],
        title: _t(isEn, 'On the Way', 'في الطريق'),
        subtitle: _t(isEn,
            'Confirm you have started heading to the customer\'s location.',
            'أكّد أنك بدأت التوجه إلى موقع العميل.'),
        sliderLabel:
            _t(isEn, 'Slide to confirm on the way', 'اسحب لتأكيد الانطلاق'),
        onConfirmed: _markOnTheWay,
      ),
      _StepDef(
        // Release-006: source state moved from technician_accepted to on_the_way.
        activeStatus: 'on_the_way',
        doneStatuses: const [
          'technician_arrived',
          'work_finished',
          'awaiting_customer_approval',
          'awaiting_payment',
          'awaiting_payment_verification',
          'receipt_disputed',
          'completed',
        ],
        title: _t(isEn, 'Arrived at Location', 'الوصول للموقع'),
        subtitle: _t(isEn,
            'Confirm you have arrived at the customer\'s location.',
            'أكّد وصولك إلى موقع العميل.'),
        sliderLabel:
            _t(isEn, 'Slide to confirm arrival', 'اسحب لتأكيد الوصول'),
        onConfirmed: _markArrived,
      ),
      _StepDef(
        activeStatus: 'technician_arrived',
        doneStatuses: const [
          'work_finished',
          'awaiting_customer_approval',
          'awaiting_payment',
          'awaiting_payment_verification',
          'receipt_disputed',
          'completed',
        ],
        title: _t(isEn, 'Work Finished', 'اكتمال العمل'),
        subtitle: _t(isEn,
            'Confirm the physical work on site is done. You will then fill the receipt.',
            'أكّد انتهاء العمل الفعلي. ستقوم بعدها بملء الإيصال.'),
        sliderLabel: _t(
            isEn, 'Slide to confirm work done', 'اسحب لتأكيد انتهاء العمل'),
        onConfirmed: _markWorkFinished,
      ),
    ];

    final children = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      final stepState = _resolveState(status, step);

      if (stepState == _StepState.pending) {
        // Future steps are hidden entirely.
        break;
      }

      if (i > 0) children.add(const SizedBox(height: 12));

      if (stepState == _StepState.done) {
        children.add(_CompletedStepRow(
          stepNumber: i + 1,
          title: step.title,
          isEn: Localizations.localeOf(context).languageCode == 'en',
        ));
      } else {
        // Active step — full card with slider.
        children.add(_ActiveStepCard(
          stepNumber: i + 1,
          title: step.title,
          subtitle: step.subtitle,
          sliderLabel: step.sliderLabel,
          onConfirmed: _actionInProgress ? null : step.onConfirmed,
          enabled: !_actionInProgress,
          loading: _actionInProgress,
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  _StepState _resolveState(String status, _StepDef step) {
    if (status == step.activeStatus) return _StepState.active;
    if (step.doneStatuses.contains(status)) return _StepState.done;
    return _StepState.pending;
  }

  // ── Widget builders ──────────────────────────────────────────────────────

  Widget _cancelButton(bool isEn) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _actionInProgress ? null : _cancelJob,
        icon: const Icon(Icons.close, size: 18),
        label: Text(
          _t(isEn, 'Cancel Order', 'إلغاء الطلب'),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red.shade600,
          side: BorderSide(color: Colors.red.shade300),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
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
                  _t(isEn, 'Service Address', 'عنوان الخدمة'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  address.isEmpty
                      ? _t(isEn, 'Address unavailable', 'العنوان غير متاح')
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

  Widget _receiptDisputedCard(bool isEn) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade200),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 8,
              offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.gavel, color: Colors.red.shade400, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEn ? 'Receipt Disputed' : 'تم الاعتراض على الإيصال',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700),
                ),
                const SizedBox(height: 4),
                Text(
                  isEn
                      ? 'The customer has disputed the receipt. Admin is reviewing the case.'
                      : 'اعترض العميل على الإيصال. الإدارة تراجع الحالة.',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.4),
                ),
              ],
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

  Widget _awaitingPaymentCard(bool isEn) {
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
          Icon(Icons.payments_outlined,
              color: _syanatBlue, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEn ? 'Awaiting Customer Payment' : 'بانتظار دفع العميل',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  isEn
                      ? 'The customer approved the receipt. They will pay you in person; you will then confirm with a photo proof.'
                      : 'وافق العميل على الإيصال. سيدفع لك شخصياً، ثم تؤكد الاستلام بصورة إثبات.',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal models
// ─────────────────────────────────────────────────────────────────────────────

enum _StepState { pending, active, done }

class _StepDef {
  final String activeStatus;
  final List<String> doneStatuses;
  final String title;
  final String subtitle;
  final String sliderLabel;
  final Future<void> Function() onConfirmed;

  const _StepDef({
    required this.activeStatus,
    required this.doneStatuses,
    required this.title,
    required this.subtitle,
    required this.sliderLabel,
    required this.onConfirmed,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Completed step — compact row
// ─────────────────────────────────────────────────────────────────────────────

class _CompletedStepRow extends StatelessWidget {
  final int stepNumber;
  final String title;
  final bool isEn;

  const _CompletedStepRow({
    required this.stepNumber,
    required this.title,
    required this.isEn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF10B981),
            ),
            child: const Center(
              child: Icon(Icons.check, size: 16, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF065F46),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isEn ? 'Done' : 'تم',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF10B981),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Active step card — full card with slider
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveStepCard extends StatelessWidget {
  final int stepNumber;
  final String title;
  final String subtitle;
  final String sliderLabel;
  final Future<void> Function()? onConfirmed;
  final bool enabled;
  final bool loading;

  const _ActiveStepCard({
    required this.stepNumber,
    required this.title,
    required this.subtitle,
    required this.sliderLabel,
    required this.onConfirmed,
    required this.enabled,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _syanatBlue.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _syanatBlue.withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _syanatBlue,
                ),
                child: Center(
                  child: Text(
                    '$stepNumber',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.0, color: _syanatBlue),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Text(
              subtitle,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade600, height: 1.5),
            ),
          ),
          const SizedBox(height: 18),
          _SlideToConfirmBar(
            label: sliderLabel,
            onConfirmed: onConfirmed ?? () async {},
            enabled: enabled && onConfirmed != null,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slide-to-confirm bar
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
      unawaited(widget.onConfirmed().then((_) {
        // Success path: the parent usually rebuilds with a new status (e.g.
        // status='work_finished') so this slider is replaced by a
        // CompletedStepRow. If that stream snapshot is delayed, reset locally
        // so the thumb never spins indefinitely after a successful write.
        if (mounted) {
          setState(() {
            _confirmed = false;
            _progress = 0.0;
          });
        }
      }).catchError((Object err, StackTrace st) {
        // Log so failures aren't silently swallowed — a silent catch was the
        // primary cause of the "spins forever with no hint" symptom.
        debugPrint('SlideToConfirm onConfirmed error: $err\n$st');
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
    _resetAnimation = Tween<double>(begin: _progress, end: 0).animate(
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
        final maxTravel = (constraints.maxWidth - thumbSize - 8)
            .clamp(0.0, double.infinity)
            .toDouble();
        final thumbOffset = 4 + (maxTravel * _progress);

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
              color: _syanatBlue.withOpacity(widget.enabled ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 72),
                    child: AnimatedOpacity(
                      opacity: _confirmed ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        widget.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _syanatBlue
                              .withOpacity(widget.enabled ? 1.0 : 0.4),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: isRtl ? null : thumbOffset,
                  right: isRtl ? thumbOffset : null,
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
                    child: _confirmed
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: Center(
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: _syanatBlue),
                            ),
                          )
                        : Icon(
                            Icons.arrow_forward,
                            color: _syanatBlue
                                .withOpacity(widget.enabled ? 1.0 : 0.4),
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
