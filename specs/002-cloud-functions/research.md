# Research: Admin Cloud Functions

**Feature**: `002-cloud-functions`
**Date**: 2026-04-14 (R-1..R-7); **amended 2026-04-15** (R-7 superseded; R-8..R-12 added per spec.md §Clarifications → Session 2026-04-15)
**Status**: Complete — zero open clarifications

This document captures the non-obvious decisions the implementer needs to trust. Each entry follows `Decision / Rationale / Alternatives considered`. Everything here is downstream of `WOOHOO/Migration_Implementation_Plan.md` Phases 3 and 4 and the constitution at `.specify/memory/constitution.md`.

---

## R-1 — Why split `updatePaymentStatus` into two callables instead of one

**Decision**: Implement payment review as **two** separate Cloud Functions: `adminApprovePayment({paymentId})` and `adminRejectPayment({paymentId, reason})`. Do not implement a single `updatePaymentStatus({paymentId, status, reason?})` function.

**Rationale**: The two operations diverge on a hard requirement. `adminRejectPayment` MUST require a non-empty `reason` (constitution Principle X: "A rejection without a reason MUST never reach Firestore"). `adminApprovePayment` does not. A combined function would either:
1. Make `reason` always optional and lose the rejection-requires-reason guarantee, or
2. Conditionally validate `reason` based on `status`, which puts a critical security check behind a conditional and makes the code harder to audit.

Two functions also let each one be analysed in isolation by the emulator test matrix and let the audit log entry pick the right `type` value (`payment_approved` vs `payment_rejected`) without an `if`. The mobile admin client's existing `updatePaymentStatus(paymentId, status)` is unchanged — it is not a caller of these new functions, so there is no API breakage.

**Alternatives considered**:
- *Single `updatePaymentStatus` callable* — rejected as above.
- *Single callable that takes a discriminated union* (`{op: 'approve', paymentId}` | `{op: 'reject', paymentId, reason}`) — rejected because the validation surface is identical to two functions but the function name in Cloud Functions logs becomes ambiguous, hurting observability.

**Reference**: Migration plan §Task 4-2; constitution Principle X §"A rejection without a reason MUST never reach Firestore".

---

## R-2 — Why `adminAssignJob` looks up the technician name server-side

**Decision**: `adminAssignJob({jobId, technicianId})` reads `users/{technicianId}.fullName` inside the function and writes that value to the job document as `assignedTechnicianName`. The client does NOT pass `technicianName`.

**Rationale**: Trusting a client-supplied display name is a low-grade integrity bug today (the mobile admin client passes `technicianName` from a pre-fetched user doc — see `lib/firebase_service.dart` `assignJob` at line 1048). The client could pre-fetch the wrong document, the user doc could change between the fetch and the assignment, or a future malicious client could lie about it outright. None of these break the system, but all of them make the admin audit trail less trustworthy.

Server-side lookup is one extra Firestore read per assignment — negligible cost on a low-volume admin path, and it kills the entire class of "the assigned name is wrong" bugs. It also lets the function reject the assignment (with `not-found`) when the technician document genuinely does not exist, which is a useful signal the current mobile flow does not produce.

**Alternatives considered**:
- *Trust the client's `technicianName`* — current mobile behaviour. Rejected for the audit-integrity reason above.
- *Look up the name asynchronously in a follow-up Cloud Function trigger* — rejected because it puts the displayed name in eventually-consistent territory, which contradicts the synchronous semantics admins expect.

**Reference**: Migration plan §Task 4-1 §"Look up technician name from `users/{technicianId}` document (server-side — web client doesn't need to pass it)"; constitution decision D5.

---

## R-3 — Why `adminCloseJob`'s idempotency guard lives **inside** the transaction

**Decision**: The `adminClosedAt != null` check in `adminCloseJob` is performed against the snapshot read inside `db.runTransaction(...)`, NOT against a pre-transaction read.

**Rationale**: A pre-transaction read followed by a transaction write is a classic time-of-check / time-of-use (TOCTOU) defect: two concurrent retries can both observe `adminClosedAt == null` outside the transaction, both enter the transaction, and both write — double-stamping the timestamp and writing two `activity_log` entries. The whole point of Firestore transactions is that the read and the conditional write happen against the same locked snapshot, and the transaction retries automatically when the snapshot is stale.

The constitution makes this explicit (Principle X §"Checking a status outside the transaction and then writing inside it is a TOCTOU defect"). `adminCloseJob` is the one function in this spec where idempotency *materially* matters — admins are most likely to retry a force-close after a flaky network error — so this guard is the load-bearing piece of the function. The audit entry is also written inside the same transaction, so a "second call returns success without writing" path also produces no audit noise.

**Alternatives considered**:
- *Pre-transaction read + transaction write* — rejected per constitution Principle X.
- *Use a deduplication token from the client* — rejected because it requires a roundtrip to allocate the token and adds API surface that the migration plan does not authorise.
- *Rely on Firestore document version numbers via `precondition`* — rejected because the Admin SDK Node bindings do not surface a stable version field at the right granularity, and the transaction approach is simpler and more idiomatic.

**Reference**: Migration plan §Task 4-4 §"check if `adminClosedAt` field is already non-null. If so, return success without re-writing"; constitution Principle X.

---

## R-4 — Why deploy `--only functions,firestore:rules` atomically (and never split)

**Decision**: The Cloud Functions and the FR-012 rule update deploy in a single `firebase deploy --only functions,firestore:rules` command. They MUST NOT be split into two deploys.

**Rationale**: The rule update expands the assignment whitelist from `{status, assignedTechnicianId, technicianId, assignedTechnicianName, updatedAt}` to `{status, assignedTechnicianId, technicianId, assignedTechnicianName, assignedBy, assignedAt, updatedAt}`. The functions write the new fields (`assignedBy`, `assignedAt`). Cloud Functions use the Admin SDK and bypass rules entirely, so the rule update is technically not load-bearing for the function calls — but it IS load-bearing for the existing mobile admin client, which writes the same job document directly.

If we deployed the functions FIRST, the mobile client's existing assignment writes (which do NOT include `assignedBy`/`assignedAt`) would still pass the existing whitelist (because `hasOnly` permits subsets). No regression. If we deployed the rule FIRST, the new whitelist permits `{...assignedBy, assignedAt}` but the mobile client still writes the old shape — also no regression. So in *theory* either order is safe.

In *practice* the constitution Principle IV §"Firestore rules and Cloud Functions that must go live together are deployed in a single `firebase deploy --only X,Y` command — never separately" is a blanket rule. We honour the blanket rule because:
1. It is one less command for the on-call engineer to remember.
2. It eliminates an entire class of "did we actually deploy the rules" bugs.
3. It rules out drift if a future mobile release coincidentally also writes `assignedBy` / `assignedAt` — which Spec 006 will, eventually.

**Alternatives considered**:
- *Deploy rules first, then functions* — rejected per constitution.
- *Deploy functions first, then rules* — rejected per constitution.

**Reference**: Constitution Principle IV; migration plan §Task 4-1b "Update Firestore Rules for CF Assignment Fields".

---

## R-5 — Why `verifyAdmin` does a Firestore read (not Custom Claims)

**Decision**: `verifyAdmin(context)` performs an async Firestore read against `users/{context.auth.uid}` and checks `data.get('role', '') == 'admin'`. It does NOT use Firebase Auth Custom Claims.

**Rationale**: Decision D1 in the migration plan is the resolved blueprint for admin verification. The reasoning, copied verbatim from the plan: "Current `isAdmin()` works. Small admin team = negligible read cost. Eliminates 3 tasks (claim script, dual-mode rules, cleanup). Additive change later if needed." The Firestore rule helper `isAdmin()` already does the exact same thing for direct-client paths; mirroring it in TypeScript means there is one mental model for "what is an admin" across rules and functions.

The constitution explicitly forbids switching to Custom Claims without an amendment (Principle IX §"Custom Claims are out of scope and MUST NOT be introduced without a constitution amendment"). So this decision is locked.

**Cost analysis**: One extra Firestore read per privileged invocation. The admin team is ≤ 5 people; combined privileged write volume is on the order of dozens per day. Cost is fractions of a cent per month and the read is on the warm path (`users/{uid}` is the most-cached document for any session). No optimisation is needed.

**Alternatives considered**:
- *Custom Claims set via a Cloud Function trigger on `users/{uid}` writes* — rejected per constitution.
- *In-memory cache of admin UIDs* — rejected as premature optimisation (Principle VII).

**Reference**: Migration plan §Architectural Decisions D1; constitution Principle IX; constitution decision D1.

---

## R-6 — Why the `activity_log` write goes inside the same transaction as the job/payment write

**Decision**: For all five callables, the `activity_log` document is created inside the same `db.runTransaction(...)` block that updates the job or payment. The audit write uses the transaction's `tx.set()` against a freshly-allocated `activity_log` document reference.

**Rationale**: Constitution Principle XI says "Every state-changing Cloud Function MUST additionally write an entry to `activity_log` ... The entry is written inside the same transaction where practical; when transactional writes are not possible, the audit write MUST still complete before the function returns success." For Spec 002 it is always practical — the job/payment write and the audit write live in the same Firestore database, so a single transaction can hold both.

The benefit: the job-state change and the audit record are atomically committed together. There is never a state where the job moved but the audit log has no record, or where the audit log records a change that the job document does not actually reflect. This also closes a subtle race where a Cloud Function would commit the job write, then fail to commit the audit log (network blip, deploy mid-call), leaving an unauditable state change in production.

The cost: the transaction is slightly larger (two writes instead of one). Firestore allows up to 500 writes per transaction, so this is comfortably within budget.

**Alternatives considered**:
- *Sequential writes (job then audit)* — rejected because of the partial-failure window.
- *Audit log as an event-driven Cloud Function trigger on `jobs/*` writes* — rejected because the trigger fires from the job document itself, so it cannot reliably attribute the change to the admin who made it (the job document does not store the admin UID for every state transition).
- *Defer the audit write to a queue (Pub/Sub) for asynchronous processing* — rejected for spec scope (no Pub/Sub infrastructure exists yet) and because async audit defeats Principle XI's "before the function returns success" clause.

**Reference**: Constitution Principle XI; migration plan §Task 3-1 §"Create `audit-log.ts` ... function that writes to `activity_log` collection".

---

## R-7 — Automated Jest test suite inside `functions/test/**` (SUPERSEDED 2026-04-15)

> **History**: R-7 originally (2026-04-14) deferred test automation to Spec 007. Spec.md clarification Q4 (2026-04-15) reversed that decision. The current decision is below; the original text is preserved further down under "Previous decision" for traceability.

**Decision (2026-04-15)**: Verification of the five callables AND the FR-012 rule update is done by an automated Jest test suite committed at `functions/test/**.test.ts`. The suite is invoked by `firebase emulators:exec --only functions,firestore,auth "jest --runInBand"` from the `functions/` directory (wired behind `npm test`). Its exit code IS the FR-013 gate AND — via Q1's clarification — the FR-015 pre-prod deploy gate.

**Rationale**: Q1 of the 2026-04-15 clarification replaced the (unenforceable) Firebase Hosting preview channel with `firebase emulators:exec "npm test"` as the mandatory pre-prod gate. That gate requires a deterministic exit code, which a manual checklist cannot produce. Once an automated harness is required for the deploy gate, making the FR-013 matrix manual would be nonsensical — we would be running the same scenarios twice, once by hand and once in Jest. So FR-013 and FR-015 collapse onto the same Jest invocation.

Secondary benefits:
1. **Regression protection for future specs**. Spec 003 (event-driven stats) and Spec 005 (admin web features) will want to exercise these exact admin callables from new consumers. A committed Jest harness means they can add new `test/**` files without scaffolding their own.
2. **Constitution alignment**. Principle XI's audit trail is more credible when the emulator assertions explicitly check that `activity_log` has the expected `type`, `description`, `userId`, and timestamp on every successful call. A manual walkthrough cannot produce that evidence reproducibly.
3. **Security evidence**. Principle IX's "verifyAdmin is called first" and Principle X's "validation happens before any Firestore read" are testable invariants. The Jest suite encodes each as an assertion, not a code-review promise.

**Cost**: ~400 lines of test code + the `jest` / `ts-jest` / `firebase-functions-test` dev dependencies. Accepted.

**Optional add-on**: `@firebase/rules-unit-testing` for a single rule-harness test (`test/rules/assignment-whitelist.test.ts`) covering FR-012's subset-safety of `hasOnly`. This is optional because Spec 001 §R-4 already deferred the full rules harness, and adding it for one rule line is low-value. A plan may skip it and cover FR-012 in the Rules Playground during the deploy — research R-10 expresses no strong preference.

**Alternatives considered (2026-04-15)**:
- *Manual checklist against emulator UI* — rejected because FR-015 (as clarified in Q1) requires an exit-code gate that manual can't produce.
- *`firebase-functions-test` offline stubs only (no emulator)* — rejected because offline stubs do not exercise Firestore transactions, which is where the most important invariants (TOCTOU, idempotency guard) live. Transactions must run against a real Firestore — even if it is emulated.
- *Vitest instead of Jest* — no strong reason either way; Jest chosen because `firebase-functions-test` historically ships with Jest-compatible types. Swapping later is mechanical.

**Reference**: spec.md §Clarifications Q4 (2026-04-15); constitution Principle XI; spec §FR-013, §FR-015.

### Previous decision (2026-04-14, superseded)

> *Decision*: No automated unit-test framework in this spec. Manual emulator walkthrough of the FR-013 matrix.
>
> *Rationale (now invalidated)*: The Spec 001 §R-4 deferral was applied verbatim — introducing a test runner was considered out of scope for Phase 3+4.
>
> *Why superseded*: The 2026-04-15 clarification pass established that FR-015's pre-prod gate must produce an exit code, which a manual walkthrough cannot. The manual-checklist approach was therefore incompatible with the pre-prod deploy gate, not with FR-013 itself.

---

## R-8 — Node.js 20 (supersedes constitution §Technology Constraints "Node.js 18") — added 2026-04-15

**Decision**: The `functions/` project targets **Node.js 20** (Firebase Functions 2nd-gen runtime `nodejs20`). `functions/package.json` sets `"engines": { "node": "20" }`. Node.js 18 is explicitly prohibited.

**Rationale**: Node.js 18 reached upstream EOL on 2025-04-30 and Firebase Functions has begun rejecting new deploys against the Node 18 runtime. Scaffolding a fresh `functions/` project on Node 18 — in April 2026, a year after EOL — would produce a project that either fails to deploy or ships on an unsupported runtime from day one. Node 20 is the current Firebase Functions LTS default and has full compatibility with the `firebase-admin` and `firebase-functions` versions this spec will pull in.

This **does** deviate from constitution v1.1.0 §Technology Constraints ("Runtime: Node.js 18"). The deviation is tracked in `plan.md` §Complexity Tracking. A follow-up PATCH-level constitution amendment (wording-only, no principle change) is warranted to unpin the runtime line from a specific LTS version; that amendment is out of scope for Spec 002.

**Alternatives considered**:
- *Node.js 18 as written in the constitution* — rejected per above.
- *Node.js 22 (latest supported)* — valid but newer and less battle-tested in Firebase production. A newer runtime buys marginal benefit for an admin-only low-volume surface. Node 20 LTS is the lower-risk default.

**Reference**: spec.md §Clarifications Q2 (2026-04-15); spec §FR-001 (post-clarification text); constitution §Technology Constraints (deviation noted in plan).

---

## R-9 — `europe-west1` deployment region (not `us-central1` default) — added 2026-04-15

**Decision**: All five admin callables (and any Spec 003 stats stubs re-exported from `functions/src/index.ts`) deploy to Firebase Functions region **`europe-west1`** (Belgium). Region is set per-callable via the 2nd-gen options object (`{ region: 'europe-west1' }`) — NOT via a global default — so that a future code move cannot silently re-route.

**Rationale**: Syanat is an Arabic-language service operating in the MENA region. The default `us-central1` adds roughly 250ms of round-trip latency per admin call for a MENA-based admin user; `europe-west1` brings that down to ~60ms. For an internal admin tool that difference is not urgent, but it IS an annoying per-click tax that compounds across a day of dispute-resolution work. `europe-west1` is the closest Firebase Functions region to MENA with **full feature parity** and a stable SLA history — `me-central1`/`me-central2` (Doha/Dammam) are geographically closer but some feature support has historically lagged there, and an internal admin tool does not justify taking that risk for the marginal extra latency win.

**Operational hazard**: Once a callable is deployed to a region, moving it to another region is NOT a config flip — it requires deleting the old function and redeploying with a new region. The name can stay the same only if the delete/redeploy is done back-to-back in one `firebase deploy`, and even then there is a short window where clients may hit the old region. Because of this, locking the region now (in the first-ever deploy of `functions/`) is strictly simpler than picking `us-central1` now and migrating later.

**Alternatives considered**:
- *`us-central1` (Firebase default)* — rejected because of the MENA latency tax and because switching regions after deploy is painful.
- *`me-central1` / `me-central2`* — rejected because of historical feature-parity lag and because the latency win over `europe-west1` is imperceptible in practice for ≤100 admin calls per day.
- *Match the Firestore database region* — reviewed: the existing Firestore database in `syana-ea75a` is in `nam5` (multi-region US). Matching it would pull functions into `us-central1` and re-introduce the MENA latency issue. Rejected. Firestore cross-region reads from `europe-west1` to `nam5` add ~150ms per read/write inside the function, but at ≤100 invocations per day this is acceptable; the dominant cost is the admin's click-to-response latency, which `europe-west1` minimises.

**Reference**: spec.md §Clarifications Q3 (2026-04-15); spec §FR-004a.

---

## R-10 — `firebase emulators:exec` as pre-prod deploy gate (replaces FR-015 hosting preview) — added 2026-04-15

**Decision**: The pre-production deploy gate for Spec 002 is a zero exit-code run of `firebase emulators:exec --only functions,firestore,auth "npm test"` from the `functions/` directory. Firebase Hosting preview channels are NOT used for this spec because they do not run Cloud Functions — they only serve Hosting content to a preview URL.

**Rationale**: The original FR-015 text ("`firebase hosting:channel:deploy preview-phase4`") was unenforceable as written. Firebase Hosting preview channels only exercise the Hosting layer — Cloud Functions are not deployed to a preview channel, so a hosting preview deploy passing gives zero evidence that the functions will work in production. In an earlier spec (Spec 001) this was harmless because Spec 001 touched only Hosting content. For Spec 002, which is 100% Cloud Functions + Firestore rules, the hosting preview step would be a pure ceremony producing no signal.

`firebase emulators:exec` is the equivalent gate that DOES produce signal: it boots the functions + Firestore + auth emulators locally, runs the Jest suite against them, and exits zero only if every assertion passes. Because FR-013 already enumerates the exact scenarios that must pass, encoding them as Jest tests (R-7 updated) gives the deploy gate a deterministic pass/fail that is also reproducible on any developer machine.

**Alternatives considered**:
- *Keep the hosting preview as-is (ceremony only)* — rejected because a meaningless gate is worse than no gate: it creates a false sense of security and eats deploy budget.
- *Deploy functions to a second Firebase project as a staging environment* — rejected because standing up `syana-ea75a-staging` is a significant operational lift (duplicate Firestore data, duplicate Auth users, duplicate App Check config) and is explicitly out of scope for Spec 002. Revisit in Spec 005 if the team decides a full staging env is warranted.
- *Skip the pre-prod gate entirely* — rejected per Principle IV ("Every production deploy must be preceded by a Firebase preview channel deploy OR emulator test"). The OR clause in Principle IV is the exact escape hatch that R-10 leans on.

**Constitutional alignment**: Principle IV's "preview channel OR emulator test" wording was written with exactly this case in mind — Spec 002 exercises the "emulator test" branch and leaves the "preview channel" branch to specs that actually ship Hosting content (Spec 004/005).

**Reference**: spec.md §Clarifications Q1 (2026-04-15); spec §FR-015 (post-clarification text); constitution Principle IV.

---

## R-11 — Automated Jest supersedes Spec 001 §R-4 deferral (scoped to Spec 002) — added 2026-04-15

**Decision**: The deferral recorded in Spec 001 §R-4 ("no automated test harness in this sprint") applies ONLY to Spec 001's rule-harness concern. Spec 002 introduces a Jest test harness for Cloud Functions at `functions/test/**`, and this does NOT constitute violating the Spec 001 deferral because:
1. Spec 001's R-4 concerned `@firebase/rules-unit-testing` for Firestore rules specifically.
2. Spec 002's harness is `firebase-functions-test` + Jest for Cloud Functions specifically.
3. The two are independent systems; the former is optional in Spec 002 (see R-7), the latter is mandatory.

**Rationale**: This record exists purely to close a possible reading of "Spec 002 violates Spec 001 §R-4 by introducing a test harness." It does not. Spec 001's deferral was scoped to rule tests; Spec 002 introduces function tests. The one overlap — an optional `test/rules/assignment-whitelist.test.ts` file for FR-012's subset-safety — is treated as **optional** precisely to honour the Spec 001 deferral for as long as possible. If a plan author chooses to add that file, they SHOULD note it as an exception to Spec 001 §R-4 and justify it.

**Alternatives considered**:
- *Treat the Jest harness as a Spec 001 §R-4 violation and defer it* — rejected because Spec 001's wording is explicit about the rules harness, not the functions harness, and because R-7's deploy-gate argument makes a function-side harness mandatory for Spec 002.

**Reference**: Spec 001 §R-4; spec.md §Clarifications Q4 (2026-04-15); this file §R-7.

---

## R-12 — Fixed `activity_log.description` templates (no free-text interpolation) — added 2026-04-15

**Decision**: Every `activity_log` entry written by Spec 002's five functions uses a fixed `description` template keyed on the `type` enum. Only server-derived identifiers are interpolated — user-supplied free-text (`reason`, `resolutionNote`, `overrideAmount`) does NOT appear in `description`. Canonical templates:

| `type` | `description` template |
|---|---|
| `job_assigned` | `"Admin assigned job {jobId} to {assignedTechnicianName}"` |
| `payment_approved` | `"Admin approved payment {paymentId}"` |
| `payment_rejected` | `"Admin rejected payment {paymentId}"` |
| `dispute_resolved` | `"Admin resolved dispute on job {jobId} ({resolution})"` |
| `job_force_closed` | `"Admin force-closed job {jobId}"` |

Free-text fields (e.g., `rejectionReason`, `resolutionNote`) stay on their own document fields and are rendered separately by downstream consumers (Spec 005's Activity screen).

**Rationale**:
1. **Downstream render determinism**. Spec 005's Activity screen will render `description` directly as the primary column. Fixed templates mean Spec 005 can use the string as-is without a per-`type` lookup table.
2. **Log leak prevention (Principle XIII)**. Free-text `reason` strings in `description` would bleed user-typed content into a field that is heavily read at list-time. Keeping free-text in its own field lets consumers choose whether to render it at all, and lets Principle XIII's 200-char truncation rule apply at the boundary.
3. **Backwards-stable for future callers**. If Spec 003 or Spec 005 adds a new admin callable, it will use the same template discipline — the template table grows, but existing templates never change mid-flight. Template string changes are a breaking change for any downstream consumer that has pinned copy.

**Alternatives considered**:
- *Leave `description` up to each function's implementation* — rejected because it creates inconsistency across functions and bakes a copy refactor into Spec 005.
- *Include the trimmed `reason` in the reject/resolve templates* — rejected because it couples audit descriptions to user content and makes Principle XIII's log-safety harder to enforce.
- *Just use the type word as the description (`"payment_approved"`)* — rejected because `type` is already its own field; duplicating it into `description` makes the field a no-op.

**Reference**: spec.md §Clarifications Q5 (2026-04-15); spec §FR-003a; constitution Principle XI; constitution Principle XIII.

---

## Open questions

None. All inputs are resolved against the migration plan and the current `firestore.rules` / `lib/firebase_service.dart` / `firebase.json` files on `HEAD`.

If you find what looks like an open question while implementing:
1. Re-read the spec.md §Assumptions block.
2. Re-read this file.
3. Grep the migration plan: `grep -n "<term>" WOOHOO/Migration_Implementation_Plan.md`.
4. If the answer is still missing, escalate to the reviewer. Do NOT improvise.
