# Spec 005 Input Brief — Admin Web App Feature Screens

**Target phase in migration plan:** `WOOHOO/Migration_Implementation_Plan.md` → Phase 7 (Tasks 7-1 through 7-7).
**Builds on:** Spec 004 (admin web shell at `.claude/AdminWebApp/`).
**Created:** 2026-04-19
**Status:** Input brief only — no `spec.md` yet. Will be authored by the implementing model via speckit commands listed at the end of this file.

---

## Path Override (READ FIRST — non-negotiable)

Every path, command, and reference in this spec MUST target `.claude/AdminWebApp/` — NOT `admin_web/`.
- The migration plan and parent docs use `admin_web/` nomenclature; this is a rename-only override. `.claude/AdminWebApp/` is the agreed holding location until the admin app moves to its own repo.
- `.claude/` is NOT gitignored. Files land in normal tracked history.
- Root-level touches allowed: `firebase.json`, `.github/workflows/admin-web.yml`, `functions/` (only if a new callable is needed for a screen). **Do NOT modify `lib/` (mobile app) in this spec** — mobile cleanup is Spec 006 / Phase 8.

---

## Feature Description (raw input for `/speckit.specify`)

Implement the six admin dashboard feature screens inside `.claude/AdminWebApp/`, replacing the Phase 6 placeholders with real, production-ready functionality. Every privileged write goes through a Cloud Function (already deployed in Specs 002/003). Every read is a bounded Firestore query. No direct admin writes from the client.

The six screens, in priority order:

1. **Overview** (P1) — KPI cards backed by a single `stats/global` stream. Six cards: `totalUsers`, `totalEarnings` (formatted as `{value} EGP`), `jobsRequested`, `jobsCompleted`, `jobsCancelled`, `jobsOngoing`. Loading, empty, and error states required. Cards update in real time.
2. **Jobs** (P1) — Three sub-tabs (Requested / Active / Completed) with bounded `limit 50` queries ordered by `createdAt desc`. "Assign" action on Requested rows opens a dialog listing available technicians for the job's service key and calls `adminAssignJob` callable. Force-close on Active job detail calls `adminCloseJob` with a confirmation dialog that names the exact job ID plus a non-negative amount input.
3. **Payments** (P1) — `limit 100` payments stream ordered by `createdAt desc`. Status badges (PENDING orange, CONFIRMED green, REJECTED red). Approve/Reject visible only for PENDING. Reject requires a non-empty reason; confirm button stays disabled while `reason.trim().isEmpty`. Both actions call `adminApprovePayment` / `adminRejectPayment` callables.
4. **Disputes** (P2) — Filtered view on `status == 'receipt_disputed'` (bounded `limit 50`). Per job: summary, required reason text field, optional override amount (only enabled for the `complete` action), and three hard-coded resolution buttons (Reopen / Complete / Cancel) that call `adminResolveDispute`. Resolution strings come from constants, never from button labels.
5. **Support** (P2) — Inbox (`limit 50`, ordered by `lastMessageAt desc`) + per-chat real-time message stream + sidebar unread badge from a `count()` or bounded stream of `support_chats` where `unreadByAdmin == true AND status == 'open'`. `markSupportChatReadByAdmin`, `closeSupportChat`, and `sendSupportMessage` can remain direct Firestore writes (Low-risk per migration plan §Security Blueprint), but MUST respect the existing throttling rules in `firestore.rules`.
6. **Activity** (P3) — Last 50 `activity_log` entries ordered by `createdAt desc`, with icon mapping from the migration plan (Task 7-6).

Final deliverable is the Task 7-7 end-to-end operator smoke test: **27 scenarios must pass on a preview-channel deploy before the spec is accepted.**

---

## Functional Requirements (extract from migration plan Task 7-1 → 7-7)

### Service layer (`.claude/AdminWebApp/lib/services/`)

All methods declared as stubs in Spec 004 are now implemented:

- `streamStats() → Stream<DocumentSnapshot>` — single-doc stream of `stats/global`.
- `streamJobsByStatus(String status) → Stream<QuerySnapshot>` — `jobs.where('status', ==, status).orderBy('createdAt', desc).limit(50)`.
- `streamActiveJobsAdmin() → Stream<QuerySnapshot>` — `jobs.where('status', whereIn, [six active statuses]).orderBy('createdAt', desc).limit(50)`.
- `streamAllPayments() → Stream<QuerySnapshot>` — `payments.orderBy('createdAt', desc).limit(100)`.
- `streamSupportChats() → Stream<QuerySnapshot>` — `support_chats.orderBy('lastMessageAt', desc).limit(50)`.
- `streamUnreadSupportCount() → Stream<int>` — derived from a bounded `support_chats.where('unreadByAdmin', ==, true).where('status', ==, 'open')` stream; map to `.size`.
- `streamActivityLog() → Stream<QuerySnapshot>` — `activity_log.orderBy('createdAt', desc).limit(50)`.
- `getAvailableTechnicianIdsByService(String serviceKey) → Future<List<String>>` — one-shot read, limited.
- `AdminCloudFunctions.assignJob({jobId, technicianId})`.
- `AdminCloudFunctions.approvePayment({paymentId})`.
- `AdminCloudFunctions.rejectPayment({paymentId, reason})`.
- `AdminCloudFunctions.resolveDispute({jobId, resolution, reason, overrideAmount?})`.
- `AdminCloudFunctions.closeJob({jobId, amountPaid})`.
- Direct Firestore writes (Low risk only): `markSupportChatReadByAdmin`, `closeSupportChat`, `sendSupportMessage`.

### UI rules

- Every `StreamSubscription` cancelled in `dispose()` (no leak when tab switches).
- Every callable result wrapped in try/catch — surface `FirebaseFunctionsException.message` inline, never silent.
- Confirmation dialogs for every destructive action (reject payment, resolve dispute, close chat, force-close job) and MUST name the specific entity (job ID, payment ID, chat user name).
- Buttons show a loading spinner while a callable is in flight; UI is non-interactive until the call returns.
- No Firestore query in the codebase may omit `.limit(...)`. This rule is enforced by the checklist (see below).

---

## Non-Functional / Security & Cost Requirements (MUST be in spec.md)

**The implementing model MUST address each of the following items explicitly in the generated spec and plan. These are the concerns the reviewer will grade against.** Do not silently drop any; if an item cannot be met, write an explicit "Complexity Tracking" deviation in `plan.md`.

### A. Privilege isolation

- A-1. The admin web client MUST NOT call any Firestore write that a non-admin could also perform. Every write to `jobs/`, `payments/`, `stats/`, `activity_log/` from this app must go through a Cloud Function. Direct writes are allowed ONLY on `support_chats/*` for the Low-risk operations listed above.
- A-2. The admin-role check from Spec 004 (`users/{uid}.role == 'admin'`) stays the source of truth at the UI layer. Every screen MUST re-check `AuthGate` is mounted above it — no screen is routable without it.
- A-3. Callable error-handling MUST NOT leak the `details` field of `FirebaseFunctionsException` verbatim to the UI — only `code` and `message` are user-visible. `details` may contain internal IDs or payloads we don't want on screen.

### B. Code leak / secret hygiene

- B-1. No service-account JSON, reCAPTCHA key, or Firebase config value beyond the public web SDK config (already in Spec 004 `main.dart`) is allowed anywhere in `.claude/AdminWebApp/`.
- B-2. `print`/`debugPrint` of Firestore document contents is forbidden in release builds. Any `kDebugMode`-gated logging MUST redact `email`, `phone`, `address`, and payment `screenshotUrl`.
- B-3. All callable responses are treated as untrusted for UI rendering — status strings are mapped through a client-side constants table before displaying, never rendered raw.

### C. Firebase quota / cost guardrails

- C-1. Every query MUST carry an explicit `.limit(N)` — values fixed in §Service layer above. No unbounded `snapshots()`.
- C-2. No `collectionGroup` queries, no cross-collection joins from the client. If a screen needs data from two collections, fetch them sequentially with bounded reads.
- C-3. Streams are started lazily via `StreamBuilder`, never in `initState` with a long-lived subscription, unless the widget's `dispose` explicitly cancels it. The spec MUST include the "cancel in dispose" rule as an acceptance scenario.
- C-4. The unread-support badge uses a bounded, indexed query — NOT a `count()` aggregation on every tab switch. If `count()` is used, it is called at most once per navigation event, not on every rebuild.
- C-5. Pagination, if added, uses `startAfterDocument` cursors — not `offset`, which is billed as reads-skipped.
- C-6. A new composite index is only added if a query in this spec needs it. Any new index MUST be declared in `firestore.indexes.json` with a one-line comment saying which query uses it, and deployed atomically with the code that depends on it.

### D. Rate limiting / abuse surface

- D-1. Every callable in `functions/src/admin/*` already validates `context.auth.token.admin == true` (Spec 002). This spec MUST NOT add a new callable without that gate.
- D-2. Client-side debounce: the Approve / Reject / Resolve / Assign / Force-close buttons MUST disable themselves for the duration of the call and for at least 500 ms after success to prevent double-submit on slow connections.
- D-3. Support `sendSupportMessage` MUST respect the existing per-message throttle in `firestore.rules` (if one exists — implementing model must verify in `research.md`). If the rule throttle is not present, this spec adds one; do not rely on UI timing alone.
- D-4. No auto-retry on failed callable calls. A failed call surfaces the error and waits for the operator to click again.

### E. Input sanitization

- E-1. All free-text fields (reject reason, dispute reason, support chat message) MUST be:
    - Trimmed (`reason.trim()`).
    - Length-capped on the client — reject reason ≤ 500 chars, dispute reason ≤ 1000 chars, support message ≤ 2000 chars. These limits MUST also be enforced server-side (either in the callable or in the Firestore rule).
    - NOT HTML-rendered. All text displayed through `Text()`, never `Html()` or `RichText` with user-controlled fragments.
- E-2. Numeric inputs (force-close amount, dispute override amount) MUST:
    - Use `TextInputType.numberWithOptions(decimal: true, signed: false)`.
    - Reject negative values and `NaN`/`Infinity` on both client and server.
    - Cap at a sensible ceiling (e.g. 1,000,000 EGP) to block typo-driven huge writes.
- E-3. Job/payment/chat IDs in confirmation dialogs MUST render through a guard that verifies the ID matches `^[A-Za-z0-9_-]{10,50}$` — defend against hostile doc IDs from collection scans.
- E-4. The implementing model MUST document in `spec.md`'s Edge Cases the behaviour for: empty reason, whitespace-only reason, reason at exactly the char cap, reason one over the char cap, negative amount, zero amount, amount at the cap, amount one over the cap.

### F. Concurrency & idempotency

- F-1. Force-close on an already-closed job returns success from the callable (migration plan §7-6). The UI MUST treat both "closed now" and "was already closed" the same way — no error toast on the second click.
- F-2. Assigning a job that is no longer in `requested` status (race with another admin) surfaces a clear "Job no longer assignable" error, not a generic 500.
- F-3. Dispute resolution is one-shot — after success, the job disappears from the Disputes list; the implementing model MUST describe how the UI handles the race where two admins resolve the same dispute simultaneously.

### G. Observability

- G-1. Every successful admin write-callable appends one entry to `activity_log` (done server-side in Spec 002). The Activity screen is the only place those entries are surfaced; `spec.md` MUST state that the Activity screen is the operator audit trail.
- G-2. Client-side `kDebugMode` logging of callable `code` values is allowed and encouraged for debugging. Release builds MUST NOT log.

---

## Out of scope for Spec 005

- Mobile cleanup — removing `AdminDashboardScreen` from `lib/` is Phase 8 / Spec 006.
- Service catalog management, bulk actions, CSV export, advanced search / filtering — deferred per migration plan §7 "MVP".
- Pagination beyond `limit 50/100` — deferred. If an operator hits the limit, a later spec adds cursor pagination.
- Dark mode, internationalization. The shell is English-only; Material 3 light theme from Spec 004.
- New Cloud Functions. All callables listed above already exist (Specs 002/003). If the implementing model discovers a missing callable, STOP and escalate — do not add one inside this spec.

---

## Dependencies already in place

- ✅ `.claude/AdminWebApp/` scaffold, auth gate, nav rail — Spec 004.
- ✅ Callables `adminAssignJob`, `adminApprovePayment`, `adminRejectPayment`, `adminResolveDispute`, `adminCloseJob` — Spec 002.
- ✅ Event-driven stats triggers — Spec 003.
- ✅ Hardened `firestore.rules` with `affectedKeys()` — Spec 001.

## Known risks for the implementing model

| # | Risk | Mitigation it must build in |
|---|------|-----------------------------|
| 1 | Stream subscriptions left alive across tab switches → quota burn | Checklist item: every `StreamSubscription` cancelled in `dispose()`. Grep must show zero leaks. |
| 2 | An unbounded `snapshots()` slips in during a late edit | `flutter analyze` lint + manual grep for `.snapshots()` without `.limit(` on the preceding line. |
| 3 | Admin double-click submits a callable twice | D-2 debounce + button disable during in-flight call. |
| 4 | Callable error leaks internal IDs via `.details` | A-3 — surface `.code` and `.message` only. |
| 5 | `NaN` / negative / huge amount reaches the callable | E-2 client caps + server-side validation. Log in `research.md` where the server cap lives. |
| 6 | Operator closes a dispute that another admin just resolved | F-3 — define UI behaviour; callable already returns a clear error in Spec 002. |
| 7 | New composite index deployed out of sync with code | C-6 — atomic deploy in `tasks.md`, not a separate PR. |

---

## Speckit commands to generate the artifacts

Run these in order from the repo root. Each one consumes the previous step's output. After each command, stop and skim the produced file — if the model drifted from the brief above, correct it before moving to the next step.

```text
1. /speckit.specify   specs/005-admin-web-features/INPUT.md
   → produces specs/005-admin-web-features/spec.md

2. /speckit.clarify
   → up to 5 targeted clarifying questions, answers folded back into spec.md

3. /speckit.plan
   → produces plan.md, research.md, data-model.md, contracts/, quickstart.md

4. /speckit.tasks
   → produces tasks.md (dependency-ordered, per user-story grouping)

5. /speckit.checklist   security-and-quota
   → produces checklists/security-and-quota.md, enforcing §A–G of this brief

6. /speckit.analyze
   → cross-artifact consistency check across spec/plan/tasks/checklist
```

Do NOT run `/speckit.implement` yet — review each artifact first.
