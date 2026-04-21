# Implementation Plan: Admin Cloud Functions

**Branch**: `002-cloud-functions` | **Date**: 2026-04-15 | **Spec**: [./spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-cloud-functions/spec.md`

**Note**: This plan was regenerated on 2026-04-15 to absorb the five clarifications recorded in `spec.md` §Clarifications → Session 2026-04-15. Every row below that is newly driven by a clarification is tagged **[Clarified 2026-04-15]**.

## Summary

Ship Phases 3 + 4 of `WOOHOO/Migration_Implementation_Plan.md` as a single atomic deploy: a fresh TypeScript Cloud Functions project at `functions/` containing five admin callables (`adminAssignJob`, `adminApprovePayment`, `adminRejectPayment`, `adminResolveDispute`, `adminCloseJob`), two shared helpers (`verifyAdmin`, `writeAuditLog`), and one Firestore rule whitelist expansion. Every privileged admin write that today executes directly from the mobile admin client moves server-side, gains a `verifyAdmin` gate, a transactional precondition, and an immutable `activity_log` audit record. The mobile admin client remains untouched for the duration of this spec — backward compatibility is mandatory (constitution Principle V).

The 2026-04-15 clarification pass locked five decisions that materially shape the implementation: (1) Node.js **20** (not 18 — 18 is EOL); (2) deployment region **`europe-west1`** (not default `us-central1`); (3) an **automated Jest + emulator test suite at `functions/test/**`** runnable via `firebase emulators:exec "npm test"`, with its exit code as the pre-prod gate; (4) **`firebase emulators:exec`** replaces the unenforceable hosting-preview step in FR-015; and (5) **fixed per-type `activity_log.description` templates** with no free-text interpolation. All five are reflected in the Technical Context, Constitution Check, and Security Review Gate below.

## Technical Context

**Language/Version**: TypeScript 5.x (strict mode) on **Node.js 20** runtime **[Clarified 2026-04-15]** — supersedes Node 18 referenced in constitution §Technology Constraints (see Complexity Tracking).
**Primary Dependencies**: `firebase-functions` (2nd-gen), `firebase-admin` (SDK), `firebase-functions-test` (unit harness), `jest` + `ts-jest` (runner), `@firebase/rules-unit-testing` (optional, for FR-012 rule scenario). No HTTP framework — Firebase callable protocol only. No external SDKs — every write goes through the Firebase Admin SDK.
**Storage**: Firestore (`jobs/*`, `payments/*`, `activity_log/*`, `users/*`) in the existing `syana-ea75a` project. No new collections. No new composite indexes (all admin-function writes are by primary key).
**Testing**: Jest with `ts-jest`, executed against the Firebase Emulator Suite (`firestore`, `auth`, `functions`). Entry point: `cd functions && npm test` → underneath, `firebase emulators:exec --only functions,firestore,auth "jest --runInBand"`. **[Clarified 2026-04-15]** — replaces the manual checklist walkthrough originally deferred by Spec 001 §R-4.
**Target Platform**: Firebase Cloud Functions 2nd-gen, region **`europe-west1`** **[Clarified 2026-04-15]**. Region MUST be set per-callable (`{ region: 'europe-west1' }` in 2nd-gen options) — no reliance on a global default. Changing region post-deploy is a delete + redeploy under a new function name and is explicitly out of scope.
**Project Type**: Server-only addition to an existing Flutter mobile monorepo. No web frontend, no new mobile code. New top-level directory `functions/` lives alongside `lib/` (mobile) and the future `admin_web/` (or `.claude/AdminWebApp/` per user path override).
**Performance Goals**: Admin callables are low-volume (dozens of invocations per day across the full admin team). No throughput target; no p99 target. Cold-start latency is explicitly accepted as "several seconds possible" (spec §Edge Cases) because the callers are internal admin tooling.
**Constraints**:
- Cloud Functions and the FR-012 rule update MUST deploy in one command: `firebase deploy --only functions,firestore:rules`. Splitting is a defect (Principle IV).
- Pre-prod gate is `firebase emulators:exec "npm test"` exiting `0`. **[Clarified 2026-04-15]**
- No service account key file at any commit (Principle VIII, FR-020).
- Must preserve existing mobile admin writes (FR-012 whitelist expansion is subset-safe via `hasOnly`).
- `disputeResolvedAt` field name is frozen — no rename (FR-019).
**Scale/Scope**: 5 callables + 2 helpers + 1 rule-line edit + 1 Jest test suite (~12 test cases). Expected source volume: ~500 lines of TypeScript plus ~400 lines of tests. One feature branch, one PR, one deploy.

### Unknowns after clarification

None. All five pre-plan ambiguities were resolved on 2026-04-15. See `research.md` §R-8 through §R-12 (newly added) for the decision records.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Constitution version: **1.1.0** (ratified 2026-04-13). Every plan for Specs 002+ MUST enumerate compliance with Principles I–XIII — this block does so explicitly.

| Principle | Status | How this plan complies |
|---|---|---|
| I. Migration Plan Is the Source of Truth | ✅ | Every FR in spec.md cites `WOOHOO/Migration_Implementation_Plan.md` Phase 3/4. No field name is guessed. |
| II. Workspace Boundary | ✅ | All new code lives in `functions/`. No file in `lib/` is touched (FR-017). No file in `admin_web/` / `.claude/AdminWebApp/` is touched (Spec 004 scope). |
| III. No Guessing — Read First | ✅ | Payment status enum (`'PENDING'`/`'CONFIRMED'`/`'REJECTED'`) and technician name field (`users/{uid}.fullName`) MUST be re-confirmed against `lib/firebase_service.dart` before function bodies are written (spec §Assumptions). |
| IV. Deploy Safety | ✅ | Single atomic deploy: `firebase deploy --only functions,firestore:rules`. Pre-prod gate is `firebase emulators:exec "npm test"` exit-zero **[Clarified 2026-04-15]** — replaces the previously-planned hosting-preview step, which did not actually exercise functions. |
| V. Backward Compatibility During Migration | ✅ | Mobile admin client continues to write directly to Firestore for the entire duration of this spec. FR-012 whitelist expansion is subset-safe via `hasOnly`. Job status stays `'completed'` (not `'force_closed'`) per FR-009. |
| VI. Flutter Tooling Isolation | N/A | This spec adds no Flutter project. `functions/` is a standalone Node/TypeScript project with its own `package.json` and `node_modules`. |
| VII. No Premature Abstraction | ✅ | No shared packages. No monorepo tooling. Two helpers (`verify-admin.ts`, `audit-log.ts`) are the only shared code; everything else is per-function. |
| VIII. Secrets & Credential Hygiene | ✅ | FR-020 adds `serviceAccountKey.json`, `**/serviceAccountKey*.json`, `functions/.env`, `functions/.runtimeconfig.json` to `.gitignore` in the first commit of `functions/`. No credentials read from env at runtime — Cloud Functions runtime auto-injects. See Security Review Gate row VIII. |
| IX. Least Privilege & Explicit Authorization | ✅ | Every callable calls `verifyAdmin(context)` as its first executable line (FR-002). Firestore rule FR-012 retains `isAdmin()` + `affectedKeys().hasOnly([...])`. Custom Claims explicitly forbidden (research R-5). See Security Review Gate row IX. |
| X. Input Validation & Transactional Integrity | ✅ | All inputs validated via trimmed strings / finite non-negative numbers / enum `as const` arrays before any Firestore read (FR-005–009). All state transitions inside `db.runTransaction` with the precondition read from the transaction snapshot (research R-3). `adminCloseJob` idempotency guard lives inside the transaction. See Security Review Gate row X. |
| XI. Audit Trail & Accountability | ✅ | Every callable writes to `activity_log` inside the same transaction as the job/payment write (research R-6). Audit fields (`assignedBy`, `reviewedBy`, `resolvedBy`, `adminClosedBy`) sourced from `context.auth.uid` server-side — never from `data.*` (FR-003). All timestamps use `FieldValue.serverTimestamp()`. **[Clarified 2026-04-15]** `description` uses fixed per-type templates (FR-003a) — no free-text interpolation. See Security Review Gate row XI. |
| XII. Defense in Depth | ✅ | Firestore rules stay the first line of defense (FR-012). Cloud Function inputs validated redundantly with rules (Principle X). App Check enforcement flip is deferred to Spec 005 per §Out of scope — acceptable under the Principle XII timeline ("before Spec 005 is considered complete"). See Security Review Gate row XII. |
| XIII. Safe Error Reporting & Logging | ✅ | All callables catch non-`HttpsError` exceptions and rethrow as `HttpsError('internal', 'Unexpected error')` (FR-010). Server logs include function name + `context.auth.uid` only; payment/user fields and reasons > 200 chars are forbidden from logs (FR-011). No `console.log(data)` anywhere. See Security Review Gate row XIII. |

**Gate result**: ✅ All thirteen principles satisfied. Proceed to Phase 0.

### Security Review Gate

Per constitution §Governance → Security Review Gate, every plan for Specs 002–006 MUST attach this table with one row per Principles VIII–XIII.

| Principle | Specific Control | File path | Verification method |
|---|---|---|---|
| VIII. Secrets & Credential Hygiene | `.gitignore` excludes service account keys + `functions/.env` + `functions/.runtimeconfig.json` | `.gitignore` (repo root) | `git log -p functions/` grep at sign-off (SC-008); pre-merge review of first `functions/` commit |
| IX. Least Privilege | `verifyAdmin(context)` as first executable line of every callable + `affectedKeys().hasOnly([...])` on assignment rule | `functions/src/lib/verify-admin.ts`; `firestore.rules` (assignment branch) | Jest cases: non-admin call returns `permission-denied`; rule test: write with extra field is denied |
| X. Input Validation & Transactional Integrity | Input validation before Firestore read; `db.runTransaction` precondition check; idempotency guard inside transaction | `functions/src/admin/*.ts` (all 5 files) | Jest cases: empty/invalid inputs return `invalid-argument` BEFORE any Firestore write; wrong-status returns `failed-precondition`; second `adminCloseJob` returns success with no re-write |
| XI. Audit Trail & Accountability | `activity_log` write inside same transaction; fixed per-type `description` templates **[Clarified 2026-04-15]**; audit fields server-sourced | `functions/src/lib/audit-log.ts`; each `functions/src/admin/*.ts` | Jest assertion: after each successful call, exact `activity_log` doc exists with expected `type`, `userId`, `description`, timestamp |
| XII. Defense in Depth | FR-012 rule whitelist expansion; rules NOT relaxed anywhere | `firestore.rules` (line range of assignment branch) | Rules Playground scenarios in FR-012 acceptance test; Jest rule-harness test (optional) for the subset-safety of `hasOnly` |
| XIII. Safe Error Reporting & Logging | Top-level try/catch rethrowing as `HttpsError('internal')`; log redaction in `functions/src/lib/log-safe.ts` helper | `functions/src/admin/*.ts`; `functions/src/lib/log-safe.ts` | Jest case: thrown `Error('boom')` inside handler surfaces as `HttpsError('internal')` at the client; manual log grep for absence of forbidden fields |

**Sign-off**: no row is blank. Plan may enter implementation.

## Project Structure

### Documentation (this feature)

```text
specs/002-cloud-functions/
├── plan.md              # This file (/speckit.plan command output)
├── spec.md              # Feature spec (with 2026-04-15 clarifications)
├── research.md          # Phase 0 output — decision records R-1..R-12
├── data-model.md        # Phase 1 output (generated below)
├── quickstart.md        # Phase 1 output (generated below)
├── contracts/           # Phase 1 output (generated below)
│   └── callable-signatures.md
├── checklists/
│   └── requirements.md  # Pre-existing
└── tasks.md             # Phase 2 output (/speckit.tasks — NOT created here)
```

### Source Code (repository root)

```text
functions/                       # NEW top-level dir (FR-001)
├── package.json                  # engines.node = "20" [Clarified 2026-04-15]
├── tsconfig.json                 # strict mode
├── .gitignore                    # functions-local ignores (FR-020)
├── src/
│   ├── index.ts                  # admin.initializeApp() + re-exports (FR-004)
│   ├── lib/
│   │   ├── verify-admin.ts       # FR-002 — first line of every callable
│   │   ├── audit-log.ts          # FR-003 — writeAuditLog helper
│   │   ├── audit-templates.ts    # FR-003a — per-type description templates [Clarified 2026-04-15]
│   │   └── log-safe.ts           # FR-011 — redacting log helper
│   ├── admin/
│   │   ├── assign-job.ts         # FR-005 — adminAssignJob
│   │   ├── approve-payment.ts    # FR-006 — adminApprovePayment
│   │   ├── reject-payment.ts     # FR-007 — adminRejectPayment
│   │   ├── resolve-dispute.ts    # FR-008 — adminResolveDispute
│   │   └── close-job.ts          # FR-009 — adminCloseJob
│   └── stats/
│       └── index.ts              # Empty stub for Spec 003 to fill
└── test/
    ├── setup.ts                  # Emulator bootstrap, fixture seeding
    ├── admin/
    │   ├── assign-job.test.ts
    │   ├── approve-payment.test.ts
    │   ├── reject-payment.test.ts
    │   ├── resolve-dispute.test.ts
    │   └── close-job.test.ts
    └── rules/
        └── assignment-whitelist.test.ts   # Optional: FR-012 subset safety

firestore.rules                   # MODIFIED — FR-012 whitelist expansion only
firebase.json                     # MODIFIED — adds functions section (predeploy lint)
```

**Structure Decision**: Single new top-level directory `functions/` as the constitution §Technology Constraints already prescribes. No monorepo tooling, no workspace root — the `functions/` project has its own `package.json` and `node_modules`, kept isolated from the Flutter project via `.gitignore` and a predeploy lint. The `test/` directory is a first-class sibling of `src/` (new this spec per Q4 clarification), not a buried subfolder, so the Jest config in `package.json` can pick it up with the default glob.

## Phase 0: Outline & Research

Research already exists at `./research.md` with decision records R-1 through R-7 (authored 2026-04-14). The 2026-04-15 clarification pass requires:

1. **R-7 update** — the current R-7 decision ("No automated unit-test framework in this spec") is **invalidated** by Q4 of the clarification session. R-7 MUST be rewritten to reflect the new decision: Jest + `firebase-functions-test` harness committed inside `functions/test/**`, run via `firebase emulators:exec "npm test"`.
2. **R-8 through R-12 (new)** — one new decision record per clarification:
    - R-8: Node.js 20 chosen over Node.js 18 (EOL risk + Firebase Functions deprecation)
    - R-9: `europe-west1` region chosen (MENA latency vs `us-central1` default)
    - R-10: `firebase emulators:exec` chosen as pre-prod gate (replaces hosting-preview step)
    - R-11: Automated Jest suite supersedes Spec 001 §R-4 deferral (plus a note on why `@firebase/rules-unit-testing` is optional)
    - R-12: Fixed `activity_log.description` templates chosen (no free-text interpolation)

Both updates are applied in the same edit pass immediately after this plan is saved. The research.md file is the authoritative source for rationale — this plan references the record numbers, not the rationale itself.

**Phase 0 output**: `research.md` updated in place. No `NEEDS CLARIFICATION` markers remain.

## Phase 1: Design & Contracts

### Data Model

All three relevant collections (`jobs/*`, `payments/*`, `activity_log/*`) are pre-existing and fully documented in spec.md §Key Entities. This spec adds the following fields (recap):

| Collection | New fields | Set by | Notes |
|---|---|---|---|
| `jobs/{jobId}` | `assignedBy`, `assignedAt` | `adminAssignJob` | Whitelisted by FR-012 |
| `jobs/{jobId}` | `resolvedBy`, `resolutionNote` | `adminResolveDispute` | `disputeResolvedAt` already exists (FR-019) |
| `jobs/{jobId}` | `adminClosedBy` | `adminCloseJob` | `adminClosedAt` already exists |
| `payments/{paymentId}` | `reviewedBy`, `reviewedAt` | approve + reject | |
| `payments/{paymentId}` | `rejectionReason` | reject only | |
| `activity_log/{autoId}` | `type`, `description`, `userId`, `role`, `createdAt`, `jobId?`, `paymentId?`, `resolution?`, `reason?` | all 5 callables via `writeAuditLog` | `description` uses fixed templates per FR-003a **[Clarified 2026-04-15]** |

No state machine diagram is needed beyond what spec.md §Acceptance Scenarios already provides for each function. A concise `data-model.md` is generated at this path with the table above — see file for details.

### Contracts

The five callable signatures ARE the contract surface. Because Firebase callables do not use OpenAPI / gRPC / REST-style IDLs, the contract is expressed as a TypeScript-flavoured signature list. See `contracts/callable-signatures.md` for the generated file. Every signature there maps to FR-005..FR-009 one-for-one and to one Jest `describe` block in `test/admin/*.test.ts` one-for-one.

### Agent context update

To be run at the end of this plan command:

```powershell
.specify/scripts/powershell/update-agent-context.ps1 -AgentType claude
```

Adds the new Node.js 20 / TypeScript entries to `CLAUDE.md` without overwriting manual sections.

## Complexity Tracking

Only **one** constitutional deviation is introduced by this plan, and it exists solely because the constitution text predates the Node.js 20 Firebase Functions LTS migration.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Constitution §Technology Constraints says "Runtime: Node.js 18" but this plan uses **Node.js 20**. **[Clarified 2026-04-15]** | Node 18 is EOL (upstream since April 2025) and Firebase Functions has begun rejecting new deploys against it. A Node 18 scaffold would be DOA. | "Stay on Node 18" rejected because the deploy may be rejected outright by Firebase; even if accepted, the runtime would be unsupported within the lifetime of this deployment. A constitution amendment to §Technology Constraints is warranted but out of scope for Spec 002 — a follow-up patch to the constitution is tracked as a PATCH-level amendment (rationale: wording clarification only, no principle changed). |

No other violations. Every other decision in this plan is directly sanctioned by the migration plan, the spec, or a clarification answer.

## Post-Design Constitution Re-Check

Re-evaluated after Phase 1 data-model + contracts artifacts were generated. No new violations surfaced. The Node 20 deviation above is the only one, and it is pre-accepted via the Complexity Tracking table. Gate status: ✅ **PASS**. Implementation may proceed.
