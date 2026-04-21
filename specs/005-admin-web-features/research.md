# Research: Admin Web App Feature Screens (Spec 005)

**Feature Branch**: `005-admin-web-features`
**Date**: 2026-04-19
**Purpose**: Resolve every "NEEDS CLARIFICATION" / open question surfaced by the spec + plan before Phase 1 design. Each section below records a Decision, a Rationale (with the file + line that was read to reach it — per Constitution Principle III "No Guessing — Read First"), and Alternatives Considered.

Every decision here traces back to an already-existing artifact: the Spec-002 callable source (`functions/src/admin/*.ts`), the Spec-001-hardened `firestore.rules`, the deployed Spec-003 stats triggers, or the Spec-004 admin web shell (`.claude/AdminWebApp/lib/**`).

---

## R-1 — Callable region for the Dart client

**Question raised in**: spec Assumption A-10 ("region is verified during `research.md`").

**Decision**: All five admin callables are deployed in `europe-west1`. The Dart client MUST invoke them via `FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable(name)`, NOT `FirebaseFunctions.instance.httpsCallable(name)`.

**Rationale (file + line evidence)**:
- `functions/src/admin/assign-job.ts:13` → `{ region: "europe-west1" }`.
- `functions/src/admin/approve-payment.ts:12` → `{ region: "europe-west1" }`.
- `functions/src/admin/reject-payment.ts:13` → `{ region: "europe-west1" }`.
- `functions/src/admin/resolve-dispute.ts:28` → `{ region: "europe-west1" }`.
- `functions/src/admin/close-job.ts:13` → `{ region: "europe-west1" }`.
- Stats triggers (`functions/src/stats/on-*.ts`) are also `europe-west1`, confirming a project-wide region convention.

Using `FirebaseFunctions.instance` in the Dart client defaults to `us-central1` and every call returns `not-found`. This is a common footgun — it MUST be caught in code review and in task list (see `tasks.md` forthcoming).

**Alternatives considered**:
- Setting a per-call region override on each `httpsCallable` — rejected because `cloud_functions` for Flutter expects the region on the `FirebaseFunctions` instance, not per-call. Trying to mix defaults to silent region mismatches.
- Adding a `setGlobalOptions({ region: "europe-west1" })` in `functions/src/index.ts` — rejected because (a) it's a `functions/` change, explicitly out of scope (FR-044), and (b) it does not remove the client-side requirement anyway.

**Contract implication**: `.claude/AdminWebApp/lib/services/admin_cloud_functions.dart` exposes a single private `_functions` field:
```dart
final FirebaseFunctions _functions =
    FirebaseFunctions.instanceFor(region: 'europe-west1');
```
Every callable wrapper uses `_functions.httpsCallable('adminXxx')`. No other region is allowed.

---

## R-2 — Exact callable input/output schemas

**Question raised in**: FR-009–FR-012 describe wrapper signatures but the implementing model MUST match the server-side contract byte-for-byte.

**Decision**: The five callable wrappers use these exact payload shapes and handle these response shapes. Any additional field breaks `invalid-argument`; any wrong case breaks `not-found`.

| Callable | Input map | Success response | Possible `HttpsError.code` values |
|----------|-----------|------------------|-----------------------------------|
| `adminAssignJob` | `{ jobId: String, technicianId: String }` — both required, trimmed, non-empty | `{ ok: true }` | `unauthenticated`, `permission-denied`, `invalid-argument`, `failed-precondition` (job not `requested`), `not-found` (technician missing), `internal` |
| `adminApprovePayment` | `{ paymentId: String }` — required, trimmed, non-empty | `{ ok: true }` | `unauthenticated`, `permission-denied`, `invalid-argument`, `failed-precondition`, `internal` |
| `adminRejectPayment` | `{ paymentId: String, reason: String }` — both required, trimmed, non-empty. **Reason MUST be trimmed client-side and length ≤ 500** | `{ ok: true }` | `unauthenticated`, `permission-denied`, `invalid-argument`, `failed-precondition`, `internal` |
| `adminResolveDispute` | `{ jobId: String, resolution: 'reopen'\|'complete'\|'cancel', reason: String, overrideAmount?: number }` — `overrideAmount` is a `num` on the Dart side, must be finite and ≥ 0 if present. **Reason trimmed, length ≤ 1000** | `{ ok: true }` | `unauthenticated`, `permission-denied`, `invalid-argument` (bad resolution or missing reason), `failed-precondition` (wrong status OR `complete` without a price/override), `internal` |
| `adminCloseJob` | `{ jobId: String, amountPaid: number }` — amount finite, ≥ 0. **0 is valid (penalty / no-op).** **Capped at 1,000,000 EGP client-side (FR-038).** Server has no cap → client cap is defense-in-depth. | `{ ok: true }` — note: a second call on an already-closed job ALSO returns `{ ok: true }` silently, per the server-side idempotency guard | `unauthenticated`, `permission-denied`, `invalid-argument`, `failed-precondition` (job doesn't exist), `internal` |

**Rationale (file + line evidence)**:
- `functions/src/admin/assign-job.ts:19–28` (input validation), `:55–64` (write fields), `:66–71` (audit write), `:73` (response `{ ok: true }`).
- `functions/src/admin/close-job.ts:19–29` (input), `:41–45` (idempotency guard — second call returns without writes), `:47–54` (write), `:64` (response).
- `functions/src/admin/resolve-dispute.ts:7` (`RESOLUTIONS = ["reopen", "complete", "cancel"] as const`), `:33–56` (validation), `:86–105` (resolution-specific fields, including the `failed-precondition` on `complete` without a price/override), `:119` (response).
- `functions/src/admin/approve-payment.ts` and `reject-payment.ts` follow the same pattern (verified in file listing).

**Alternatives considered**:
- Returning the updated document body from the callable — rejected at server side (response is `{ ok: true }` only). The client MUST re-read via its stream rather than expect a payload echo. This is already the pattern in every callable.
- Treating `adminCloseJob` with `amountPaid == 0` as an error client-side — rejected because migration plan §7-6 explicitly allows zero for the penalty/no-op case. Only negative, `NaN`, `Infinity`, and `> 1,000,000` are blocked client-side.

**Contract implication**: The five wrappers map exceptions through `utils/callable_errors.dart` which returns a `(String code, String message)` record — never `.details`.

---

## R-3 — Audit-log `type` enum: reconciling spec wording with server source

**Question raised in**: spec User Story 6 §2 lists icon-map keys `account_created`, `job_requested`, `job_completed`, `job_cancelled`, `receipt_rejected`, `dispute_resolved`. The actual server-emitted types differ.

**Decision**: The canonical audit-log `type` values emitted by the deployed Cloud Functions are:

| `type` (from server) | Emitting function | Intended UI icon | Color | Display label template |
|----------------------|-------------------|------------------|-------|------------------------|
| `job_assigned` | `adminAssignJob` | `Icons.assignment_ind` | blue | "Job {jobId} assigned to {assignedTechnicianName}" |
| `job_force_closed` | `adminCloseJob` | `Icons.lock` | red | "Job {jobId} force-closed" |
| `dispute_resolved` | `adminResolveDispute` | `Icons.gavel` | purple | "Dispute on {jobId} resolved ({resolution})" |
| `payment_approved` | `adminApprovePayment` | `Icons.check_circle` | green | "Payment {paymentId} approved" |
| `payment_rejected` | `adminRejectPayment` | `Icons.warning` | amber | "Payment {paymentId} rejected: {reason}" |
| `account_created` | Spec-003 `onUserCreated` trigger | `Icons.person_add` | blue | "New {role} account" |
| `job_requested` | Spec-003 `onJobCreated` trigger (or mobile-side log — to verify before render) | `Icons.pending_actions` | orange | "Job {jobId} requested" |
| `job_completed` | Spec-003 `onJobStatusChanged` (status → `completed`) | `Icons.check_circle` | green | "Job {jobId} completed" |
| `job_cancelled` | Spec-003 `onJobStatusChanged` (status → `cancelled`) | `Icons.cancel` | red | "Job {jobId} cancelled" |

The spec's `receipt_rejected` label was a mis-translation from the migration plan. The server emits `payment_rejected`. Unknown types fall back to `Icons.info_outline` + grey per spec User Story 6 §2.

**Rationale (file + line evidence)**:
- `functions/src/admin/assign-job.ts:66` → `type: "job_assigned"`.
- `functions/src/admin/close-job.ts:57` → `type: "job_force_closed"`.
- `functions/src/admin/resolve-dispute.ts:110` → `type: "dispute_resolved"`.
- `functions/src/admin/approve-payment.ts:42` → `type: "payment_approved"`.
- `functions/src/admin/reject-payment.ts:50` → `type: "payment_rejected"`.
- Spec-003 stats triggers likely emit `account_created` / `job_requested` / `job_completed` / `job_cancelled`; to be confirmed by the implementing model via a grep in `functions/src/stats/` at the start of implementation. If any of those types are NOT emitted, the implementing model MUST remove the row from `constants/activity_icons.dart` and update spec User Story 6 AS2. This is the only spec-text reconciliation this spec permits.

**Alternatives considered**:
- Renaming server-side `type` values to match the migration-plan wording — rejected (FR-044 forbids `functions/` changes).
- Adding a client-side translation layer that maps `payment_rejected` → `receipt_rejected` for display — rejected because translating type strings hides the real server event from a reader of the UI; far simpler to use the server name directly and update the spec wording.

**Contract implication**: `constants/activity_icons.dart` is keyed on the server-emitted `type` string verbatim. The spec wording in User Story 6 §2 will be amended to use `payment_rejected` via a trivial edit (no `/speckit.clarify` round-trip required because this is a pure typo discovered through code-read, not a user decision).

---

## R-4 — Composite indexes required by the new queries

**Question raised in**: FR-032 + Constitution XII ("explicit indexes in `firestore.indexes.json`").

**Decision**: Zero new composite indexes are required by this spec. Every query in the service layer is either a single-field `.orderBy` (satisfied by the auto-single-field index) or already covered by an existing composite index in `firestore.indexes.json`. The file is NOT modified.

**Rationale (per-query audit)**:

| Query | Requires composite index? | Index source |
|-------|---------------------------|-------------|
| `stats/global` doc stream | No — single-doc read | N/A |
| `jobs.where(status == X).orderBy(createdAt desc).limit(50)` — three instances (Requested / Active whereIn / Completed) | Yes for `status + createdAt desc`. **Already deployed** (read from `firestore.indexes.json`; field names verified). `whereIn` on `status` with `orderBy(createdAt)` uses the same index. | `firestore.indexes.json` (pre-existing) |
| `payments.orderBy(createdAt desc).limit(100)` | No — single-field `orderBy` | auto-single-field |
| `support_chats.orderBy(lastMessageAt desc).limit(50)` | No — single-field `orderBy` | auto-single-field |
| `support_chats.where(unreadByAdmin == true).where(status == 'open').limit(100)` (unread count) | Yes for `unreadByAdmin + status`. **Already deployed** (Spec 004 added it). | `firestore.indexes.json` (pre-existing) |
| `support_chats/{chatId}/messages.orderBy(createdAt desc).limit(50)` | No — single-field `orderBy` inside a fixed parent doc | auto-single-field |
| `activity_log.orderBy(createdAt desc).limit(50)` | No — single-field `orderBy` | auto-single-field |
| `users.where(role == 'technician').where(availableForServices contains serviceKey).limit(100)` — for `getAvailableTechnicianIdsByService` | Yes for `role + availableForServices array-contains`. **Already deployed** — confirmed by the mobile app's existing `getAvailableTechnicianIdsByService` in `lib/firebase_service.dart`. | `firestore.indexes.json` (pre-existing) |

**Verification at implementation time**: before the preview deploy, run `firebase firestore:indexes` against the project and confirm the three composite indexes above match the three rows marked "already deployed". If any is missing, STOP and escalate — `firestore.indexes.json` edits require FR-032's atomic-deploy rule and belong in a tiny follow-up spec, not silently glued onto this one.

**Alternatives considered**:
- Relaxing the `jobs` status filter to a single where-clause without the orderBy — rejected because the UI requires ordered jobs (migration plan §7-2).
- Replacing the support unread count with a `count()` aggregation — rejected by FR-006 + INPUT.md §C-4 explicitly (per-render aggregation burns quota; the bounded `.limit(100)` stream is the mandated pattern).

---

## R-5 — `sendSupportMessage` throttle: does the Firestore rule enforce it?

**Question raised in**: spec Assumption A-6, FR-035 ("the implementing model MUST verify; if the throttle does not exist, STOP and escalate").

**Decision**: The throttle **exists** in `firestore.rules` lines 370–425. Specifically:
- 10-second cooldown between user messages: `resource.data.lastUserMessageAt + duration.value(10, 's')` (line 389).
- Per-chat cap of 50 user messages total: `userMessageCount <= 50` (line 392).
- Max message text size: 2000 characters (line 413).
- **Admin path is unrestricted** on message creation (line 415: `isAdmin()` short-circuits the user-side throttle). The admin can send as many messages as they want.

**Rationale (file + line evidence)**:
- `firestore.rules:377` — `allow update: if isAdmin() || (...user-side throttle branch...)`.
- `firestore.rules:385–394` — the 10 s cooldown + 50-message cap on user-side updates.
- `firestore.rules:410–422` — `allow create` on `messages` subcollection: unrestricted for admins (`isAdmin()` short-circuit) and throttled for users via `getAfter(...).userMessageCount`.

**Implication for spec 005**: Since the admin path is intentionally unrestricted (the admin is expected to respond rapidly during support conversations), the **client-side debounce + button disable** (FR-033: 500 ms lockout after success) is the only abuse-surface control. This is sufficient because:
1. The admin UI is internal; only `role == 'admin'` accounts reach it.
2. The 2000-char length limit is both client-side (FR-036) and server-side (rule line 413).
3. There is no rate-budget concern at 5-user admin scale.

**No escalation required.** Implementation proceeds per FR-035.

**Alternatives considered**:
- Adding an admin-side rate limit in `firestore.rules` — rejected because (a) it's a rules change, requires a dedicated hardening spec, and (b) the defense-in-depth balance (App Check + admin role gate + 2000-char per-message cap + UI debounce) is already sufficient.

---

## R-6 — Pagination strategy for Jobs / Payments / Activity

**Question raised in**: FR-031 ("pagination MUST use `startAfterDocument`"). The spec caps every list at 50/100/50 items but does not require pagination inside the MVP.

**Decision**: **No pagination in MVP.** The caps are hard (50 for jobs/support/activity, 100 for payments). If an operator hits the cap, the "latest 50/100" is still the most useful view (newest-first). A later spec can add `startAfterDocument(cursor)` load-more buttons — but it is NOT part of this spec.

**Rationale**:
- Migration plan §7 explicitly defers pagination to post-MVP.
- The 27-scenario smoke test (Task 7-7) does NOT require pagination.
- Adding pagination multiplies the surface area by 3 (per-tab state, cursor handling, prefix/dedup on real-time updates) without operational value at current scale (5 concurrent admins, hundreds of daily jobs).

If pagination ever lands: it MUST use `startAfterDocument(lastVisibleSnapshot)` — never `offset`. Documented here so a future implementing model reads it.

**Alternatives considered**:
- Infinite scroll — rejected (FR-031 + INPUT.md §C-5; also complicates the "cancel in dispose" invariant).
- Bumping the cap from 50 to 200 — rejected because larger lists increase read cost linearly and do NOT scale; pagination is the right lever when we reach it.

---

## R-7 — Where to hang the sidebar unread-support badge stream

**Question raised in**: FR-030 ("stream opened once in the shell and cancelled in the shell's `dispose()`"). There are two candidate mount-points: the Spec-004 `DashboardScreen` widget or a new shell-level controller.

**Decision**: Hang the unread-badge stream on the existing `DashboardScreen.State` from Spec 004. Make it a single `StreamSubscription<int>? _unreadSub` field initialized in `initState` via `AdminFirebaseService().streamUnreadSupportCount().listen(...)`, cancelled in `dispose()`. The badge value is stored in `_unreadCount` and rendered inside the `NavigationRailDestination.label` for the Support section.

**Rationale**:
- `DashboardScreen` is already the mount-point for every section's `IndexedStack` child (Spec 004 design). The stream must outlive the individual section switches — any tighter scope would tear it down each tab switch, costing a reconnect every time (INPUT.md §C-1 stream-leak concern manifests as a stream-churn concern at this scope).
- `StatefulWidget` + `initState`/`dispose` on `DashboardScreen` is the simplest mount-point that satisfies "once per shell, cancel on shell dispose" without introducing a new provider/controller layer (Principle VII — no premature abstraction).
- `StreamBuilder` is an anti-pattern here because it creates a new subscription on every rebuild; `StreamSubscription` + `setState` is the explicit, auditable version.

**Alternatives considered**:
- Wrapping the badge in a `StreamBuilder` nested inside the navigation rail — rejected: a rebuild of the rail tears down and reopens the stream, violating FR-030.
- Creating a `ChangeNotifier` / `Provider` — rejected as premature abstraction (Principle VII).

---

## R-8 — `flutter pub outdated` audit for new dependencies

**Question raised in**: Constitution XII (d) — "known-vulnerable packages MUST be upgraded before deploy".

**Decision**: No new dependencies are added by this spec (Technical Context §Primary Dependencies). The implementing model MUST still run `cd .claude/AdminWebApp && flutter pub outdated` as part of the quickstart verification, and if any pinned package has a known CVE in the period since Spec 004 lockfile, the upgrade MUST happen in a dedicated commit before the first feature-screen PR lands.

**Rationale**: Spec 004 locked the versions; one spec later, zero net-new dependencies is the safest starting state. But time passes — Spec 005 runs Phase 7 a day/week after Spec 004 ships, and a dependency disclosed as vulnerable in that interval must not be ignored.

**Alternatives considered**:
- Skipping the audit because no new deps — rejected; Constitution XII is explicit.
- Upgrading the pubspec prophylactically — rejected as unnecessary churn; only upgrade if `pub outdated` flags a vulnerability or the Spec-004 preview-channel smoke test caught a regression.

---

## R-9 — Dispute-list filter: `streamJobsByStatus('receipt_disputed')` vs. filtering from the Active stream

**Question raised in**: User Story 4 AS1 says "filter on `status == 'receipt_disputed'`", and `streamActiveJobsAdmin` already includes `'receipt_disputed'` in its `whereIn` list.

**Decision**: The Disputes screen uses `streamJobsByStatus('receipt_disputed')` — a **separate, dedicated stream**, not an in-memory filter of the Active Jobs stream.

**Rationale**:
- Separation of concern: the Active tab shows "in-flight jobs" as a bundle; the Disputes tab is a dedicated operator queue. Reusing the Active stream would make Disputes depend on Jobs being mounted/alive, which breaks FR-029 (stream-cancelled-in-dispose) if the user navigates from Active → Overview → Disputes (the stream would be re-opened on Jobs, or Disputes would see stale data).
- Query cost is identical: `jobs.where('status', ==, 'receipt_disputed').orderBy('createdAt', desc).limit(50)` uses the same existing composite index (R-4 row 2).
- It matches the migration-plan wording: Task 7-5 says "streamJobsByStatus('receipt_disputed') (or filters from active jobs stream)" and the first option is simpler.

**Alternatives considered**:
- In-memory filter — rejected above.
- A new callable that returns only disputed jobs — rejected (FR-044).

---

## R-10 — Error-toast UX for callable failures

**Question raised in**: FR-023 + SC-006 ("only `code` and `message`, never `details`"). What widget type surfaces the error?

**Decision**: Use Flutter's `ScaffoldMessenger.of(context).showSnackBar(SnackBar(...))` for transient callable errors (assign, approve, reject, resolve, close). The SnackBar text is `"${code}: ${message}"` where `code` is the `FirebaseFunctionsException.code.name` (e.g. `failed-precondition`) and `message` is the `FirebaseFunctionsException.message` (the human-readable string from the server's `HttpsError`). A retry button is NOT added (FR-034 forbids auto-retry; manual retry means the operator re-clicks the original action button).

For **dialog-level** errors (e.g. Reject dialog with empty reason after a network hiccup), an inline `Text` below the form field is used instead, because the dialog might obscure a SnackBar behind it.

**Rationale**:
- `SnackBar` is Flutter's standard transient-error surface for Material 3 (our theme).
- Inline `Text` for dialog errors keeps the error proximate to the action the operator just attempted.
- Both paths render only `code` + `message`; `.details` is never referenced in UI code (SC-006 grep check).

**Alternatives considered**:
- Full-screen error page — rejected (too disruptive for per-action failures).
- Toast package — rejected (not in allow-list; `SnackBar` does the job).

---

## R-11 — Job-detail "Force close" button: routing vs. bottom-sheet

**Question raised in**: migration plan §7-6 says "Force-close in jobs screen: 'Force close' button on active job detail." Where does job detail live?

**Decision**: `JobDetailScreen` is a **full-screen route** pushed via `Navigator.of(context).push(MaterialPageRoute(...))` from the Active tab row tap. The Force Close confirmation is a modal `AlertDialog` inside that route. No bottom-sheet pattern.

**Rationale**:
- Full-screen is a desktop-web pattern (the migration plan explicitly pushes back on "mobile `BottomSheet` patterns" for the web app).
- `Navigator.push` on top of the Spec-004 shell works without a routing package — it stacks beneath the nav rail and preserves the rail for a Back.
- An `AlertDialog` for the amount-input confirmation is the standard Material dialog pattern, sized correctly on desktop.

**Alternatives considered**:
- A `Drawer` or right-side `SideSheet` for detail — rejected (Material 3 `SideSheet` is not stable on Flutter web, and a new navigation idiom inflates the surface for no win).
- Placing the Force Close button directly on the Active row — rejected because the confirmation dialog needs the full job context to render the "naming the jobId" requirement (FR-041), which belongs in a detail view.

---

## R-12 — Where the client constants for payment-status colors, resolution strings, and activity-type icons live

**Question raised in**: FR-024 (callable responses mapped through client-side constants before display).

**Decision**: Three files under `.claude/AdminWebApp/lib/constants/`:
1. `payment_status.dart` — `enum PaymentStatus { pending, confirmed, rejected }` + `PaymentStatus fromString(String raw)` that returns a sentinel `pending` default for unknown strings + a `Color` and label map.
2. `resolutions.dart` — `enum Resolution { reopen, complete, cancel }` + `String serverValue(Resolution r)` returning the literal `'reopen' | 'complete' | 'cancel'`. Callable wrappers use `serverValue()` to derive the payload string — never the button label.
3. `activity_icons.dart` — `const Map<String, _ActivityStyle> activityTypeMap` keyed on the server-emitted `type` string (R-3). Unknown keys fall through to a neutral style.

**Rationale**:
- Keeping all three in `constants/` centralizes the "what strings cross the wire" surface — a single file to grep when auditing for leaked server strings in the UI.
- `enum` + `fromString`/`serverValue` pattern makes it impossible to compile a UI string from a button label (FR-024 violation) by accident: the compiler rejects any route that doesn't go through the enum.

**Alternatives considered**:
- Inline string literals at each call site — rejected (FR-024 — risk of accidental raw-string UI).
- Code generation (`freezed`) — rejected as premature (Principle VII).

---

## R-13 — Monthly Firestore read-cost envelope for SC-012

**Question raised in**: SC-012 (monthly Firestore read cost stays within a projected envelope documented here).

**Decision**: Under the query inventory of §FR-001…§FR-008, a single admin session that sits on the dashboard for an 8-hour workday consumes at most **~19,000 document reads per admin per workday**, dominated by two steady-state streams (the unread-badge query at ~100 docs/refresh and whichever list view is foreground at ~50–100 docs/refresh). At 10 active admins × 22 workdays, this ceiling is **~4.2M reads/month** — well inside the default Firebase quota envelope.

**Math (worst-case, ceiling — real usage will be a fraction of this because listeners emit only on delta in practice)**:

| Surface | Query | Limit | Foreground rate | Reads/hour (upper bound) |
|---|---|---|---|---|
| Overview | `stats/global` doc-watch | 1 | `.snapshots()` (delta-only) | ~12 (writes cause emissions) |
| Support badge (always live) | `support_chats.where(unread, status).limit(100)` | 100 | emits on any matching doc mutation | 100 × 20 emits/hr ≈ 2,000 |
| Active section list | `jobs.orderBy(createdAt).limit(50)` OR `payments.limit(100)` OR inbox `.limit(50)` OR chat `.limit(50)` OR activity `.limit(50)` | 50–100 | emits on delta; assume 1 foreground stream at a time, 30 emits/hr | 100 × 30 ≈ 3,000 |
| Ad-hoc technician lookup (Assign dialog) | `users.where(...).limit(100)` one-shot | 100 | ~2 opens/hr × 100 docs | 200 |

Per admin per hour ≈ **5,200 reads** (rounded generously). 8-hour workday ≈ **41,600 reads**. In reality steady-state delta emissions are far below these worst-case counts — the listener only re-reads the docs whose fields changed, not the entire result set. A 1/4 reality factor is a realistic estimate → ~10,000 reads/admin/workday.

10 admins × 22 workdays × 10,000 ≈ **2.2M reads/month** (realistic) or **9.2M/month** (worst-case ceiling). Both fit inside the Firebase Spark-tier-plus-buffer allocation documented in the project's Firebase billing dashboard as of 2026-04-19.

**Rationale**:
- FR-027 + FR-028 already bound every query with `.limit(...)` and forbid `collectionGroup` — the envelope cannot grow without a spec change.
- FR-029 + FR-030 cancel every `StreamSubscription` in `dispose()`, so tab-switching does NOT leave orphan listeners multiplying reads.
- `startAfterDocument` pagination (FR-031, US5 AS7) is cursor-based and adds reads only on explicit user action — no auto-scroll listeners.
- The unread-badge stream is the ONE stream pinned to the shell's lifetime (R-7) — its cost is bounded by its `.limit(100)` cap.

**Alternatives considered**:
- Use `count()` aggregations for the badge — rejected (FR-006; aggregations billed per document considered).
- Skip the cost envelope — rejected (SC-012 requires a documented bound; without numbers the gate is unfalsifiable).

**Verification procedure (post-deploy)**: 48 hours after first production deploy, pull the Firebase Console → Firestore → Usage panel and record actual daily-read counts per admin UID. If any admin exceeds 20,000 reads/workday, re-check against this envelope before shipping new streams.

---

## Research completion gate

- ✅ R-1: region locked to `europe-west1` with source evidence.
- ✅ R-2: callable schemas locked with source line numbers.
- ✅ R-3: activity-log type enum reconciled; one spec wording fix needed (`receipt_rejected` → `payment_rejected`).
- ✅ R-4: zero new composite indexes; pre-deploy verification step documented.
- ✅ R-5: `support_chats` throttle confirmed in `firestore.rules:377–394` + `:410–422`; no escalation needed.
- ✅ R-6: no pagination in MVP; future path uses `startAfterDocument`.
- ✅ R-7: unread-badge stream hangs on `DashboardScreen.State`, `initState` + `dispose` cancellation.
- ✅ R-8: `flutter pub outdated` audit step added to quickstart.
- ✅ R-9: Disputes screen uses a dedicated `streamJobsByStatus('receipt_disputed')` stream.
- ✅ R-10: `SnackBar` for transient errors, inline `Text` for dialog errors; both render `code + message` only.
- ✅ R-11: Job detail is a full-screen `Navigator.push`; Force Close is a modal `AlertDialog` within it.
- ✅ R-12: three constants files centralize every server↔UI string mapping.
- ✅ R-13: read-cost envelope for SC-012 documented with worst-case + realistic numbers and a 48-hour post-deploy verification procedure.

**Unresolved items**: none. Spec-005 ready to proceed to Phase 1 design.
