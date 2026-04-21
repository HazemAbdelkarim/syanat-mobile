# Contract: `AdminCloudFunctions`

**File**: `.claude/AdminWebApp/lib/services/admin_cloud_functions.dart`
**Purpose**: Every privileged admin write in this spec (assign, approve, reject, resolve, close) flows through this one class. Every method wraps an existing `onCall` function deployed in Spec 002 in region `europe-west1` (research R-1). No method in this class makes a direct Firestore write.

Modifies the Spec-004 stub file in place; does NOT create a new file.

---

## Shared setup

```dart
final FirebaseFunctions _functions =
    FirebaseFunctions.instanceFor(region: 'europe-west1');
```

**Critical**: the region MUST be `europe-west1`. Forgetting it defaults the client to `us-central1` and every call returns `not-found` (research R-1). There is exactly one `_functions` field; every `httpsCallable(...)` goes through it.

---

## Method: `assignJob`

```dart
Future<void> assignJob({required String jobId, required String technicianId})
```

**Client-side validation** (before the call):
- `jobId.trim().isNotEmpty` and `technicianId.trim().isNotEmpty`. Throw `ArgumentError` synchronously if not — caller should have blocked, but defense-in-depth.

**Call** (exact):
```dart
final res = await _functions.httpsCallable('adminAssignJob').call(<String, dynamic>{
  'jobId': jobId.trim(),
  'technicianId': technicianId.trim(),
});
assert(res.data is Map && res.data['ok'] == true);
```

**Success response**: `{ ok: true }` (research R-2).

**Possible exceptions surfaced to UI** (via `callable_errors.dart`):
- `unauthenticated` — admin signed out between click and call. UI: signs out and returns to login screen.
- `permission-denied` — user is no longer admin. UI: same as above.
- `invalid-argument` — trimmed fields empty. UI: inline error "Missing required field".
- `failed-precondition` — job is not in `'requested'` status. UI: SnackBar "Job no longer assignable" (FR-041).
- `not-found` — technician missing. UI: SnackBar "Technician not found".
- `internal` — unknown server error. UI: SnackBar "Unexpected error. Please try again."

**UI wiring** (`assign_dialog.dart`):
- Confirm button disabled while `Future` in flight.
- Button stays disabled for 500 ms after success (FR-033).
- No auto-retry on failure (FR-034).

---

## Method: `approvePayment`

```dart
Future<void> approvePayment({required String paymentId})
```

**Call**:
```dart
final res = await _functions.httpsCallable('adminApprovePayment').call(<String, dynamic>{
  'paymentId': paymentId.trim(),
});
```

**Response**: `{ ok: true }`.

**UI wiring** (`payments_screen.dart`):
- Approve button disabled during the call.
- On success, local badge updates to CONFIRMED within 2 s via the stream (no optimistic update; wait for server truth).
- Confirmation dialog names the specific `paymentId` (FR-039 regex guard applied).

---

## Method: `rejectPayment`

```dart
Future<void> rejectPayment({required String paymentId, required String reason})
```

**Client-side validation**:
- `reason = reason.trim()`; reject if empty with `ArgumentError`.
- Cap `reason.length <= 500` (FR-036); cut by the dialog's counter UI, but defense-in-depth here.

**Call**:
```dart
final res = await _functions.httpsCallable('adminRejectPayment').call(<String, dynamic>{
  'paymentId': paymentId.trim(),
  'reason': reason,
});
```

**Response**: `{ ok: true }`.

**UI wiring** (`reject_dialog.dart`):
- Confirm disabled while `reason.trim().isEmpty`.
- Remaining-chars counter (`500 - reason.length`).
- On success, the dialog closes and the row's badge updates within 2 s.

---

## Method: `resolveDispute`

```dart
Future<void> resolveDispute({
  required String jobId,
  required Resolution resolution,
  required String reason,
  double? overrideAmount,
})
```

**Client-side validation**:
- `jobId.trim().isNotEmpty`.
- `reason = reason.trim()`; must be non-empty; capped at 1000 chars (FR-036).
- `resolution` is the enum `Resolution.reopen | complete | cancel`. The wrapper converts it to the server string via `serverValue(resolution)` (research R-12). **The button label is NEVER used as the payload.**
- If `overrideAmount != null`: must be finite, ≥ 0, ≤ 1,000,000 (FR-038). For `Resolution.complete` the caller MUST supply either a non-null override or the server falls back to the job's existing `price`; if neither exists the callable returns `failed-precondition`.
- For `Resolution.reopen` and `Resolution.cancel`, `overrideAmount` MUST be null (defensive).

**Call**:
```dart
final Map<String, dynamic> payload = <String, dynamic>{
  'jobId': jobId.trim(),
  'resolution': serverValue(resolution),  // 'reopen' | 'complete' | 'cancel'
  'reason': reason,
};
if (overrideAmount != null) {
  payload['overrideAmount'] = overrideAmount;
}
final res = await _functions.httpsCallable('adminResolveDispute').call(payload);
```

**Response**: `{ ok: true }`.

**UI wiring** (`resolve_panel.dart`):
- Three buttons (Reopen / Complete / Cancel), all disabled while `reason.trim().isEmpty`.
- Override amount input enabled only when Complete is the selected action (User Story 4 AS2).
- On success, the job disappears from the Disputes list via stream update.
- On `failed-precondition` ("wrong status" — another admin resolved first): SnackBar "Dispute no longer pending" (FR-042).

---

## Method: `closeJob`

```dart
Future<void> closeJob({required String jobId, required double amountPaid})
```

**Client-side validation** (FR-038):
- `jobId.trim().isNotEmpty`.
- `amountPaid` must be finite, ≥ 0, ≤ 1,000,000.
- `amountPaid == 0` is allowed (penalty / no-op).

**Call**:
```dart
final res = await _functions.httpsCallable('adminCloseJob').call(<String, dynamic>{
  'jobId': jobId.trim(),
  'amountPaid': amountPaid,
});
```

**Response**: `{ ok: true }` — including when the job was already closed (idempotent, see `functions/src/admin/close-job.ts:41–45`).

**UI wiring** (`job_detail_screen.dart`):
- Force Close button hidden if `job.adminClosedAt != null` (defensive).
- Confirmation dialog names the specific `jobId` (FR-039 regex guard).
- Amount input uses `TextInputType.numberWithOptions(decimal: true, signed: false)` (FR-038).
- On success, whether first-time or idempotent repeat, show the same SnackBar "Job closed" (FR-040).

---

## Error handling (shared)

All five methods above route `FirebaseFunctionsException` through a single helper:

```dart
// lib/utils/callable_errors.dart
class CallableErrorView {
  final String code;
  final String message;
  const CallableErrorView(this.code, this.message);
}

CallableErrorView fromException(Object error) {
  if (error is FirebaseFunctionsException) {
    return CallableErrorView(error.code, error.message ?? 'Unknown error');
    // NOTE: error.details is intentionally NOT read here — Principle XIII / SC-006.
  }
  if (error is FirebaseAuthException) {
    return CallableErrorView(error.code, error.message ?? 'Auth error');
  }
  if (error is FirebaseException) {
    // Firestore stream / read errors surface here (e.g. 'permission-denied'
    // from a security-rule deny, or 'unavailable' on transient Firestore loss).
    // `code` already namespaces as e.g. 'cloud_firestore/permission-denied' —
    // surface the message only. `plugin` and any internal details are NOT read.
    return CallableErrorView(error.code, error.message ?? 'Firestore error');
  }
  return const CallableErrorView('unknown', 'Unexpected error. Please try again.');
}
```

The UI renders `"${e.code}: ${e.message}"` inside a `SnackBar` or inline `Text`. **`error.details` MUST NEVER be read anywhere in `.claude/AdminWebApp/lib/**`** (FR-023, SC-006 grep gate).

---

## Forbidden patterns (will fail code review)

- Any `httpsCallable(...)` call NOT on the `_functions` field (i.e. not in `europe-west1`).
- Any direct `FirebaseFirestore.instance.collection('jobs').doc(...).update(...)` call from admin web code (FR-021).
- Any `catch` branch that reads `.details` from a `FirebaseFunctionsException` and surfaces it (FR-023).
- Any `retry`, `backoff`, `timeout + retry` pattern around these calls (FR-034).
- Any `Future.delayed(...)` inserted for the sole purpose of "re-enabling" the button — the 500 ms post-success lockout is explicit via a `bool _justSucceeded` state flag + `Timer`, not a `sleep`.

---

## Removed stub methods

None. All five Spec-004 stubs remain (they get filled in). The service-layer method removals from `AdminFirebaseService` (`fetchRecentUsers`, `fetchRecentActivity`, `initializeStatsGlobal`) do NOT have callable counterparts, so no change here.
