# Contract: Client-Side Constants & Icon Mapping

**Scope**: Every server↔UI string mapping is declared once, here, and referenced by enum / lookup. No screen or widget is allowed to build a server string from a UI label (FR-024).

All three files below live under `.claude/AdminWebApp/lib/constants/`.

---

## `resolutions.dart` — dispute resolution enum

```dart
enum Resolution { reopen, complete, cancel }

String serverValue(Resolution r) {
  switch (r) {
    case Resolution.reopen:   return 'reopen';
    case Resolution.complete: return 'complete';
    case Resolution.cancel:   return 'cancel';
  }
}

String displayLabel(Resolution r) {
  switch (r) {
    case Resolution.reopen:   return 'Reopen';
    case Resolution.complete: return 'Complete';
    case Resolution.cancel:   return 'Cancel';
  }
}
```

**Usage rule**: `resolveDispute(...)` callable wrapper passes `serverValue(resolution)` into the payload. The UI button is labeled via `displayLabel(resolution)`. They are independent and CANNOT be combined accidentally (FR-024).

**Why enum, not just String**: makes it a compile-time error to pass a button label into the callable.

---

## `payment_status.dart` — payment status enum + color map

```dart
enum PaymentStatus { pending, confirmed, rejected }

PaymentStatus paymentStatusFromString(String? raw) {
  switch (raw?.toUpperCase()) {
    case 'CONFIRMED': return PaymentStatus.confirmed;
    case 'REJECTED':  return PaymentStatus.rejected;
    case 'PENDING':
    default:          return PaymentStatus.pending;  // defensive default
  }
}

Color paymentStatusColor(PaymentStatus s) {
  switch (s) {
    case PaymentStatus.pending:   return Colors.orange;
    case PaymentStatus.confirmed: return Colors.green;
    case PaymentStatus.rejected:  return Colors.red;
  }
}

String paymentStatusLabel(PaymentStatus s) {
  switch (s) {
    case PaymentStatus.pending:   return 'Pending';
    case PaymentStatus.confirmed: return 'Confirmed';
    case PaymentStatus.rejected:  return 'Rejected';
  }
}
```

**Usage rule**: the `StatusBadge` widget takes `PaymentStatus`, looks up color + label internally. Raw string from Firestore never reaches UI code directly.

---

## `job_status.dart` — job status enum + tab filter lists

```dart
enum JobStatus {
  requested,
  active,
  technicianAccepted,
  technicianArrived,
  workFinished,
  awaitingCustomerApproval,
  receiptDisputed,
  completed,
  cancelled,
}

const Map<JobStatus, String> jobStatusServerValue = {
  JobStatus.requested: 'requested',
  JobStatus.active: 'active',
  JobStatus.technicianAccepted: 'technician_accepted',
  JobStatus.technicianArrived: 'technician_arrived',
  JobStatus.workFinished: 'work_finished',
  JobStatus.awaitingCustomerApproval: 'awaiting_customer_approval',
  JobStatus.receiptDisputed: 'receipt_disputed',
  JobStatus.completed: 'completed',
  JobStatus.cancelled: 'cancelled',
};

const List<String> activeJobStatusStrings = [
  'active',
  'technician_accepted',
  'technician_arrived',
  'work_finished',
  'awaiting_customer_approval',
  'receipt_disputed',
];
```

**Usage rule**: `streamActiveJobsAdmin` uses `activeJobStatusStrings` literal in its `whereIn`. The UI always decodes `job.status` back into `JobStatus` via a lookup from the reverse map (or through the model's `fromFirestore`).

---

## `activity_icons.dart` — activity-log type → icon/color/label map

Keyed on the **server-emitted `type` string** (research R-3). Unknown types render a neutral style.

```dart
class ActivityStyle {
  final IconData icon;
  final Color color;
  final String labelTemplate;    // "{jobId}", "{resolution}", "{reason}" placeholders
  const ActivityStyle({required this.icon, required this.color, required this.labelTemplate});
}

const Map<String, ActivityStyle> activityTypeMap = {
  'job_assigned': ActivityStyle(
    icon: Icons.assignment_ind,
    color: Colors.blue,
    labelTemplate: 'Job {jobId} assigned to {assignedTechnicianName}',
  ),
  'job_force_closed': ActivityStyle(
    icon: Icons.lock,
    color: Colors.red,
    labelTemplate: 'Job {jobId} force-closed',
  ),
  'dispute_resolved': ActivityStyle(
    icon: Icons.gavel,
    color: Colors.purple,
    labelTemplate: 'Dispute on {jobId} resolved ({resolution})',
  ),
  'payment_approved': ActivityStyle(
    icon: Icons.check_circle,
    color: Colors.green,
    labelTemplate: 'Payment {paymentId} approved',
  ),
  'payment_rejected': ActivityStyle(
    icon: Icons.warning,
    color: Colors.amber,
    labelTemplate: 'Payment {paymentId} rejected: {reason}',
  ),
  'account_created': ActivityStyle(
    icon: Icons.person_add,
    color: Colors.blue,
    labelTemplate: 'New account',
  ),
  'job_requested': ActivityStyle(
    icon: Icons.pending_actions,
    color: Colors.orange,
    labelTemplate: 'Job {jobId} requested',
  ),
  'job_completed': ActivityStyle(
    icon: Icons.check_circle,
    color: Colors.green,
    labelTemplate: 'Job {jobId} completed',
  ),
  'job_cancelled': ActivityStyle(
    icon: Icons.cancel,
    color: Colors.red,
    labelTemplate: 'Job {jobId} cancelled',
  ),
};

const ActivityStyle unknownActivityStyle = ActivityStyle(
  icon: Icons.info_outline,
  color: Colors.grey,
  labelTemplate: '{type}',
);
```

**Interpolation rule**: the `labelTemplate` is filled by a simple `String.replaceAll('{field}', value)` pass, where `value` is the field read from the `ActivityEntry` model. `jobId` / `paymentId` values are routed through `utils/doc_id_guard.dart` before interpolation (FR-039). `reason` is clipped to 120 chars with an ellipsis for row display (full reason is visible on tap).

**At implementation time** (research R-3): the implementing model MUST grep `functions/src/stats/` to confirm `account_created`, `job_requested`, `job_completed`, `job_cancelled` are actually emitted by the Spec-003 triggers. If any is not emitted, remove its row from this map. Leaving a never-matched row is dead code.

---

## Importer invariants

1. Every `constants/*.dart` file is a pure lookup module — zero imports of `package:firebase_*`.
2. No `dart:convert` / `jsonDecode` in these files — they are compile-time constants.
3. A widget that needs a string goes through an `enum` + lookup; direct `String` literals in UI code that match a server value are a lint-level defect flagged in code review.
