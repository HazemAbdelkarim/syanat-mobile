# Trigger Contracts — Event-Driven Stats (Spec 003)

**Created**: 2026-04-18
**Feature**: [../spec.md](../spec.md)  |  **Plan**: [../plan.md](../plan.md)

Firebase Firestore triggers do not have OpenAPI / gRPC style IDLs. The contract surface is the **event subscription tuple** (resource path + trigger kind + region) plus the **fields consumed** and **deltas produced**. One section per trigger; one-to-one with FR-001, FR-002/FR-004/FR-009/FR-013, FR-003; one-to-one with a Jest `describe` block in `functions/test/stats/*.test.ts`.

---

## 1. `onUserCreated` — FR-001

| Attribute | Value |
|---|---|
| Export name | `onUserCreated` |
| File | `functions/src/stats/on-user-created.ts` |
| Trigger kind | Firestore `onDocumentCreated` (2nd-gen) |
| Resource path | `users/{uid}` |
| Region | `europe-west1` (FR-005) |
| Runtime | Node.js 20 |
| Auth context | None (Firestore triggers have no `context.auth`) |

### Event payload consumed

```ts
event.data.data(): {
  role?: string;   // 'customer' | 'technician' | 'admin' | other
  // — other user fields exist but are not read by this trigger
}
event.id: string;  // used for dedup
event.params.uid: string;  // logged only; not used for logic
```

### Behavior

1. `await recordEventOrSkip(event.id)` — if already processed, return without side effects.
2. Read `role` from `event.data.data()`. Default to `undefined` if missing.
3. Compute increments:
   - `totalUsers: +1` (always)
   - `customers: +1` **iff** `role === 'customer'`
   - `technicians: +1` **iff** `role === 'technician'`
4. Single merge-write to `stats/global` with all applicable `FieldValue.increment(1)` values.

### Error handling

- Top-level try/catch wraps the whole handler. Any thrown error is logged as structured output (`event.id`, `params.uid`, error message) and **not** re-thrown — because re-throwing triggers retries, and dedup already handles idempotency for legitimate retries. Un-retryable errors (e.g., malformed `role` of unexpected type) should not create retry storms.

### Test contract (one Jest `describe` block)

Cases (from spec §US1 Acceptance Scenarios):
- AS1: `role = 'customer'` → `totalUsers +1`, `customers +1`, `technicians` unchanged
- AS2: `role = 'technician'` → `totalUsers +1`, `technicians +1`, `customers` unchanged
- AS3: `role = 'admin'` → `totalUsers +1`, `customers` and `technicians` unchanged
- AS4: missing `stats/global` doc → created with correct initial field values
- Idempotency: replay same `event.id` → no additional increments

---

## 2. `onJobCreated` — FR-003

| Attribute | Value |
|---|---|
| Export name | `onJobCreated` |
| File | `functions/src/stats/on-job-created.ts` |
| Trigger kind | Firestore `onDocumentCreated` (2nd-gen) |
| Resource path | `jobs/{jobId}` |
| Region | `europe-west1` (FR-005) |
| Runtime | Node.js 20 |
| Auth context | None |

### Event payload consumed

```ts
event.data.data(): {
  status?: string;   // typically 'requested' at creation time
  // — other job fields exist but are not read by this trigger
}
event.id: string;
event.params.jobId: string;  // logged only
```

### Behavior

1. `await recordEventOrSkip(event.id)` — idempotency guard.
2. Read `status` from `event.data.data()`.
3. Resolve `bucket = STATUS_TO_BUCKET[status]`. If missing (unknown status) → log warning with `{ jobId, status }` and return without writing (FR-013).
4. Merge-write `stats/global` with `{ [bucket]: FieldValue.increment(1) }`.

### Error handling

Same top-level try/catch pattern as §1.

### Test contract

Cases (from spec §US3 Acceptance Scenarios):
- AS1: `status = 'requested'` → `jobsRequested +1`
- AS2: `status = 'active'` (abnormal initial status) → `jobsOngoing +1`
- Unknown status → warning logged, no counter change, no throw
- Idempotency: replay → no additional increments

---

## 3. `onJobStatusChanged` — FR-002, FR-004, FR-009, FR-013

| Attribute | Value |
|---|---|
| Export name | `onJobStatusChanged` |
| File | `functions/src/stats/on-job-status-changed.ts` |
| Trigger kind | Firestore `onDocumentUpdated` (2nd-gen) |
| Resource path | `jobs/{jobId}` |
| Region | `europe-west1` (FR-005) |
| Runtime | Node.js 20 |
| Auth context | None |

### Event payload consumed

```ts
event.data.before.data(): {
  status?: string;      // previous status
  // other fields unused
}
event.data.after.data(): {
  status?: string;      // new status
  amountPaid?: number;  // optional; only read when transitioning to 'completed'
}
event.id: string;
event.params.jobId: string;
```

### Behavior

1. `const beforeStatus = before.status`, `const afterStatus = after.status`.
2. **No-op guard** (FR-009): `if (beforeStatus === afterStatus) return;` — do NOT touch dedup for no-op, do not write.
3. `await recordEventOrSkip(event.id)` — idempotency guard (only reached when there is a real status change).
4. Resolve `beforeBucket = STATUS_TO_BUCKET[beforeStatus]`, `afterBucket = STATUS_TO_BUCKET[afterStatus]`.
   - If either is missing → log warning with `{ jobId, beforeStatus, afterStatus }` and return (FR-013).
5. **Intra-bucket short-circuit**: `if (beforeBucket === afterBucket) return;` — e.g., `active → technician_accepted` both map to `jobsOngoing`. No counter change needed.
6. Build the update:
   - `[beforeBucket]: FieldValue.increment(-1)`
   - `[afterBucket]: FieldValue.increment(+1)`
   - **Iff** `afterStatus === 'completed'`: read `amountPaid = after.amountPaid`. If `typeof amountPaid === 'number' && Number.isFinite(amountPaid) && amountPaid > 0`, add `totalEarnings: FieldValue.increment(amountPaid)`. For `amountPaid === 0`, missing, non-number, negative, or `NaN`/`Infinity` → skip the earnings bump (FR-004, FR-013, spec §Edge Cases).
7. Single merge-write to `stats/global`.

### Error handling

Same top-level try/catch pattern as §1.

### Test contract (largest — covers FR-002, FR-004, FR-009, FR-013)

Cases (from spec §US2 Acceptance Scenarios + §Edge Cases):
- AS1: `requested → active` → `jobsRequested -1`, `jobsOngoing +1`
- AS2: `active → completed` with `amountPaid: 150` → `jobsOngoing -1`, `jobsCompleted +1`, `totalEarnings +150`
- AS3: `active → cancelled` → `jobsOngoing -1`, `jobsCancelled +1`
- AS4: status unchanged (only `notes` edited) → no-op, no dedup consumed, no write
- AS5: `active → completed`, `amountPaid: 0` → counters update, `totalEarnings` unchanged
- AS6: `active → completed`, no `amountPaid` field → counters update, `totalEarnings` unchanged
- AS7: `awaiting_customer_approval → completed` → `jobsOngoing -1`, `jobsCompleted +1` (intermediate ongoing maps to `jobsOngoing`)
- Edge: `active → technician_accepted` (intra-bucket) → short-circuit, no write
- Edge: `active → completed` with `amountPaid: -50` → counters update, `totalEarnings` unchanged (FR-013 guard)
- Edge: `active → completed` with `amountPaid: NaN` → counters update, `totalEarnings` unchanged
- Edge: `active → <unknown_status>` → warning logged, no write, no throw
- Idempotency: replay same `event.id` → no additional increments

---

## 4. Cross-trigger invariants

- All three triggers are deployed as 2nd-gen functions with **explicit** region `europe-west1`. No global region default is relied upon.
- All three import `recordEventOrSkip` from the same helper file (`functions/src/stats/lib/event-dedup.ts`). No trigger implements its own dedup logic.
- All three import `STATUS_TO_BUCKET` from the same source of truth (`functions/src/stats/lib/status-map.ts`) — when used.
- All three are re-exported from `functions/src/stats/index.ts`, which is re-exported from `functions/src/index.ts` (already wired in Spec 002's `export * from "./stats"`).
- None of the three call into the admin-callable modules (`functions/src/admin/*`). Stats triggers and admin callables share only the Admin SDK initialization in `functions/src/index.ts` (FR-012).

---

## 5. Out-of-contract — explicitly NOT triggers

For future reference:
- No chat-status trigger → `activeChats` goes stale (spec §Edge Cases; future spec).
- No user-doc-update trigger → role changes after creation are NOT reflected in `customers`/`technicians` counters. Accepted; role changes are vanishingly rare and typically only go `null → customer/technician` at signup time.
- No user-doc-delete trigger → deleting a user does NOT decrement `totalUsers`. Accepted; user deletes are admin-only and rare.
- No job-delete trigger → deleting a job does NOT adjust counters. Accepted; job deletes are admin-only and extremely rare.
