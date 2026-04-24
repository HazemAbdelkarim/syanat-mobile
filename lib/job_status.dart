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
/// completed`; only an admin can do it from `receipt_disputed`).
enum JobActor { admin, technician, customer, system }

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
    // Release-006 completion path: tech verifies payment with photo proof.
    // Gated server-side on paymentProofUrl + amountPaid >= receiptTotal.
    if (from == JobStatus.awaitingPaymentVerification &&
        to == JobStatus.completed) {
      return true;
    }
    // Tech may cancel only before they've accepted.
    if (from == JobStatus.active && to == JobStatus.cancelled) return true;
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
