# Feature Specification: Admin Web App Feature Screens

**Feature Branch**: `005-admin-web-features`
**Created**: 2026-04-19
**Status**: Draft
**Input**: User description: "specs/005-admin-web-features/INPUT.md" — implement the six admin dashboard feature screens in `.claude/AdminWebApp/` (Phase 7 of `WOOHOO/Migration_Implementation_Plan.md`), replacing the Phase-6 placeholders with real functionality. Every privileged write flows through an existing Cloud Function (Specs 002/003); every read is a bounded Firestore query; no direct admin writes from the client except the three Low-risk support operations.

---

## Context & Path Override (READ FIRST — non-negotiable)

This spec implements **Phase 7** of `WOOHOO/Migration_Implementation_Plan.md` (Tasks 7-1 through 7-7).

**PATH OVERRIDE.** The migration plan writes about an `admin_web/` folder at the repo root. **This spec overrides that to `.claude/AdminWebApp/`.** Any reference in this spec or the migration plan that says `admin_web/` MUST be interpreted as `.claude/AdminWebApp/`. Rationale: the admin web app will eventually move to its own repo; `.claude/AdminWebApp/` is the agreed holding location within this repo until that move happens. `.claude/` is NOT in `.gitignore`, so the folder is tracked normally.

This spec is deliberately exhaustive because a weaker model will implement the tasks. Every field, file path, query limit, callable name, and error-message rule is stated here so a reviewer can grade the implementation against black-and-white criteria.

**Out of scope for this spec** (deferred to later specs):

- Mobile cleanup (removing `AdminDashboardScreen` and admin methods from `lib/`) — that is Phase 8 / Spec 006.
- Service catalog management, bulk actions, CSV export, advanced search / filtering.
- Cursor pagination beyond the fixed limits below (`limit 50` for jobs, `limit 100` for payments, `limit 50` for support, `limit 50` for activity).
- Dark mode, internationalization, RTL layout work.
- Any new Cloud Functions. All callables named in this spec already exist from Specs 002/003. If the implementing model discovers a missing callable, STOP and escalate — do not add one inside this spec.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Real-Time Operations Overview (Priority: P1) MVP

A signed-in admin lands on the Overview section and immediately sees the six KPIs for the business — total users, total payouts, jobs requested, jobs completed, jobs cancelled, jobs ongoing — streaming live from `stats/global`. No buttons, no writes, no risk. This is the single-pane-of-glass that tells the admin whether the system is healthy.

**Why this priority**: This is the smallest end-to-end slice of the feature phase. It proves the bounded-stream pattern works, lets the admin confirm the Spec 003 event-driven counters are wired correctly, and delivers standalone value even if the other five screens slip. It is also zero-risk because there are no writes.

**Independent Test**: Deploy to a preview channel. Sign in as an admin. The Overview section renders six cards within 3 seconds. Create a new `users/{uid}` document in the Firebase Console; confirm `totalUsers` increments in the admin UI within 5 seconds without a page refresh.

**Acceptance Scenarios**:

1. **Given** the admin is signed in and on the Overview section, **When** the Overview renders, **Then** six KPI cards are shown in this exact order: Total Users (`totalUsers`), Total Payouts (`totalEarnings`, formatted as `{value} EGP`), Jobs Requested (`jobsRequested`), Completed Jobs (`jobsCompleted`), Cancelled Orders (`jobsCancelled`), Active Jobs (`jobsOngoing`).
2. **Given** `stats/global` contains non-zero values, **When** a field in `stats/global` changes, **Then** the matching card updates in place within 5 seconds with no page refresh.
3. **Given** `stats/global` does not exist yet, **When** the Overview renders, **Then** an explicit empty-state message "No stats yet — counters will populate after the first tracked event" is shown, not a crash and not zero-valued cards.
4. **Given** the stream emits an error, **When** the Overview renders, **Then** an error banner with the error message is shown and the six cards are replaced with an inline retry control — the rest of the dashboard shell stays usable.
5. **Given** the admin navigates away from Overview and back, **When** Overview re-mounts, **Then** the stream subscription from the previous mount is confirmed closed (via inspection/logging rule in Edge Cases) so no duplicate stream remains open.

---

### User Story 2 — Assigning a Requested Job to a Technician (Priority: P1)

An admin opens the Jobs section, switches to the Requested sub-tab, picks a pending job, and assigns it to an available technician for the requested service. The assignment flows through the `adminAssignJob` Cloud Function — never a direct Firestore write. On success, the job disappears from the Requested list and the admin sees a success toast. On failure, the error from the callable is surfaced inline and the button re-enables.

**Why this priority**: Job assignment is the most frequent admin action and the primary operational loop the migration is trying to move off mobile. Without it, the web app is read-only and the mobile admin path can't be decommissioned.

**Independent Test**: Seed a job with `status == 'requested'`. From the admin web preview, open the Assign dialog, pick a technician, confirm. Verify the job's `status` transitions to `active` in Firestore and `assignedTechnicianId` is set, and confirm the job disappears from the Requested list in the UI within 2 seconds.

**Acceptance Scenarios**:

1. **Given** the admin is on the Jobs section, **When** the Jobs screen renders, **Then** a top tab bar with three tabs is shown in this order: Requested, Active, Completed.
2. **Given** the Requested tab is active, **When** the tab is viewed, **Then** it streams at most 50 jobs where `status == 'requested'`, ordered by `createdAt desc`. No query in the Requested tab may omit `.limit(50)`.
3. **Given** a Requested row, **When** the admin clicks "Assign", **Then** a dialog opens listing available technicians for the job's `serviceKey`, fetched via a one-shot bounded read (no unbounded stream).
4. **Given** the Assign dialog is open and at least one technician is listed, **When** the admin selects a technician and clicks Confirm, **Then** the `adminAssignJob` callable is invoked with `{ jobId, technicianId }` and the Confirm button is disabled with a loading indicator until the call resolves.
5. **Given** the callable returns success, **When** the response arrives, **Then** the dialog closes, a success toast "Job {jobId} assigned" appears, and the job disappears from the Requested list within 2 seconds. The Confirm button stays disabled for 500 ms after success to prevent double-submit.
6. **Given** the callable returns an error (e.g. `failed-precondition` because the job is no longer `requested`), **When** the response arrives, **Then** the dialog remains open, an inline error message shows the callable's `code` and `message` but never `details`, and the Confirm button re-enables.
7. **Given** the Active tab is active, **When** the tab is viewed, **Then** it streams at most 50 jobs whose `status` is in `['active','technician_accepted','technician_arrived','work_finished','awaiting_customer_approval','receipt_disputed']`, ordered by `createdAt desc`, read-only (no inline Assign button).
8. **Given** the Completed tab is active, **When** the tab is viewed, **Then** it streams at most 50 jobs with `status == 'completed'`, ordered by `createdAt desc`, read-only.
9. **Given** the admin switches between Jobs sub-tabs, **When** a sub-tab is deactivated, **Then** its `StreamSubscription` is cancelled before the next sub-tab's stream is opened.

---

### User Story 3 — Reviewing and Moderating a Payment (Priority: P1)

An admin opens the Payments section, sees a list of up to 100 payments ordered newest-first, and for each PENDING payment can Approve it (one click + confirmation) or Reject it (requires a non-empty reason). Both actions call Cloud Functions; direct Firestore writes to `payments/*` are forbidden from this app.

**Why this priority**: Payment moderation involves money and is the highest-risk admin action. It is also the second-highest-volume action after job assignment. Shipping it on web with a Cloud Function gate is the whole reason the migration is happening.

**Independent Test**: Seed a `payments/*` document with `status == 'PENDING'`. Approve it from the admin web; verify the status becomes `CONFIRMED` and an `activity_log` entry is written with the admin's UID. Repeat with Reject + a reason; verify status becomes `REJECTED` and the reason is stored.

**Acceptance Scenarios**:

1. **Given** the admin is on Payments, **When** the screen renders, **Then** up to 100 payments are streamed ordered by `createdAt desc`. The query MUST use `.limit(100)`.
2. **Given** a payment row, **When** the row renders, **Then** its status is shown as a badge colored PENDING=orange, CONFIRMED=green, REJECTED=red. The color mapping comes from a client-side constant, never from the document.
3. **Given** a PENDING payment row, **When** the row renders, **Then** Approve and Reject buttons are visible. For non-PENDING rows, neither button is rendered.
4. **Given** the admin clicks Approve on a PENDING payment, **When** they confirm the dialog that names the specific `paymentId`, **Then** the `adminApprovePayment` callable is invoked with `{ paymentId }` and the button disables with a spinner until the call resolves.
5. **Given** the admin clicks Reject on a PENDING payment, **When** the Reject dialog opens, **Then** a required reason text field is shown and the Confirm button stays disabled while `reason.trim().isEmpty`.
6. **Given** the Reject dialog with a non-empty reason, **When** the admin confirms, **Then** the `adminRejectPayment` callable is invoked with `{ paymentId, reason }` (trimmed), and `reason.length` is capped at 500 characters on the client before the call.
7. **Given** the callable returns success, **When** the response arrives, **Then** the dialog closes, the row's status badge updates to CONFIRMED or REJECTED within 2 seconds, and the acting button stays disabled for 500 ms after success.
8. **Given** the callable returns an error, **When** the response arrives, **Then** an inline error displays `code` and `message` only (never `details`), and the acting button re-enables.

---

### User Story 4 — Resolving a Disputed Receipt (Priority: P2)

An admin opens the Disputes section, which lists jobs with `status == 'receipt_disputed'`, reviews the dispute, fills in a required reason, optionally sets an override amount (only relevant to the Complete resolution), and picks one of three resolutions: Reopen, Complete, or Cancel. The resolution flows through the `adminResolveDispute` Cloud Function with a hard-coded resolution string — never the button label — and the job disappears from the Disputes list on success.

**Why this priority**: Dispute resolution involves money and customer trust. It is lower-frequency than payments and job assignment, which is why it is P2 rather than P1, but it must be implemented correctly the first time because the resolution types and audit trail are final.

**Independent Test**: Seed a job with `status == 'receipt_disputed'`. From the admin web, Resolve → Complete with a reason and a valid override amount. Verify the job transitions to `completed`, the `activity_log` entry records the resolution type, and the job disappears from the Disputes list.

**Acceptance Scenarios**:

1. **Given** the admin is on Disputes, **When** the screen renders, **Then** up to 50 jobs with `status == 'receipt_disputed'` are streamed ordered by `createdAt desc`. Query MUST use `.limit(50)`.
2. **Given** a dispute row is expanded, **When** the row renders, **Then** three controls are shown in this order: a required reason text field (capped at 1000 chars client-side), an optional override-amount numeric field (enabled only if the Complete action is selected), and three buttons: Reopen, Complete, Cancel.
3. **Given** the reason field is empty or whitespace-only, **When** the admin views the row, **Then** all three resolution buttons are disabled.
4. **Given** the reason field has non-empty trimmed content, **When** the admin clicks a resolution button, **Then** the `adminResolveDispute` callable is invoked with `{ jobId, resolution, reason, overrideAmount? }` where `resolution` is one of the exact string constants `"reopen" | "complete" | "cancel"` from a client-side constants table — NEVER the human-readable button label.
5. **Given** the Complete action is chosen with a non-negative override amount, **When** the callable succeeds, **Then** the job disappears from the Disputes list and a success toast is shown.
6. **Given** two admins resolve the same dispute simultaneously, **When** the second callable returns a `failed-precondition` error, **Then** an inline error message is shown to the losing admin and the row stays visible until the next stream emission removes it.
7. **Given** the override amount is negative, zero with the Complete action, or exceeds 1,000,000 EGP, **When** the admin tries to confirm, **Then** the submit is blocked client-side with an inline validation message, and no callable is invoked.

---

### User Story 5 — Support Inbox and Real-Time Chat (Priority: P2)

An admin opens the Support section, sees an inbox of up to 50 chats ordered by most recent message, with unread chats visually distinguished. Opening an unread chat marks it read (which decrements the sidebar unread badge), and the admin can send a message into the live chat stream or close the chat. These three support operations are the only direct Firestore writes allowed from the admin web app, because they are Low-risk per the migration plan.

**Why this priority**: Support chat is the operational channel to end users and must be available on web. It is P2 (not P1) because its actions are low-risk and can ride on Firestore rules alone — but the feature must ship for the web app to replace the mobile admin experience.

**Independent Test**: Seed a `support_chats/*` doc with `unreadByAdmin == true` and `status == 'open'`. Verify the sidebar badge shows the count. Open the chat → badge decrements. Send a message → it appears in the chat within 2 seconds. Close the chat → status becomes `closed` and the chat moves out of the open filter.

**Acceptance Scenarios**:

1. **Given** the admin is on Support, **When** the inbox renders, **Then** up to 50 chats are streamed ordered by `lastMessageAt desc`. Query MUST use `.limit(50)`.
2. **Given** the sidebar is visible on any section, **When** the dashboard is mounted, **Then** the Support destination shows a red badge with the count of chats where `unreadByAdmin == true AND status == 'open'`, sourced from a bounded `.limit()`-capped stream, NOT a per-render `count()` aggregation.
3. **Given** the admin clicks an unread chat in the inbox, **When** the chat opens, **Then** `markSupportChatReadByAdmin(chatId)` sets `unreadByAdmin = false` and the sidebar badge decrements within 2 seconds.
4. **Given** an open chat is on screen, **When** the admin types a message and sends it, **Then** a new doc is appended to the `support_chats/{chatId}/messages` subcollection with `senderId = currentUser.uid`, `text` (trimmed, capped at 2000 chars client-side), `createdAt = serverTimestamp`, and the parent doc's `lastMessageAt` is updated. The send button is disabled while the write is in flight.
5. **Given** the admin clicks "Close chat", **When** they confirm the dialog that names the chat by its `chatId` rendered through the `safeDocIdForUi` guard (FR-039), **Then** the chat's `status` becomes `'closed'` and `closedAt` is set to server timestamp. The chat leaves any open-only filtered views. The dialog MUST NOT render any user-supplied field (display name, email, last message preview) — only the guarded `chatId`.
6. **Given** the Firestore rule for `sendSupportMessage` enforces a throttle, **When** the admin sends messages rapidly, **Then** excess messages are rejected by the rule and the UI shows the rejection inline; the client MUST NOT implement retry.
7. **Given** a chat is open with more than 50 messages, **When** the chat screen subscribes to `support_chats/{chatId}/messages`, **Then** the initial query MUST be `.orderBy('createdAt', descending: true).limit(50)`. Older pages are loaded ONLY on explicit "Load older" user action via `startAfterDocument(lastFetchedSnap)` — never via `offset`, never via an automatic on-scroll trigger that could unbound the cost envelope.

---

### User Story 6 — Activity Audit Trail and Force-Closing a Job (Priority: P3)

The Activity section shows the last 50 entries from `activity_log`, each with an icon mapped to the event type, a human description, and a timestamp — this is the operator audit trail for every privileged admin action. From the Active Jobs detail view, a rare Force-Close action lets the admin terminate a stuck job (after a confirmation that names the job ID) with a non-negative amount paid, routed through `adminCloseJob`. Force-closing an already-closed job returns success.

**Why this priority**: Force-close is a rare admin action and can be deferred to the tail of the phase. The Activity feed is read-only and straightforward. Both are P3 because the dashboard is operationally usable without them, but the spec must complete them before Phase 8 mobile cleanup (Task 7-7 gate).

**Independent Test**: Trigger any privileged admin action (e.g. assign a job). Verify the event appears in the Activity feed within 3 seconds with the correct icon. Force-close an active job with amount `100`; verify the job transitions to `completed` and an `activity_log` entry is written. Re-attempt force-close on the same job and verify the UI treats the second attempt as a no-op success.

**Acceptance Scenarios**:

1. **Given** the admin is on Activity, **When** the screen renders, **Then** up to 50 `activity_log` entries are streamed ordered by `createdAt desc`. Query MUST use `.limit(50)`.
2. **Given** an activity entry, **When** the entry renders, **Then** its icon and color come from a client-side mapping keyed by `type`: `account_created` → person_add / blue, `job_requested` → pending_actions / orange, `job_completed` → check_circle / green, `job_cancelled` → cancel / red, `payment_rejected` → warning / amber, `dispute_resolved` → gavel / purple. Unknown types fall back to a neutral icon.
3. **Given** the admin is on any job's detail view where `adminClosedAt == null` (i.e. the job is not already closed) — including Requested, Active, and any in-flight status listed in FR-003 — **When** the detail view renders, **Then** a "Force close" button is visible. On jobs where `adminClosedAt != null` the button MUST be hidden.
4. **Given** the admin clicks "Force close", **When** the confirmation dialog opens, **Then** the dialog names the exact `jobId` and shows a required non-negative numeric amount input (capped at 1,000,000 EGP client-side).
5. **Given** a valid amount is entered, **When** the admin confirms, **Then** the `adminCloseJob` callable is invoked with `{ jobId, amountPaid }` and the button disables with a spinner until the call resolves.
6. **Given** the job was already closed by another admin, **When** the callable returns its idempotent success response, **Then** the UI treats the response identically to a first-time success — no error toast.
7. **Given** a negative, zero, or NaN amount is entered, **When** the admin tries to confirm, **Then** client-side validation blocks the submit and no callable call is made.

---

### Edge Cases

- **Query limit bypass**: Any `snapshots()` call anywhere in `.claude/AdminWebApp/lib/` that does not have `.limit(N)` on the preceding chain MUST fail the build (enforced via checklist grep during analyze phase).
- **Stream leaks across tab switches**: Every `StreamSubscription` opened in a widget MUST be cancelled in that widget's `dispose()`. Switching between nav-rail destinations many times MUST not grow the open-stream count beyond the active screen's subscriptions (+/- 1 for transition).
- **Sidebar badge stays fresh across sections**: The support-unread badge stream stays alive for the lifetime of the shell, NOT per destination. It MUST be opened once when the shell mounts and cancelled in the shell's `dispose()`.
- **Double-click on action buttons**: Every callable-invoking button disables for the duration of the call AND for 500 ms after success, to defeat double-submit on slow connections.
- **Reason / message at exactly the cap**: Reason fields at exactly the cap (500 / 1000 / 2000) MUST be accepted. One character over MUST be blocked client-side with an inline counter showing remaining characters near the field.
- **Whitespace-only reason**: A reason of `"   "` MUST be treated as empty — the submit stays disabled.
- **Numeric input edge cases**: `NaN`, `Infinity`, negative numbers, and amounts `> 1,000,000` MUST be blocked client-side. Zero is allowed for Force-Close and Reject-Payment (no-op/penalty semantics), disallowed for Complete-Dispute.
- **Hostile document IDs in dialog text**: Job/payment/chat IDs rendered inside confirmation dialogs MUST match the regex `^[A-Za-z0-9_-]{10,80}$` (lower bound guards against short injection strings; upper bound is intentionally wider than the Firestore auto-ID length of 20 to accept legitimate custom-keyed IDs up to 80 chars). IDs that fail the regex MUST be rendered as the literal string `"<invalid id>"` instead of the raw bytes, to defend against injection via collection-scan-created docs.
- **Callable `details` leakage**: `FirebaseFunctionsException.details` MUST NEVER reach the UI. Only `code` and `message` surface. `details` may be logged in `kDebugMode` only.
- **No auto-retry on callable failure**: A failed callable surfaces the error and waits for the operator. No exponential backoff, no silent retry, no offline queue.
- **Concurrent admin actions**: Two admins acting on the same entity at once — the losing admin MUST see a clear error (from the callable's `failed-precondition` response) and the UI state MUST refresh from the stream on the next emission.
- **Release-build logging**: `print` / `debugPrint` of Firestore document contents is forbidden in release builds. `kDebugMode`-gated logging is allowed but MUST redact `email`, `phone`, `address`, and `screenshotUrl`.
- **New composite indexes**: If any query in this spec requires a new composite index, the index MUST be added to `firestore.indexes.json` with a one-line comment stating which query uses it, and deployed in the SAME commit as the code that depends on it. Shipping code that references a missing index is a spec-failure condition.
- **Callable availability**: If any callable named in this spec is not yet deployed (Specs 002/003 must be live first), the implementing model MUST STOP and escalate — it must NOT define a new callable inside this spec.
- **`.claude` gitignore drift**: If `.gitignore` acquires a `.claude/` entry at any point, the build MUST fail a pre-flight check. The admin web app living under `.claude/AdminWebApp/` depends on this folder being tracked.

---

## Requirements *(mandatory)*

### Functional Requirements

#### Service-layer stubs implemented (§A)

- **FR-001**: The service layer at `.claude/AdminWebApp/lib/services/admin_firebase_service.dart` MUST implement `streamStats()` returning a stream of the single `stats/global` document.
- **FR-002**: The service layer MUST implement `streamJobsByStatus(String status)` as `jobs.where('status', isEqualTo: status).orderBy('createdAt', descending: true).limit(50)`.
- **FR-003**: The service layer MUST implement `streamActiveJobsAdmin()` as `jobs.where('status', whereIn: ['active','technician_accepted','technician_arrived','work_finished','awaiting_customer_approval','receipt_disputed']).orderBy('createdAt', descending: true).limit(50)`.
- **FR-004**: The service layer MUST implement `streamAllPayments()` as `payments.orderBy('createdAt', descending: true).limit(100)`.
- **FR-005**: The service layer MUST implement `streamSupportChats()` as `support_chats.orderBy('lastMessageAt', descending: true).limit(50)`.
- **FR-006**: The service layer MUST implement `streamUnreadSupportCount()` as a bounded `support_chats.where('unreadByAdmin', isEqualTo: true).where('status', isEqualTo: 'open').limit(100)` mapped to `.size` — NOT a per-build `count()` aggregation.
- **FR-007**: The service layer MUST implement `streamActivityLog()` as `activity_log.orderBy('createdAt', descending: true).limit(50)`.
- **FR-008**: The service layer MUST implement `getAvailableTechnicianIdsByService(String serviceKey)` as a one-shot read (`get()`), bounded with `limit(100)`.
- **FR-009**: The callable wrapper at `.claude/AdminWebApp/lib/services/admin_cloud_functions.dart` MUST implement `assignJob({required String jobId, required String technicianId})`, routing the call through a single shared `FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');` field and invoking `_functions.httpsCallable('adminAssignJob')`. Using `FirebaseFunctions.instance` (no region override) is forbidden — it defaults to `us-central1` and returns `not-found` (verified in research R-1).
- **FR-010**: The callable wrapper MUST implement `approvePayment({required String paymentId})`, `rejectPayment({required String paymentId, required String reason})` where `reason.trim().length <= 500`.
- **FR-011**: The callable wrapper MUST implement `resolveDispute({required String jobId, required String resolution, required String reason, double? overrideAmount})`, where `resolution` is constrained to the constants `'reopen' | 'complete' | 'cancel'` and `reason.trim().length <= 1000`.
- **FR-012**: The callable wrapper MUST implement `closeJob({required String jobId, required double amountPaid})` with `amountPaid >= 0 && amountPaid <= 1000000 && !amountPaid.isNaN && !amountPaid.isInfinite`.
- **FR-013**: Direct Firestore writes are allowed only for `markSupportChatReadByAdmin(chatId)`, `closeSupportChat(chatId)`, and `sendSupportMessage({chatId, text})`. Every other write from this app MUST go through a callable (§A-1).
- **FR-013a**: Callable payloads MUST carry ONLY the business-input fields declared in FR-009 through FR-012 (`jobId`, `technicianId`, `paymentId`, `reason`, `resolution`, `overrideAmount`, `amountPaid`). The client MUST NEVER include audit-provenance fields — specifically `assignedBy`, `reviewedBy`, `resolvedBy`, `adminClosedBy`, `assignedAt`, `reviewedAt`, `resolvedAt`, `adminClosedAt`, `actedBy`, or any other `*By` / `*At` key — even if the UI happens to know them. Provenance is set exclusively by the server (Spec 002 callables) from the authenticated context (Constitution Principle XI). Including any of these keys in a payload is a spec-failure condition.

#### Screen-level behaviour (§B)

- **FR-014**: Overview MUST render the six KPI cards in the exact order specified in User Story 1 §1.
- **FR-015**: Jobs MUST expose three sub-tabs (Requested, Active, Completed) in that order.
- **FR-016**: Payments MUST render Approve/Reject buttons only for PENDING rows.
- **FR-017**: Disputes MUST disable the three resolution buttons while the reason field is empty or whitespace-only.
- **FR-018**: Support MUST expose the inbox, per-chat stream, and close action; the sidebar MUST show the unread badge.
- **FR-019**: Activity MUST render the icon/color mapping from User Story 6 §2.
- **FR-020**: Every screen MUST show loading, error, and empty states — none of them may render a raw Firestore error or silently stay blank on error.

#### Privilege & leak prevention (§C — from INPUT.md §A/B)

- **FR-021**: No admin write outside the three allowed support operations may go direct to Firestore. All admin writes on `jobs/*`, `payments/*`, `stats/*`, `activity_log/*` MUST flow through a Cloud Function.
- **FR-022**: Every screen file MUST be mounted beneath the Spec 004 `AuthGate` — no screen may be navigable without it.
- **FR-022a**: When any callable returns `permission-denied` or `unauthenticated`, OR when the `users/{uid}` profile read resolves with `role != 'admin'`, the UI MUST `await FirebaseAuth.instance.signOut()` BEFORE painting any error screen. A "you are not an admin" message rendered to a still-signed-in non-admin is forbidden — the sign-out call is the security boundary, the error text is only the post-boundary explanation (Constitution Principle IX).
- **FR-023**: The UI MUST NOT render `FirebaseFunctionsException.details`. Only `code` and `message` surface to the user.
- **FR-024**: Callable response fields MUST be mapped through client-side constants tables before display (status strings, resolution types). Raw server strings MUST NEVER be rendered as UI labels.
- **FR-025**: No service-account JSON, reCAPTCHA key, or Firebase config value beyond the public Spec 004 `main.dart` config may be introduced in `.claude/AdminWebApp/`.
- **FR-026**: `print` and `debugPrint` of Firestore document contents are forbidden in release builds. `kDebugMode`-gated logs MUST redact `email`, `phone`, `address`, and `screenshotUrl`.

#### Quota / cost guardrails (§D)

- **FR-027**: Every Firestore query in the codebase MUST carry an explicit `.limit(N)` with N equal to the values stated in FR-001 through FR-008.
- **FR-028**: `collectionGroup` queries are forbidden. Cross-collection joins from the client are forbidden.
- **FR-029**: Streams MUST be opened inside `StreamBuilder` or cancelled in `dispose()`. A `StreamSubscription` stored in `State` MUST have a matching `cancel()` call in `dispose()`.
- **FR-030**: The support unread badge's stream is opened once in the shell and cancelled in the shell's `dispose()`.
- **FR-031**: If pagination is introduced, it MUST use `startAfterDocument(cursor)` — `offset` is forbidden.
- **FR-032**: Any new composite index MUST be declared in `firestore.indexes.json` and deployed atomically with the code that needs it (same commit, same deploy).

#### Rate limiting / abuse surface (§E)

- **FR-033**: Every callable-invoking button MUST disable itself for the duration of the call AND for 500 ms after success.
- **FR-034**: No UI code may implement automatic retry of a failed callable.
- **FR-035**: `sendSupportMessage` respects the existing Firestore rules throttle on `support_chats/{chatId}/messages`. The implementing model MUST verify the throttle exists in `firestore.rules` during `research.md`; if it does not exist, this spec STOPS and the implementing model escalates (this is a change in server-side rules that belongs in a rules-hardening spec, not here).

#### Input sanitization (§F)

- **FR-036**: All free-text fields MUST be trimmed before use. Reason fields MUST be length-capped client-side (reject payment ≤ 500, dispute reason ≤ 1000, support message ≤ 2000) and the UI MUST show a remaining-chars counter.
- **FR-037**: Free-text is rendered through `Text()` only. The following widgets are forbidden anywhere in `.claude/AdminWebApp/lib/`: `Html(`, `HtmlWidget(`, `RichText(`, `Text.rich(`, `Markdown(`, `MarkdownBody(`, `Linkify(`, `SelectableText.rich(`, and any third-party markup-parsing widget. A grep for `rg '\b(Html|HtmlWidget|RichText|Markdown|MarkdownBody|Linkify)\(|Text\.rich\(|SelectableText\.rich\(' .claude/AdminWebApp/lib` MUST return zero matches (SC-007).
- **FR-038**: Numeric inputs (Force-close amount, dispute override amount) MUST reject `NaN`, `Infinity`, and negative values client-side, AND MUST cap at 1,000,000 EGP. Server-side validation lives in the callable (Spec 002); the client layer is defense-in-depth.
- **FR-039**: Job/payment/chat IDs rendered into confirmation dialogs MUST pass a regex guard `^[A-Za-z0-9_-]{10,80}$`, implemented as the pure function `safeDocIdForUi(String id)` in `.claude/AdminWebApp/lib/utils/doc_id_guard.dart` returning either the original `id` or the literal string `"<invalid id>"`. Callers MUST route every ID through this function before passing it to a `Text()` widget — direct string interpolation of raw IDs into dialog text is forbidden.

#### Concurrency & idempotency (§G)

- **FR-040**: Force-closing an already-closed job returns the callable's idempotent success and the UI treats it identically to a first-time success.
- **FR-041**: Assigning a job that is no longer `requested` surfaces the callable's `failed-precondition` error inline; the UI does NOT retry.
- **FR-042**: Resolving a dispute that was just resolved by another admin surfaces the callable's error inline and lets the next stream emission remove the stale row.

#### Out-of-scope enforcement (§H)

- **FR-043**: This spec MUST NOT modify any file under `lib/` (the mobile app). Mobile cleanup is Phase 8 / Spec 006.
- **FR-044**: This spec MUST NOT add any new Cloud Function. All callables named here exist from Specs 002/003.
- **FR-045**: This spec MUST NOT modify `firestore.rules` except the new-index case covered by FR-032. Rules hardening is covered by Spec 001 and the §E throttle-check escalation path.

### Key Entities *(feature involves data)*

- **`stats/global`** — single document, read-only from the admin web app. Fields: `totalUsers`, `totalEarnings`, `jobsRequested`, `jobsCompleted`, `jobsCancelled`, `jobsOngoing`. Mutated exclusively by Spec 003 event-driven functions.
- **`jobs/{jobId}`** — read via three bounded streams. Written from this app only through Cloud Functions (`adminAssignJob`, `adminCloseJob`, `adminResolveDispute`). Key fields used by this spec: `status`, `createdAt`, `serviceKey`, `assignedTechnicianId`, `receipt`.
- **`payments/{paymentId}`** — read via one bounded stream. Written from this app only through Cloud Functions (`adminApprovePayment`, `adminRejectPayment`). Key fields: `status` (one of `PENDING | CONFIRMED | REJECTED`), `createdAt`, `userId`, `amount`, `screenshotUrl`.
- **`support_chats/{chatId}`** — read via one bounded stream + the unread-count stream. Written directly from this app for three Low-risk operations: `unreadByAdmin`, `status`, `closedAt`, `lastMessageAt`. `messages/*` subcollection written via `sendSupportMessage`. Key fields: `unreadByAdmin`, `status`, `lastMessageAt`, `closedAt`.
- **`activity_log/{entryId}`** — read-only via one bounded stream. Written server-side by Cloud Functions. Key fields: `type`, `description`, `createdAt`, `actedBy`.
- **`users/{uid}`** — read one-shot via `getAvailableTechnicianIdsByService` (bounded). Never written from this spec.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An admin can complete the full 27-scenario operator smoke test from Task 7-7 of the migration plan on a preview-channel deploy with zero browser `console.error` entries and zero unhandled Dart exceptions. Entries at `console.info` / `console.log` / `console.warn` DO NOT count as failures (framework-level warnings such as App Check debug notices and `flutter_web` deprecation notices are permitted), but every `console.error` entry — including ones emitted by Firebase SDK handlers — MUST be investigated and either fixed or explicitly waived with a written rationale in the smoke-test artifact.
- **SC-002**: Every screen's first paint of real data happens within 3 seconds of navigating to that section on a broadband connection; KPI / list updates reflect Firestore changes within 5 seconds without a page refresh.
- **SC-003**: Zero admin write in this app bypasses a Cloud Function except the three Low-risk support operations (markRead, closeChat, sendMessage). A reviewer grep for direct writes to `jobs/*`, `payments/*`, `stats/*`, or `activity_log/*` from the admin web codebase returns zero matches.
- **SC-004**: Every Firestore *collection/query* watch in `.claude/AdminWebApp/lib/` carries an explicit `.limit(...)`. Scope: this applies to `Query.snapshots()` and `CollectionReference.snapshots()` — the expressions that could return unbounded result sets. `DocumentReference.snapshots()` (single-document watches, e.g. `FirebaseFirestore.instance.doc('stats/global').snapshots()`) is EXPLICITLY EXEMPT because it streams exactly one document. Audit procedure: list every `.snapshots()` call in `.claude/AdminWebApp/lib/`; classify each as "doc-watch" (exempt) or "query-watch" (must have `.limit(` somewhere on the preceding chain in the same expression); the count of query-watches that lack `.limit(` MUST be zero.
- **SC-005**: Every `StreamSubscription` assigned to a `State` field has a matching `cancel()` call in `dispose()`. A reviewer grep for `StreamSubscription` fields returns a count equal to the count of `cancel()` calls in `dispose()`.
- **SC-006**: No call site renders `FirebaseFunctionsException.details`. A reviewer grep for `.details` on a `FirebaseFunctionsException` returns zero matches in UI code.
- **SC-007**: No free-text field is rendered through `Html`, `RichText`, or any markup-parsing widget. A reviewer grep for those widget names returns zero matches.
- **SC-008**: `flutter analyze` from inside `.claude/AdminWebApp/` exits with "No issues found!".
- **SC-009**: `flutter build web --web-renderer html --release` from inside `.claude/AdminWebApp/` exits 0 and the resulting bundle loads in Chrome with zero `console.error` entries that originate from app-level code (i.e. entries whose stack trace points into `.claude/AdminWebApp/lib/` or into a direct Firebase SDK call made from app code). Framework `console.warn` / `console.info` entries from `flutter_web` bootstrap are permitted.
- **SC-010**: CI (`.github/workflows/admin-web.yml` from Spec 004) stays green throughout the spec; adding new screens does not break `flutter analyze` or `flutter build web`.
- **SC-011**: Every privileged admin write produces exactly one `activity_log` entry (server-side, by the callable). A manual audit via the Activity screen after the 27-scenario smoke test shows one entry per admin action with the acting admin's UID — no duplicates, no missing entries.
- **SC-012**: The admin web app's monthly Firestore read cost stays within the projected envelope (documented in `research.md` during `/speckit.plan`). This bounds the feature-phase against accidental quota spikes.

## Assumptions

- **A-1**: Spec 004 is fully merged. `.claude/AdminWebApp/` contains a working shell with AuthGate, nav rail, Material 3 theme, Firebase init, App Check activated with a real reCAPTCHA Enterprise v3 key, and the hosting block in root `firebase.json`.
- **A-2**: Spec 002 (Cloud Functions) is deployed. The callables `adminAssignJob`, `adminApprovePayment`, `adminRejectPayment`, `adminResolveDispute`, `adminCloseJob` exist in production with the admin-claim/role gate and append to `activity_log` on success.
- **A-3**: Spec 003 (event-driven stats) is deployed. `stats/global` is maintained by `onUserCreated` / `onJobStatusChanged` triggers, not by the client.
- **A-4**: Spec 001 (Firestore rules hardening) is live. Admin read rules, `activity_log` append-only guarantees, and payment/job rule gates are in place as of 2026-04-14.
- **A-5**: The admin has re-authenticated since Spec 001 deployed, so the admin-claim check in Firestore rules passes (if the rules use custom claims). If custom claims are not yet wired, the fallback `users/{uid}.role == 'admin'` path is still live per the dual-check pattern in the migration plan §Risk-6.
- **A-6**: The existing `support_chats/*` Firestore rules include a per-message throttle. The implementing model MUST verify this during `/speckit.plan`'s `research.md`; if the throttle does not exist, STOP and escalate before writing any code (FR-035).
- **A-7**: `.claude/` is NOT listed in `.gitignore` at the start of implementation. Pre-flight grep: `grep -nE '^\.claude(/|$)' .gitignore` MUST return zero matches.
- **A-8**: The implementing model has read `WOOHOO/Migration_Implementation_Plan.md` Phase 7 tasks 7-1 through 7-7 end-to-end before writing any code.
- **A-9**: The admin operator uses Chrome on a desktop (1280×800 or larger). Mobile-browser responsiveness is out of scope.
- **A-10**: Spec 002 deployed all five admin callables (`adminAssignJob`, `adminApprovePayment`, `adminRejectPayment`, `adminResolveDispute`, `adminCloseJob`) to region `europe-west1` (verified in `research.md` R-1). Every callable client in this spec MUST acquire its `FirebaseFunctions` handle via `FirebaseFunctions.instanceFor(region: 'europe-west1')` — using the default `FirebaseFunctions.instance` is forbidden because it binds to `us-central1` and every call returns `not-found`.
- **A-11**: The 27-scenario operator smoke test from Task 7-7 of the migration plan is the acceptance test for this spec. It runs against a preview-channel deploy, NOT local emulator, because the callable auth gate requires real claim tokens.
