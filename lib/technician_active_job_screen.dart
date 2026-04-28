import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'firebase_service.dart';
import 'job_status.dart';
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

  // The screen used to read `widget.job['status']` directly. That map is a
  // snapshot captured when the home screen pushed this route — it never
  // refreshes, so a successful slide-to-confirm wrote the new status to
  // Firestore but the local UI kept showing the old step until the user
  // popped and re-entered the screen. We now subscribe to the job doc and
  // drive the UI off `_currentJob` so the next step appears the instant
  // the server-side write lands.
  late Map<String, dynamic> _currentJob;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _jobSub;

  String get _status => (_currentJob['status'] as String?) ?? '';
  String get _jobId => (_currentJob['id'] as String?) ?? '';

  @override
  void initState() {
    super.initState();
    _currentJob = Map<String, dynamic>.from(widget.job);
    _subscribeJob();
  }

  @override
  void dispose() {
    _jobSub?.cancel();
    super.dispose();
  }

  void _subscribeJob() {
    final id = (_currentJob['id'] as String?) ?? '';
    if (id.isEmpty) return;
    _jobSub?.cancel();
    _jobSub = FirebaseService.firestore
        .collection('jobs')
        .doc(id)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;
      final data = snap.data();
      if (data == null) return;
      if (!mounted) return;
      setState(() {
        _currentJob = <String, dynamic>{
          ...data,
          'id': snap.id,
        };
      });
    }, onError: (Object e, StackTrace st) {
      if (kDebugMode) {
        debugPrint('[TechnicianActiveJob] job stream error: $e\n$st');
      }
    });
  }

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
            job: Map<String, dynamic>.from(_currentJob),
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
          job: Map<String, dynamic>.from(_currentJob),
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
        (_currentJob['serviceCategory'] as String?)?.trim();
    final serviceKey =
        (_currentJob['serviceKey'] as String?)?.trim() ?? '';
    final address =
        (_currentJob['locationAddress'] as String?)?.trim() ?? '';

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

    // Resolve each step's state once. Active index is the first non-done
    // step; if every step is done we fall through and the post-step cards
    // (fill receipt etc) take over. The horizontal stepper card is always
    // rendered so the technician sees the full progression at a glance —
    // matches design-system/JobAcceptance.jsx > AcceptanceVariantA.
    final stepStates =
        steps.map((s) => _resolveState(status, s)).toList(growable: false);
    var activeIndex = stepStates.indexOf(_StepState.active);
    if (activeIndex == -1) {
      // All four progress steps are done; collapse into "all complete" view.
      activeIndex = steps.length;
    }
    final pastTitles = <String>[
      for (var i = 0; i < activeIndex && i < steps.length; i++) steps[i].title,
    ];

    final children = <Widget>[
      _HorizontalStepper(
        steps: steps.map((s) => s.title).toList(),
        activeIndex: activeIndex,
      ),
      const SizedBox(height: 14),
    ];

    if (pastTitles.length >= 3) {
      // Avatar-stack collapsed past steps row.
      children.add(_CollapsedPastStepsRow(titles: pastTitles, isEn: isEn));
      children.add(const SizedBox(height: 12));
    } else {
      for (var i = 0; i < pastTitles.length; i++) {
        if (i > 0) children.add(const SizedBox(height: 8));
        children.add(_CompletedStepRow(
          stepNumber: i + 1,
          title: pastTitles[i],
          isEn: isEn,
        ));
      }
      if (pastTitles.isNotEmpty) {
        children.add(const SizedBox(height: 12));
      }
    }

    if (activeIndex < steps.length) {
      final step = steps[activeIndex];

      // Time-gate the "On the way" step: a tech may not start a trip more
      // than 60 minutes before the job's scheduledTime. Mirrors the gate
      // enforced in firestore.rules. canStartTrip returns true for null
      // scheduledTime (urgent jobs) and for past scheduledTime.
      final dynamic scheduledRaw = _currentJob['scheduledTime'];
      final DateTime? scheduledAt =
          scheduledRaw is Timestamp ? scheduledRaw.toDate() : null;
      final bool tripBlocked = step.activeStatus == 'technician_accepted' &&
          !canStartTrip(scheduledAt, DateTime.now());

      final String renderedSubtitle = tripBlocked
          ? _t(
              isEn,
              'Available 60 minutes before scheduled time.',
              'متاح قبل 60 دقيقة من الموعد.',
            )
          : step.subtitle;
      final bool sliderEnabled = !_actionInProgress && !tripBlocked;

      children.add(_ActiveStepCard(
        stepNumber: activeIndex + 1,
        totalSteps: steps.length,
        title: step.title,
        subtitle: renderedSubtitle,
        sliderLabel: step.sliderLabel,
        onConfirmed: sliderEnabled ? step.onConfirmed : null,
        enabled: sliderEnabled,
        loading: _actionInProgress,
        isEn: isEn,
      ));
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
    // Mirrors design-system/JobAcceptance.jsx > AddressCard. The new bit is
    // the trailing "Maps" button — kept as a no-op placeholder for now since
    // there is no Maps integration in the codebase. Wire it once Storage /
    // url_launcher land. (TODO(BLAZE) is not relevant here: this is purely
    // a client-side intent.)
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0x1A3C21C8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.location_on, color: _syanatBlue, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t(isEn, 'Service Address', 'عنوان الخدمة'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  address.isEmpty
                      ? _t(isEn, 'Address unavailable', 'العنوان غير متاح')
                      : address,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: _syanatBlue,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.directions, size: 14),
              label: Text(
                _t(isEn, 'Maps', 'الخريطة'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: address.isEmpty ? null : () {},
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
  final int totalSteps;
  final String title;
  final String subtitle;
  final String sliderLabel;
  final Future<void> Function()? onConfirmed;
  final bool enabled;
  final bool loading;
  final bool isEn;

  const _ActiveStepCard({
    required this.stepNumber,
    required this.totalSteps,
    required this.title,
    required this.subtitle,
    required this.sliderLabel,
    required this.onConfirmed,
    required this.enabled,
    required this.loading,
    required this.isEn,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _syanatBlue, width: 2),
        boxShadow: [
          BoxShadow(
            color: _syanatBlue.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _syanatBlue,
                ),
                child: Center(
                  child: Text(
                    '$stepNumber',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.0, color: _syanatBlue),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x1A3C21C8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isEn
                        ? 'STEP $stepNumber OF $totalSteps'
                        : 'الخطوة $stepNumber من $totalSteps',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _syanatBlue,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(
                fontSize: 14, color: Colors.grey.shade700, height: 1.5),
          ),
          const SizedBox(height: 16),
          _SlideToConfirmBar(
            label: sliderLabel,
            onConfirmed: onConfirmed ?? () async {},
            enabled: enabled && onConfirmed != null,
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              isEn
                  ? 'Slide thumb past the marker to confirm'
                  : 'اسحب الزر بعد العلامة للتأكيد',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Horizontal numbered stepper — matches design-system/JobAcceptance.jsx >
// HorizontalStepper. Past nodes turn green with a check, the active node
// gets a halo, future nodes are grey-bordered.
// ─────────────────────────────────────────────────────────────────────────────

class _HorizontalStepper extends StatelessWidget {
  final List<String> steps;
  final int activeIndex;

  const _HorizontalStepper({required this.steps, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                _StepNode(index: i, activeIndex: activeIndex),
                if (i < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: i < activeIndex
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEEEEEE),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < steps.length; i++)
                Expanded(
                  child: Text(
                    // Take the first two words to keep labels compact.
                    steps[i].split(' ').take(2).join(' '),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: i == activeIndex
                          ? _syanatBlue
                          : i < activeIndex
                              ? const Color(0xFF10B981)
                              : const Color(0xFF9E9E9E),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepNode extends StatelessWidget {
  final int index;
  final int activeIndex;
  const _StepNode({required this.index, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    final isDone = index < activeIndex;
    final isActive = index == activeIndex;
    final isFuture = index > activeIndex;
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone
            ? const Color(0xFF10B981)
            : isActive
                ? _syanatBlue
                : Colors.white,
        border: isFuture
            ? Border.all(color: const Color(0xFFE0E0E0), width: 2)
            : null,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: _syanatBlue.withValues(alpha: 0.18),
                  blurRadius: 0,
                  spreadRadius: 4,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: isDone
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isFuture
                    ? const Color(0xFF9E9E9E)
                    : Colors.white,
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Collapsed past-steps row — avatar-stack with breadcrumb summary. Used when
// at least 3 steps have been completed (mirrors AcceptanceVariantA).
// ─────────────────────────────────────────────────────────────────────────────

class _CollapsedPastStepsRow extends StatelessWidget {
  final List<String> titles;
  final bool isEn;

  const _CollapsedPastStepsRow({required this.titles, required this.isEn});

  @override
  Widget build(BuildContext context) {
    final firstWords = titles.map((t) => t.split(' ').first).join(' › ');
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0x0F10B981),
        border: Border.all(color: const Color(0x3310B981)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Avatar stack — show up to 3 overlapping check chips.
          SizedBox(
            width: 22 + 14 * 2.0,
            height: 22,
            child: Stack(
              children: [
                for (var j = 0; j < titles.length && j < 3; j++)
                  Positioned(
                    left: j * 14,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF10B981),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.check,
                          size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 13, color: Colors.black87, height: 1.3),
                children: [
                  TextSpan(
                    text: isEn
                        ? '${titles.length} steps completed'
                        : 'تم إكمال ${titles.length} خطوات',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: ' · $firstWords',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
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

  // Threshold at which the slide locks. Mirrors design-system/JobAcceptance.jsx
  // > SlideToConfirm: drag past 80% of the track and release, and the slider
  // animates to 100% + fires the confirm callback.
  static const double _confirmThreshold = 0.8;

  void _handleDragUpdate(
    DragUpdateDetails details,
    double maxTravel,
    bool isRtl,
  ) {
    if (!widget.enabled || _confirmed) return;
    _controller.stop();
    final delta =
        isRtl ? -(details.primaryDelta ?? 0) : (details.primaryDelta ?? 0);
    final next = (_progress * maxTravel + delta).clamp(0.0, maxTravel);
    final progress = maxTravel == 0 ? 0.0 : next / maxTravel;
    setState(() => _progress = progress);
  }

  void _handleDragEnd() {
    if (!widget.enabled || _confirmed) return;
    if (_progress >= _confirmThreshold) {
      _confirm();
    } else {
      _animateReset();
    }
  }

  void _confirm() {
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
  }

  void _animateReset() {
    if (_progress == 0) return;
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

        // Track width (0..1) of progress, used for the gradient fill.
        final fillFraction = _progress.clamp(0.0, 1.0);

        // Threshold tick position (mirrors design's 80% marker line).
        final thresholdLeft = 4 + (maxTravel * _confirmThreshold) + thumbSize / 2;

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            final rtl = Directionality.of(context) == TextDirection.rtl;
            _handleDragUpdate(details, maxTravel, rtl);
          },
          onHorizontalDragEnd: (_) => _handleDragEnd(),
          onHorizontalDragCancel: _handleDragEnd,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: _confirmed
                    ? const Color(0xFF10B981)
                    : _syanatBlue
                        .withValues(alpha: widget.enabled ? 0.10 : 0.06),
                border: _confirmed
                    ? null
                    : Border.all(
                        color: _syanatBlue.withValues(alpha: 0.20)),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Stack(
                alignment: Alignment.centerLeft,
                clipBehavior: Clip.none,
                children: [
                  // Gradient fill that grows with the drag.
                  if (!_confirmed)
                    Positioned.fill(
                      child: Align(
                        alignment: isRtl
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: fillFraction,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: isRtl
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                end: isRtl
                                    ? Alignment.centerLeft
                                    : Alignment.centerRight,
                                colors: [
                                  _syanatBlue.withValues(alpha: 0.20),
                                  _syanatBlue.withValues(alpha: 0.40),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // 80% threshold tick (hidden once confirmed).
                  if (!_confirmed && maxTravel > 0)
                    Positioned(
                      top: 8,
                      bottom: 8,
                      left: isRtl ? null : thresholdLeft,
                      right: isRtl ? thresholdLeft : null,
                      child: Container(
                        width: 2,
                        decoration: BoxDecoration(
                          color: _syanatBlue.withValues(alpha: 0.30),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  // Centered label — fades out as the user drags so the thumb
                  // never overlaps unreadable text.
                  Positioned.fill(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 72),
                        child: _confirmed
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.check,
                                      color: Colors.white, size: 22),
                                  SizedBox(width: 8),
                                  Text(
                                    'Confirmed',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              )
                            : Opacity(
                                opacity:
                                    (1.0 - fillFraction).clamp(0.35, 1.0),
                                child: Text(
                                  widget.label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: _syanatBlue.withValues(
                                        alpha: widget.enabled ? 1.0 : 0.4),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  // Thumb — anchored to the track via thumbOffset. Hidden
                  // once locked (the green pill stands in for it).
                  if (!_confirmed)
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
                                color: Color(0x26000000),
                                blurRadius: 8,
                                offset: Offset(0, 3)),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_forward,
                          color: _syanatBlue.withValues(
                              alpha: widget.enabled ? 1.0 : 0.4),
                          size: 22,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
