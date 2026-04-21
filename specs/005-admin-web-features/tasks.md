---

description: "Task list for Spec 005 — Admin Web App Feature Screens"
---

# Tasks: Admin Web App Feature Screens (Spec 005)

**Input**: Design documents from `specs/005-admin-web-features/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/*`, `quickstart.md`

**Tests**: Not requested in spec. No unit / integration test tasks. Acceptance is gated by the 27-scenario manual smoke test from `quickstart.md` §6 (SC-001).

**Organization**: Tasks are grouped by user story so each can be shipped as an independent increment.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no cross-task dependency)
- **[Story]**: Maps to a user story from `spec.md` (US1–US6)
- **All paths are absolute from the repo root** `C:\users\ltc\Downloads\Syanat-main-mine\Syanat-lastupdate\`. In this spec, every source file lives under `.claude\AdminWebApp\lib\` (Path Override — see `MEMORY.md`).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm the Spec-004 shell is still green and that downstream deps are current. Any failure here STOPS the spec.

- [ ] T001 Confirm Git branch is `005-admin-web-features` via `git branch --show-current`; if not, stop and fix before continuing (per `quickstart.md` §0).
- [ ] T002 Verify the Spec-004 shell exists — confirm `.claude/AdminWebApp/lib/main.dart`, `.claude/AdminWebApp/lib/auth/`, `.claude/AdminWebApp/lib/dashboard/`, `.claude/AdminWebApp/lib/services/` all exist (per `quickstart.md` §0 check 2).
- [ ] T003 Verify the five admin callables exist in `europe-west1` via Firebase Console → Functions → region filter (per `quickstart.md` §0 check 3): `adminAssignJob`, `adminApprovePayment`, `adminRejectPayment`, `adminResolveDispute`, `adminCloseJob`.
- [ ] T004 Verify `stats/global` has the six non-null fields in Firebase Console → Firestore (per `quickstart.md` §0 check 4).
- [ ] T005 [P] Run `flutter pub outdated` inside `.claude\AdminWebApp\`; if any locked dependency has a published CVE since Spec 004, upgrade it in a dedicated commit BEFORE any feature code is written (`quickstart.md` §0 dependency audit, research R-8).
- [ ] T006 [P] Confirm `.claude/` is NOT listed in `.gitignore` via a grep for `^\.claude(/|$)`; zero matches expected (Principle II discipline, `quickstart.md` §Prerequisites item 6).

**Checkpoint**: Environment is verified; proceed to Phase 2.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Build every shared module (constants, models, utilities) and replace the Spec-004 service-layer stubs with real implementations. Every user story below imports from these modules, so nothing in Phase 3+ can start until Phase 2 is fully green (`flutter analyze` → `No issues found!`).

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

### Constants (4 files)

- [X] T007 [P] Create `.claude\AdminWebApp\lib\constants\resolutions.dart` defining `enum Resolution { reopen, complete, cancel }` plus `serverValue(Resolution)` and `displayLabel(Resolution)` per `contracts/constants.md` §`resolutions.dart` (enables FR-024 compile-time safety).
- [X] T008 [P] Create `.claude\AdminWebApp\lib\constants\payment_status.dart` defining `enum PaymentStatus { pending, confirmed, rejected }`, `paymentStatusFromString(String?)`, `paymentStatusColor(PaymentStatus)`, `paymentStatusLabel(PaymentStatus)` per `contracts/constants.md` §`payment_status.dart`.
- [X] T009 [P] Create `.claude\AdminWebApp\lib\constants\job_status.dart` defining `enum JobStatus` (9 values), `const Map<JobStatus,String> jobStatusServerValue`, and `const List<String> activeJobStatusStrings` per `contracts/constants.md` §`job_status.dart`.
- [X] T010 [P] Create `.claude\AdminWebApp\lib\constants\activity_icons.dart` defining `class ActivityStyle`, `const Map<String,ActivityStyle> activityTypeMap` (9 server-emitted types: `job_assigned`, `job_force_closed`, `dispute_resolved`, `payment_approved`, `payment_rejected`, `account_created`, `job_requested`, `job_completed`, `job_cancelled`), and `const ActivityStyle unknownActivityStyle` per `contracts/constants.md` §`activity_icons.dart`. Grep `functions/src/stats/*` before including `account_created`/`job_requested`/`job_completed`/`job_cancelled` — remove any row whose type is not actually emitted (research R-3).

### Utilities (3 files)

- [X] T011 [P] Create `.claude\AdminWebApp\lib\utils\doc_id_guard.dart` exposing `String safeDocIdForUi(String raw)` that validates the doc ID matches `^[A-Za-z0-9_-]{10,80}$` and returns a placeholder `'<invalid id>'` otherwise (FR-039, SC-007 XSS defense).
- [X] T012 [P] Create `.claude\AdminWebApp\lib\utils\callable_errors.dart` exposing `class CallableErrorView { final String code; final String message; }` and `CallableErrorView fromException(Object error)` per `contracts/admin-cloud-functions.md` §Error handling. **MUST NOT read `error.details`** (FR-023, SC-006 grep gate).
- [X] T013 [P] Create `.claude\AdminWebApp\lib\utils\numeric_input.dart` exposing `TextInputFormatter` + validator that caps decimals to 2, accepts only non-negative finite values, and enforces the ≤ 1,000,000 ceiling (FR-038).

### Models (7 files)

- [X] T014 [P] Create `.claude\AdminWebApp\lib\models\stats_global.dart` defining `class StatsGlobal` with the 6 counter fields + `fromDocumentSnapshot` factory per `data-model.md` §StatsGlobal.
- [X] T015 [P] Create `.claude\AdminWebApp\lib\models\job.dart` defining `class Job` with all fields from `data-model.md` §Job + `fromFirestore(DocumentSnapshot)` factory that decodes `status` via the reverse lookup on `jobStatusServerValue` (T009).
- [X] T016 [P] Create `.claude\AdminWebApp\lib\models\payment.dart` defining `class Payment` + `fromFirestore` factory that decodes `status` via `paymentStatusFromString` (T008) per `data-model.md` §Payment.
- [X] T017 [P] Create `.claude\AdminWebApp\lib\models\support_chat.dart` defining `class SupportChat` + `fromFirestore` factory per `data-model.md` §SupportChat.
- [X] T018 [P] Create `.claude\AdminWebApp\lib\models\support_message.dart` defining `class SupportMessage` + `fromFirestore` factory per `data-model.md` §SupportMessage.
- [X] T019 [P] Create `.claude\AdminWebApp\lib\models\activity_entry.dart` defining `class ActivityEntry` + `fromFirestore` factory; `type` is kept as a raw `String` (not an enum) so unknown server types render `unknownActivityStyle` without throwing (research R-3).
- [X] T020 [P] Create `.claude\AdminWebApp\lib\models\technician_option.dart` defining `class TechnicianOption` with `id`, `name`, `phone` + `fromDoc(DocumentSnapshot)` factory per `data-model.md` §TechnicianOption.

### Service layer — `admin_firebase_service.dart`

- [X] T021 In `.claude\AdminWebApp\lib\services\admin_firebase_service.dart`, REMOVE the three deferred stubs: `fetchRecentUsers`, `fetchRecentActivity`, `initializeStatsGlobal` (contract `admin-firebase-service.md` §Methods REMOVED). Any caller imports must be updated or deleted in the same edit.
- [X] T022 In `.claude\AdminWebApp\lib\services\admin_firebase_service.dart`, implement `streamJobsByStatus(String status)` per the exact query in `contracts/admin-firebase-service.md` §`streamJobsByStatus` — include the `.limit(50)` and the `ArgumentError` for unknown statuses.
- [X] T023 In `.claude\AdminWebApp\lib\services\admin_firebase_service.dart`, implement `streamActiveJobsAdmin()` using `activeJobStatusStrings` (from T009) in the `whereIn` clause, ordered by `createdAt desc`, `.limit(50)`.
- [X] T024 In `.claude\AdminWebApp\lib\services\admin_firebase_service.dart`, implement `streamAllPayments()` per the exact query in `contracts/admin-firebase-service.md` §`streamAllPayments` — include the `.limit(100)`.
- [X] T025 In `.claude\AdminWebApp\lib\services\admin_firebase_service.dart`, implement `streamSupportChats()` per the exact query in `contracts/admin-firebase-service.md` §`streamSupportChats` — include the `.limit(50)`.
- [X] T026 In `.claude\AdminWebApp\lib\services\admin_firebase_service.dart`, implement `streamUnreadSupportCount()` as a bounded `.limit(100)` stream that `.map((snap) => snap.size)` (NOT `.count()` aggregation — FR-006, research R-7).
- [X] T027 In `.claude\AdminWebApp\lib\services\admin_firebase_service.dart`, implement `streamActivityLog()` per the exact query in `contracts/admin-firebase-service.md` §`streamActivityLog` — include the `.limit(50)`.
- [X] T028 In `.claude\AdminWebApp\lib\services\admin_firebase_service.dart`, implement `getAvailableTechnicianIdsByService(String serviceKey)` as a one-shot `.get()` with `.limit(100)` and `TechnicianOption.fromDoc` mapping per `contracts/admin-firebase-service.md` §`getAvailableTechnicianIdsByService`.
- [X] T029 In `.claude\AdminWebApp\lib\services\admin_firebase_service.dart`, implement `markSupportChatReadByAdmin(String chatId)` as the exact `{'unreadByAdmin': false}` update (allowed by `firestore.rules:377–384`).
- [X] T030 In `.claude\AdminWebApp\lib\services\admin_firebase_service.dart`, implement `closeSupportChat(String chatId)` as the exact `{'status':'closed','closedAt':FieldValue.serverTimestamp()}` update.
- [X] T031 In `.claude\AdminWebApp\lib\services\admin_firebase_service.dart`, implement `sendSupportMessage({chatId, text})` with client-side trim + 2000-char cap, then the sequential two-write pattern (message add → chat update) per `contracts/admin-firebase-service.md` §`sendSupportMessage`.
- [ ] T032 Run `flutter analyze` inside `.claude\AdminWebApp\`; MUST report `No issues found!` before proceeding to T033. (Gate: service-layer clean.)

### Callable wrappers — `admin_cloud_functions.dart`

- [X] T033 In `.claude\AdminWebApp\lib\services\admin_cloud_functions.dart`, declare a single shared field `final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');` and route every `httpsCallable(...)` through it (research R-1, FR-025). **MUST NOT use `FirebaseFunctions.instance`** — `us-central1` default silently breaks every call.
- [X] T034 In `.claude\AdminWebApp\lib\services\admin_cloud_functions.dart`, implement `assignJob({jobId, technicianId})` wrapping `adminAssignJob` per `contracts/admin-cloud-functions.md` §`assignJob` — include the `ArgumentError` defence and the `res.data['ok'] == true` assertion.
- [X] T035 In `.claude\AdminWebApp\lib\services\admin_cloud_functions.dart`, implement `approvePayment({paymentId})` wrapping `adminApprovePayment` per `contracts/admin-cloud-functions.md` §`approvePayment`.
- [X] T036 In `.claude\AdminWebApp\lib\services\admin_cloud_functions.dart`, implement `rejectPayment({paymentId, reason})` with trim + 500-char cap validation, wrapping `adminRejectPayment`, per `contracts/admin-cloud-functions.md` §`rejectPayment`.
- [X] T037 In `.claude\AdminWebApp\lib\services\admin_cloud_functions.dart`, implement `resolveDispute({jobId, resolution: Resolution, reason, overrideAmount?})` using `serverValue(resolution)` in the payload, 1000-char reason cap, `overrideAmount` validation (finite, ≥0, ≤1,000,000) and enforcement that `overrideAmount` MUST be null unless `resolution == Resolution.complete`, per `contracts/admin-cloud-functions.md` §`resolveDispute`.
- [X] T038 In `.claude\AdminWebApp\lib\services\admin_cloud_functions.dart`, implement `closeJob({jobId, amountPaid})` with finite/range validation, wrapping `adminCloseJob`, idempotent on repeat call (research-verified against `functions/src/admin/close-job.ts:41–45`).
- [ ] T039 Run `flutter analyze` inside `.claude\AdminWebApp\`; MUST report `No issues found!` before proceeding. (Gate: callable-wrapper clean.)

### Shell integration (unread badge + dashboard wiring)

- [X] T040 In `.claude\AdminWebApp\lib\dashboard\dashboard_screen.dart`, add one `StreamSubscription<int>? _unreadSub` field on the State, initialize it in `initState` against `AdminFirebaseService().streamUnreadSupportCount()`, store latest count in a `int _unreadCount = 0` field, and cancel it in `dispose()` (research R-7, SC-005). Render the count as a circle badge next to the "Support" nav-rail entry when `_unreadCount > 0`.

**Checkpoint**: Foundation ready. `flutter analyze` is green. Every user story below can now start. Dashboard still shows Spec-004 placeholder widgets for each section — those get replaced in the story phases.

---

## Phase 3: User Story 1 — Real-Time Operations Overview (Priority: P1) 🎯 MVP

**Goal**: Operator sees a live KPI dashboard the moment they sign in. Six cards read from `stats/global` and update in real time as mobile activity fires Spec-003 triggers.

**Independent Test**: Sign in as admin → land on Dashboard → Overview section shows six cards with live counts. In another tab, create a test user through the mobile app sign-up; within 2 seconds the `Users` card in the admin overview increments by one. No browser console errors.

### Implementation for User Story 1

- [X] T041 [P] [US1] Create `.claude\AdminWebApp\lib\overview\widgets\kpi_card.dart` — stateless widget taking `{icon, label, value, color}` and rendering a Card with an `Icon`, the label, and the value as a `Text` widget (NOT `Html` / `RichText` — SC-007). Per `contracts/screen-contracts.md` §Screen: Overview.
- [X] T042 [P] [US1] Create `.claude\AdminWebApp\lib\overview\widgets\error_banner.dart` — stateless widget that takes a `CallableErrorView` (T012) and renders an inline red banner with `"${code}: ${message}"` and a `Retry` button that invokes the provided `onRetry` callback.
- [X] T043 [US1] Create `.claude\AdminWebApp\lib\overview\overview_screen.dart` — `StreamBuilder<DocumentSnapshot>` over `AdminFirebaseService().streamStats()`, decode into `StatsGlobal`, render a `GridView` with six KPI cards (Users, Technicians, Active Jobs, Pending Receipts, Disputes, Revenue). On stream error use `ErrorBanner`. On waiting state show the skeleton loading placeholders (grey shimmer cards). Depends on T014 (model), T041 (widget), T042 (widget).
- [X] T044 [US1] In `.claude\AdminWebApp\lib\dashboard\dashboard_screen.dart`, replace the Spec-004 Overview placeholder widget with `OverviewScreen()`. Do not change routing — the nav-rail `IndexedStack` already hosts it.
- [ ] T045 [US1] Run `flutter analyze` — must remain `No issues found!`.

**Checkpoint**: User Story 1 is independently testable. Ship as MVP-0 if desired.

---

## Phase 4: User Story 2 — Assigning a Requested Job to a Technician (Priority: P1)

**Goal**: Operator sees every job in each lifecycle state across three tabs, opens a Requested job, selects an available technician filtered by service, and assigns — persisted via `adminAssignJob` (the canonical `requested → active` transition). Force-close is wired in US6.

**Independent Test**: Seed or wait for one `requested` job. Open Jobs → Requested tab → pick the job → Assign → technician dropdown populated → pick a technician → Confirm. Button disables during the call; 500 ms post-success lockout re-enables. Firestore shows the job `assignedTechnicianId` updated and `status = 'active'`. SnackBar shows success.

### Implementation for User Story 2

- [X] T046 [P] [US2] Create `.claude\AdminWebApp\lib\jobs\widgets\job_list_item.dart` — stateless row widget taking a `Job` and an `onTap` callback; renders job ID (via `safeDocIdForUi` from T011), service key, customer display, formatted `createdAt`, and a `StatusBadge` colored per `JobStatus`. No raw server strings in UI (FR-024).
- [X] T047 [P] [US2] Create `.claude\AdminWebApp\lib\jobs\widgets\job_list_page.dart` — stateful widget taking a `Stream<QuerySnapshot>` and a title; uses `StreamBuilder` to render a `ListView` of `JobListItem`s, with skeleton loading on waiting and `ErrorBanner` on error.
- [X] T048 [US2] Create `.claude\AdminWebApp\lib\jobs\jobs_screen.dart` — a `DefaultTabController` with three tabs (`Requested`, `Active`, `Completed`), each a `JobListPage` bound to the correct `AdminFirebaseService` stream (`streamJobsByStatus('requested')`, `streamActiveJobsAdmin()`, `streamJobsByStatus('completed')`). Tab state persists on nav-rail switch via the dashboard `IndexedStack`. Depends on T046, T047.
- [X] T049 [US2] Create `.claude\AdminWebApp\lib\jobs\widgets\assign_dialog.dart` — stateful dialog that, on open, calls `AdminFirebaseService().getAvailableTechnicianIdsByService(job.serviceKey)` (T028) and renders a loading spinner until done. Shows a dropdown of `TechnicianOption`s. Confirm button disabled while the future is in flight. On tap, calls `AdminCloudFunctions().assignJob(jobId: job.id, technicianId: picked.id)` and shows a SnackBar on success. On `FirebaseFunctionsException` routes through `CallableErrorView.fromException` (T012) and surfaces `code: message` inline (never `.details` — FR-023). After success the Confirm button stays disabled for 500 ms (FR-033) via a `bool _justSucceeded` + `Timer` — NO `Future.delayed` re-enable pattern (Forbidden pattern list in `contracts/admin-cloud-functions.md`). No auto-retry (FR-034).
- [X] T050 [US2] In `.claude\AdminWebApp\lib\dashboard\dashboard_screen.dart`, replace the Spec-004 Jobs placeholder with `JobsScreen()`. Wire the `JobListItem.onTap` to `Navigator.push` into a full-screen `JobDetailScreen` placeholder (body comes in US6) whose app bar contains an Assign button that opens `AssignDialog` when `job.status == 'requested'`.
- [ ] T051 [US2] Run `flutter analyze` — must remain `No issues found!`.

**Checkpoint**: US1 + US2 both functional and independently testable.

---

## Phase 5: User Story 3 — Reviewing and Moderating a Payment (Priority: P1)

**Goal**: Operator sees all payments in reverse-chronological order with their status. For any `PENDING` payment they can Approve (one-click, confirmation dialog names the paymentId) or Reject with a required reason (≤500 chars).

**Independent Test**: Seed one `PENDING` payment. Open Payments → see the row with a `Pending` badge → tap Approve → confirmation dialog names the payment ID → confirm. Badge flips to `Confirmed` within 2 s via the stream (no optimistic UI). Repeat with a Reject path: Confirm button disabled until reason has characters; counter shows `500 - length`; server write succeeds; badge flips to `Rejected`.

### Implementation for User Story 3

- [X] T052 [P] [US3] Create `.claude\AdminWebApp\lib\payments\widgets\status_badge.dart` — stateless widget taking a `PaymentStatus` enum; looks up color + label via `paymentStatusColor` / `paymentStatusLabel` (T008). Never accepts a raw string (FR-024).
- [X] T053 [P] [US3] Create `.claude\AdminWebApp\lib\payments\widgets\reject_dialog.dart` — stateful dialog with a multiline `TextField` capped at 500 chars via a `maxLength` + `TextInputFormatter.lengthLimitingTextInputFormatter(500)`; shows `500 - reason.length` remaining-counter below the field; Confirm button disabled while `reason.trim().isEmpty`. On Confirm calls `AdminCloudFunctions().rejectPayment(paymentId: p.id, reason: reason)` and closes on success. Error surfacing via `CallableErrorView` (never `.details`).
- [X] T054 [US3] Create `.claude\AdminWebApp\lib\payments\payments_screen.dart` — `StreamBuilder` over `streamAllPayments()` (T024), rendering a `ListView` of `PaymentRow` widgets that show payment ID (via `safeDocIdForUi`), job ID (via `safeDocIdForUi`), amount, created timestamp, a `StatusBadge`, and for `PaymentStatus.pending` two trailing buttons: Approve (opens a confirmation dialog naming the payment ID, then calls `approvePayment`) and Reject (opens `RejectDialog`). Buttons disabled during the in-flight call. Depends on T052, T053.
- [X] T055 [US3] In `.claude\AdminWebApp\lib\dashboard\dashboard_screen.dart`, replace the Spec-004 Payments placeholder with `PaymentsScreen()`.
- [ ] T056 [US3] Run `flutter analyze` — must remain `No issues found!`.

**Checkpoint**: All three P1 user stories are functional. This is the **MVP scope** — spec ships here if US4–US6 are deferred.

---

## Phase 6: User Story 4 — Resolving a Disputed Receipt (Priority: P2)

**Goal**: Operator sees every job in `receipt_disputed` status, opens it, reads the dispute note + prior receipt, picks a resolution (Reopen / Complete / Cancel), and writes a required reason. For Complete they may override the amount.

**Independent Test**: Seed one `receipt_disputed` job. Open Disputes → row present → tap → detail view shows dispute reason + prior amount. Pick Complete → override-amount field becomes enabled → enter `150.00` → write reason → Confirm → CF call succeeds → row disappears from Disputes list via stream update.

### Implementation for User Story 4

- [X] T057 [P] [US4] Create `.claude\AdminWebApp\lib\disputes\widgets\resolve_panel.dart` — stateful panel with (a) three radio buttons labeled via `displayLabel(Resolution)` (never hardcoded strings), (b) a `TextField` for reason capped at 1000 chars with remaining-counter, (c) an amount `TextField` using `numeric_input.dart` formatters (T013) that is only enabled when `Resolution.complete` is picked, (d) three bottom buttons (Reopen / Complete / Cancel) all disabled while `reason.trim().isEmpty`, each invokes `AdminCloudFunctions().resolveDispute(...)` with the selected resolution. Error surfacing via `CallableErrorView`. On `failed-precondition`, SnackBar `"Dispute no longer pending"` (FR-042).
- [X] T058 [US4] Create `.claude\AdminWebApp\lib\disputes\disputes_screen.dart` — `StreamBuilder` over `streamJobsByStatus('receipt_disputed')` (T022, research R-9), rendering a `ListView` of `JobListItem` (T046). On tap, push a `DisputeDetailScreen` that shows the dispute reason + receipt payload + the `ResolvePanel` (T057).
- [X] T059 [US4] In `.claude\AdminWebApp\lib\dashboard\dashboard_screen.dart`, replace the Spec-004 Disputes placeholder with `DisputesScreen()`.
- [ ] T060 [US4] Run `flutter analyze` — must remain `No issues found!`.

**Checkpoint**: P1 + P2-disputes functional.

---

## Phase 7: User Story 5 — Support Inbox and Real-Time Chat (Priority: P2)

**Goal**: Operator sees an inbox of support chats sorted by `lastMessageAt desc`, an unread-count badge on the Support nav-rail entry (already wired in T040), can open a chat, read prior messages in real time, send an admin reply (2000-char cap, empty-string blocked), and Close the chat.

**Independent Test**: Seed one open support chat with an unread customer message. Open Admin → badge shows `1`. Open Support → row visible. Tap row → badge decrements to `0` (the `markSupportChatReadByAdmin` write). Type a reply → Send → message appears in the real-time stream within 2 s. Tap Close → confirmation dialog → confirm → `status = 'closed'` in Firestore; chat disappears from inbox filter.

### Implementation for User Story 5

- [X] T061 [P] [US5] Create `.claude\AdminWebApp\lib\support\widgets\support_chat_row.dart` — stateless row widget showing chat ID (safe), last-message preview (truncated 80 chars), `lastMessageAt`, and an unread dot when `unreadByAdmin == true`.
- [X] T062 [P] [US5] Create `.claude\AdminWebApp\lib\support\widgets\close_chat_dialog.dart` — confirmation dialog that calls `AdminFirebaseService().closeSupportChat(chatId)` (T030) on confirm.
- [X] T063 [US5] Create `.claude\AdminWebApp\lib\support\support_inbox_screen.dart` — `StreamBuilder` over `streamSupportChats()` (T025). On row tap: call `markSupportChatReadByAdmin(chat.id)` (T029), then `Navigator.push` to `SupportChatScreen(chatId: chat.id)`.
- [X] T064 [US5] Create `.claude\AdminWebApp\lib\support\support_chat_screen.dart` — full-screen chat widget with: (a) top-bar Close button that opens `CloseChatDialog`, (b) a `StreamBuilder` over a fresh `.collection('support_chats').doc(chatId).collection('messages').orderBy('createdAt', descending: true).limit(50).snapshots()` stream (add a method on `AdminFirebaseService` if helpful — keep the `.limit(50)` bound, per SC-004), (c) `startAfterDocument` pagination on scroll (no `offset`), (d) bottom composer: `TextField` capped at 2000 chars + Send button disabled while empty or in-flight. On Send, call `sendSupportMessage(chatId: id, text: text)` (T031) then clear the field. The `StreamSubscription` for the messages stream is stored on the State and cancelled in `dispose()` (SC-005).
- [X] T065 [US5] In `.claude\AdminWebApp\lib\dashboard\dashboard_screen.dart`, replace the Spec-004 Support placeholder with `SupportInboxScreen()`.
- [ ] T066 [US5] Run `flutter analyze` — must remain `No issues found!`.

**Checkpoint**: P1 + P2 all functional. US6 is optional-for-MVP.

---

## Phase 8: User Story 6 — Activity Audit Trail and Force-Closing a Job (Priority: P3)

**Goal**: Operator sees the last 50 audit-log entries, ordered by `createdAt desc`, each rendered via `activityTypeMap` (T010). From any job's detail view, a Force-Close button opens a dialog that writes through `adminCloseJob` (idempotent).

**Independent Test**: Perform any admin action (assign a job, approve a payment). Within 2 s an entry appears at the top of Activity with the correct icon and label. Then open a `completed` job, tap Force-Close (even though closed — should still show, since the callable is idempotent), enter a valid amount, confirm → SnackBar `"Job closed"`. Repeat the Force-Close → SnackBar `"Job closed"` again (idempotent, no state change). Open a fresh admin session, open Activity → the force-close entries visible.

### Implementation for User Story 6

- [X] T067 [P] [US6] Create `.claude\AdminWebApp\lib\activity\widgets\activity_tile.dart` — stateless tile taking an `ActivityEntry`, looks up the style via `activityTypeMap[entry.type] ?? unknownActivityStyle`, performs the `labelTemplate` field-substitution pass where `jobId` / `paymentId` values route through `safeDocIdForUi` (T011) and `reason` is clipped at 120 chars with an ellipsis (per `contracts/constants.md` §activity_icons.dart Interpolation rule).
- [X] T068 [US6] Create `.claude\AdminWebApp\lib\activity\activity_screen.dart` — `StreamBuilder` over `streamActivityLog()` (T027) rendering a `ListView` of `ActivityTile`s. Store the `StreamSubscription` on the State and cancel in `dispose()`.
- [X] T069 [P] [US6] Create `.claude\AdminWebApp\lib\jobs\widgets\force_close_dialog.dart` — stateful dialog with an amount `TextField` using `numeric_input.dart` formatters (T013). Dialog title names the specific `jobId` via `safeDocIdForUi` (FR-039). Confirm disabled while amount is invalid. On Confirm calls `closeJob(jobId: id, amountPaid: amount)` (T038). SnackBar `"Job closed"` on success (including idempotent repeat — FR-040). Error via `CallableErrorView`.
- [X] T070 [US6] Create `.claude\AdminWebApp\lib\jobs\job_detail_screen.dart` — full-screen route showing the `Job` fields, the Assign button (already wired via AssignDialog in T049), and a `Force Close` button that opens `ForceCloseDialog` (T069). The Force-Close button is hidden when `job.adminClosedAt != null` (defensive).
- [X] T071 [US6] In `.claude\AdminWebApp\lib\dashboard\dashboard_screen.dart`, replace the Spec-004 Activity placeholder with `ActivityScreen()`.
- [X] T072 [US6] Update the `onTap` wiring in `JobsScreen` (T048) so Requested / Active / Completed tab rows all push `JobDetailScreen` (T070) — consolidating the placeholder route introduced in T050.
- [ ] T073 [US6] Run `flutter analyze` — must remain `No issues found!`.

**Checkpoint**: All 6 user stories functional. Full Spec-005 scope met.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Gate checks, build, deploy, smoke test. No new features introduced here.

- [X] T074 [P] Grep gate SC-004: run `rg '\.snapshots\(\)' .claude/AdminWebApp/lib` — verify every match's preceding chain contains `.limit(`. Any match without `.limit(` is a defect; fix before proceeding.
- [X] T075 [P] Grep gate SC-005: count `StreamSubscription<` field declarations vs `.cancel()` calls inside `dispose()` bodies in `.claude/AdminWebApp/lib`; the two counts must match.
- [X] T076 [P] Grep gate SC-006: run `rg '\.details' .claude/AdminWebApp/lib` — zero matches (FR-023).
- [X] T077 [P] Grep gate SC-007: run `rg 'Html\(|RichText\(' .claude/AdminWebApp/lib` — zero matches (XSS defense).
- [X] T078 [P] Grep gate FR-025: run `rg 'FirebaseFunctions\.instance\b' .claude/AdminWebApp/lib` — must match zero UI code (only the single `instanceFor(region: 'europe-west1')` in `admin_cloud_functions.dart:T033` is allowed).
- [X] T079 [P] Grep gate Principle IX: run `rg "collection\('jobs'\)|collection\('payments'\)|collection\('stats'\)|collection\('activity_log'\)" .claude/AdminWebApp/lib` — every match must be a read (`.snapshots()` / `.get()` / `.doc(...)` reads), never `.update(...)` / `.set(...)` / `.delete(...)`.
- [ ] T080 Run `flutter build web --web-renderer html --release` inside `.claude\AdminWebApp\`. Expected: exit 0; `.claude/AdminWebApp/build/web/index.html` exists (`quickstart.md` §4).
- [ ] T081 Deploy to preview channel: `firebase hosting:channel:deploy preview-e2e --only hosting:syanat-admin`. Capture the preview URL (`quickstart.md` §5). **DO NOT run** `firebase deploy --only functions` or `firebase deploy --only firestore:rules` — out of scope for this spec.
- [ ] T082 Run the 27-scenario smoke-test checklist from `quickstart.md` §6 against the preview URL. For each scenario record: (a) pass/fail, (b) the elapsed time in seconds between navigating to the section and first paint of real data (SC-002 requires ≤ 3 s per section; measure using Chrome DevTools Performance panel or a visible stopwatch), (c) any `console.error` entry with its source URL (SC-001). Save the 27-row table as `specs/005-admin-web-features/smoke-test-results.md`. SC-001 requires 27/27 pass and zero unwaived `console.error` entries; SC-002 requires every measured first-paint to be ≤ 3 s. Any failure blocks T083.
- [ ] T083 Production deploy: `firebase deploy --only hosting:syanat-admin` (`quickstart.md` §7). Only after T082 is fully green.
- [ ] T084 Post-deploy verification per `quickstart.md` §8: open production URL in Chrome, nav every section, zero console errors. Trigger one admin action, confirm `activity_log` has a new entry with the acting admin UID (SC-011).

**Checkpoint**: Spec 005 complete and shipped to production.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: no dependencies; tasks T005 and T006 can run in parallel with T001–T004 (though T001–T004 are sequential verify-style checks).
- **Phase 2 (Foundational)**: depends on Phase 1 completion. **BLOCKS** every user-story phase.
- **Phase 3 (US1)**: depends on Phase 2.
- **Phase 4 (US2)**: depends on Phase 2.
- **Phase 5 (US3)**: depends on Phase 2.
- **Phase 6 (US4)**: depends on Phase 2.
- **Phase 7 (US5)**: depends on Phase 2.
- **Phase 8 (US6)**: depends on Phase 2 AND on T050 (US2 introduces the `JobDetailScreen` placeholder route that T070/T072 consolidate).
- **Phase 9 (Polish)**: depends on whichever user-story phases are shipped (minimum: Phase 3–5 for MVP).

### User Story Dependencies

- **US1 (P1)**: pure-read screen; fully independent after Phase 2.
- **US2 (P1)**: independent of US1; introduces the route-to-detail pattern that US6 consolidates.
- **US3 (P1)**: independent of US1 and US2.
- **US4 (P2)**: reuses `JobListItem` from US2 (T046) — if shipping US4 without US2, duplicate or move that widget. Otherwise independent.
- **US5 (P2)**: independent. Uses the badge-stream field introduced in Phase 2 (T040).
- **US6 (P3)**: requires the `JobDetailScreen` route; US6's T070/T072 finish what US2's T050 stubbed. If US2 is skipped for MVP, US6 must re-create that route.

### Within Each Phase

- **Phase 2**: constants + utilities + models (T007–T020) are all `[P]` — different files, no dependencies — so run in parallel. Service-layer implementations (T021–T031) must follow because they import constants/models. `flutter analyze` gates (T032, T039) are sequential between the two service-layer blocks.
- **Each user story**: widgets before screens before dashboard wiring; `flutter analyze` at the end of each phase.

### Parallel Opportunities

- **Phase 2**: T007–T020 can all run in parallel (14 files, zero cross-dependency).
- **Phase 3**: T041 + T042 are parallel; T043 depends on both.
- **Phase 4**: T046 + T047 are parallel; T048 depends on both. T049 is parallel to T048 (different file).
- **Phase 5**: T052 + T053 parallel; T054 depends on both.
- **Phase 6**: T057 is standalone; T058 depends on T057 AND on T046 (from US2). If shipping US4 before US2 is complete, duplicate T046 first.
- **Phase 7**: T061 + T062 parallel; T063 depends on both; T064 is independent of T061–T063.
- **Phase 8**: T067 + T069 parallel; T068 depends on T067; T070 depends on T069; T072 depends on T070.
- **Phase 9**: T074–T079 (grep gates) all run in parallel.

---

## Parallel Example: Phase 2 (launch 14 foundational files together)

```bash
# All constants + utilities + models are different files and independent.
Task: "T007 Create resolutions.dart"
Task: "T008 Create payment_status.dart"
Task: "T009 Create job_status.dart"
Task: "T010 Create activity_icons.dart"
Task: "T011 Create doc_id_guard.dart"
Task: "T012 Create callable_errors.dart"
Task: "T013 Create numeric_input.dart"
Task: "T014 Create stats_global.dart"
Task: "T015 Create job.dart"
Task: "T016 Create payment.dart"
Task: "T017 Create support_chat.dart"
Task: "T018 Create support_message.dart"
Task: "T019 Create activity_entry.dart"
Task: "T020 Create technician_option.dart"
```

After all 14 land, run `flutter analyze` once as a sanity pass, then proceed sequentially through T021–T031, then T033–T038, with the two analyze-gates T032 and T039 between them.

## Parallel Example: User Story 1 (MVP)

```bash
# Two widget files first
Task: "T041 Create overview/widgets/kpi_card.dart"
Task: "T042 Create overview/widgets/error_banner.dart"
# Then the screen + wiring
Task: "T043 Create overview/overview_screen.dart"
Task: "T044 Wire OverviewScreen into dashboard"
```

---

## Implementation Strategy

### MVP First (US1 + US2 + US3, all P1)

1. Complete **Phase 1** (T001–T006) — environment verified.
2. Complete **Phase 2** (T007–T040) — foundation ready. `flutter analyze` green.
3. Complete **Phase 3** (T041–T045) — Overview live.
4. Complete **Phase 4** (T046–T051) — job assignment live.
5. Complete **Phase 5** (T052–T056) — payment moderation live.
6. Run a **truncated smoke test** — scenarios 1–13 (sign-in, Overview, Jobs, Payments) from `quickstart.md` §6.
7. Ship to preview channel (T081 with a shorter smoke list). Stop here if US4–US6 are deferred.

### Incremental Delivery

- MVP ships after Phase 5.
- Phase 6 (US4 Disputes) ships independently — add smoke-test scenarios 14–18.
- Phase 7 (US5 Support) ships independently — add smoke-test scenarios 19–23.
- Phase 8 (US6 Activity + Force-Close) ships last — add smoke-test scenarios 24–27.
- Each story ships via its own preview-channel deploy; production deploy (T083) is one shot at the end.

### Parallel Team Strategy

Post-Phase-2, stories can be claimed by separate implementers:

- Implementer A: US1 + US3 (both pure-read + moderation; share no files).
- Implementer B: US2 (Jobs + AssignDialog) — sets up the `JobDetailScreen` route US6 extends.
- Implementer C: US5 (Support + chat).
- After B lands, Implementer D: US4 (reuses US2 widgets) + US6 (extends US2's route).

Integration conflicts are minimized because each story adds a fresh folder under `.claude/AdminWebApp/lib/`; the only shared-file edits are the dashboard wiring (T044, T050, T055, T059, T065, T071), which land one per story and are trivially mergeable.

---

## Notes

- **No test tasks** — acceptance is the 27-scenario manual smoke test (T082). If a later spec or reviewer demands automated tests, add a Phase-3b/4b/... with widget tests.
- **Every task has an absolute file path.** `.claude/AdminWebApp/` is the path (Path Override vs Constitution Principle II).
- **Every `flutter analyze` gate must be `No issues found!`** — fix before continuing, never suppress with `// ignore:`.
- **Forbidden patterns** (will fail review): `FirebaseFunctions.instance`, `error.details`, `Html(`, `RichText(`, direct writes to `jobs/` / `payments/` / `stats/` / `activity_log/`, `offset` pagination, `.count()` aggregations, optimistic UI on callable writes, `Future.delayed` used to re-enable buttons (use `Timer` + `_justSucceeded` flag), auto-retry on callable failure.
- **Commit after each logical group** — e.g., after Phase 2 constants+utils+models, after each story phase. The `after_tasks` / `after_implement` hooks remind to commit automatically.
- **Stop at any Checkpoint** to validate the next increment independently against the relevant subset of the 27-scenario smoke test.
