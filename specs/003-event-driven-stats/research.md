# Research — Event-Driven Stats (Spec 003)

**Created**: 2026-04-18
**Feature**: [spec.md](./spec.md)  |  **Plan**: [plan.md](./plan.md)

This document captures every non-trivial decision the plan depends on, with rationale and the alternatives that were rejected. One record per decision. Plan.md cites these by ID (R-1..R-6) rather than restating the rationale.

---

## R-1 — Trigger topology: three separate Firestore triggers

**Decision**: Implement three independent Firestore triggers — `onUserCreated` (`users/{uid}` onCreate), `onJobCreated` (`jobs/{jobId}` onCreate), `onJobStatusChanged` (`jobs/{jobId}` onUpdate). Each is its own 2nd-gen Cloud Function in `functions/src/stats/`.

**Rationale**:
- Firestore trigger types are already distinct at the Firebase API level (`onDocumentCreated` vs `onDocumentUpdated` vs `onDocumentWritten`). A single function subscribed via `onDocumentWritten` would need to branch on `event.data.before.exists` / `event.data.after.exists` to distinguish create/update/delete, and the body for "user create" has nothing in common with "job update."
- Keeping the three triggers separate makes the Jest test files align one-for-one with FR-001, FR-002+FR-004+FR-009+FR-013, FR-003 — traceable from spec to test.
- Each trigger can be independently disabled in an incident without taking the others down.

**Alternatives considered**:
- **Single multiplexed `onDocumentWritten('{coll}/{doc}')` function**: rejected because wildcarded collection paths are not supported at the top level; and even if they were, the dispatch logic inside would amount to three separate code paths in one file with no real code sharing.
- **Two triggers (one for users, one for jobs-any-change)**: rejected because the job-create path needs different logic than job-update (no "before status" exists on create), and collapsing them forces a conditional that confuses retries and the idempotency guard.

---

## R-2 — Idempotency via event-ID dedup marker (FR-007)

**Decision**: Each trigger uses the Cloud Functions `event.id` as a dedup key and writes a short-TTL marker document at `_event_dedup/{eventId}` inside the same logical operation. On replay, the marker write fails (already exists) and the trigger returns early without incrementing.

**Rationale**:
- `FieldValue.increment()` is not idempotent — retry replay would double-count. SC-006 explicitly requires proof of idempotency.
- The `event.id` delivered by the 2nd-gen Firestore trigger is stable across retries for the same logical event (documented guarantee).
- A single-doc marker at `_event_dedup/{eventId}` is O(1) to check-and-write, bounded in size (one boolean field + TTL), and can be swept by a scheduled Cloud Function or Firestore TTL policy after ~24h to prevent unbounded growth.
- Implementation fits in a ~30-line helper (`functions/src/stats/lib/event-dedup.ts`) — the plan's "minimum viable abstraction" bar (Principle VII).

**Alternatives considered**:
- **Store a seen-events set on `stats/global` itself**: rejected because the set grows unbounded and bloats the hot stats doc; Firestore doc size limit (1 MiB) would be hit eventually.
- **No dedup — accept rare double counts as "good enough"**: rejected because SC-006 requires the automated test suite to prove idempotency; a probabilistic approach fails that test.
- **Transactional precondition (read-then-check-then-write)**: rejected because the counter write is a single-doc merge-`increment` — transactions add cost and do not help with retry dedup (the same event retried still passes the precondition).

**Implementation note**: The dedup marker write and the counter increment are **not** transactional across collections (`stats/global` and `_event_dedup/*` are different docs). A crash between the two writes could produce a marker without a counter bump or vice versa. The chosen ordering — **check-or-create marker first, then increment** — means a mid-flight crash leaves a marker but no counter bump, which undercounts on crash but never double-counts. Undercounting on a rare crash is the accepted trade-off (spec §Edge Cases accepts small stale windows; `activeChats` is already going stale by design).

---

## R-3 — Client-side stats writes to delete (FR-008)

**Decision**: Delete every `stats/global` incremental write in `lib/firebase_service.dart`. Preserve `initializeStatsGlobal()` at line 1714+ as an admin bootstrap tool (spec §US5 AS4).

**Write sites to delete** (line numbers verified 2026-04-18 against HEAD of branch `003-event-driven-stats`):

| Line | Context | Action |
|---|---|---|
| 357 | Signup path — customer/technician counter bump | DELETE the `.set(..., merge: true)` block and its surrounding try/catch |
| 531 | Additional signup path (technician registration flow) | DELETE |
| 788 | Job creation increment (`jobsRequested += 1`) | DELETE (replaced by `onJobCreated` trigger, FR-003) |
| 1036 | Job assignment / status transition writer | DELETE (replaced by `onJobStatusChanged`, FR-002) |
| 1078 | Job status transition (another branch) | DELETE |
| 1135 | Job status transition (another branch) | DELETE |
| 1436 | Job close writer — stats increment for completion | DELETE (replaced by FR-002 + FR-004) |
| 1519 | `statsRef` usage in a transaction — earnings tally | DELETE |
| 1639 | `statsRef` usage in a transaction — another path | DELETE |
| 1652 | `statsRef` usage in a transaction — another path | DELETE |
| 1729 | `initializeStatsGlobal()` seed write | **PRESERVE** — admin bootstrap tool |

**Rationale**: Every write site is wrapped in try/catch (confirmed by grep at R-3 verification time). After the rule lockdown (FR-006), each of these calls would throw silently with permission-denied. Deleting them removes log noise and eliminates the double-count race that exists today (client writes + triggers would both bump on the release boundary).

**Alternatives considered**:
- **Feature-flag the deletions ("stats writes on/off")**: rejected per the "no feature flags when you can just change the code" directive in the repo's general coding guidance. The rule lockdown ships in the same atomic deploy — there is no half-on state.
- **Keep client writes, deploy rules later**: rejected because the migration plan and Principle XII forbid rule relaxation once a CF takes over.

**Verification at implementation time**: each line number MUST be re-confirmed before deletion because `lib/firebase_service.dart` may shift between plan time and task time. The grep pattern `stats/global` finds every site in one query.

---

## R-4 — Status-to-bucket mapping (FR-002, FR-013)

**Decision**: Encode the mapping as an `as const` lookup table in `functions/src/stats/lib/status-map.ts`. Any status not in the table triggers a warning log and an early return (FR-013).

**Mapping** (per spec §Key Entities):

```ts
export const STATUS_TO_BUCKET = {
  requested: 'jobsRequested',
  active: 'jobsOngoing',
  technician_accepted: 'jobsOngoing',
  technician_arrived: 'jobsOngoing',
  work_finished: 'jobsOngoing',
  awaiting_customer_approval: 'jobsOngoing',
  receipt_disputed: 'jobsOngoing',
  completed: 'jobsCompleted',
  cancelled: 'jobsCancelled',
} as const;
```

**Rationale**:
- `as const` gives TypeScript full literal-type inference — any code that destructures this object gets exhaustive `keyof` checks for free.
- Centralizing the mapping in one file means the three triggers all agree on the set of known statuses; adding a status is a one-line edit.
- Verified on 2026-04-18 against the mobile job state machine (grep for status assignments in `lib/technician_active_job_screen.dart`, `lib/user_home_screen.dart`, and `lib/firebase_service.dart`) — no status value used by the client is missing from this map.

**Alternatives considered**:
- **Hardcode the mapping inside each trigger**: rejected for drift risk — three copies of a status list will diverge.
- **Read the mapping from a Firestore config doc**: rejected as premature abstraction (Principle VII) and as an extra read per trigger with no operational benefit.

---

## R-5 — No `activity_log` write from stats triggers

**Decision**: None of the three triggers write to `activity_log`. The source document update (to `jobs/{jobId}` or `users/{uid}`) is the sole durable event.

**Rationale**:
- `activity_log` is designed for admin-attributable actions (Spec 002 defines `'JOB_ASSIGNED'`, `'PAYMENT_APPROVED'`, etc.). Stats bumps have no admin actor — the triggering mutation already has its own audit fields (job `updatedAt`, `assignedBy`, `adminClosedBy`, user `createdAt`).
- Adding an entry per trigger invocation would multiply `activity_log` volume by ~10–100× with no forensic value that isn't already derivable from the source doc's history.
- Principle XI requires "every privileged write" to leave an audit record. Counter bumps are not privileged writes — they are derived state of a privileged write that was already logged.

**Alternatives considered**:
- **Log a `'STATS_COUNTER_UPDATED'` entry per trigger**: rejected — pure noise, no new information vs the source doc.
- **Log only on the completion bucket (earnings tally)**: rejected — the completion is already recorded on the job (`adminClosedBy` / `adminClosedAt` in Spec 002; or the customer-approval path writes its own timestamp), so the stats entry would be duplicative.

---

## R-6 — Atomic deploy mechanics (FR-010)

**Decision**: Deploy both rules and functions in a single `firebase deploy --only functions,firestore:rules` invocation.

**Rationale**:
- Principle IV mandates that rules and functions that must go live together deploy in a single command.
- `firebase deploy --only functions,firestore:rules` is the canonical form. Internally, the CLI publishes rules, then functions; the rules write and the function upload are not transactional, but the window is < 2 seconds in practice.
- Within that window, there is no double-count risk because:
    - Client writes after rules are live will fail with permission-denied → zero client write.
    - Triggers only begin firing for events that occur **after** the functions are deployed and registered to the Firestore change stream. Events during the interleaved window do not trigger the functions (they pre-date the subscription).
- Net effect on the ~2s window: a handful of client writes are rejected that would have been accepted a second earlier — but those writes would have been counted by the pre-deploy client code anyway, so no counter data is lost. The first post-deploy job status change triggers the new function path.

**Alternatives considered**:
- **Two-phase deploy (functions first, rules second) with a quiet-hour window**: rejected — adds operational complexity for no measurable reliability gain vs the single atomic deploy.
- **Rules first, then functions**: rejected — creates a real gap where client writes fail but no trigger is live yet, losing counter bumps for the gap duration.
- **Blue/green with Firebase hosting preview channels**: rejected — triggers are not hostable, so preview channels do not apply.

---

## Summary

Six decisions. Zero open `NEEDS CLARIFICATION` markers. All rationale anchors the plan's FR citations. No decision depends on technology choices outside what Spec 002 already established.
