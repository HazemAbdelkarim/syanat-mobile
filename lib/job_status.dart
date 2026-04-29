// Job status vocabulary + pure-Dart transition guard.
//
// This file is the canonical client-side description of the job state
// machine. It is duplicated by design: the authoritative enforcement lives
// in `firestore.rules` (server-side) and in the typed transactions inside
// `FirebaseService` (client-side, in `firebase_service.dart`). This file
// exists for two reasons:
//
// 1. To make transitions unit-testable in pure Dart (no Firebase harness)
//    — see `test/job_status_test.dart`.
// 2. To serve as a human-readable map of "who can drive what state change"
//    when reading rules gets tedious.
//
// If the rules or the `FirebaseService` transactions change, update this
// file too. Drift is caught by the unit tests the first time the
// transition list disagrees with expectations.

/// Canonical status values on the `jobs` document.
class JobStatus {
  JobStatus._();

  // Pre-assignment
  static const String requested = 'requested';
  // Admin-assigned, tech has not yet accepted
  static const String active = 'active';
  // Tech lifecycle
  static const String technicianAccepted = 'technician_accepted';
  static const String onTheWay = 'on_the_way';
  static const String technicianArrived = 'technician_arrived';
  static const String workFinished = 'work_finished';
  // Receipt + payment lifecycle (release 006 splits the old single
  // customer-confirms-pay hop into approve → initiate → verify).
  static const String awaitingCustomerApproval = 'awaiting_customer_approval';
  static const String awaitingPayment = 'awaiting_payment';
  static const String awaitingPaymentVerification =
      'awaiting_payment_verification';
  static const String receiptDisputed = 'receipt_disputed';
  // Terminal
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';

  static const Set<String> terminal = {completed, cancelled};
}

/// Who is attempting the transition. Rules enforce per-actor gates — the
/// same (from, to) may be allowed for one actor and denied for another
/// (e.g. only the customer can transition `awaiting_customer_approval →
/// awaiting_payment`; only an admin can do it from `receipt_disputed`).
enum JobActor { admin, technician, customer, system }

/// Returns a bilingual status label from the *technician's* perspective.
/// Used by `tech_home_screen.dart` tiles and the active-job screen banners.
/// The sibling `jobStatusCustomerLabel` below renders the same statuses
/// from the customer's perspective; both share this file's status enum.
///
/// Unknown statuses fall back to the raw string so a forgotten mapping is
/// visible in-app rather than silently empty.
String jobStatusTechLabel(String status, {required bool isEn}) {
  switch (status) {
    case JobStatus.requested:
      return isEn ? 'Pending assignment' : 'بانتظار التعيين';
    case JobStatus.active:
      return isEn ? 'New assignment' : 'مهمة جديدة';
    case JobStatus.technicianAccepted:
      return isEn ? 'Ready to start' : 'جاهز للبدء';
    case JobStatus.onTheWay:
      return isEn ? 'On the way' : 'في الطريق';
    case JobStatus.technicianArrived:
      return isEn ? 'Arrived on site' : 'وصلت إلى الموقع';
    case JobStatus.workFinished:
      return isEn ? 'Fill receipt' : 'إعداد الفاتورة';
    case JobStatus.awaitingCustomerApproval:
      return isEn ? 'Awaiting customer approval' : 'بانتظار موافقة العميل';
    case JobStatus.awaitingPayment:
      return isEn ? 'Awaiting customer payment' : 'بانتظار الدفع';
    case JobStatus.awaitingPaymentVerification:
      return isEn ? 'Approve payment' : 'تأكيد الدفع';
    case JobStatus.receiptDisputed:
      return isEn ? 'Receipt disputed' : 'الفاتورة محل نزاع';
    case JobStatus.completed:
      return isEn ? 'Completed' : 'مكتملة';
    case JobStatus.cancelled:
      return isEn ? 'Cancelled' : 'ملغاة';
    default:
      return status;
  }
}

/// Returns a bilingual status label from the *customer's* perspective.
/// Used by `orders_screen.dart` and the customer review/payment screens.
/// Strings are worded as full messages (not short badges) because this is
/// the customer's primary read on what's happening with their order.
String jobStatusCustomerLabel(String status, {required bool isEn}) {
  switch (status) {
    case JobStatus.requested:
      return isEn
          ? 'Waiting for a technician to be assigned'
          : 'في انتظار تعيين فني';
    case JobStatus.active:
      return isEn
          ? 'Technician assigned — awaiting confirmation'
          : 'تم تعيين الفني — بانتظار التأكيد';
    case JobStatus.technicianAccepted:
      return isEn ? 'Technician confirmed' : 'أكد الفني';
    case JobStatus.onTheWay:
      return isEn ? 'Technician is on the way' : 'الفني في الطريق';
    case JobStatus.technicianArrived:
      return isEn ? 'Technician has arrived' : 'وصل الفني';
    case JobStatus.workFinished:
      return isEn
          ? 'Work finished — technician is preparing your receipt'
          : 'انتهى العمل — يقوم الفني بإعداد الفاتورة';
    case JobStatus.awaitingCustomerApproval:
      return isEn ? 'Review and approve your receipt' : 'راجع الفاتورة';
    case JobStatus.awaitingPayment:
      return isEn
          ? 'Approved — please pay the technician'
          : 'تمت الموافقة — يرجى الدفع للفني';
    case JobStatus.awaitingPaymentVerification:
      return isEn
          ? 'Payment recorded — technician is confirming'
          : 'تم تسجيل الدفع — الفني يؤكد';
    case JobStatus.receiptDisputed:
      return isEn
          ? 'Receipt disputed — admin is reviewing'
          : 'الفاتورة محل نزاع — الإدارة تراجع';
    case JobStatus.completed:
      return isEn ? 'Completed' : 'مكتملة';
    case JobStatus.cancelled:
      return isEn ? 'Cancelled' : 'ملغاة';
    default:
      return status;
  }
}

/// Returns true when the technician's "On the way" slider may fire for a
/// job whose [scheduledTime] is being evaluated against [now].
///
/// Rules (mirrors `firestore.rules` branch `technician_accepted → on_the_way`):
///   - `null` scheduledTime → urgent job, always allowed
///   - scheduledTime in the past or now → allowed (tech starting late is fine)
///   - scheduledTime within 60 minutes → allowed
///   - scheduledTime more than 60 minutes ahead → blocked
///
/// The 60-minute window is the same gate enforced server-side in the rules,
/// so a successful client-side check should never see a permission-denied
/// from the server. The check is duplicated here so the slider can disable
/// itself with explanatory copy instead of letting the user slide and fail.
bool canStartTrip(DateTime? scheduledTime, DateTime now) {
  if (scheduledTime == null) return true;
  if (!scheduledTime.isAfter(now)) return true;
  return scheduledTime.difference(now) <= const Duration(minutes: 60);
}

/// Cancellation-penalty result for a tech-initiated cancel of an accepted
/// job. [penalty] is the EGP amount to record on the job document; [escalate]
/// flags cases that warrant manual review (urgent jobs, past-scheduled, or
/// cancels under one hour before the slot). Wallet deduction is intentionally
/// NOT modelled here — a future task will read these fields and act on them.
typedef CancellationPenalty = ({num penalty, bool escalate});

/// Returns the cancellation penalty in EGP for a tech-side cancellation of
/// an accepted job whose [scheduledTime] is being evaluated at [now].
///
/// Tiers, by hours-before-scheduledTime:
///   - more than 6 h           → 0   EGP, no escalation
///   - 6 h ≤ Δ < 5 h            → 20  EGP, no escalation
///   - 5 h ≤ Δ < 4 h            → 40  EGP, no escalation
///   - 4 h ≤ Δ < 3 h            → 70  EGP, no escalation
///   - 3 h ≤ Δ < 2 h            → 100 EGP, no escalation
///   - 2 h ≤ Δ < 1 h            → 200 EGP, no escalation
///   - less than 1 h or past    → 200 EGP, escalate
///   - urgent (scheduledTime null) → 200 EGP, escalate
///
/// Boundaries: each tier is half-open at the lower end. A job exactly 6 h
/// out is in the "more than 6 h" tier (Δ = 6:00:00 → 0 EGP); at 5:59:59 it
/// drops into the 20 EGP tier.
CancellationPenalty calculateCancellationPenalty(
  DateTime? scheduledTime,
  DateTime now,
) {
  if (scheduledTime == null) return (penalty: 200, escalate: true);
  if (!scheduledTime.isAfter(now)) return (penalty: 200, escalate: true);
  final delta = scheduledTime.difference(now);
  if (delta < const Duration(hours: 1)) return (penalty: 200, escalate: true);
  if (delta < const Duration(hours: 2)) return (penalty: 200, escalate: false);
  if (delta < const Duration(hours: 3)) return (penalty: 100, escalate: false);
  if (delta < const Duration(hours: 4)) return (penalty: 70, escalate: false);
  if (delta < const Duration(hours: 5)) return (penalty: 40, escalate: false);
  if (delta < const Duration(hours: 6)) return (penalty: 20, escalate: false);
  return (penalty: 0, escalate: false);
}

/// Returns true when [scheduledTime] falls on the same local calendar day
/// as [now]. A null [scheduledTime] (urgent / now jobs) is also considered
/// same-day so urgent work always sits on the technician's active list.
///
/// Used by the technician home routing logic to split jobs between the
/// Active Jobs list (today / urgent) and the Schedule view (other days).
/// Boundary is local midnight — a job at 23:59 today is same-day, a job
/// at 00:01 tomorrow is not.
bool isSameDay(DateTime? scheduledTime, DateTime now) {
  if (scheduledTime == null) return true;
  return scheduledTime.year == now.year &&
      scheduledTime.month == now.month &&
      scheduledTime.day == now.day;
}

/// Returns the price to display on customer-facing surfaces for a given
/// job map. Prefers the receipt's `grandTotal` once a receipt has been
/// submitted, so the customer sees the actual amount they owe (which may
/// exceed the original quote when the technician adds parts or services
/// on-site). Falls back to the original `job.price` quote pre-receipt,
/// then to 0 for jobs missing both fields.
///
/// Returned as `num` so call sites can format with `.toStringAsFixed(...)`
/// or compare to zero without re-typing.
num jobDisplayPrice(Map<String, dynamic> job) {
  final receipt = job['receipt'] as Map<String, dynamic>?;
  final grand = receipt?['grandTotal'];
  if (grand is num) return grand;
  final price = job['price'];
  if (price is num) return price;
  return 0;
}

/// Returns `true` when [actor] may transition a job from [from] to [to].
/// Mirrors `firestore.rules:177-321` (jobs update branches).
///
/// This is a client-side sanity check only. The rules are the authority:
/// even if this function returns `true`, Firestore will reject the write
/// unless the rule agrees. Keep this list in sync when rules change.
bool isValidJobTransition({
  required String from,
  required String to,
  required JobActor actor,
}) {
  // Admin-driven transitions
  if (actor == JobActor.admin) {
    if (from == JobStatus.requested && to == JobStatus.active) return true;
    // Admin reassigns (same status, new tech)
    if (from == JobStatus.active && to == JobStatus.active) return true;
    // Dispute resolution: admin reopens / completes / cancels
    if (from == JobStatus.receiptDisputed &&
        (to == JobStatus.awaitingCustomerApproval ||
            to == JobStatus.completed ||
            to == JobStatus.cancelled)) {
      return true;
    }
    // Admin can cancel any non-terminal
    if (!JobStatus.terminal.contains(from) && to == JobStatus.cancelled) {
      return true;
    }
  }

  // Technician-driven transitions
  if (actor == JobActor.technician) {
    if (from == JobStatus.active && to == JobStatus.technicianAccepted) {
      return true;
    }
    // New in release-006: start-trip step between accept and arrive.
    if (from == JobStatus.technicianAccepted && to == JobStatus.onTheWay) {
      return true;
    }
    if (from == JobStatus.onTheWay && to == JobStatus.technicianArrived) {
      return true;
    }
    if (from == JobStatus.technicianArrived && to == JobStatus.workFinished) {
      return true;
    }
    if (from == JobStatus.workFinished &&
        to == JobStatus.awaitingCustomerApproval) {
      return true;
    }
    // Release-006 completion path: tech taps to confirm payment received.
    // Gated server-side on amountPaid >= receiptTotal.
    // TODO(BLAZE): photo-proof gate removed pending Storage init — see
    // firestore.rules branch 5.
    if (from == JobStatus.awaitingPaymentVerification &&
        to == JobStatus.completed) {
      return true;
    }
    // Tech may cancel from `active` (no penalty) or `technician_accepted`
    // (penalty applies, see calculateCancellationPenalty). Both branches
    // are authorised in firestore.rules and exercised by cancelJobByTech;
    // keep them in sync here.
    if (from == JobStatus.active && to == JobStatus.cancelled) return true;
    if (from == JobStatus.technicianAccepted && to == JobStatus.cancelled) {
      return true;
    }
  }

  // Customer-driven transitions
  if (actor == JobActor.customer) {
    // Release-006: customer approves receipt line items. No money moves here.
    if (from == JobStatus.awaitingCustomerApproval &&
        to == JobStatus.awaitingPayment) {
      return true;
    }
    // Release-006: customer marks "I paid the technician" — hands off to tech
    // for photo-proof verification. No amountPaid/paidAt on this branch.
    if (from == JobStatus.awaitingPayment &&
        to == JobStatus.awaitingPaymentVerification) {
      return true;
    }
    // Reject receipt → dispute
    if (from == JobStatus.awaitingCustomerApproval &&
        to == JobStatus.receiptDisputed) {
      return true;
    }
    // Customer may cancel only before acceptance.
    if ((from == JobStatus.requested || from == JobStatus.active) &&
        to == JobStatus.cancelled) {
      return true;
    }
  }

  return false;
}
