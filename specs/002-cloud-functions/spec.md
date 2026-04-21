# Feature Specification: Admin Cloud Functions

**Feature Branch**: `002-cloud-functions`
**Created**: 2026-04-14
**Status**: Draft
**Input**: User description: "Create spec 002 (Cloud Functions) covering Phase 3 and Phase 4 of WOOHOO/Migration_Implementation_Plan.md"

## Clarifications

### Session 2026-04-15

- Q: FR-015 mandates a hosting preview channel deploy, but Firebase does not offer preview channels for Cloud Functions — what is the real pre-prod deploy gate? → A: Replace FR-015 with an automated `firebase emulators:exec` run of the full FR-013 test matrix as the mandatory pre-prod gate.
- Q: FR-001 pins Node.js 18, which is EOL and being deprecated by Firebase Functions — which runtime should the `functions/` project target? → A: Node.js 20 (current Firebase Functions LTS default).
- Q: The spec never names a Firebase Functions deployment region — which region should the five admin callables deploy to? → A: `europe-west1` (closest mature region to MENA with full feature parity).
- Q: Is the FR-013 test matrix a manual engineer-driven walk-through or a committed automated test suite? → A: Automated Jest suite at `functions/test/**`, run via `firebase emulators:exec "npm test"`, exit code gates deploy.
- Q: What should the `activity_log.description` string contain for each function type? → A: Fixed per-type template strings with only server-derived IDs interpolated; no user free-text (reasons stay in their own field).

## Overview

This is the second deliverable of the Admin Web Migration programme. Spec 001 hardened the Firestore and Storage rules so that admin writes can only touch a known field set. This spec moves the **actual write logic** off the mobile admin client and onto Cloud Functions, so that every privileged admin action (assigning a job, approving a payment, rejecting a payment, resolving a dispute, force-closing a job) executes server-side with a verified admin identity, a transactional precondition check, and a durable audit trail.

This spec covers Phases 3 and 4 of `WOOHOO/Migration_Implementation_Plan.md`. It does **not** introduce the event-driven stats functions (Phase 5 → Spec 003), the admin web shell (Phase 6 → Spec 004), the admin web feature screens (Phase 7 → Spec 005), or any mobile cleanup (Phase 8 → Spec 006). The mobile admin client keeps working unchanged for the duration of this spec — backward compatibility is mandatory (constitution Principle V).

The work is bounded to:
- **Phase 3** (one task): scaffold a `functions/` TypeScript project and write two shared helpers (`verifyAdmin`, `writeAuditLog`).
- **Phase 4** (five sub-tasks): implement five admin callable Cloud Functions (`adminAssignJob`, `adminApprovePayment`, `adminRejectPayment`, `adminResolveDispute`, `adminCloseJob`), update one Firestore rule whitelist to add the new audit fields, and deploy.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Move admin job assignment to a server-verified Cloud Function (Priority: P1)

When an admin assigns a `requested` job to a technician, the operation must execute on the server inside a transaction. The server verifies the caller is an admin, looks up the technician's display name from `users/{technicianId}` (so the client cannot lie about it), updates the job atomically, and writes an `activity_log` entry recording who did the assignment and when. The mobile admin client today writes these fields directly from the device, with no audit trail and no server-side verification of the technician name.

**Why this priority**: Job assignment is the highest-volume privileged admin action and is the foundation that every later admin web screen builds on. It also exercises every shared piece (`verifyAdmin`, transaction read, `writeAuditLog`) — once it works, the other four functions are pattern repetitions.

**Independent Test**: A signed-in admin calls the function via the Firebase emulator with a valid `jobId` + `technicianId`. The function returns success, the job document moves from `requested` to `active`, the new fields (`assignedBy`, `assignedAt`, `assignedTechnicianName`) appear, and a matching `activity_log` entry exists. A non-admin caller gets `permission-denied`. A call against a job that is not in `requested` status gets `failed-precondition`.

**Acceptance Scenarios**:

1. **Given** an admin signed in with `users/{uid}.role == 'admin'` and a job in `requested` status, **When** the admin calls `adminAssignJob({jobId, technicianId})`, **Then** the function returns success, the job document has `status='active'`, `assignedTechnicianId`, `technicianId`, `assignedTechnicianName` (looked up server-side from `users/{technicianId}.fullName`), `assignedBy=<admin uid>`, `assignedAt=<server timestamp>`, and `updatedAt=<server timestamp>`, AND a new `activity_log` document exists with `type='job_assigned'` and `jobId=<jobId>`.
2. **Given** a signed-in user whose `users/{uid}.role` is NOT `'admin'`, **When** they call `adminAssignJob`, **Then** the function throws `HttpsError('permission-denied')` and the job document is unchanged.
3. **Given** an unauthenticated caller, **When** they call `adminAssignJob`, **Then** the function throws `HttpsError('unauthenticated')`.
4. **Given** an admin and a job in `active` status (not `requested`), **When** they call `adminAssignJob`, **Then** the function throws `HttpsError('failed-precondition')` and the job document is unchanged.
5. **Given** an admin and a `technicianId` that does not exist in `users/`, **When** they call `adminAssignJob`, **Then** the function throws `HttpsError('not-found')` and the job document is unchanged.
6. **Given** an admin calling with an empty or missing `jobId` or `technicianId`, **When** the call reaches the function, **Then** it throws `HttpsError('invalid-argument')` *before* any Firestore read.

---

### User Story 2 - Move admin payment approval/rejection to Cloud Functions with accountability (Priority: P1)

When an admin approves or rejects a customer's payment screenshot, the operation must execute server-side and record who reviewed the payment, when, and (for rejections) why. Today the mobile admin client writes `status: 'CONFIRMED'` or `status: 'REJECTED'` directly to `payments/{paymentId}` with no `reviewedBy`, no `reviewedAt`, and no `rejectionReason`. There is currently no way to answer "which admin rejected this payment and what reason did they give" because the data is not captured.

**Why this priority**: Equal to US1 because payments touch real money and a missing audit trail here is a compliance gap. Splitting the single `updatePaymentStatus` call into two distinct callables (`adminApprovePayment`, `adminRejectPayment`) also lets the rejection path enforce that a reason is mandatory — something the current API physically cannot do.

**Independent Test**: An admin calls `adminApprovePayment({paymentId})` against a `PENDING` payment; the doc transitions to `CONFIRMED` and `reviewedBy`/`reviewedAt` are stamped. An admin calls `adminRejectPayment({paymentId, reason: 'Receipt unreadable'})`; the doc transitions to `REJECTED`, `reviewedBy`/`reviewedAt` are stamped, and `rejectionReason` is recorded. An admin calling `adminRejectPayment` with an empty reason is rejected with `invalid-argument`.

**Acceptance Scenarios**:

1. **Given** an admin and a payment in `PENDING` status, **When** they call `adminApprovePayment({paymentId})`, **Then** the payment document has `status='CONFIRMED'`, `reviewedBy=<admin uid>`, `reviewedAt=<server timestamp>`, AND a new `activity_log` entry exists with `type='payment_approved'`.
2. **Given** the same setup, **When** they call `adminRejectPayment({paymentId, reason: 'Wrong amount on receipt'})`, **Then** the payment document has `status='REJECTED'`, `reviewedBy`, `reviewedAt`, and `rejectionReason='Wrong amount on receipt'`, AND a new `activity_log` entry exists with `type='payment_rejected'` and the reason recorded in the entry.
3. **Given** an admin, **When** they call `adminRejectPayment` with `reason: ''` or `reason: '   '` or no `reason` at all, **Then** the function throws `HttpsError('invalid-argument')` and the payment document is unchanged.
4. **Given** an admin and a payment that is already `CONFIRMED` or `REJECTED`, **When** they call either approve or reject, **Then** the function throws `HttpsError('failed-precondition')` and the payment document is unchanged.
5. **Given** a non-admin caller, **When** they call either approve or reject, **Then** the function throws `HttpsError('permission-denied')`.

---

### User Story 3 - Move admin dispute resolution to a Cloud Function that records the resolver and reason (Priority: P1)

When a customer disputes a receipt and an admin resolves the dispute (by reopening for customer approval, force-completing, or cancelling), the resolution must be recorded on the server with the admin's UID and a free-text reason. Today the mobile admin client writes the new status directly with no `resolvedBy` and no `resolutionNote`, so the team cannot answer "why did this dispute end the way it did". The function must support all three resolution types and must use the existing field name `disputeResolvedAt` (not `resolvedAt`) to stay consistent with the field already populated on the job document.

**Why this priority**: Equal to US1 and US2 because dispute resolution is the most contested admin operation — it is exactly the path where "who decided this and why" matters. It is also the most complex of the five functions (three resolution types, optional `overrideAmount`, optional extra fields on the `complete` branch), so writing it early de-risks the spec.

**Independent Test**: An admin calls `adminResolveDispute({jobId, resolution: 'reopen', reason: 'Customer agreed receipt was correct'})` against a job in `receipt_disputed`; the job moves to `awaiting_customer_approval`, `disputeResolvedAt` and `resolvedBy` are stamped, and `receiptRejected` is set to `false`. The same call with `resolution: 'complete'` and `overrideAmount: 150` moves the job to `completed` and stamps `amountPaid=150`, `price=150`, `adminClosedAt=<ts>`. The same call with `resolution: 'cancel'` moves the job to `cancelled`. A call with an invalid `resolution` value or empty `reason` is rejected with `invalid-argument`.

**Acceptance Scenarios**:

1. **Given** an admin and a job in `receipt_disputed`, **When** they call `adminResolveDispute({jobId, resolution: 'reopen', reason: 'Confirmed valid'})`, **Then** the job has `status='awaiting_customer_approval'`, `disputeResolvedAt=<ts>`, `resolvedBy=<admin uid>`, `resolutionNote='Confirmed valid'`, `receiptRejected=false`, and a matching `activity_log` entry exists.
2. **Given** the same setup, **When** they call `adminResolveDispute({jobId, resolution: 'complete', reason: 'Force closed', overrideAmount: 150})`, **Then** the job has `status='completed'`, `amountPaid=150`, `price=150`, `adminClosedAt=<ts>`, `disputeResolvedAt=<ts>`, `resolvedBy`, `resolutionNote`, and a matching `activity_log` entry.
3. **Given** the same setup, **When** they call `adminResolveDispute({jobId, resolution: 'cancel', reason: 'Customer not reachable'})`, **Then** the job has `status='cancelled'` plus the dispute resolution audit fields and an `activity_log` entry.
4. **Given** an admin, **When** they call `adminResolveDispute` with `resolution: 'foo'` (not in the allowed set), **Then** the function throws `HttpsError('invalid-argument')`.
5. **Given** an admin, **When** they call `adminResolveDispute` with `reason: ''` (empty after trim), **Then** the function throws `HttpsError('invalid-argument')`.
6. **Given** an admin and a job in any status other than `receipt_disputed`, **When** they call the function, **Then** it throws `HttpsError('failed-precondition')`.

---

### User Story 4 - Move admin force-close to an idempotent Cloud Function (Priority: P2)

When an admin force-closes a stuck job (for example, a job where the technician left the area without marking work finished), the operation must execute server-side and must be **idempotent**: a second call against an already-closed job must return success without re-writing the document, re-stamping the timestamp, or re-charging anything. The transaction reads `adminClosedAt` and short-circuits if it is already set. The status remains `'completed'` (NOT `'force_closed'`) for backward compatibility with every existing stream query that filters on `status == 'completed'`.

**Why this priority**: Lower than US1–US3 because force-close is rare and its only data-quality risk is double-stamping on retry — which the idempotency guard fully prevents. Still part of this spec because the migration plan groups all five admin write functions together (Phase 4) and shipping four of them while leaving a fifth on the mobile client would produce a partial and confusing audit surface.

**Independent Test**: An admin calls `adminCloseJob({jobId, amountPaid: 200})` against an `active` job; the job moves to `completed` with `amountPaid=200`, `price=200`, `adminClosedAt=<ts>`, `adminClosedBy=<admin uid>`. The admin calls the same function with the same arguments again — the function returns success and the job document timestamps and field values are unchanged from the first call.

**Acceptance Scenarios**:

1. **Given** an admin and a job in `active` (or any non-terminal status that is not already closed), **When** they call `adminCloseJob({jobId, amountPaid: 200})`, **Then** the job has `status='completed'`, `amountPaid=200`, `price=200`, `adminClosedAt=<ts>`, `adminClosedBy=<admin uid>`, `updatedAt=<ts>`, and an `activity_log` entry with `type='job_force_closed'`.
2. **Given** an admin who just successfully called `adminCloseJob` and is now retrying the same call (idempotency check), **When** they call `adminCloseJob({jobId, amountPaid: 200})` a second time, **Then** the function returns success, the job document fields are unchanged, no second `activity_log` entry is written, and no double-stamping occurs.
3. **Given** an admin, **When** they call `adminCloseJob` with `amountPaid: -1` or `amountPaid: 'nope'` or no `amountPaid` at all, **Then** the function throws `HttpsError('invalid-argument')`. Note that `amountPaid: 0` is valid (free service) and must succeed.
4. **Given** a non-admin caller, **When** they call `adminCloseJob`, **Then** the function throws `HttpsError('permission-denied')`.

---

### User Story 5 - Update the Firestore admin-assignment rule whitelist to admit the new audit fields (Priority: P1)

Spec 001 added an `affectedKeys().hasOnly([...])` whitelist to the admin job-assignment rule covering `{status, assignedTechnicianId, technicianId, assignedTechnicianName, updatedAt}`. The new `adminAssignJob` Cloud Function additionally writes `assignedBy` and `assignedAt`. Cloud Functions use the Firebase Admin SDK and bypass Firestore rules entirely, so the function call itself will not be denied — but the existing mobile admin client (which writes the same fields directly) will be denied as soon as it starts writing the new audit fields, and any future direct-client write path will be denied too. The whitelist must be expanded to `{status, assignedTechnicianId, technicianId, assignedTechnicianName, assignedBy, assignedAt, updatedAt}` so that defense-in-depth is preserved (constitution Principle XII).

**Why this priority**: P1 because it is part of the same atomic shipping unit as US1. Per constitution Principle IV, rules and functions that go live together must deploy together. Splitting this rule update into a separate spec would create a window where the rule and the function disagree.

**Independent Test**: After deploying both the function and the rule update, an admin write to the assignment path that includes `assignedBy` and `assignedAt` is allowed by the rule. A write that adds an unrelated field (e.g., `customerId`) is still denied.

**Acceptance Scenarios**:

1. **Given** the deployed Spec 002 ruleset, **When** a write to a job document under the admin-assignment branch sets only `{status, assignedTechnicianId, technicianId, assignedTechnicianName, assignedBy, assignedAt, updatedAt}`, **Then** the write is allowed.
2. **Given** the same setup, **When** a write also sets `customerId`, **Then** the write is denied.
3. **Given** the current production mobile admin client (which does NOT write `assignedBy` / `assignedAt`), **When** it performs its existing assignment flow, **Then** the write is still allowed (the whitelist permits subsets via `hasOnly`).

---

### Edge Cases

- **Mobile admin client still active**: For the duration of this spec, the mobile admin client keeps writing directly to Firestore (it does not yet call the new Cloud Functions). Both the old direct-write path and the new CF path must coexist without producing duplicate audit entries. Mitigation: the mobile client never writes to `activity_log`, so the only place an entry can come from is the CF. There is no double-audit risk during the overlap.
- **Cloud Function cold start latency**: A first invocation after idle may take several seconds. Acceptable for an internal admin tool; no warmer is added. The spec does not commit to a sub-second cold-start budget.
- **Transaction contention**: Two admins simultaneously trying to assign the same `requested` job will race. The losing transaction will see `status != 'requested'` on its retry and throw `failed-precondition`. The first admin's call wins; the second sees a clean error. This is intentional.
- **Idempotent close raced with a state transition**: If `adminCloseJob` runs against a job that another path just moved to `completed`, the idempotency guard (`adminClosedAt != null`) will treat the job as closed and return success without writing. This is acceptable because the alternative (overwriting another path's `completed` state) would be worse.
- **`adminResolveDispute` complete branch with no `overrideAmount`**: The function uses the job's existing `price` field if no override is supplied. If the existing `price` is also missing (data integrity issue), the function throws `failed-precondition` rather than writing `null`/`undefined`.
- **`activity_log` write fails after the job write succeeded**: When the audit write is inside the same transaction as the job write, both succeed or both fail — there is no half-state. For the rare functions where the audit cannot be in the same transaction (none in this spec, but the rule is documented), the audit write must complete before the function returns success. A successful function call without a corresponding `activity_log` entry is a defect.
- **A field rename in the existing schema**: This spec uses the EXISTING field name `disputeResolvedAt`, not `resolvedAt`. Any future code that grep-replaces one for the other will break the dispute resolution function. The spec explicitly calls this out so a future refactor cannot silently regress it.

## Requirements *(mandatory)*

### Functional Requirements

#### Cloud Functions project + shared helpers (Phase 3)

- **FR-001**: A TypeScript Cloud Functions project MUST exist at `functions/` at the repo root, configured for Node.js 20 runtime (Firebase Functions LTS default as of 2026-04-15) and TypeScript strict mode. The `engines.node` field in `functions/package.json` MUST be `"20"`, and the Firebase Functions 2nd-gen runtime spec MUST target `nodejs20`. The project MUST build with zero TypeScript errors. Node.js 18 MUST NOT be used — it is EOL and Firebase Functions has begun rejecting new deploys against it. (Migration plan §Task 3-1, adjusted for runtime currency.)
- **FR-002**: A shared helper `verifyAdmin(context)` MUST exist and MUST be the first executable line of every admin write function. It MUST throw `HttpsError('unauthenticated')` if `context.auth` is missing, and `HttpsError('permission-denied')` if `users/{context.auth.uid}.role` is not `'admin'`. The admin check MUST be a Firestore document read against `users/{uid}` (constitution decision D1 — Custom Claims are forbidden without a constitution amendment).
- **FR-003**: A shared helper `writeAuditLog(entry)` MUST exist and MUST write an immutable document to the `activity_log` collection containing at minimum: `type` (enum), `description` (string), `createdAt` (server timestamp), and contextual fields where applicable (`jobId`, `userId`, `role`). Audit fields MUST NEVER be accepted from the client — `userId` is sourced from `context.auth.uid` server-side. (Constitution Principle XI.)
- **FR-003a**: The `description` string on every `activity_log` entry written by this spec's five functions MUST be generated from a fixed per-`type` template. Only server-derived identifiers (IDs and the server-looked-up `assignedTechnicianName`) may be interpolated. User-supplied free-text fields (`reason`, `resolutionNote`, `overrideAmount`) MUST NOT appear in `description` — they remain on the job / payment document (or on a separate `reason` field of the `activity_log` entry) and are rendered by consumers separately. The canonical templates are:
  - `job_assigned` → `"Admin assigned job {jobId} to {assignedTechnicianName}"`
  - `payment_approved` → `"Admin approved payment {paymentId}"`
  - `payment_rejected` → `"Admin rejected payment {paymentId}"`
  - `dispute_resolved` → `"Admin resolved dispute on job {jobId} ({resolution})"` where `{resolution}` is one of `reopen`/`complete`/`cancel`
  - `job_force_closed` → `"Admin force-closed job {jobId}"`
  These strings are the source of truth for what Spec 005's Activity screen renders; changing them later is a breaking change for that screen.
- **FR-004**: The `index.ts` entry point MUST call `admin.initializeApp()` exactly once and re-export the callable functions from `./admin` (and stub `./stats` for Spec 003 to fill in later).
- **FR-004a**: All five admin callables in this spec (and any Spec 003 stats stubs referenced from `index.ts`) MUST be deployed to the `europe-west1` region. The region MUST be set on each callable's definition (e.g., `functions.region('europe-west1').https.onCall(...)` for 1st-gen or `{ region: 'europe-west1' }` in the 2nd-gen options object) — it MUST NOT rely on a global default. Region choice rationale: closest mature Firebase Functions region to the MENA user base with full feature parity; `us-central1` default would add ~250ms per admin call. Changing region after deploy requires a delete + redeploy under a new function name and is out of scope for this spec.

#### Five admin callable functions (Phase 4)

- **FR-005**: A callable function `adminAssignJob({jobId, technicianId})` MUST exist. It MUST verify admin, validate both inputs as non-empty strings, look up the technician's display name from `users/{technicianId}.fullName` server-side, verify inside a transaction that the job's `status == 'requested'`, then update the job to `status='active'` with `assignedTechnicianId`, `technicianId`, `assignedTechnicianName`, `assignedBy=<admin uid>`, `assignedAt=<server timestamp>`, `updatedAt=<server timestamp>`, and write a matching `activity_log` entry with `type='job_assigned'`.
- **FR-006**: A callable function `adminApprovePayment({paymentId})` MUST exist. It MUST verify admin, validate `paymentId` as a non-empty string, verify inside a transaction that the payment's `status == 'PENDING'`, then update the payment to `status='CONFIRMED'`, `reviewedBy=<admin uid>`, `reviewedAt=<server timestamp>`, and write a matching `activity_log` entry with `type='payment_approved'`.
- **FR-007**: A callable function `adminRejectPayment({paymentId, reason})` MUST exist. It MUST verify admin, validate `paymentId` as a non-empty string, validate `reason` as a non-empty string after `.trim()` (empty/whitespace-only reasons MUST be rejected with `invalid-argument` BEFORE any Firestore read), verify inside a transaction that the payment's `status == 'PENDING'`, then update the payment to `status='REJECTED'`, `reviewedBy=<admin uid>`, `reviewedAt=<server timestamp>`, `rejectionReason=<trimmed reason>`, and write a matching `activity_log` entry with `type='payment_rejected'`.
- **FR-008**: A callable function `adminResolveDispute({jobId, resolution, reason, overrideAmount?})` MUST exist. It MUST verify admin, validate `jobId` as a non-empty string, validate `resolution` against the locally-defined set `['reopen', 'complete', 'cancel']` (any other value MUST throw `invalid-argument`), validate `reason` as non-empty after trim, validate `overrideAmount` (if present) as a finite non-negative number, verify inside a transaction that the job's `status == 'receipt_disputed'`, then update the job's status to the mapped target (`reopen` → `awaiting_customer_approval`, `complete` → `completed`, `cancel` → `cancelled`), set `disputeResolvedAt=<server timestamp>`, `resolvedBy=<admin uid>`, `resolutionNote=<trimmed reason>`, `updatedAt=<server timestamp>`. For `reopen`, additionally set `receiptRejected=false`. For `complete`, additionally set `amountPaid` (from `overrideAmount` if supplied, else from existing `price`), `price` (mirrors `amountPaid`), and `adminClosedAt=<server timestamp>`. Write a matching `activity_log` entry with `type='dispute_resolved'` and the resolution + reason recorded.
- **FR-009**: A callable function `adminCloseJob({jobId, amountPaid})` MUST exist. It MUST verify admin, validate `jobId` as a non-empty string, validate `amountPaid` as a finite non-negative number (`0` is valid), verify inside a transaction that the job is not already closed (read `adminClosedAt` from the transaction snapshot — if non-null, return success WITHOUT writing, idempotency guard), then update the job to `status='completed'` (NOT `'force_closed'`), `amountPaid`, `price=amountPaid`, `adminClosedAt=<server timestamp>`, `adminClosedBy=<admin uid>`, `updatedAt=<server timestamp>`, and write a matching `activity_log` entry with `type='job_force_closed'`. The second invocation against an already-closed job MUST return success, MUST NOT re-write the job, and MUST NOT write a second audit entry.
- **FR-010**: All five callable functions MUST throw `HttpsError` with the precise standard codes: `unauthenticated`, `permission-denied`, `invalid-argument`, `failed-precondition`, `not-found`. They MUST NOT throw raw `Error` objects to the client. Any non-`HttpsError` exception MUST be caught at the top of the function body and re-thrown as `HttpsError('internal', 'Unexpected error')` (constitution Principle XIII).
- **FR-011**: All five callable functions MUST log a server-side message recording the function name and `context.auth.uid` for every successful invocation. Logged values MUST NOT include any field from `payments/*`, any field from `users/*`, or any free-text reason longer than 200 characters (truncate). (Constitution Principle XIII.)

#### Firestore rule update (Phase 4-1b)

- **FR-012**: The Firestore rule for the admin job-assignment write path MUST be updated so that its `affectedKeys().hasOnly([...])` whitelist additionally permits `assignedBy` and `assignedAt`. The full whitelist becomes `{status, assignedTechnicianId, technicianId, assignedTechnicianName, assignedBy, assignedAt, updatedAt}`. The rule MUST continue to require `isAdmin()` and the `status: requested → active` precondition. No other rule block in `firestore.rules` may be modified by this spec.

#### Deployment (Phase 4-5)

- **FR-013**: Before any production deploy, the Cloud Functions project MUST pass a complete Firebase emulator test pass covering: valid admin call (success) for all 5 functions, non-admin call (`permission-denied`) for all 5 functions, wrong status precondition (`failed-precondition`) for all applicable functions, missing/invalid arguments (`invalid-argument`) for all 5 functions, non-existent document (`not-found`) for `adminAssignJob` (technician lookup), idempotency (second `adminCloseJob` call returns success without re-write), and rejection without reason (`invalid-argument` for `adminRejectPayment`). These test cases MUST be implemented as an automated Jest test suite committed at `functions/test/**.test.ts`, runnable via `npm test` from the `functions/` directory. The tests MUST boot the Firestore + Auth + Functions emulators, seed fixture data (admin user, non-admin user, jobs in each required status, payments in each required status), invoke the callables via the `firebase-functions-test` or emulator-HTTP client, and assert document state after each call. A manual checklist walk-through is NOT acceptable as the FR-013 gate — only a green `npm test` run counts.
- **FR-014**: The Cloud Functions and the Firestore rule update MUST deploy in a single combined command so that the rule and the functions go live atomically: `firebase deploy --only functions,firestore:rules`. Splitting this into two deploys is a defect (constitution Principle IV).
- **FR-015**: Before the production deploy, the engineer MUST run the full FR-013 test matrix under the Firebase emulator via `firebase emulators:exec --only functions,firestore,auth "<test command>"` from the `functions/` project. The `auth` emulator is required because the Jest suite simulates authenticated admin and non-admin callers via `firebase-functions-test` against the Auth emulator. The production deploy (`firebase deploy --only functions,firestore:rules`) may only proceed if this command exits with code `0`. Firebase Hosting preview channels are NOT used for this spec because they do not exercise Cloud Functions — the emulator run is the canonical pre-prod gate.
- **FR-016**: After production deploy, all 5 functions MUST appear in the Firebase Console with no startup errors, and a smoke test of one successful call per function MUST be performed within 10 minutes of the deploy.

#### Backward compatibility

- **FR-017**: This spec MUST NOT modify any file in `lib/` (the mobile app). The mobile admin client continues to call its existing `firebase_service.dart` methods. Migration of the mobile admin client off direct writes is deferred to Spec 006 (Phase 8).
- **FR-018**: This spec MUST NOT modify the existing Firestore rules for payments, stats, or `activity_log` writes (only the admin job-assignment whitelist may be touched). Spec 003 is responsible for closing the client-side stats write paths.
- **FR-019**: The existing field name `disputeResolvedAt` MUST be reused. Renaming it to `resolvedAt` (or any other variant) is forbidden in this spec — the field is already populated on production job documents and renaming would orphan the existing values.

#### Secrets and credentials

- **FR-020**: `serviceAccountKey.json`, `**/serviceAccountKey*.json`, `functions/.env`, and `functions/.runtimeconfig.json` MUST be added to `.gitignore` before the first commit of `functions/`. No service account key file may be committed at any point. (Constitution Principle VIII.)

### Key Entities

- **Cloud Functions project (`functions/`)**: A TypeScript project containing 5 admin callable functions (`adminAssignJob`, `adminApprovePayment`, `adminRejectPayment`, `adminResolveDispute`, `adminCloseJob`), 2 stats stubs (filled in Spec 003), and 2 shared helpers (`verifyAdmin`, `writeAuditLog`). Lives at the repo root, deployed to the existing `syana-ea75a` Firebase project.
- **Job document (`jobs/{jobId}`)**: Same entity as Spec 001. Spec 002 adds these new fields: `assignedBy`, `assignedAt` (set by `adminAssignJob`); `resolvedBy`, `resolutionNote` (set by `adminResolveDispute`); `adminClosedBy` (set by `adminCloseJob`). Existing fields `disputeResolvedAt` and `adminClosedAt` are reused unchanged.
- **Payment document (`payments/{paymentId}`)**: Has `status` (`PENDING` / `CONFIRMED` / `REJECTED`), and after this spec, `reviewedBy`, `reviewedAt`, and `rejectionReason` (rejection only).
- **Activity log document (`activity_log/{autoId}`)**: Immutable audit record. Fields: `type` (enum drawn from `job_assigned`, `payment_approved`, `payment_rejected`, `dispute_resolved`, `job_force_closed`), `description` (string), `createdAt` (server timestamp), `userId` (admin UID), `role` (`'admin'`), and optionally `jobId`, `paymentId`, `resolution`. The `activity_log` Firestore rule already enforces `allow update, delete: if false` and is unchanged by this spec.
- **Admin user (`users/{uid}` where `role == 'admin'`)**: Same entity as Spec 001. Read by `verifyAdmin` on every privileged invocation.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of the emulator test matrix in FR-013 passes (success / permission-denied / failed-precondition / invalid-argument / not-found / idempotency / rejection-without-reason) before any production deploy is performed.
- **SC-002**: After production deploy, all 5 admin functions are listed in the Firebase Console with `Active` status and zero startup errors within 10 minutes of the deploy.
- **SC-003**: Within the first 72 hours after deploy, every successful admin write performed via a Cloud Function has a corresponding `activity_log` entry. Target: 100% match. **Reconciliation mechanism**: query `firebase functions:log --only adminAssignJob,adminApprovePayment,adminRejectPayment,adminResolveDispute,adminCloseJob` for the 72-hour window and count entries whose structured log line contains `"status":"ok"` or equivalent success marker; query Firestore `activity_log` collection with `where('createdAt','>=', deployTimestamp)` and count entries whose `userId` matches the admin UIDs observed in the functions log. The two counts MUST match exactly. The 72-hour wall clock starts from the completion of the FR-016 post-deploy smoke test (T032).
- **SC-004**: Within the first 72 hours after deploy, zero `adminRejectPayment` calls without a non-empty `reason` field reach Firestore. Target: 100% — the validation makes this physically impossible.
- **SC-005**: A second `adminCloseJob` call against an already-closed job returns success in 100% of test cases without writing a second `activity_log` entry or modifying the job document. Verified in the emulator before deploy and re-verified once on production within 24 hours of deploy.
- **SC-006**: Within the first 72 hours after deploy, the existing mobile admin client continues to perform its existing assign/approve/reject/resolve/close flows with zero new rule-related denials attributable to FR-012's whitelist expansion. Measured against Firestore debug logs.
- **SC-007**: The phase ships in at most one production deploy: `firebase deploy --only functions,firestore:rules`. No follow-up hotfix deploy is required to recover from a regression in the first 72 hours.
- **SC-008**: No service account key file appears in `git log -p functions/` at any point during or after this spec. Verified by an explicit grep of the commit history at sign-off.

## Assumptions

- The existing `isAdmin()` Firestore document read (`users/{uid}.role == 'admin'`) is the authoritative admin check for Cloud Functions as well — `verifyAdmin` is a TypeScript implementation of the same check, not a different mechanism. Custom Claims are explicitly out of scope (constitution decision D1).
- The five admin callables in this spec are the **complete** Phase 3 + Phase 4 set per the migration plan. No additional admin functions are added in this spec. New admin operations discovered after sign-off are tracked as a follow-up spec, not silently appended here.
- The mobile admin client is left untouched. It keeps writing directly to Firestore for the entire duration of this spec. The only file in `lib/` that any future mobile-client refactor may touch is `firebase_service.dart`, and that work is reserved for Spec 006 (Phase 8). No spec between 002 and 006 may touch root `lib/`.
- The `activity_log` schema and rules are already in place (`firestore.rules` lines 444–465 per migration plan §"activity_log Rules"). This spec only writes to it; it does not modify the rule.
- Cloud Functions use the Firebase Admin SDK and bypass Firestore rules entirely. The rule update in FR-012 is a defense-in-depth measure for the transition period; it is not load-bearing for the function calls themselves.
- The existing payment status enum is `'PENDING'` / `'CONFIRMED'` / `'REJECTED'` (uppercase). This is what the current `updatePaymentStatus` mobile method writes today and is the source of truth for FR-006/007 — confirm against `lib/firebase_service.dart` before writing the function bodies (constitution Principle III: read first, do not guess).
- The existing technician name field on `users/{uid}` is `fullName`. This is the field `adminAssignJob` reads. Confirm against `users/` documents in the emulator before writing the function body — if the field is named differently in production, the function fails at the lookup step.
- Deployment is performed via the local Firebase CLI by an engineer who has owner-level access to project `syana-ea75a`. CI-driven deploy is out of scope for this spec.
- Spec 002 is sequenced AFTER Spec 001 has reached "deployed" state. As of 2026-04-14 the Spec 001 Firestore rules are already deployed to production; the storage rule + mobile release portions of Spec 001 may still be pending, but they do not block Spec 002 because they touch different code paths (storage rules / mobile filename convention) than Spec 002 (Cloud Functions / job + payment write paths).
- The user has explicitly overridden constitution Principle II's path for the admin web app: future admin web code (Spec 004 onward) lives in `.claude/AdminWebApp/`, not in `admin_web/`. This override does NOT affect Spec 002 because Spec 002 has no web component — Cloud Functions live in `functions/` regardless. The override is recorded so Spec 004's plan can pick it up.

## Out of scope (stated explicitly so it cannot be re-litigated)

- Event-driven stats functions (`onJobStatusChanged`, `onPaymentStatusChanged`). These are Phase 5 → Spec 003.
- Locking down client-side stats writes (`stats/global` rule change to `allow write: if false`). Phase 5 → Spec 003.
- Admin web shell (Flutter Web project, auth gate, navigation). Phase 6 → Spec 004. Will live in `.claude/AdminWebApp/` per user override.
- Admin web feature screens (Overview, Jobs, Payments, Support, Disputes, Activity). Phase 7 → Spec 005.
- Mobile admin code removal. Phase 8 → Spec 006.
- Replacing the existing direct-Firestore admin reads (`streamJobsByStatus`, `streamAllPayments`, `streamSupportChats`, etc.). The migration plan §Method Mapping marks these as "Direct Firestore" — they stay direct reads forever. Only WRITES move to Cloud Functions in this spec.
- Support chat operations (`closeSupportChat`, `markSupportChatReadByAdmin`, `sendSupportMessage`). Per migration plan §Method Mapping, these stay as direct Firestore writes from `AdminFirebaseService` in the future admin web app.
- App Check enforcement on Cloud Functions. App Check is enabled at the project level by Spec 005's deploy gate (constitution Principle XII); turning the enforcement knob is not part of Spec 002.
- Any change to `firestore.indexes.json`. The five admin functions write to documents by primary key; no new composite indexes are required.
- A `@firebase/rules-unit-testing` harness for the FR-012 rule update. Spec 001 §R-4 explicitly deferred this and Spec 002 inherits the deferral. The Rules Playground covers FR-012's three scenarios.
