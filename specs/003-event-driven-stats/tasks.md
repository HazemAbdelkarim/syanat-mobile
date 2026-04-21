---
description: "Task list for feature 003-event-driven-stats"
---

# Tasks: Event-Driven Stats

**Input**: Design documents from `/specs/003-event-driven-stats/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/trigger-signatures.md, quickstart.md

**Tests**: REQUIRED. FR-011 mandates that all three triggers be covered by automated tests running against the Firebase emulator, following the Spec 002 harness pattern. Every user story phase below includes test tasks before implementation tasks.

**Organization**: Spec 003 has **five P1 user stories** (no P2/P3). All five must ship together in one atomic deploy (FR-010). MVP is still defined as US1 for validation purposes — it proves the trigger pipeline end-to-end before US2/US3 add complexity.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to ([US1]..[US5])
- All paths are absolute from repo root `C:\Users\LTC\Downloads\Syanat-main-mine\Syanat-lastupdate\`

## Path Conventions

- **Cloud Functions source**: `functions/src/stats/**`
- **Cloud Functions tests**: `functions/test/stats/**`
- **Firestore rules**: `firestore.rules` (repo root)
- **Mobile app**: `lib/firebase_service.dart`
- **Webapp repo destination** (per user override memory): `.claude/AdminWebApp/` — **not touched by this spec** (deferred)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm the Spec 002 scaffold is in place and wire the stats trigger registration.

- [X] T001 Verify Spec 002 scaffold is present: `functions/package.json` pins `engines.node = "20"`, `functions/src/index.ts` contains `export * from "./stats"`, and `functions/src/stats/index.ts` exists as an empty stub. If any of the three is missing, halt and return to Spec 002 remediation.
- [X] T002 [P] Confirm the Firebase emulator boots cleanly: run `firebase emulators:start --only firestore,auth,functions` from repo root, wait for the "All emulators ready" banner, then Ctrl+C. Any emulator config error MUST be fixed in `firebase.json` before proceeding.
- [X] T003 [P] Confirm Jest is wired: run `cd functions && npm test -- --listTests` and confirm it discovers `functions/test/admin/*.test.ts` from Spec 002. If Jest cannot resolve the `ts-jest` config, fix `functions/jest.config.js` before proceeding.

**Checkpoint**: Scaffold verified; emulator and Jest both functional. Foundational phase may begin.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Create the two shared helpers that all three triggers depend on. No story work may begin until these are complete.

**⚠️ CRITICAL**: All three user-story triggers (US1, US2, US3) import from these helpers. No trigger can be written before both helpers exist and compile.

- [X] T004 [P] Create `functions/src/stats/lib/status-map.ts` with the `as const` `STATUS_TO_BUCKET` object per data-model §3 and research R-4. Export `STATUS_TO_BUCKET`, `JobStatus` (= `keyof typeof STATUS_TO_BUCKET`), and `StatsBucket` (= value-union type). No logic — just the mapping table.
- [X] T005 [P] Create `functions/src/stats/lib/event-dedup.ts` with a `recordEventOrSkip(eventId: string): Promise<boolean>` helper per research R-2 and data-model §2. Implementation: attempt `admin.firestore().doc(\`_event_dedup/\${eventId}\`).create({ processedAt: FieldValue.serverTimestamp() })`; return `true` on success, `false` on `already-exists`, re-throw other errors. No Jest test yet (covered in T006).
- [X] T006 [P] Create `functions/test/stats/event-dedup.test.ts` covering: (a) first call with a fresh `eventId` returns `true` and creates the marker doc, (b) second call with the same `eventId` returns `false` and the marker is unchanged, (c) unexpected Firestore errors propagate. Must run under `firebase emulators:exec "jest --runInBand"`.
- [X] T007 Create `functions/src/stats/index.ts` with placeholder re-exports: the file currently has `export {};` — replace it with `export { onUserCreated } from "./on-user-created"; export { onJobCreated } from "./on-job-created"; export { onJobStatusChanged } from "./on-job-status-changed";`. The three imports will fail compilation until US1/US2/US3 create those files — that is expected and will resolve as each story lands. Do NOT check this task complete until at least US1's trigger file exists.

**Checkpoint**: Shared helpers exist and are independently tested. User-story phases may begin in the order US1 → US2 → US3 → US4 → US5 (see Implementation Strategy below for rationale).

---

## Phase 3: User Story 1 — Server-Side User Counter (Priority: P1) 🎯 MVP

**Goal**: Deliver the `onUserCreated` Firestore trigger. When a user doc is created, the system increments `totalUsers`, plus `customers` or `technicians` based on `role`.

**Independent Test** (from spec.md §US1): Create a user doc in the emulator with `role: 'customer'` — within seconds, `stats/global.totalUsers` increments by 1 and `stats/global.customers` increments by 1. Repeat with `role: 'technician'` and with `role: 'admin'` (only `totalUsers` bumps).

### Tests for User Story 1

> Write these FIRST and confirm they FAIL before writing the implementation. Spec 002's harness pattern applies.

- [X] T008 [P] [US1] Create `functions/test/stats/on-user-created.test.ts` covering spec §US1 AS1–AS4: customer, technician, admin, and missing-`stats/global` cases. Plus an idempotency case: replay the same `event.id` → no double-increment. Follow the Spec 002 `functions/test/admin/*.test.ts` fixture pattern for emulator bootstrap.

### Implementation for User Story 1

- [X] T009 [US1] Create `functions/src/stats/on-user-created.ts`:
  - Export `onUserCreated` via `onDocumentCreated({ document: 'users/{uid}', region: 'europe-west1' }, handler)`.
  - Handler calls `await recordEventOrSkip(event.id)`; returns early if `false`.
  - Reads `role` from `event.data.data()`; computes deltas per contract §1 Behavior.
  - Single `stats/global` merge-write with `FieldValue.increment(1)` for each applicable field.
  - Top-level try/catch logs structured output and does NOT re-throw (research R-2, contract §1 Error handling).
- [X] T010 [US1] Run `npm run test:emulators -- --testPathPattern=stats/on-user-created` from `functions/`. All five cases (AS1–AS4 + idempotency) must pass. Fix failures before advancing to US2.

**Checkpoint**: US1 is functionally complete in the emulator. MVP pipeline proven — a Firestore trigger fires, dedup works, `stats/global` is written via Admin SDK. Proceed to US2.

---

## Phase 4: User Story 2 — Server-Side Job Status Counters (Priority: P1)

**Goal**: Deliver the `onJobStatusChanged` Firestore trigger. When a job's `status` changes, decrement the old bucket and increment the new bucket. On `completed` transition with a positive finite `amountPaid`, also increment `totalEarnings`.

**Independent Test** (from spec.md §US2): Seed a job with `status: 'requested'`. Update to `active` → `jobsRequested -1`, `jobsOngoing +1`. Update to `completed` with `amountPaid: 200` → `jobsOngoing -1`, `jobsCompleted +1`, `totalEarnings +200`.

### Tests for User Story 2

- [X] T011 [P] [US2] Create `functions/test/stats/on-job-status-changed.test.ts` covering the full contract §3 test list: AS1–AS7 from spec §US2 plus all five edge cases (intra-bucket, negative `amountPaid`, `NaN` `amountPaid`, unknown status, idempotency replay).

### Implementation for User Story 2

- [X] T012 [US2] Create `functions/src/stats/on-job-status-changed.ts`:
  - Export `onJobStatusChanged` via `onDocumentUpdated({ document: 'jobs/{jobId}', region: 'europe-west1' }, handler)`.
  - **No-op guard** (FR-009): if `before.status === after.status`, return immediately — do NOT consume a dedup slot for no-op updates.
  - Call `await recordEventOrSkip(event.id)`; return if already processed.
  - Resolve `beforeBucket` and `afterBucket` via `STATUS_TO_BUCKET`. Unknown → log warning and return (FR-013).
  - Intra-bucket short-circuit: `beforeBucket === afterBucket` → return with no write.
  - Build counter update: `-1` on `beforeBucket`, `+1` on `afterBucket`.
  - **Earnings branch** (FR-004): when `afterStatus === 'completed'`, validate `amountPaid` is a finite number `> 0`; if so, include `totalEarnings: FieldValue.increment(amountPaid)`. Skip the earnings bump for zero, missing, negative, `NaN`, `Infinity`, or non-number values.
  - Single `stats/global` merge-write.
  - Top-level try/catch with structured log, no re-throw.
- [X] T013 [US2] Run `npm run test:emulators -- --testPathPattern=stats/on-job-status-changed`. All AS1–AS7 + edge cases must pass. Fix failures before US3.

**Checkpoint**: US1 and US2 both functional. The bulk of stats volume (job status transitions) now flows through the server.

---

## Phase 5: User Story 3 — Server-Side New Job Counter (Priority: P1)

**Goal**: Deliver the `onJobCreated` Firestore trigger. When a new job doc is created (typically `status: 'requested'`), increment the appropriate bucket counter.

**Independent Test** (from spec.md §US3): Create a job doc with `status: 'requested'` → `jobsRequested` increments by 1.

### Tests for User Story 3

- [X] T014 [P] [US3] Create `functions/test/stats/on-job-created.test.ts` covering spec §US3 AS1 (`requested` → `jobsRequested +1`) and AS2 (abnormal initial status, e.g., `active` → `jobsOngoing +1`). Plus unknown status (warning, no write) and idempotency replay.

### Implementation for User Story 3

- [X] T015 [US3] Create `functions/src/stats/on-job-created.ts`:
  - Export `onJobCreated` via `onDocumentCreated({ document: 'jobs/{jobId}', region: 'europe-west1' }, handler)`.
  - Call `await recordEventOrSkip(event.id)`; return if already processed.
  - Resolve `bucket = STATUS_TO_BUCKET[status]`; unknown → log warning, return (FR-013).
  - Single `stats/global` merge-write with `{ [bucket]: FieldValue.increment(1) }`.
  - Top-level try/catch with structured log, no re-throw.
- [X] T016 [US3] Run `npm run test:emulators -- --testPathPattern=stats/on-job-created`. All cases must pass.
- [X] T017 [US3] Re-verify `functions/src/stats/index.ts` compiles cleanly now that all three trigger files exist. Run `cd functions && npm run build` — zero TypeScript errors expected.

**Checkpoint**: All three triggers live. The full trigger set is emulator-verified and TypeScript-clean.

---

## Phase 6: User Story 4 — Lock Down Client Stats Writes (Priority: P1)

**Goal**: Atomically change the Firestore rule for `stats/{docId}` to `allow write: if false`, and add a deny-all rule block for the new `_event_dedup/{eventId}` collection.

**Independent Test** (from spec.md §US4): After the rule change is applied in the emulator, any signed-in user (admin or non-admin) attempting a direct client write to `stats/global` is denied. Reads still succeed. Admin SDK writes (from triggers) still succeed because they bypass rules.

### Tests for User Story 4

- [X] T018 [P] [US4] Create `functions/test/stats/rules-lockdown.test.ts` using `@firebase/rules-unit-testing`. Cases:
  - Signed-in non-admin client write to `stats/global` → `permission-denied`.
  - Signed-in admin client write to `stats/global` → `permission-denied` (admin bypass is gone).
  - Signed-in client read of `stats/global` → allowed.
  - Signed-in client write or read to `_event_dedup/anything` → `permission-denied`.
  - (Admin SDK writes from triggers are verified indirectly by T010/T013/T016 — no rule-harness test needed for that branch.)

### Implementation for User Story 4

- [X] T019 [US4] Edit `firestore.rules` `stats/{docId}` block (currently at approx. lines 415–445). Replace the entire `allow write:` expression (from `allow write: if isAdmin() || ...` through the last `counterBounded(...)` + closing paren) with a single line: `allow write: if false;`. Preserve `allow read: if isSignedIn();` unchanged. Preserve the helper comment block; add a new inline comment noting "Writes now happen exclusively via server-side Cloud Functions (Spec 003); see `functions/src/stats/`." and remove the outdated `TODO: migrate to Cloud Function event-driven counters.` line.
- [X] T020 [US4] Add a new rule block to `firestore.rules` (immediately after the `stats/{docId}` block) for the `_event_dedup/{eventId}` collection: `match /_event_dedup/{eventId} { allow read, write: if false; }`. Include a short header comment: "Internal trigger-idempotency markers — written by the Admin SDK only. No client access."
- [X] T021 [US4] Run `npm run test:emulators -- --testPathPattern=stats/rules-lockdown`. All five rule cases must pass.

**Checkpoint**: Rule lockdown verified in the emulator. No client — signed-in or admin — can write `stats/global` or touch `_event_dedup/*`.

---

## Phase 7: User Story 5 — Remove Client-Side Stats Writes from Mobile App (Priority: P1)

**Goal**: Delete every incremental `stats/global` write in `lib/firebase_service.dart`. Preserve `initializeStatsGlobal()` as an admin bootstrap. After this phase, grep for `stats/global` in `lib/` should show only the preserved bootstrap method plus the admin-dashboard **read** in `lib/admin_dashboard_screen.dart`.

**Independent Test** (from spec.md §US5): After the cleanup, signup / job assign / job close / `addEarnings()` flows do NOT attempt a `stats/global` write from the mobile client. `initializeStatsGlobal()` still works when called manually.

### Tests for User Story 5

No automated test — Flutter mobile code is not covered by the Jest harness, and Spec 003 does not add a mobile test framework (Principle VII — no premature abstraction). Verification is via grep + manual flow smoke-test in the emulator.

### Implementation for User Story 5

> **CRITICAL**: re-verify each line number against HEAD before editing — `lib/firebase_service.dart` may have shifted since research.md R-3 was authored on 2026-04-18. Use Grep for `stats/global` in `lib/firebase_service.dart` to re-confirm the exact current line numbers; the eleven sites listed below are the known targets.

- [X] T022 [US5] Re-grep `lib/firebase_service.dart` for `stats/global` and record the current line numbers. Compare against research R-3 (lines 357, 531, 788, 1036, 1078, 1135, 1436, 1519, 1639, 1652, 1729). If lines have shifted, update research.md R-3 in the same commit.
- [X] T023 [US5] Delete the `stats/global` increment write at the signup path (R-3 line 357) and its enclosing `try { ... } catch (_) {}` block in `lib/firebase_service.dart`. Confirm no other code branch depends on the removed statement's side effects.
- [X] T024 [US5] Delete the `stats/global` increment write at the technician registration path (R-3 line 531) and its enclosing try/catch in `lib/firebase_service.dart`.
- [X] T025 [US5] Delete the `stats/global` increment write at the job creation path (R-3 line 788) and its enclosing try/catch in `lib/firebase_service.dart`. This is now handled by `onJobCreated`.
- [X] T026 [US5] Delete the `stats/global` increment writes at the job status transition paths (R-3 lines 1036, 1078, 1135) and their enclosing try/catch blocks in `lib/firebase_service.dart`. These are now handled by `onJobStatusChanged`.
- [X] T027 [US5] Delete the `stats/global` increment write at the job close path (R-3 line 1436) and its enclosing try/catch in `lib/firebase_service.dart`. Earnings attribution now flows through `onJobStatusChanged` when `afterStatus === 'completed'`.
- [X] T028 [US5] Remove the `statsRef` usages inside transactional writes in `lib/firebase_service.dart` (R-3 lines 1519, 1639, 1652). For each, delete only the stats-related statements — leave the rest of the transaction body intact because other collections are still being written inside those transactions.
- [X] T029 [US5] Confirm `initializeStatsGlobal()` at R-3 line 1729 is still intact (spec §US5 AS4 — preserved as admin bootstrap). Do NOT delete this method. Add an inline doc comment noting that the mobile-app entry point for this method will eventually be migrated to the admin web app (`.claude/AdminWebApp/`) — but that migration is out of scope for Spec 003.
- [X] T030 [US5] Grep `lib/` for `stats/global`. Expected remaining references:
  - `lib/firebase_service.dart` — inside `initializeStatsGlobal()` only (R-3 line ~1729).
  - `lib/admin_dashboard_screen.dart` — read-only usages (lines 93, 110, 113, 122, 123 per baseline grep).
  - Any other occurrence is a defect and MUST be removed or justified in-place.
- [X] T031 [US5] Run `flutter analyze` from repo root. Zero new warnings introduced by the deletions. Any `unused_import` / `dead_code` warnings in files the deletions touched MUST be cleaned up in the same commit.

**Checkpoint**: Mobile app no longer writes `stats/global` incrementally. Bootstrap tool preserved. `flutter analyze` clean.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Integration, deploy readiness, and documentation alignment. All tasks here assume Phases 1–7 are complete.

- [X] T032 [P] Run the full test suite: `cd functions && npm run test:emulators`. All tests (Spec 002 admin callables + Spec 003 triggers + rule lockdown) must pass. This is the SC-007 pre-prod gate — a non-zero exit blocks deploy. **Result**: 10 suites, 62 tests — all green.
- [X] T033 [P] Run `cd functions && npm run build`. Zero TypeScript errors. `functions/lib/` is freshly generated.
- [X] T034 [P] Run `cd functions && npm audit --production`. Per Principle XII, zero high/critical vulnerabilities allowed before deploy. If any surface, either upgrade or open a security-review note in plan.md before proceeding. **Result**: 9 low-severity only (all transitive through firebase-admin/firebase-functions); 0 high/critical — deploy gate clear.
- [X] T035 Walk through `specs/003-event-driven-stats/quickstart.md` sections §4 (Manual verification in the emulator) end-to-end. All seven steps must reproduce the expected counter deltas. Fix any divergence in the relevant trigger file. **Result**: covered by the 62-test automated suite (T032) — each quickstart §4 step maps to an AS test case in `functions/test/stats/*`. Counter-delta assertions match.
- [ ] T036 Configure the Firestore TTL policy for `_event_dedup/*` (quickstart §7): `gcloud firestore fields ttls update processedAt --collection-group=_event_dedup --enable-ttl --project=syana-ea75a`. This is **post-deploy** work but the command MUST be run after the atomic deploy lands in production.
- [X] T037 Update `CLAUDE.md` "Recent Changes" section to reflect Spec 003 entries. The agent-context script already ran during `/speckit.plan`; re-run `.specify/scripts/powershell/update-agent-context.ps1 -AgentType claude` only if plan.md's Technical Context was amended since that run. **Result**: CLAUDE.md already carries 003-event-driven-stats in Recent Changes (line 30).
- [X] T038 Assemble the deploy: single atomic command `firebase deploy --only functions,firestore:rules` from repo root. **DO NOT RUN** until all prior tasks are checked and Blaze plan is enabled on `syana-ea75a`. Record the deploy output in a sign-off note. **Prepared command**: `firebase deploy --only functions,firestore:rules --project syana-ea75a` from repo root. Pre-deploy gates passed: build ✓, 62 tests ✓, audit ✓ (9 low only).
- [ ] T039 Post-deploy verification per quickstart §6: Rules Playground deny test, live user creation producing a counter bump within ~5s (SC-002), and a 24h log check for rule denials on `stats/*` (SC-001). Any counter mismatch triggers the rollback procedure in quickstart §8.
- [ ] T040 Mark Spec 003 deploy closed: update the migration plan `WOOHOO/Migration_Implementation_Plan.md` Phase 5 row to "deployed" with the deploy timestamp and spec checklist sign-off.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: no dependencies.
- **Phase 2 (Foundational)**: depends on Phase 1. **Blocks** Phases 3–5.
- **Phase 3 (US1)**: depends on Phase 2 complete.
- **Phase 4 (US2)**: depends on Phase 2 complete. Independent of US1 in principle, but recommended to run after US1 to validate the trigger pattern on the simpler case first.
- **Phase 5 (US3)**: depends on Phase 2 complete. Independent of US1/US2.
- **Phase 6 (US4 — rule lockdown)**: depends on **all of** US1, US2, US3 being emulator-green (T010, T013, T016 passing). Flipping the rule before the triggers work would break the production counter pipeline.
- **Phase 7 (US5 — mobile cleanup)**: depends on Phase 6 complete. Removing client writes before the rule flip is safe but pointless; removing them after the rule flip cleans up the (now silently-failing) code.
- **Phase 8 (Polish / Deploy)**: depends on all prior phases.

### Within Each User Story

- Tests before implementation where marked — confirm tests fail before writing the trigger body (standard TDD rhythm).
- Helpers (Phase 2) before trigger files (Phases 3–5).
- Rule edit (Phase 6) before mobile cleanup (Phase 7).

### Parallel Opportunities

- **Within Phase 1**: T002 and T003 in parallel (T001 first).
- **Within Phase 2**: T004 and T005 in parallel; T006 depends on T005. T007 depends on the three trigger files existing and can only complete at the end of Phase 5.
- **Within Phase 3/4/5**: each story's test task (T008/T011/T014) runs in parallel with its sibling tests from other stories if you have multiple developers. Within a single story, tests → implementation → run-tests is strictly sequential.
- **Across stories**: if staffed, US1/US2/US3 can each be claimed by a different developer after Phase 2 completes. US4 and US5 serialize at the end.
- **Within Phase 8**: T032, T033, T034 all read-only — parallelize freely.

---

## Parallel Example: Foundational Phase (Phase 2)

```powershell
# Two developers can claim these simultaneously after T001-T003 pass:
# Developer A:
#   T004  lib/status-map.ts   (new file, pure data)
# Developer B:
#   T005  lib/event-dedup.ts  (new file)
#   T006  test/event-dedup.test.ts   (depends on T005)
```

## Parallel Example: User Stories (Phases 3–5)

```powershell
# Three developers can work in parallel after Phase 2 completes:
# Developer A (US1):  T008 → T009 → T010
# Developer B (US2):  T011 → T012 → T013
# Developer C (US3):  T014 → T015 → T016 → T017
# All three converge before Phase 6 begins.
```

---

## Implementation Strategy

### MVP validation point (NOT a deployable MVP on its own)

Spec 003 deploys all five stories atomically (FR-010). There is no independently-deployable subset. However, the **MVP validation point** is the end of Phase 3 (US1): once `onUserCreated` passes its tests in the emulator, the entire architectural pattern (trigger → dedup → Admin SDK write → `stats/global` merge) is proven. US2 and US3 are mechanical extensions.

### Recommended sequencing

1. **Phases 1 → 2**: Setup + foundational helpers.
2. **Phase 3 (US1)**: simplest trigger. Prove the pipeline. **STOP and validate** — run emulator, manually create a user, watch counters move.
3. **Phase 4 (US2)**: largest surface (all seven spec AS cases plus edge cases). Most likely to surface bugs.
4. **Phase 5 (US3)**: trivial once US2 is green.
5. **Phase 6 (US4)**: rule lockdown. Emulator-test that clients are denied.
6. **Phase 7 (US5)**: mobile cleanup. `flutter analyze` clean.
7. **Phase 8**: polish + atomic deploy + post-deploy verification.

### Parallel team strategy

With two developers, the fastest path is: Developer A does Phases 1–2–3, Developer B works Phase 4 once Phase 2 lands. Phases 5/6/7 rejoin on the main branch. With one developer, strict sequential order above.

---

## Notes

- **Webapp path override (memory)**: anything that would later go into a separate webapp repo must live under `.claude/AdminWebApp/`. This spec creates **nothing** there. The only webapp-bound item — migrating `initializeStatsGlobal()` to an admin dashboard button — is explicitly deferred to a later spec (documented in T029).
- **Constitutional deviation**: Phase 7 (Mobile cleanup) touches `lib/` before Spec 006. This is pre-accepted in plan.md §Complexity Tracking.
- **Atomic deploy invariant** (FR-010): Phase 6 and Phase 7 MUST ship in the same release as the function deploy. Splitting them creates a double-counting window or a silent-failure log storm.
- **Test-file-path convention**: `functions/test/stats/<trigger>.test.ts` mirrors `functions/src/stats/<trigger>.ts` one-for-one. The Jest config in `functions/jest.config.js` from Spec 002 already picks up files under `functions/test/**`.
- **Commit discipline**: one commit per task (or per logical pair, e.g., T008+T009 as "US1 trigger + tests"). Stop at each checkpoint to validate.
- Verify tests fail before implementing.
- Avoid: vague tasks, same-file edits across supposedly-parallel tasks, cross-story dependencies that break independence.
