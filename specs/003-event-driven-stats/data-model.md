# Data Model — Event-Driven Stats (Spec 003)

**Created**: 2026-04-18
**Feature**: [spec.md](./spec.md)  |  **Plan**: [plan.md](./plan.md)

Spec 003 reads existing collections (`users/*`, `jobs/*`), writes one existing document (`stats/global`), and introduces one small new collection (`_event_dedup/*`) for trigger idempotency. No existing field is renamed, re-shaped, or repurposed.

---

## 1. `stats/global` (single document — pre-existing)

**Path**: `stats/global` (Firestore).
**Doc ID**: always the literal string `global`. This is a singleton — no other document in the `stats` collection is written by this spec.
**Before this spec**: written by the mobile client on signup, job creation, job status change, job close.
**After this spec**: written **only** by the three Cloud Functions (`onUserCreated`, `onJobCreated`, `onJobStatusChanged`) via `FieldValue.increment(...)` with `{ merge: true }`. The client-direct write path is closed by the `allow write: if false` rule (FR-006).

### Fields

| Field | Type | Initial value | Modified by | Direction | Notes |
|---|---|---|---|---|---|
| `totalUsers` | `number` (integer) | `0` | `onUserCreated` | `+1` per user doc create | Counts all roles, including `'admin'` |
| `customers` | `number` (integer) | `0` | `onUserCreated` | `+1` when `role == 'customer'` | Unchanged for other roles |
| `technicians` | `number` (integer) | `0` | `onUserCreated` | `+1` when `role == 'technician'` | Unchanged for other roles |
| `jobsRequested` | `number` (integer) | `0` | `onJobCreated` (status=`requested`); `onJobStatusChanged` (from/to `requested`) | `+1` / `-1` | The default creation bucket |
| `jobsOngoing` | `number` (integer) | `0` | `onJobStatusChanged` (from/to any of: `active`, `technician_accepted`, `technician_arrived`, `work_finished`, `awaiting_customer_approval`, `receipt_disputed`) | `+1` / `-1` | All intermediate working statuses collapse into one bucket |
| `jobsCompleted` | `number` (integer) | `0` | `onJobStatusChanged` (to `completed`) | `+1` | Terminal |
| `jobsCancelled` | `number` (integer) | `0` | `onJobStatusChanged` (to `cancelled`) | `+1` | Terminal |
| `totalEarnings` | `number` (float) | `0` | `onJobStatusChanged` (to `completed`, when `amountPaid` is positive finite) | `+amountPaid` | Skipped for zero/missing/invalid `amountPaid` (FR-004, FR-013) |
| `activeChats` | `number` (integer) | `0` | **Nothing in this spec** | — | Explicitly out of scope; will go stale after the rule lockdown. Accepted trade-off (spec §Edge Cases) |

### Write semantics

- All writes use `FieldValue.increment(delta)` with `set({ ... }, { merge: true })`. A missing field on `stats/global` is initialized to the delta.
- A missing `stats/global` document is created by the first increment (merge-write creates the doc). No bootstrap is required in production if the doc has already been seeded by `initializeStatsGlobal()`.
- No read-before-write is performed. Increments are blind atomic operations (the trigger only reads `before`/`after` snapshots from the event payload).

### Read semantics (unchanged)

- Mobile and admin clients continue to read `stats/global` via the existing `allow read: if isSignedIn()` rule. This spec does **not** alter read behavior.

---

## 2. `_event_dedup/{eventId}` (new collection — NEW this spec)

**Path**: `_event_dedup/{eventId}` (Firestore).
**Doc ID**: `event.id` as delivered by the Cloud Functions 2nd-gen Firestore trigger. This value is stable across retries for the same logical event.
**Written by**: all three triggers via the shared `recordEventOrSkip(eventId)` helper in `functions/src/stats/lib/event-dedup.ts`.
**Read by**: nothing. The marker's presence is implicit — its creation-failure IS the dedup signal.

### Fields

| Field | Type | Value | Notes |
|---|---|---|---|
| `processedAt` | `Timestamp` | `FieldValue.serverTimestamp()` | Populated on creation. Useful only for TTL sweeping and debugging |

### Semantics

- `recordEventOrSkip(eventId)` attempts a create-only write (`.create()` on the doc ref). If the create succeeds, the trigger proceeds with the counter increment. If the create fails with `already-exists`, the trigger returns early without incrementing — this is the "replay" branch.
- Collection is swept by either:
    - A Firestore **TTL policy** on `processedAt` with a 24-hour expiration (recommended; configured in console or via `gcloud firestore fields ttls update`), or
    - A scheduled Cloud Function sweeper — **deferred**; TTL policy is the chosen option for this spec.
- Naming: the leading underscore signals "internal / not client-visible" and matches common Firebase conventions. Firestore security rules MUST block all client access to this collection (see §Rules impact below).

### Rules impact

A new rule block MUST be added to `firestore.rules` to block all client reads/writes of `_event_dedup/*`:

```
match /_event_dedup/{eventId} {
  allow read, write: if false;
}
```

This goes into the same atomic deploy as the `stats/{docId}` rule flip (FR-006, FR-010).

---

## 3. Status-to-bucket mapping (logical entity)

**Location**: `functions/src/stats/lib/status-map.ts` (TypeScript source of truth).
**Shape**: `as const` object literal.

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

export type JobStatus = keyof typeof STATUS_TO_BUCKET;
export type StatsBucket = typeof STATUS_TO_BUCKET[JobStatus];
```

**Usage**:
- `onJobCreated`: looks up `STATUS_TO_BUCKET[status]`. If status is missing from the map, logs a warning and returns (FR-013).
- `onJobStatusChanged`: looks up `STATUS_TO_BUCKET[beforeStatus]` and `STATUS_TO_BUCKET[afterStatus]`. If either is missing, logs a warning and returns. If both resolve to the same bucket (e.g., `active → technician_accepted`), returns early with no stats write (no-op for intra-bucket transitions; FR-009 "status did not change" is a stricter form of this).

**Invariants**:
- Every literal in the map must be a valid `keyof typeof stats/global counter fields` on the RHS.
- The client's job state machine uses exactly these status strings; verified at plan time on 2026-04-18.

---

## 4. Collections consumed (read-only at trigger time)

### `users/{uid}`

Read on `onUserCreated`. Fields consumed from the `event.data` snapshot (not a Firestore read — already in the event payload):
- `role` (string): one of `'customer'`, `'technician'`, `'admin'`, or other. Drives which per-role counter is bumped.

### `jobs/{jobId}`

Read on `onJobCreated` and `onJobStatusChanged`. Fields consumed:
- `status` (string): the current status. `onJobCreated` reads the `after.data.status`; `onJobStatusChanged` reads both `before.data.status` and `after.data.status`.
- `amountPaid` (number, optional): read only on `onJobStatusChanged` when the new status is `completed`. Must be a finite non-negative number to be added to `totalEarnings` (FR-004, FR-013).

---

## 5. State transitions (job status machine — reference only)

This spec does not change the state machine. For cross-reference, the client-side job state machine flows are:

```
requested → active → technician_accepted → technician_arrived →
             work_finished → awaiting_customer_approval →
             [completed | receipt_disputed]

receipt_disputed → [completed | cancelled]
<any status>    → cancelled  (limited paths; see mobile job-state code)
```

Stats buckets only care about source/destination, not path length:
- Any transition **into** `requested` → `+1 jobsRequested`
- Any transition **out of** `requested` → `-1 jobsRequested`
- Any transition into an "ongoing" status group → `+1 jobsOngoing` (only when crossing the group boundary, not within)
- etc.

The `onJobStatusChanged` trigger handles the delta by symmetrically applying `-1` to the `before` bucket and `+1` to the `after` bucket, short-circuiting if both are identical (intra-group or no-op transitions).

---

## 6. What this spec does NOT touch

For clarity — the following are explicitly out of scope:
- `activity_log/*`: not written by these triggers. See research R-5.
- `payments/*`: not read, not written. Earnings attribution is derived from `jobs/{jobId}.amountPaid` at completion time, not from the `payments` collection.
- `chats/*` and `active_chats`: no chat trigger. `activeChats` counter goes stale. Future spec.
- `users/{uid}` updates (role change, profile edit): not monitored. Counter is only bumped at user-doc creation.
