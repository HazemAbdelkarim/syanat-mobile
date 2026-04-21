# Contract: Screen-Level Behaviour

**Scope**: Per-screen widget tree + state + acceptance hooks. Every screen below lives under `.claude/AdminWebApp/lib/` in its own folder (see plan.md §Source Code).

Every screen:
1. Is mounted beneath the Spec-004 `AuthGate`.
2. Declares every `StreamSubscription` in a `State` field and cancels in `dispose()`.
3. Shows loading / empty / error states — never renders a raw Firestore error or silently stays blank.
4. Uses only `Text()` widgets for user-controlled strings — never `Html`, `RichText` with user fragments, or any markup parser (FR-037).
5. Routes every server-sourced string (status, resolution, type) through a `constants/` table (FR-024).

---

## Screen: Overview (`lib/overview/overview_screen.dart`)

**Priority**: P1 (MVP). Implements User Story 1.

**State**: stateless widget — `StreamBuilder<DocumentSnapshot>` wrapping `AdminFirebaseService().streamStats()`.

**Tree**:
```
OverviewScreen (StatelessWidget)
└── StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>
    ├── loading    → centered CircularProgressIndicator
    ├── empty doc  → centered Text "No stats yet — counters will populate after the first tracked event"
    ├── error      → ErrorBanner (reusable) + Retry button (re-subscribes via setState of a stream-key)
    └── data       → GridView of 6 KpiCard widgets in this exact order:
                     1. Total Users       (stats.totalUsers)
                     2. Total Payouts     (stats.totalEarnings, formatted "{value} EGP")
                     3. Jobs Requested    (stats.jobsRequested)
                     4. Completed Jobs    (stats.jobsCompleted)
                     5. Cancelled Orders  (stats.jobsCancelled)
                     6. Active Jobs       (stats.jobsOngoing)
```

**Acceptance hooks**:
- User Story 1 AS1 → the 6 KPI cards are rendered in this order, each has an icon + large value + label.
- User Story 1 AS2 → `StreamBuilder` re-builds on new doc snapshots within the Firestore latency window (≤ 5 s).
- User Story 1 AS3 → missing-doc branch renders the empty-state text.
- User Story 1 AS4 → error-state branch renders the error banner.
- User Story 1 AS5 → statelessness of the widget means no lingering subscription; navigation away + back gets a fresh `StreamBuilder` + subscription. (No explicit `dispose()` needed here.)

**Forbidden**: any optimistic update of `stats/global` from the client. Stats are server-driven (Spec 003).

---

## Screen: Jobs (`lib/jobs/jobs_screen.dart`)

**Priority**: P1. Implements User Story 2.

**State**: `StatefulWidget` with a `TabController(length: 3)` and three child tabs. Each child tab is itself a `StatefulWidget` holding its own `StreamSubscription` (so cancelling on tab teardown is scoped).

**Tree**:
```
JobsScreen (StatefulWidget)
├── TabBar: [Requested, Active, Completed]
└── TabBarView
    ├── RequestedTab (StatefulWidget)
    │   └── StreamBuilder on streamJobsByStatus('requested')
    │       └── ListView of JobListTile(job, onAssign: (job) → AssignDialog)
    ├── ActiveTab (StatefulWidget)
    │   └── StreamBuilder on streamActiveJobsAdmin()
    │       └── ListView of JobListTile(job, onTap: → JobDetailScreen)
    └── CompletedTab (StatefulWidget)
        └── StreamBuilder on streamJobsByStatus('completed')
            └── ListView of JobListTile(job, read-only)
```

**`AssignDialog`** (`lib/jobs/assign_dialog.dart`):
- On mount: calls `getAvailableTechnicianIdsByService(job.serviceKey)` once.
- Shows a `DropdownButtonFormField<TechnicianOption>` populated from the result.
- Confirm button disabled while dropdown is null.
- On confirm: calls `assignJob(jobId: job.id, technicianId: selected.uid)`.
- Success: closes dialog, parent stream removes the job within 2 s, `SnackBar` "Job {jobId} assigned" (doc-id guard applied). Confirm stays disabled for 500 ms after success (FR-033).
- Failure: inline `Text` below the dropdown with `code: message` (FR-023). Confirm re-enables.

**`JobDetailScreen`** (full-screen route, research R-11):
- Push via `Navigator.of(context).push(MaterialPageRoute(...))` from an ActiveTab row tap.
- Shows job summary + receipt + Force Close button (Active only).
- Force Close opens a confirmation `AlertDialog` containing:
  - A `Text` "Force-close job {jobId}?" — `jobId` routed through doc-id guard (FR-039).
  - A numeric `TextFormField` with `numberWithOptions(decimal: true, signed: false)` (FR-038).
  - A Confirm button disabled while amount is invalid.
- On Confirm: `closeJob(jobId: job.id, amountPaid: value)` → on success pop the dialog, `SnackBar` "Job closed".

**Acceptance hooks**:
- User Story 2 AS1 → 3 tabs in exact order.
- User Story 2 AS2 → `streamJobsByStatus('requested')` called with `.limit(50)`.
- User Story 2 AS3 → `AssignDialog` populates from one-shot `getAvailableTechnicianIdsByService`.
- User Story 2 AS4 → Confirm disabled while callable in flight, spinner visible.
- User Story 2 AS5 → success closes dialog + toast + row disappears ≤ 2 s.
- User Story 2 AS6 → failure keeps dialog open, inline error shows code + message only.
- User Story 2 AS7/8 → Active and Completed tabs are read-only; no Assign button.
- User Story 2 AS9 → each child tab's `StreamSubscription` is cancelled in `dispose()` on tab teardown.

---

## Screen: Payments (`lib/payments/payments_screen.dart`)

**Priority**: P1. Implements User Story 3.

**State**: `StatefulWidget` with one `StreamSubscription<QuerySnapshot>` cancelled in `dispose()`.

**Tree**:
```
PaymentsScreen (StatefulWidget)
└── StreamBuilder on streamAllPayments()
    └── ListView of PaymentListTile(payment) where:
        - PaymentListTile shows StatusBadge(status) with color from PaymentStatus enum (constants)
        - If status == PENDING: trailing Row[ Approve button, Reject button ]
        - Else: no trailing actions
```

**Approve flow**:
- Tap Approve → `AlertDialog` "Approve payment {paymentId}?" (doc-id guard).
- Confirm → `approvePayment(paymentId: payment.id)` → on success close dialog + SnackBar "Payment approved".

**Reject flow** (`lib/payments/reject_dialog.dart`):
- Tap Reject → `AlertDialog` with a `TextFormField` (reason, max 500 chars with counter).
- Confirm disabled while `reason.trim().isEmpty`.
- On Confirm → `rejectPayment(paymentId: payment.id, reason: reason.trim())` → on success close + SnackBar.

**Acceptance hooks**:
- User Story 3 AS1 → stream `.limit(100)`.
- User Story 3 AS2 → status color from constants table, never from doc.
- User Story 3 AS3 → Approve/Reject only visible for PENDING.
- User Story 3 AS4 → Approve confirmation names paymentId; button disables + spinner during call.
- User Story 3 AS5 → Reject Confirm stays disabled on whitespace-only reason.
- User Story 3 AS6 → Reject payload carries trimmed reason, ≤ 500 chars.
- User Story 3 AS7 → badge updates ≤ 2 s via stream; button locked 500 ms post-success.
- User Story 3 AS8 → error inline renders code + message, not details.

---

## Screen: Disputes (`lib/disputes/disputes_screen.dart`)

**Priority**: P2. Implements User Story 4.

**State**: `StatefulWidget` with one `StreamSubscription`.

**Tree**:
```
DisputesScreen (StatefulWidget)
└── StreamBuilder on streamJobsByStatus('receipt_disputed')   // research R-9
    └── ListView of ExpansionTile per job, body = ResolvePanel(job)
```

**`ResolvePanel`** (`lib/disputes/resolve_panel.dart`):
- State: `String _reason = ''`, `Resolution? _pendingAction`, `double? _overrideAmount`, `bool _inFlight = false`.
- Tree:
  - `TextFormField` for reason (max 1000 chars, counter visible).
  - `TextFormField` for overrideAmount (numeric, optional) — **enabled only when `_pendingAction == Resolution.complete`** (User Story 4 AS2).
  - Row[ Reopen button, Complete button, Cancel button ] — all disabled while `_reason.trim().isEmpty || _inFlight`.
- On a button tap: sets `_pendingAction`, enables/disables amount field appropriately, then on a second "Confirm" (or same tap for reopen/cancel) invokes `resolveDispute(...)`.
  - Simpler UX: single-tap per resolution button. The override-amount field is toggled visibly when the Complete button is highlighted/selected; the other two buttons ignore override.
- On success: panel collapses, row disappears from the list via the stream.
- On `failed-precondition`: SnackBar "Dispute no longer pending" (FR-042).

**Acceptance hooks**:
- User Story 4 AS1 → stream uses `.limit(50)` with `status == 'receipt_disputed'`.
- User Story 4 AS2 → reason field + overrideAmount (Complete-only) + 3 buttons in order.
- User Story 4 AS3 → all three buttons disabled while reason empty/whitespace.
- User Story 4 AS4 → callable payload carries `serverValue(resolution)` (from constants), not the button label.
- User Story 4 AS5 → Complete with valid override → server-side success → row disappears.
- User Story 4 AS6 → concurrent-resolve race: UI shows error inline, stream updates on next emission.
- User Story 4 AS7 → numeric validation (negative / zero-with-complete / > 1M) blocks submit client-side.

---

## Screen: Support (`lib/support/support_inbox_screen.dart` + `support_chat_screen.dart`)

**Priority**: P2. Implements User Story 5.

**Inbox** (`support_inbox_screen.dart`):
- `StatefulWidget` with one `StreamSubscription<QuerySnapshot>`.
- Tree:
  - `StreamBuilder on streamSupportChats()` → ListView of `ChatListTile(chat)` where unread chats are highlighted (bold title + unread dot).
  - Tap → `markSupportChatReadByAdmin(chat.id)` then `Navigator.push(MaterialPageRoute(builder: (_) => SupportChatScreen(chat)))`.

**Chat screen** (`support_chat_screen.dart`):
- `StatefulWidget` with one `StreamSubscription<QuerySnapshot>` for messages.
- Tree:
  - AppBar with chat user name + "Close chat" action.
  - `StreamBuilder on _messagesStream` → reversed ListView of message bubbles (admin right-aligned).
  - Bottom: `TextFormField` (text, max 2000 chars, counter) + Send `IconButton`.
- Send button disabled while text is whitespace-only OR a send is in flight. On tap: `sendSupportMessage(chatId, text)`; clears field on success.
- Close chat: `AlertDialog` "Close chat with {chat.userDisplayName}?" → confirm → `closeSupportChat(chat.id)` → pop route.

**Sidebar badge wiring** (`dashboard_screen.dart`, research R-7):
- `initState`: `_unreadSub = AdminFirebaseService().streamUnreadSupportCount().listen((n) => setState(() => _unreadCount = n));`
- `dispose`: `_unreadSub?.cancel();`
- `NavigationRailDestination` for Support takes `label: Badge(count: _unreadCount, child: Text('Support'))`.

**Acceptance hooks**:
- User Story 5 AS1 → inbox `.limit(50)`, ordered by `lastMessageAt desc`.
- User Story 5 AS2 → badge stream bounded + `.limit(100)`, no `count()` aggregation.
- User Story 5 AS3 → tap → mark-read → badge decrement within 2 s.
- User Story 5 AS4 → message send writes trimmed text ≤ 2000 chars + updates parent `lastMessageAt`; send button disabled in flight.
- User Story 5 AS5 → Close confirmation names the user name; status flips to `'closed'`, `closedAt` set.
- User Story 5 AS6 → rule rejection surfaces inline; no retry (FR-034).

---

## Screen: Activity (`lib/activity/activity_screen.dart`)

**Priority**: P3. Implements User Story 6 (read-only part).

**State**: `StatefulWidget` with one `StreamSubscription`.

**Tree**:
```
ActivityScreen (StatefulWidget)
└── StreamBuilder on streamActivityLog()
    └── ListView of ActivityEntryTile(entry) where:
        - Leading Icon from activityTypeMap[entry.type]
        - Title from activityTypeMap[entry.type].labelTemplate interpolated with entry fields (doc-id guard on any id)
        - Subtitle: formatted entry.createdAt + entry.userId (last 4 only if it ever becomes a customer UID)
        - Unknown type → neutral style (Icons.info_outline, grey, type string as label)
```

**Acceptance hooks**:
- User Story 6 AS1 → stream `.limit(50)`.
- User Story 6 AS2 → icons/colors come from `activityTypeMap` in constants.
- SC-011 → operator audit trail view after the 27-scenario smoke test (no gaps, no dupes).

---

## Cross-screen invariants

1. **`AuthGate` mounting**: every screen in this contract is reached only through the Spec-004 `DashboardScreen`, which is itself a child of `AuthGate`. Navigator routes pushed from within the dashboard (JobDetailScreen, SupportChatScreen) inherit the same auth tree — MUST NOT create a parallel `MaterialApp` or bypass the gate.
2. **Stream cleanup**: every `_xxxSub` field in a `State` class has a matching `_xxxSub?.cancel()` in `dispose()`. A grep for `StreamSubscription` vs. `cancel()` MUST balance (SC-005).
3. **Button debounce**: every Approve/Reject/Resolve/Assign/Close button uses the same `_inFlight` + `_justSucceeded` pattern — no ad-hoc per-screen debounce implementations.
4. **Error surfaces**: `SnackBar` for screen-level transient errors, inline `Text` for dialog-scoped errors. Both render `code + message` from `CallableErrorView` (see admin-cloud-functions.md §Error handling). Neither reads `.details`.
5. **Doc-id guard**: every `jobId`/`paymentId`/`chatId` interpolated into dialog or label text routes through `utils/doc_id_guard.dart` (FR-039).
6. **No optimistic updates**: the UI waits for the Firestore stream to reflect the new state; it does not locally mutate a list on callable success. Simpler + matches server truth + avoids the split-brain case on server-side validation failure.
