---

description: "Task list for 002-cloud-functions — Phase 3 + 4 of the Admin Web Migration"
---

# Tasks: Admin Cloud Functions

**Input**: Design documents from `/specs/002-cloud-functions/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/callable-signatures.md ✅, quickstart.md ✅
**Generated**: 2026-04-15 (after the 2026-04-15 clarification pass)

**Tests**: Spec 002 explicitly requires automated Jest tests as the pre-prod deploy gate (FR-013 + FR-015, clarified 2026-04-15). Test tasks are therefore MANDATORY for every user story and MUST be written such that they FAIL before the corresponding implementation task lands.

**Organization**: Tasks are grouped by user story. US1–US4 correspond to the five admin callables (US1 = assign, US2 = approve/reject payments — combined because they share a file layer, US3 = resolve dispute, US4 = close job). US5 (the FR-012 Firestore rule update) is treated as its own story per spec.md.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no incomplete dependencies)
- **[Story]**: US1 / US2 / US3 / US4 / US5 — maps to the user stories in `spec.md`
- Every task lists exact absolute-rooted file paths under the repo root `C:\Users\LTC\Downloads\Syanat-main-mine\Syanat-lastupdate\`

## Path Conventions

All new code lives under `functions/` at the repo root. The Firestore rules file at `firestore.rules` (also at the repo root) is modified by exactly one task (T046). No file in `lib/` or `admin_web/` is touched by this spec (FR-017, FR-018, constitution Principle II).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Scaffold the `functions/` project, lock the runtime + region, wire up the test harness. Nothing in Phase 1 writes production code — only the build and test toolchain.

- [x] T001 Create the `functions/` directory at repo root via `firebase init functions` (TypeScript, no ESLint, install deps). Before committing the scaffold, review `git status` / `git diff --cached` for any `serviceAccountKey*.json` or `.env` files and remove them. Output: `functions/package.json`, `functions/tsconfig.json`, `functions/src/index.ts`, `functions/.gitignore` (auto-generated).
- [x] T002 Edit `functions/package.json`: set `"engines": { "node": "20" }` (Clarified 2026-04-15 / R-8), add dev deps `jest`, `ts-jest`, `@types/jest`, `firebase-functions-test`, and add npm scripts `"build": "tsc"`, `"serve": "npm run build && firebase emulators:start --only functions,firestore,auth"`, `"test": "jest --runInBand"`, `"test:emulators": "firebase emulators:exec --only functions,firestore,auth \"npm test\""`. Node.js 18 MUST NOT appear anywhere in the file. **Constitution deviation — do not "correct"**: the project constitution §Technology Constraints currently names Node 18; this spec intentionally supersedes that line (see plan.md §Complexity Tracking entry "Node 20 vs constitution Node 18"). A follow-up PATCH-level constitution amendment is tracked outside this spec — a cheaper executor MUST NOT rewrite `"node": "20"` back to `"18"` on the grounds that "the constitution says 18." Node 18 is EOL and Firebase rejects deploys against it.
- [x] T003 [P] Edit `functions/tsconfig.json`: enable `"strict": true`, `"target": "es2022"`, `"module": "commonjs"`, `"outDir": "lib"`, `"esModuleInterop": true`, `"skipLibCheck": true`. Verify `npm run build` from `functions/` produces zero errors with only the scaffold `index.ts` present.
- [x] T004 [P] Edit repo-root `.gitignore` to ensure **the FR-020 minimum set** is excluded (append if missing): `serviceAccountKey.json`, `**/serviceAccountKey*.json`, `functions/.env`, `functions/.runtimeconfig.json`, `functions/node_modules/`, `functions/lib/`. Additionally verify these broader Principle VIII patterns are present (add only if missing — do NOT remove existing entries): `.env`, `.env.*`, `*.jks`, `google-services.json.local`, `GoogleService-Info.plist.local`, `.flaskenv`, `.npmrc`, `*.key`, `*.pem`, `*.p8`, `*.p12`. **Scope note**: this task covers the minimum required by FR-020 plus a verification sweep of Principle VIII's enumeration; it is NOT a full repo-wide audit of every possible secret pattern. A cheaper executor MUST NOT broaden the scope beyond this list or refactor the existing `.gitignore` structure.
- [x] T005 [P] Create `functions/jest.config.js` with `preset: 'ts-jest'`, `testEnvironment: 'node'`, `testMatch: ['**/test/**/*.test.ts']`, `testTimeout: 30000`. Add `functions/test/` as a new directory with a placeholder `.gitkeep`.
- [x] T006 Edit repo-root `firebase.json` to add a `"functions"` section: `{ "source": "functions", "predeploy": ["npm --prefix \"$RESOURCE_DIR\" run build"], "runtime": "nodejs20" }`. Preserve the existing `firestore` section unchanged. Do NOT add a `hosting` section.

**Checkpoint**: `cd functions && npm run build && npm test` completes without error (test suite is empty at this point — that's expected). The `functions/` scaffold is committed. `.gitignore` excludes all credential file patterns.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Build the shared helpers (`verifyAdmin`, `writeAuditLog`, `auditTemplates`, `logSafe`) and the test-setup harness that every user story depends on. No user story can start until Phase 2 is complete.

**⚠️ CRITICAL**: Every callable in Phases 3–6 depends on these helpers. A broken helper breaks all five functions simultaneously.

- [x] T007 Create `functions/src/lib/verify-admin.ts` implementing `verifyAdmin(request)` per FR-002 / research R-5: reads `users/{request.auth.uid}` via the Admin SDK, throws `HttpsError('unauthenticated')` if `request.auth` is missing, throws `HttpsError('permission-denied')` if the document does not exist or `role !== 'admin'`. Accepts a `CallableRequest` from `firebase-functions/v2/https`. Must NOT be called inside a transaction — it runs once at the top of the handler before any `runTransaction`.
- [x] T008 [P] Create `functions/src/lib/audit-templates.ts` per FR-003a / research R-12. Export an `ActivityType` union (`'job_assigned' | 'payment_approved' | 'payment_rejected' | 'dispute_resolved' | 'job_force_closed'`) and a `renderDescription(type, fields)` function. Implement the five fixed templates verbatim from `data-model.md` §3.1 — no free-text interpolation. Add an inline `as const` array for `ActivityType` so enum values cannot drift.
- [x] T009 [P] Create `functions/src/lib/audit-log.ts` implementing `writeAuditLog(tx, entry)` per FR-003. Signature: `(tx: FirebaseFirestore.Transaction, entry: { type: ActivityType; userId: string; jobId?: string; paymentId?: string; resolution?: 'reopen'|'complete'|'cancel'; reason?: string; fields: Record<string,string> })`. Resolves a new `activity_log/{autoId}` document ref, builds the audit document with `type`, `description` (via `renderDescription`), `createdAt: FieldValue.serverTimestamp()`, `userId`, `role: 'admin'`, and any of `jobId`/`paymentId`/`resolution`/`reason` that are provided, then calls `tx.set(ref, doc)`. Audit fields MUST NEVER be accepted from the client.
- [x] T010 [P] Create `functions/src/lib/log-safe.ts` implementing `safeLog(fnName, request)` per FR-011 / Principle XIII. Logs exactly: function name, `request.auth?.uid`, and — if the handler passes a `reason` string — a `reason.slice(0, 200)`. MUST NOT log any field from `payments/*`, `users/*`, the full `request.data` payload, or `request.auth.token`.
- [x] T011 [P] Create `functions/src/index.ts` that calls `admin.initializeApp()` exactly once (FR-004). Add `export * from './stats';` as a stub for Spec 003 to fill later. **Do NOT re-export any `./admin/*` module here** — Phase 2 is helpers-only, so Phase 2 checkpoint `npm run build` must succeed with no admin callables present. Each Phase 3–6 implementation task (T016, T020, T021, T023, T025) appends its own single-line `export` to this file when it lands.
- [x] T012 [P] Create `functions/src/stats/index.ts` as an empty module (just `export {};`) so the Spec 003 re-export in `index.ts` resolves. A one-line comment notes: "Spec 003 fills in event-driven stats functions here. Do not add admin write logic."
- [x] T013 Create `functions/test/setup.ts` that exposes a `setupEmulators()` helper for Jest: initializes a test `admin.initializeApp` against the emulator (`FIRESTORE_EMULATOR_HOST`, `FIREBASE_AUTH_EMULATOR_HOST` env vars), provides a `seedFixtures()` function that creates an admin user doc (`users/test-admin-uid` with `role: 'admin'`, `fullName: 'Test Admin'`), a non-admin user doc (`users/test-nonadmin-uid` with `role: 'user'`), a technician user doc (`users/test-tech-uid` with `fullName: 'Test Technician'`), and fixture jobs/payments in each required status (requested, active, receipt_disputed, completed for jobs; PENDING, CONFIRMED, REJECTED for payments). Also provides a `cleanupFixtures()` that deletes everything it seeded.
- [x] T014 [P] Create `functions/test/helpers/call-callable.ts` with a `callAdminFn(fnRef, data, uid)` helper that wraps `firebase-functions-test` invocation with a fake auth context (sets `context.auth = { uid, token: { ... } }`). This keeps test files free of Firebase test SDK boilerplate.

**Checkpoint**: `cd functions && npm run build` succeeds with the helpers compiled but no admin callables yet. `functions/test/setup.ts` can be imported from an empty Jest test and `seedFixtures()` seeds documents into the emulator without error. Phase 2 is **complete** and all 5 user stories can now start in parallel.

---

## Phase 3: User Story 1 - Move admin job assignment to `adminAssignJob` (Priority: P1) 🎯 MVP

**Goal**: Ship `adminAssignJob` as a callable in `europe-west1`, verified by admin, transactional, writing audit + activity log. This story is the MVP per spec.md §US1 "Why this priority".

**Independent Test**: Run `cd functions && npm run test:emulators -- --testPathPattern=assign-job` and observe all 6 scenarios from spec.md §US1 passing (success, permission-denied, unauthenticated, failed-precondition on non-`requested`, not-found on missing technician, invalid-argument on empty inputs). A successful call mutates `jobs/{jobId}` per data-model.md §1 and writes a matching `activity_log` entry with `description: "Admin assigned job {jobId} to {assignedTechnicianName}"`.

### Tests for User Story 1 (write first, MUST fail before T016)

- [x] T015 [P] [US1] Create `functions/test/admin/assign-job.test.ts` containing 6 Jest cases that map 1:1 to spec.md §US1 Acceptance Scenarios 1–6: (a) success + all fields + audit entry, (b) non-admin → `permission-denied`, (c) unauthenticated → `unauthenticated`, (d) wrong status → `failed-precondition`, (e) missing technician doc → `not-found`, (f) empty `jobId`/`technicianId` → `invalid-argument` BEFORE any Firestore read (spy on `db.collection` to assert it was not called in the invalid-arg path). Each assertion on the `activity_log` entry MUST check `type === 'job_assigned'` AND `description === 'Admin assigned job ' + jobId + ' to ' + techFullName` verbatim. The test file MUST import and use `setupEmulators`, `seedFixtures`, and `callAdminFn` from Phase 2. Expected state after this task: `npm test -- assign-job` FAILS with "module not found" for `./admin/assign-job`.

### Implementation for User Story 1

- [x] T016 [US1] Create `functions/src/admin/assign-job.ts` implementing `adminAssignJob` per FR-005 / contracts §1. Use `onCall` from `firebase-functions/v2/https` with `{ region: 'europe-west1' }` (FR-004a / R-9). Top-level try/catch rethrows non-`HttpsError` as `HttpsError('internal', 'Unexpected error')` (FR-010). Order of operations: (1) `await verifyAdmin(request)`, (2) `safeLog('adminAssignJob', request)`, (3) validate `jobId` and `technicianId` as non-empty trimmed strings — throw `invalid-argument` BEFORE any Firestore read, (4) `db.runTransaction(async tx => { ... })` that reads the job doc, asserts `status === 'requested'` (else `failed-precondition`), reads the technician doc, asserts it exists (else `not-found`), extracts `fullName`, then `tx.update(jobRef, { status: 'active', assignedTechnicianId, technicianId, assignedTechnicianName, assignedBy: request.auth.uid, assignedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() })`, then `writeAuditLog(tx, { type: 'job_assigned', userId: request.auth.uid, jobId, fields: { jobId, assignedTechnicianName: fullName } })`. **Also append** `export { adminAssignJob } from './admin/assign-job';` to `functions/src/index.ts` (see T011 — admin re-exports are added per-story, not up-front). After this task lands, T015's suite MUST pass.
- [x] T017 [US1] Verify `functions/src/index.ts` now contains `export { adminAssignJob } from './admin/assign-job';` (added as the final step of T016). Run `npm run build` — must compile clean. Run `npm test -- assign-job` — all 6 scenarios must pass.

**Checkpoint**: `adminAssignJob` is fully functional, committed, and its Jest suite is green under the emulator. US1 is independently deployable. If you stop here, you have an MVP that moves the highest-volume admin action server-side.

---

## Phase 4: User Story 2 - Move payment approval/rejection to `adminApprovePayment` + `adminRejectPayment` (Priority: P1)

**Goal**: Ship two callables (not one — research R-1) so that `adminRejectPayment` can enforce a non-empty `reason` at the type level. Every approve/reject now leaves a `reviewedBy` + `reviewedAt` trail and rejections additionally stamp `rejectionReason`.

**Independent Test**: `cd functions && npm run test:emulators -- --testPathPattern=payment` passes all scenarios from spec.md §US2. Successful approve → `payments/{id}.status === 'CONFIRMED'` with reviewer stamps; successful reject → `'REJECTED'` + `rejectionReason` stamped; empty/whitespace `reason` → `invalid-argument` before any Firestore read; already-resolved payment → `failed-precondition`; non-admin caller → `permission-denied`.

### Tests for User Story 2 (write first, MUST fail before T020/T021)

- [x] T018 [P] [US2] Create `functions/test/admin/approve-payment.test.ts` covering spec.md §US2 Acceptance Scenario 1 + non-admin case + failed-precondition (payment already `CONFIRMED`/`REJECTED`) + empty `paymentId`. Assert the matching `activity_log` entry has `type === 'payment_approved'` and `description === 'Admin approved payment ' + paymentId`. Expected state: FAILS with "module not found" for `./admin/approve-payment`.
- [x] T019 [P] [US2] Create `functions/test/admin/reject-payment.test.ts` covering spec.md §US2 Acceptance Scenarios 2–5: successful reject with reason stamped, empty-reason and whitespace-reason and missing-reason (all three → `invalid-argument`), already-resolved payment → `failed-precondition`, non-admin → `permission-denied`. Assert the audit entry's `description === 'Admin rejected payment ' + paymentId` (the `reason` is on its own audit field, NOT in the description — R-12). Expected state: FAILS with "module not found" for `./admin/reject-payment`.

### Implementation for User Story 2

- [x] T020 [P] [US2] Create `functions/src/admin/approve-payment.ts` per FR-006 / contracts §2. Use `onCall` with `{ region: 'europe-west1' }`. Order of operations: (1) `await verifyAdmin(request)` as the first executable line, (2) `safeLog('adminApprovePayment', request)`, (3) validate `paymentId` non-empty trimmed string (throw `invalid-argument` before any Firestore read), (4) `runTransaction` reading `payments/{paymentId}`, asserting `status === 'PENDING'` (else `failed-precondition`), `tx.update` with `status: 'CONFIRMED'`, `reviewedBy: request.auth.uid`, `reviewedAt: FieldValue.serverTimestamp()`, then `writeAuditLog(tx, { type: 'payment_approved', userId: request.auth.uid, paymentId, fields: { paymentId } })`. Top-level try/catch rethrows non-`HttpsError` as `HttpsError('internal','Unexpected error')`. **Also append** `export { adminApprovePayment } from './admin/approve-payment';` to `functions/src/index.ts`. After this task, T018's suite passes.
- [x] T021 [P] [US2] Create `functions/src/admin/reject-payment.ts` per FR-007 / contracts §3: identical skeleton to T020 — `verifyAdmin` → `safeLog('adminRejectPayment', request)` → validation — but also validates `reason` as non-empty after `.trim()` BEFORE any Firestore read (this is the load-bearing Principle X check — "a rejection without a reason MUST never reach Firestore"), writes `status: 'REJECTED'`, `reviewedBy`, `reviewedAt`, `rejectionReason: trimmedReason`, and writes audit with `type: 'payment_rejected'`, plus a top-level `reason: trimmedReason` field on the audit entry (NOT interpolated into `description`). **Also append** `export { adminRejectPayment } from './admin/reject-payment';` to `functions/src/index.ts`. After this task, T019's suite passes.

**Checkpoint**: Both payment callables green. US2 is independently deployable.

---

## Phase 5: User Story 3 - Move dispute resolution to `adminResolveDispute` (Priority: P1)

**Goal**: Ship the most complex callable — three resolution branches (`reopen`/`complete`/`cancel`), optional `overrideAmount`, fallback to existing `price` on the complete branch, preserved field name `disputeResolvedAt` (FR-019).

**Independent Test**: `cd functions && npm run test:emulators -- --testPathPattern=resolve-dispute` passes all scenarios from spec.md §US3. Each of the three resolution branches writes exactly the fields listed in data-model.md §1.1. An invalid `resolution` value or empty `reason` throws `invalid-argument` before any Firestore read. The audit description is `"Admin resolved dispute on job {jobId} ({resolution})"` — no reason interpolated.

### Tests for User Story 3 (write first, MUST fail before T023)

- [x] T022 [P] [US3] Create `functions/test/admin/resolve-dispute.test.ts` with 7 cases mapping to spec.md §US3 Acceptance Scenarios 1–6 plus one extra case for the edge case in spec.md §Edge Cases "complete branch with no overrideAmount and no existing price" → `failed-precondition`. The `reopen` case must assert `receiptRejected === false`. The `complete` case with `overrideAmount: 150` must assert both `amountPaid === 150` and `price === 150` and `adminClosedAt` is stamped. The `cancel` case must assert `status === 'cancelled'`. All three branches assert the audit `description` matches the template `Admin resolved dispute on job {jobId} ({resolution})`. Expected state: FAILS with "module not found" for `./admin/resolve-dispute`.

### Implementation for User Story 3

- [x] T023 [US3] Create `functions/src/admin/resolve-dispute.ts` per FR-008 / contracts §4. Use `onCall` with `{ region: 'europe-west1' }`. Top-level try/catch rethrows non-`HttpsError` as `HttpsError('internal','Unexpected error')`. Order of operations: (1) `await verifyAdmin(request)` as the first executable line, (2) `safeLog('adminResolveDispute', request)`, (3) define `const RESOLUTIONS = ['reopen', 'complete', 'cancel'] as const` at the top of the file (Principle X — local `as const` enum), (4) validation order (all before any Firestore read): `jobId` non-empty trimmed string → `resolution` in `RESOLUTIONS` (else `invalid-argument`) → `reason` non-empty after trim → if `overrideAmount` is present, assert `Number.isFinite(overrideAmount) && overrideAmount >= 0`. Then `runTransaction`: read job, assert `status === 'receipt_disputed'`, compute target status from a `{ reopen: 'awaiting_customer_approval', complete: 'completed', cancel: 'cancelled' }` map, build the update object starting with `{ status, disputeResolvedAt: serverTimestamp(), resolvedBy: uid, resolutionNote: trimmedReason, updatedAt: serverTimestamp() }`, then branch: on `reopen` add `receiptRejected: false`; on `complete` compute `finalAmount = overrideAmount ?? jobData.price` — if `finalAmount == null` throw `failed-precondition` (edge case) — else add `amountPaid: finalAmount, price: finalAmount, adminClosedAt: serverTimestamp()`; on `cancel` add nothing extra. `tx.update(jobRef, updateObj)`, then `writeAuditLog(tx, { type: 'dispute_resolved', userId, jobId, resolution, reason: trimmedReason, fields: { jobId, resolution } })`. **Also append** `export { adminResolveDispute } from './admin/resolve-dispute';` to `functions/src/index.ts`. After this task, T022's suite passes.

**Checkpoint**: `adminResolveDispute` green. US3 is the most complex function; once it passes, US4 is pattern repetition.

---

## Phase 6: User Story 4 - Move force-close to idempotent `adminCloseJob` (Priority: P2)

**Goal**: Ship the one function where idempotency is load-bearing (research R-3). A second identical call produces zero observable changes — no second timestamp, no second audit entry.

**Independent Test**: `cd functions && npm run test:emulators -- --testPathPattern=close-job` passes all spec.md §US4 scenarios. The idempotency scenario (Scenario 2) MUST assert: after a second `adminCloseJob` call, `activity_log` contains exactly ONE entry for this job (not two) AND `jobs/{jobId}.adminClosedAt` is the same Firestore Timestamp object as after the first call.

### Tests for User Story 4 (write first, MUST fail before T025)

- [x] T024 [P] [US4] Create `functions/test/admin/close-job.test.ts` covering spec.md §US4 Acceptance Scenarios 1–4. Scenario 1: successful close of an `active` job — assert all fields including `status === 'completed'` (NOT `'force_closed'`, per FR-009 / Principle V). Scenario 2: **idempotency** — call twice with identical args, query `activity_log.where('jobId','==',jobId).get()` and assert `snapshot.size === 1`, also re-read the job doc after the second call and assert `adminClosedAt` is unchanged. Scenario 3: invalid `amountPaid` (`-1`, `'nope'`, missing) → `invalid-argument`; **but** `amountPaid: 0` must succeed (free service case). Scenario 4: non-admin → `permission-denied`. Expected state: FAILS with "module not found" for `./admin/close-job`.

### Implementation for User Story 4

- [x] T025 [US4] Create `functions/src/admin/close-job.ts` per FR-009 / contracts §5. Use `onCall` with `{ region: 'europe-west1' }`. Top-level try/catch rethrows non-`HttpsError` as `HttpsError('internal','Unexpected error')`. Order of operations: (1) `await verifyAdmin(request)` as the first executable line, (2) `safeLog('adminCloseJob', request)`, (3) validate `jobId` non-empty trimmed string, `amountPaid` must pass `Number.isFinite(amountPaid) && amountPaid >= 0` (so `0` succeeds, `-1` fails, `'nope'` fails, `undefined` fails) — throw `invalid-argument` before any Firestore read. (4) `runTransaction`: read `jobs/{jobId}` from the **transaction snapshot** (NOT a pre-transaction read — research R-3 TOCTOU rule), check `data.adminClosedAt != null` as the idempotency guard → if true, **return success without calling `tx.update` or `writeAuditLog`**. Otherwise `tx.update(jobRef, { status: 'completed', amountPaid, price: amountPaid, adminClosedAt: serverTimestamp(), adminClosedBy: uid, updatedAt: serverTimestamp() })` then `writeAuditLog(tx, { type: 'job_force_closed', userId, jobId, fields: { jobId } })`. Return `{ ok: true }` in both the first-call and second-call paths. **Also append** `export { adminCloseJob } from './admin/close-job';` to `functions/src/index.ts`. After this task, T024's suite passes.

**Checkpoint**: All four admin job/payment callables are implemented and tested. The Jest suite `npm test` runs all 5 test files together and exits green under `firebase emulators:exec`.

---

## Phase 7: User Story 5 - Expand Firestore rule whitelist for the new audit fields (Priority: P1)

**Goal**: Keep defense-in-depth for the direct-client admin assignment path. Expand the `affectedKeys().hasOnly([...])` whitelist on the admin-assignment rule so that any direct-client write (existing mobile admin client today, or any future direct path) that includes the new `assignedBy`/`assignedAt` fields passes.

**Independent Test**: Rules Playground in Firebase Console for project `syana-ea75a`: (1) simulate an admin write to `jobs/{jobId}` with the full new field set — ALLOWED; (2) simulate a write adding `customerId` — DENIED; (3) simulate the current mobile-client write (old smaller field set) — ALLOWED (because `hasOnly` permits subsets).

- [x] T026 [US5] Edit `firestore.rules` at the repo root. Locate the admin job-assignment write block (added by Spec 001) and expand its `affectedKeys().hasOnly([...])` from `['status', 'assignedTechnicianId', 'technicianId', 'assignedTechnicianName', 'updatedAt']` to `['status', 'assignedTechnicianId', 'technicianId', 'assignedTechnicianName', 'assignedBy', 'assignedAt', 'updatedAt']`. The rule MUST continue to require `isAdmin()` and the `status: requested → active` precondition. **No other rule block may be modified** (FR-018). Verify with `firebase emulators:start --only firestore` + the rules-playground-equivalent scenarios above, OR (optional) add `functions/test/rules/assignment-whitelist.test.ts` using `@firebase/rules-unit-testing` — but this is optional per research R-11.

**Checkpoint**: `firestore.rules` is the only file outside `functions/` touched by this spec. Rules playground confirms all three scenarios.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Deploy-readiness, smoke test, and compliance verification. These tasks touch multiple previous phases and must run **after** all five user stories are complete.

- [x] T027 [P] Run `cd functions && npm audit --production` per constitution Principle XII. Zero high/critical vulnerabilities MUST be reported. If any appear, upgrade the offending dep (usually `firebase-admin` or `firebase-functions`) and re-run until clean. Commit the resulting `package-lock.json` change if any.
- [x] T028 [P] Run `cd functions && npm run build` one final time and verify zero TypeScript errors (FR-001 acceptance criterion).
- [x] T029 Run the full pre-prod deploy gate: `cd functions && npm run test:emulators`. This is `firebase emulators:exec --only functions,firestore,auth "npm test"`. Exit code MUST be `0`. Every scenario in the FR-013 matrix must pass. This task replaces the (unenforceable) hosting-preview step originally in FR-015 — see Clarification Q1 and research R-10. If this task fails, fix and re-run; the production deploy is blocked until T029 is green.
- [x] T030 Run `git log -p functions/` and grep the output for any `serviceAccountKey` / `serviceAccount.json` / `.env` content. Zero matches MUST be found per SC-008 / FR-020 / Principle VIII. If any found, STOP — rotate the leaked credential before any deploy (Principle VIII closing sentence).
- [ ] T031 **[DEFERRED — requires Blaze plan upgrade]** Execute the atomic deploy: `firebase deploy --only functions,firestore:rules` (FR-014 / R-4 / Principle IV). Splitting into two deploys is a defect. Review the deploy diff summary that Firebase prints before confirming.
- [ ] T032 **[DEFERRED — requires T031]** Post-deploy smoke test per FR-016 / quickstart.md §7. Within 10 minutes of the deploy: (1) confirm all 5 functions appear in Firebase Console → Functions with `Active` status and region `europe-west1`; (2) invoke each of the 5 functions once against a fixture doc in production (or a test account) and verify both the expected document mutation and the matching `activity_log` entry. Log the smoke-test timestamps in the PR description for SC-002 traceability.
- [ ] T033 **[DEFERRED — requires T032]** [P] Run a second `adminCloseJob` call on the production fixture used in T032 and confirm it returns success with zero document mutation and zero new `activity_log` entry (SC-005 production verification).
- [x] T034 [P] Update `specs/002-cloud-functions/tasks.md` (this file) by checking off every completed task. Commit. DO NOT rewrite the task descriptions — only the checkboxes.
- [ ] T035 **[DEFERRED — requires T031, 72h window]** Monitor Firestore debug logs for 72 hours per SC-006 to confirm the existing mobile admin client has zero new rule-related denials attributable to T026's whitelist expansion. If any appear, the cause is a field the mobile client writes that is NOT in the expanded whitelist — add the missing field to the whitelist in a follow-up patch (NOT by widening the rule to drop `hasOnly`).
- [ ] T036 **[DEFERRED — requires T032, 72h window]** At the 72-hour mark (measured from T032 smoke-test completion), run the SC-003 audit reconciliation per spec.md §SC-003: `firebase functions:log --only adminAssignJob,adminApprovePayment,adminRejectPayment,adminResolveDispute,adminCloseJob` for the 72-hour window, count successful invocations, and cross-check against a Firestore query on `activity_log` with `where('createdAt','>=', smokeTestCompletionTimestamp).where('createdAt','<=', smokeTestCompletionTimestamp + 72h)` filtered to the admin UIDs observed. Counts MUST match exactly (SC-003 target: 100% match). Record the two counts in the PR description / sign-off comment for traceability. If they diverge, the divergence itself is the P0 defect — DO NOT silently reconcile it.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — can start immediately.
- **Phase 2 (Foundational)**: Depends on Phase 1 completion. BLOCKS all user story phases.
- **Phases 3–7 (User Stories)**: All depend on Phase 2. Once Phase 2 is green, **all five stories can run in parallel** (different files, different fixtures).
- **Phase 8 (Polish / Deploy)**: Depends on **all** user stories (Phases 3–7) being complete AND all their Jest tests passing.

### User Story Dependencies (Phases 3–7)

- **US1 (Phase 3)**: Only depends on Phase 2 helpers. Independent.
- **US2 (Phase 4)**: Only depends on Phase 2 helpers. Independent. Two functions in one story — `approve-payment.ts` and `reject-payment.ts` are in different files and fully parallelizable (T020 and T021 can run simultaneously).
- **US3 (Phase 5)**: Only depends on Phase 2 helpers. Independent.
- **US4 (Phase 6)**: Only depends on Phase 2 helpers. Independent. Pattern-repeats US1/US3 — this is why it's P2 in the spec.
- **US5 (Phase 7)**: Only depends on Phase 2 because it has no runtime dependency on the functions — it is a `firestore.rules` edit. Can technically start after Phase 1, but holding it until Phase 7 ensures the rule change and the function change ship together (Principle IV).

### Within Each User Story Phase

- Tests first (the `*.test.ts` file) MUST be written before the implementation file and MUST fail.
- Implementation file lands.
- Test suite must pass before moving to the next phase.

### Parallel Opportunities

- Phase 1: T003, T004, T005 are [P] (different files, no dependencies between them).
- Phase 2: T008, T009, T010, T011, T012, T014 are [P] — all create distinct new files under `functions/src/lib/` or `functions/test/`. Only T007 and T013 are non-parallel (T007 is the precondition for downstream tests that need `verifyAdmin`; T013 depends on T007's module path existing).
- **Phases 3–7 run in parallel with each other** once Phase 2 is done. This is the biggest parallelism win: five developers (or five Codex sessions) can own one story each with zero merge conflicts — every story edits different files.
- Within Phase 4: T020 and T021 are [P].
- Phase 8: T027, T028, T033, T034 are [P] against each other. T029 → T030 → T031 → T032 is a strict sequence (gate, audit, deploy, smoke) and MUST run serially.

---

## Parallel Example: After Phase 2 (one story per agent)

```bash
# Launch all five user stories in parallel after T014 completes:
Agent A: Phase 3 (US1 — adminAssignJob)     # T015 → T016 → T017
Agent B: Phase 4 (US2 — payment callables)  # T018 + T019 → T020 + T021
Agent C: Phase 5 (US3 — adminResolveDispute) # T022 → T023
Agent D: Phase 6 (US4 — adminCloseJob)      # T024 → T025
Agent E: Phase 7 (US5 — firestore.rules)    # T026
```

Each agent has its own admin file: `functions/src/admin/assign-job.ts`, `approve-payment.ts`, `reject-payment.ts`, `resolve-dispute.ts`, `close-job.ts`, and `firestore.rules` are all distinct paths. **One shared file** — `functions/src/index.ts` — is appended to by T016, T020, T021, T023, T025 (one `export` line each). These appends are pure additions at the end of the file and do not conflict semantically, but if run strictly in parallel they may produce textual merge conflicts. Resolve by ordering the five `export` lines however you like — the file is import-order-insensitive.

---

## Parallel Example: Within Phase 2 (foundation helpers)

```bash
# After T007 (verifyAdmin, serial because downstream files import it):
Task: "T008 Create functions/src/lib/audit-templates.ts"
Task: "T009 Create functions/src/lib/audit-log.ts"
Task: "T010 Create functions/src/lib/log-safe.ts"
Task: "T011 Create functions/src/index.ts"
Task: "T012 Create functions/src/stats/index.ts"
Task: "T014 Create functions/test/helpers/call-callable.ts"
# T013 (test/setup.ts) runs after T007 lands but does not block T008..T012.
```

---

## Implementation Strategy

### MVP First (User Story 1 only)

1. Complete Phase 1 (T001–T006) — scaffold.
2. Complete Phase 2 (T007–T014) — helpers and test harness.
3. Complete Phase 3 (T015–T017) — `adminAssignJob` + its Jest suite.
4. **STOP and VALIDATE**: Run `npm run test:emulators -- --testPathPattern=assign-job`. Green = MVP ready.
5. If the goal is "ship an MVP and iterate", Phase 7 (T026) can ride along in the same deploy so the rule update is in place, then deploy only `adminAssignJob`. The other four functions are added in subsequent deploys. This is a valid but **non-recommended** path because it violates the spec's atomic-deploy posture (FR-014 bundles all 5 together).

### Recommended: Atomic full-phase delivery

1. Phase 1 + Phase 2 sequentially (can't parallelize — they are foundations).
2. Phases 3–7 **in parallel** (5 parallel workstreams if staffed; or serial if single-developer — recommended order: US1 → US3 → US4 → US2 → US5, because US1 exercises every helper and US3 is the most complex, so bugs in helpers surface early).
3. Phase 8 serially (T027 → T028 → T029 gate → T030 credential audit → T031 atomic deploy → T032 smoke → T033 idempotency verify → T034 checkbox update → T035 72-hour monitor).
4. Single `firebase deploy --only functions,firestore:rules` ships the whole spec.

### Parallel Team Strategy (five agents)

1. One agent completes Phase 1 + Phase 2 (T001–T014) serially because they are small and interdependent.
2. Five agents pick up Phases 3–7 in parallel — one story each.
3. One agent runs Phase 8 after all five stories are in.

### Codex handoff suitability

All tasks in this file are file-scoped and have explicit paths + behavioral spec references. A cheaper execution model (Codex) can work through the tasks sequentially by phase without needing to re-plan. The expensive judgment was front-loaded into `spec.md` → `research.md` → `plan.md` → `data-model.md` → `contracts/`. This task list is the handoff boundary.

---

## Notes

- [P] tasks = different files, no incomplete dependencies.
- [Story] label maps each task to its user story for traceability to `spec.md`.
- Tests MUST be written before implementation in each user story phase (Jest + emulator harness). This is NOT strict TDD — it is the FR-013 + FR-015 deploy-gate requirement in disguise.
- Commit after each logical group (typically one task, or one test+impl pair).
- Stop at any checkpoint to validate a story independently — every story is MVP-capable.
- Avoid: vague tasks (every task above names a specific file), cross-story dependencies (there are none by design), and touching any file in `lib/` or `admin_web/` (constitution Principle II).

---

## Format validation (self-check)

Every task above conforms to the strict checklist format `- [ ] [TaskID] [P?] [Story?] Description with file path`:
- ✅ Checkbox present on all 36 tasks.
- ✅ Sequential IDs T001–T036, no gaps.
- ✅ [P] marker only on truly parallel tasks.
- ✅ [US1]..[US5] labels only on Phase 3–7 tasks; Phases 1, 2, and 8 carry no story label.
- ✅ Every task description names at least one absolute-rooted file path.

Total task count: **36**
- Phase 1 (Setup): 6
- Phase 2 (Foundational): 8
- Phase 3 (US1): 3
- Phase 4 (US2): 4
- Phase 5 (US3): 2
- Phase 6 (US4): 2
- Phase 7 (US5): 1
- Phase 8 (Polish / Deploy): 10
