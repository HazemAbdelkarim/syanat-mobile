# Data Model: Admin Web App Feature Screens (Spec 005)

**Feature Branch**: `005-admin-web-features`
**Date**: 2026-04-19
**Scope**: Client-side Dart models under `.claude/AdminWebApp/lib/models/` plus the Firestore shapes they deserialize. Zero schema changes to the server. Fields below are the subset the admin web app reads or displays; the full document shape (written by the mobile app and Cloud Functions) may contain additional fields this spec ignores.

---

## Collections read or streamed

| Collection | Read mode | Write mode from this app |
|------------|-----------|--------------------------|
| `stats/global` | Single-doc stream | None (server-only since Spec 003) |
| `jobs/{jobId}` | 3 bounded streams + 1 doc stream (detail view) | None (via callables only) |
| `payments/{paymentId}` | 1 bounded stream | None (via callables only) |
| `support_chats/{chatId}` | 1 bounded stream + unread-count stream | Direct (3 Low-risk fields only) |
| `support_chats/{chatId}/messages/{messageId}` | 1 bounded stream per open chat | Direct (create only) |
| `activity_log/{entryId}` | 1 bounded stream | None (immutable) |
| `users/{uid}` | 1 bounded one-shot `.get()` (available-tech lookup) | None |

Every query carries an explicit `.limit(N)` — no exceptions.

---

## Entity: `StatsGlobal` — `stats/global` (single doc)

**File**: `.claude/AdminWebApp/lib/models/stats_global.dart`

| Field | Type | Source | Shown in |
|-------|------|--------|----------|
| `totalUsers` | `int` | `stats/global.totalUsers` | Overview KPI "Total Users" |
| `totalEarnings` | `num` | `stats/global.totalEarnings` | Overview KPI "Total Payouts" (formatted `${value} EGP`) |
| `jobsRequested` | `int` | `stats/global.jobsRequested` | Overview KPI "Jobs Requested" |
| `jobsCompleted` | `int` | `stats/global.jobsCompleted` | Overview KPI "Completed Jobs" |
| `jobsCancelled` | `int` | `stats/global.jobsCancelled` | Overview KPI "Cancelled Orders" |
| `jobsOngoing` | `int` | `stats/global.jobsOngoing` | Overview KPI "Active Jobs" |

**Validation / defaults**:
- All six fields default to `0` on deserialization if absent — matches the "empty state" requirement in User Story 1 AS3.
- Doc missing entirely → `StreamBuilder` emits the "No stats yet" placeholder (User Story 1 AS3).
- Stream error → error banner with retry, rest of the shell usable (User Story 1 AS4).

**Write surface**: zero. Writes happen exclusively via Spec-003 event-driven triggers (`onUserCreated`, `onJobCreated`, `onJobStatusChanged`).

---

## Entity: `Job` — `jobs/{jobId}`

**File**: `.claude/AdminWebApp/lib/models/job.dart`

| Field | Type | Used by | Source of truth |
|-------|------|---------|-----------------|
| `id` | `String` (doc ID) | Every screen that renders a job | `DocumentSnapshot.id` |
| `status` | `String` | Requested/Active/Completed tabs, Disputes screen, force-close button visibility | server |
| `createdAt` | `Timestamp` | `orderBy` + list ordering + formatted display | server |
| `serviceKey` | `String?` | `AssignDialog` uses it as input to `getAvailableTechnicianIdsByService` | server |
| `assignedTechnicianId` | `String?` | Detail view header | server (written by `adminAssignJob`) |
| `assignedTechnicianName` | `String?` | Detail view header | server (written by `adminAssignJob`) |
| `customerId` | `String?` | Detail view header | server |
| `customerName` | `String?` | Detail view header | server |
| `price` | `num?` | Dispute resolve-panel default for `overrideAmount`, detail view | server |
| `amountPaid` | `num?` | Detail view (after close) | server |
| `receipt` | `Map<String, dynamic>?` | Dispute receipt summary | server |
| `adminClosedAt` | `Timestamp?` | Detail view: hides the Force Close button if non-null | server (written by `adminCloseJob`) |

**Allowed status values** (from migration plan Resolved Blueprint):
`'requested' | 'active' | 'technician_accepted' | 'technician_arrived' | 'work_finished' | 'awaiting_customer_approval' | 'receipt_disputed' | 'completed' | 'cancelled'`

**State transitions (from the admin web's perspective)**:
- `requested → active` via `adminAssignJob`.
- `receipt_disputed → awaiting_customer_approval | completed | cancelled` via `adminResolveDispute`.
- `any non-terminal → completed` via `adminCloseJob` (force-close; sets `adminClosedAt`, idempotent).
- All other transitions happen outside this spec (mobile customer/technician flows).

**Write surface from this app**: zero direct writes. All three transitions above are invoked through callables.

---

## Entity: `Payment` — `payments/{paymentId}`

**File**: `.claude/AdminWebApp/lib/models/payment.dart`

| Field | Type | Used by | Notes |
|-------|------|---------|-------|
| `id` | `String` (doc ID) | Payment list + dialogs | |
| `status` | `PaymentStatus` (enum) | Badge color + Approve/Reject visibility | Decoded via `PaymentStatus.fromString(raw)` — `'PENDING'\|'CONFIRMED'\|'REJECTED'` |
| `createdAt` | `Timestamp` | Sort + display | |
| `userId` | `String` | Row subtitle (customer UID) | |
| `amount` | `num` | Row subtitle (formatted EGP) | |
| `screenshotUrl` | `String?` | Detail view (image preview) — **MUST NOT be logged in debug builds** (Principle VIII) | |
| `reviewedBy` | `String?` | Row subtitle after moderation | server (written by callables) |
| `reviewedAt` | `Timestamp?` | Row subtitle after moderation | server |
| `rejectionReason` | `String?` | Shown on REJECTED rows | server (written by `adminRejectPayment`) |

**`PaymentStatus` enum** (`.claude/AdminWebApp/lib/constants/payment_status.dart`):
- `PaymentStatus.pending` → label "Pending", color orange (Material 3 amber/orange).
- `PaymentStatus.confirmed` → label "Confirmed", color green.
- `PaymentStatus.rejected` → label "Rejected", color red.
- Unknown / missing → falls back to `pending` (defensive default).

**Validation**:
- Approve visible only when `status == PaymentStatus.pending`.
- Reject visible only when `status == PaymentStatus.pending`; Reject dialog's Confirm button disabled while `reason.trim().isEmpty`; reason capped at 500 chars client-side before the callable call (FR-036).

---

## Entity: `SupportChat` — `support_chats/{chatId}`

**File**: `.claude/AdminWebApp/lib/models/support_chat.dart`

| Field | Type | Used by |
|-------|------|---------|
| `id` | `String` (doc ID) | Inbox + chat screen |
| `userId` | `String` | Inbox row (display name lookup) |
| `userDisplayName` | `String?` | Inbox row title, close-confirmation dialog (FR-039 guard applied to the chat `id`, not the name) |
| `status` | `String` (`'open'\|'closed'`) | Inbox filter, sidebar badge query |
| `unreadByAdmin` | `bool` | Inbox highlight + sidebar badge count |
| `lastMessageAt` | `Timestamp?` | `orderBy` + recency label |
| `closedAt` | `Timestamp?` | Detail header after close |

**Allowed client writes** (per `firestore.rules:377–394`, admin path is unrestricted):
- `markSupportChatReadByAdmin(chatId)` → `{ 'unreadByAdmin': false }`.
- `closeSupportChat(chatId)` → `{ 'status': 'closed', 'closedAt': FieldValue.serverTimestamp() }`.
- `sendSupportMessage` → side-effect on parent: `{ 'lastMessageAt': FieldValue.serverTimestamp() }`. (Message itself created under the `messages` subcollection.)

---

## Entity: `SupportMessage` — `support_chats/{chatId}/messages/{messageId}`

**File**: `.claude/AdminWebApp/lib/models/support_message.dart`

| Field | Type | Notes |
|-------|------|-------|
| `id` | `String` (doc ID) | Key in list |
| `senderId` | `String` | Display alignment (admin vs. user) — admin messages right-aligned |
| `text` | `String` | Rendered via `Text()` only — NEVER `RichText` (FR-037) |
| `createdAt` | `Timestamp` | Ordering + display |

**Allowed client writes from admin**:
- Create only (`firestore.rules:410–422` allows admin-unrestricted create with `text is string && text.size() <= 2000`).
- Client-side, `text` is `trim()`-ed and capped at 2000 chars before send (FR-036).

---

## Entity: `ActivityEntry` — `activity_log/{entryId}` (immutable)

**File**: `.claude/AdminWebApp/lib/models/activity_entry.dart`

| Field | Type | Notes |
|-------|------|-------|
| `id` | `String` (doc ID) | Key |
| `type` | `String` | One of the enum values in R-3 (see research.md). Unknown types fall back to neutral icon. |
| `userId` | `String?` | Acting admin UID (for admin-triggered types) or the user UID (for `account_created`) |
| `jobId` | `String?` | Present for `job_*` and `dispute_*` types |
| `paymentId` | `String?` | Present for `payment_*` types |
| `reason` | `String?` | Present for `payment_rejected` and `dispute_resolved` |
| `resolution` | `String?` | Present for `dispute_resolved` (`'reopen'\|'complete'\|'cancel'`) |
| `createdAt` | `Timestamp` | Sort |

**Rendering**:
- Icon + color mapped via `activity_icons.dart` keyed on `type` (R-12).
- Label template: see R-3 table. Any UID/`jobId`/`paymentId` rendered inside the label text is routed through the `doc_id_guard.dart` helper (FR-039) before interpolation.

**Write surface from this app**: zero. `activity_log` is server-immutable (Principle XI; rule enforces `allow update, delete: if false`).

---

## Entity: `TechnicianOption` — projection of `users/{uid}` for assignment UI

**File**: `.claude/AdminWebApp/lib/models/technician_option.dart`

| Field | Type | Used by |
|-------|------|---------|
| `uid` | `String` | `adminAssignJob({ technicianId: uid })` |
| `fullName` | `String` | Dropdown option label |
| `availableForServices` | `List<String>` | Filter sanity check on the client (the `.get()` already filters) |

**Query** (`getAvailableTechnicianIdsByService(String serviceKey)`):
```dart
await FirebaseFirestore.instance
    .collection('users')
    .where('role', isEqualTo: 'technician')
    .where('availableForServices', arrayContains: serviceKey)
    .limit(100)
    .get();
```

Returned as a `List<TechnicianOption>` of size ≤ 100. Composite index confirmed pre-existing (research R-4 row 7).

---

## Client-side value objects (not Firestore-backed)

### `Resolution` (enum)

**File**: `.claude/AdminWebApp/lib/constants/resolutions.dart`

- `Resolution.reopen`, `Resolution.complete`, `Resolution.cancel`.
- `String serverValue(Resolution r)` returns `'reopen' | 'complete' | 'cancel'` — used by `adminResolveDispute` wrapper. The button label is independent of this value (FR-024).

### `PaymentStatus` (enum) — see §Payment entity above.

### `ActivityStyle` (private record inside `activity_icons.dart`)

```dart
({IconData icon, Color color, String labelTemplate}) _ActivityStyle;
```

A `const Map<String, _ActivityStyle> activityTypeMap` is keyed on the server-emitted `type` string. Unknown keys → neutral style (`Icons.info_outline`, grey, `"{type}"` as label).

---

## Deserialization rules (shared across all models)

1. Every `fromFirestore` constructor tolerates missing fields — substitutes safe defaults (empty string, 0, empty list, null).
2. Timestamps are typed as `Timestamp` on the model and converted to `DateTime` at render time via `.toDate()`.
3. `num` is preferred over `int` / `double` for fields that can be either (e.g. `amountPaid`, `price`).
4. Any field whose value will be interpolated into UI user-facing text (e.g. `jobId` inside a confirmation dialog) routes through `utils/doc_id_guard.dart` before rendering (FR-039).
5. No model exposes a raw `Map<String, dynamic>` to UI widgets — every consumer sees strongly-typed fields.

---

## Not modelled in this spec

- Mobile-only fields on `jobs/*` (location, chat log with technician, image attachments) — ignored by the admin web app.
- Mobile-only fields on `payments/*` (client-side IDs) — ignored.
- Mobile-only fields on `support_chats/*` (device metadata) — ignored.
- `techProfiles/*` storage objects — not read by this spec.

Any future feature that needs these fields MUST extend the corresponding model file in a new spec, not in a side-PR.
