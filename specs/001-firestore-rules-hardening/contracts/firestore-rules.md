# Contract: `firestore.rules` changes

**Feature**: `001-firestore-rules-hardening`
**File**: `firestore.rules` (repository root)

This contract is the **exact** diff the implementer must apply. Do not paraphrase, do not "clean up nearby style," and do not touch any rule block other than the three listed below.

---

## Pre-flight check

Before editing, verify the three target blocks still exist at roughly the line numbers given. They may have shifted if `firestore.rules` has been touched since this plan was written. Use the comment headers as the reliable anchor — the line numbers are a hint only:

- `// ── Admin assigns technician: requested → active ──`  (around line 134)
- `// ── Admin resolves dispute: receipt_disputed → reopen / complete / cancel ──`  (around line 196)
- `// ── Cancellation: admin from any non-terminal status ──`  (around line 203)

If any of the three anchors is missing, STOP and escalate — the file has diverged from the plan.

---

## Edit 1 — Admin assignment block

### Before

```javascript
// ── Admin assigns technician: requested → active ──
(
  isAdmin()
  && resource.data.status == 'requested'
  && request.resource.data.status == 'active'
  && request.resource.data.assignedTechnicianId is string
) ||
```

### After

```javascript
// ── Admin assigns technician: requested → active ──
(
  isAdmin()
  && resource.data.status == 'requested'
  && request.resource.data.status == 'active'
  && request.resource.data.assignedTechnicianId is string
  && request.resource.data.diff(resource.data)
       .affectedKeys().hasOnly(['status', 'assignedTechnicianId', 'technicianId', 'assignedTechnicianName', 'updatedAt'])
) ||
```

### What changed

Exactly one new condition, appended with `&&`. Nothing else in the block. Pay attention to the trailing `) ||` — it MUST remain; it is the OR separator to the next branch in the big `allow update` chain.

---

## Edit 2 — Admin dispute resolution block

### Before

```javascript
// ── Admin resolves dispute: receipt_disputed → reopen / complete / cancel ──
(
  isAdmin()
  && resource.data.status == 'receipt_disputed'
  && request.resource.data.status in ['awaiting_customer_approval', 'completed', 'cancelled']
) ||
```

### After

```javascript
// ── Admin resolves dispute: receipt_disputed → reopen / complete / cancel ──
(
  isAdmin()
  && resource.data.status == 'receipt_disputed'
  && request.resource.data.status in ['awaiting_customer_approval', 'completed', 'cancelled']
  && request.resource.data.diff(resource.data)
       .affectedKeys().hasOnly(['status', 'receiptRejected', 'disputeResolvedAt', 'updatedAt', 'amountPaid', 'price', 'adminClosedAt'])
) ||
```

### What changed

Exactly one new condition. Watch the field name: it is `disputeResolvedAt`, not `resolvedAt`. Double-check the spelling before saving — this is a common typo site.

---

## Edit 3 — Admin cancellation block

### Before

```javascript
// ── Cancellation: admin from any non-terminal status ──
(
  isAdmin()
  && !(resource.data.status in ['completed', 'cancelled'])
  && request.resource.data.status == 'cancelled'
) ||
```

### After

```javascript
// ── Cancellation: admin from any non-terminal status ──
(
  isAdmin()
  && !(resource.data.status in ['completed', 'cancelled'])
  && request.resource.data.status == 'cancelled'
  && request.resource.data.diff(resource.data)
       .affectedKeys().hasOnly(['status', 'cancelledBy', 'cancelledAt', 'updatedAt'])
) ||
```

### What changed

Exactly one new condition. The trailing `) ||` remains because this block is followed by the customer cancellation branch.

---

## Verification — Rules Playground scenarios

After deploying (or in the Rules Playground against the unsaved rule draft), run every scenario below. Tick `[x]` only when the result matches **Expected**. Unlisted scenarios are not required but are not discouraged.

For each scenario, use:
- **Simulation type**: `update`
- **Location**: `/jobs/<test-job-id>`
- **Authenticated**: signed-in user; use `providerData` with whatever Firebase test UID you like.
- **Auth mock**: set the admin user via Firestore emulator / console to have a `users/{uid}` doc with `role: 'admin'` (required by `isAdmin()`).

### Block A (assignment)

- [x] **A1 ALLOW**: Existing doc status `'requested'`. Write sets `status='active'`, `assignedTechnicianId='tech_xyz'`, `technicianId='tech_xyz'`, `assignedTechnicianName='Alice'`, `updatedAt=<ts>`. Admin UID.
  **Expected**: Allow.
- [x] **A2 DENY**: Same as A1, but additionally sets `customerId='someone_else'`.
  **Expected**: Deny.
- [x] **A3 DENY**: Same as A1, but the admin is not actually an admin (no `users/{uid}.role == 'admin'`).
  **Expected**: Deny.
- [x] **A4 DENY**: Existing doc status `'active'`. Write attempts the same assignment shape.
  **Expected**: Deny (precondition fails on `resource.data.status == 'requested'`).

### Block B (dispute resolution)

- [x] **B1 ALLOW (reopen)**: Existing doc status `'receipt_disputed'`. Write sets `status='awaiting_customer_approval'`, `receiptRejected=false`, `disputeResolvedAt=<ts>`, `updatedAt=<ts>`. Admin.
  **Expected**: Allow.
- [x] **B2 ALLOW (complete with override)**: Existing doc status `'receipt_disputed'`. Write sets `status='completed'`, `disputeResolvedAt=<ts>`, `amountPaid=150`, `price=150`, `adminClosedAt=<ts>`, `updatedAt=<ts>`. Admin.
  **Expected**: Allow.
- [x] **B3 ALLOW (cancel)**: Existing doc status `'receipt_disputed'`. Write sets `status='cancelled'`, `disputeResolvedAt=<ts>`, `updatedAt=<ts>`. Admin.
  **Expected**: Allow.
- [x] **B4 DENY**: Same as B2, but additionally sets `description='malicious edit'`.
  **Expected**: Deny.
- [x] **B5 DENY**: Same as B1, but target status `'requested'` (not in the allowed set).
  **Expected**: Deny.

### Block C (admin cancellation)

- [x] **C1 ALLOW (minimal)**: Existing doc status `'active'`. Write sets `status='cancelled'`. Admin.
  **Expected**: Allow.
- [x] **C2 ALLOW (forward-compat)**: Existing doc status `'technician_arrived'`. Write sets `status='cancelled'`, `cancelledBy='admin_uid'`, `cancelledAt=<ts>`, `updatedAt=<ts>`. Admin.
  **Expected**: Allow.
- [x] **C3 DENY**: Same as C1, but additionally sets `amountPaid=0`.
  **Expected**: Deny.
- [x] **C4 DENY**: Existing doc status `'completed'`. Write sets `status='cancelled'`.
  **Expected**: Deny (precondition `!(status in ['completed', 'cancelled'])`).

### Smoke test against current mobile client (after deploy)

- [ ] **SMOKE-1**: Using the current admin mobile build, perform a real assignment of a `requested` job. Expect success.
- [ ] **SMOKE-2**: Using the current admin mobile build, perform a real dispute resolution (complete) on a `receipt_disputed` job. Expect success.
- [ ] **SMOKE-3**: Using the current admin mobile build, perform a real admin cancellation on an `active` job. Expect success.
- [ ] **SMOKE-4**: Watch Firestore debug logs for 10 minutes after deploy. Expect zero `PERMISSION_DENIED` events on `/jobs/*` from admin UIDs.

All 12 boxes must be checked before this contract is considered satisfied.
