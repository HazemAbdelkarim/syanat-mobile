---

description: "Task list for Firestore Rules Hardening (Spec 001)"
---

# Tasks: Firestore Rules Hardening

**Input**: Design documents from `specs/001-firestore-rules-hardening/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/firestore-rules.md`, `contracts/storage-rules.md`, `contracts/upload-photo-contract.md`, `quickstart.md`

**Tests**: Automated tests are OPTIONAL for this spec and NOT generated. Verification is manual via Firebase Rules Playground scenarios, `flutter analyze`, and live smoke tests. Rationale: see `research.md` R-4.

**Organization**: Tasks mirror the 8-step linear script in `quickstart.md` and are grouped by the three user stories from `spec.md`. This task list is a thin operational shell over `quickstart.md` — when a task description says "per `contracts/<file>`", paste the exact snippet from that file; do not improvise.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no cross-task dependencies).
- **[Story]**: Maps to user stories in `spec.md`: `[US1]` restrict admin job writes; `[US2]` techProfiles owner check; `[US3]` preserve payments/stats behaviour.
- Exact file paths are included in every task.

## Path Conventions

- Repository root: `C:\Users\LTC\Downloads\Syanat-main-mine\Syanat-lastupdate\`
- Firestore rules: `firestore.rules` (root)
- Storage rules: `storage.rules` (root)
- Mobile Dart: `lib/firebase_service.dart`

---

## Phase 1: Setup (Shared Preconditions)

**Purpose**: Confirm the working environment is in a known-good state before any file is edited.

- [ ] T001 Verify current branch is `001-firestore-rules-hardening` by running `git rev-parse --abbrev-ref HEAD` from the repo root; abort and switch if not
- [ ] T002 [P] Verify the working tree has no unrelated uncommitted changes by running `git status --short`; stash or commit unrelated changes before proceeding
- [ ] T003 [P] Verify Firebase CLI is authenticated and selected on project `syana-ea75a` by running `firebase projects:list` and `firebase use syana-ea75a`
- [ ] T004 [P] Open the four reference contract documents in the editor for side-by-side reading: `specs/001-firestore-rules-hardening/contracts/firestore-rules.md`, `specs/001-firestore-rules-hardening/contracts/storage-rules.md`, `specs/001-firestore-rules-hardening/contracts/upload-photo-contract.md`, `specs/001-firestore-rules-hardening/data-model.md`

---

## Phase 2: Foundational (Blocking Preflight Checks)

**Purpose**: Confirm the three target files still match the "Before" snippets in the contracts before any edit is made. If any anchor is missing, STOP and escalate — the repo has diverged from the plan.

**⚠️ CRITICAL**: Do not begin user-story tasks (Phase 3+) until every Phase 2 anchor has been confirmed.

- [ ] T005 Confirm the three admin-gated rule blocks exist in `firestore.rules` by grepping for their comment anchors: `// ── Admin assigns technician: requested → active ──`, `// ── Admin resolves dispute: receipt_disputed → reopen / complete / cancel ──`, `// ── Cancellation: admin from any non-terminal status ──`
- [ ] T006 [P] Confirm the `techProfiles` write rule block exists in `storage.rules` and matches the "Before" snippet in `specs/001-firestore-rules-hardening/contracts/storage-rules.md`
- [ ] T007 [P] Confirm `uploadPhoto` in `lib/firebase_service.dart` matches the "Before" snippet in `specs/001-firestore-rules-hardening/contracts/upload-photo-contract.md` by running `grep -n "uploadPhoto" lib/firebase_service.dart` and visually comparing the method body

**Checkpoint**: All three source files verified as pre-edit baselines. User story work may now begin.

---

## Phase 3: User Story 1 — Restrict admin job writes to a known field set (Priority: P1) 🎯 MVP

**Goal**: Add `affectedKeys().hasOnly([...])` whitelists to the three admin-gated branches inside `match /jobs/{jobId}` so that admin writes cannot silently change unrelated fields.

**Independent Test**: In the Firebase Rules Playground, an admin write carrying only the whitelisted fields is ALLOWED and the same write with one extra field is DENIED. The current production mobile admin client's assign/resolve/cancel flows continue to succeed unchanged.

### Implementation for User Story 1

- [ ] T008 [US1] Apply Edit 1 (admin assignment whitelist) to `firestore.rules` per `specs/001-firestore-rules-hardening/contracts/firestore-rules.md` §"Edit 1 — Admin assignment block"
- [ ] T009 [US1] Apply Edit 2 (admin dispute resolution whitelist) to `firestore.rules` per `specs/001-firestore-rules-hardening/contracts/firestore-rules.md` §"Edit 2 — Admin dispute resolution block" (watch the field name: `disputeResolvedAt`, not `resolvedAt`)
- [ ] T010 [US1] Apply Edit 3 (admin cancellation whitelist) to `firestore.rules` per `specs/001-firestore-rules-hardening/contracts/firestore-rules.md` §"Edit 3 — Admin cancellation block"
- [ ] T011 [US1] Diff-verify `firestore.rules` by running `git diff firestore.rules`; confirm exactly three `affectedKeys().hasOnly([...])` additions inside `match /jobs/{jobId}` and nothing else — revert and retry if anything else appears
- [ ] T012 [US1] Run Rules Playground scenarios A1–A4 against the draft rule set per `specs/001-firestore-rules-hardening/contracts/firestore-rules.md` §Verification; all 4 must match Expected
- [ ] T013 [US1] Run Rules Playground scenarios B1–B5 against the draft rule set per `specs/001-firestore-rules-hardening/contracts/firestore-rules.md` §Verification; all 5 must match Expected
- [ ] T014 [US1] Run Rules Playground scenarios C1–C4 against the draft rule set per `specs/001-firestore-rules-hardening/contracts/firestore-rules.md` §Verification; all 4 must match Expected

**Checkpoint 1 (pre-deploy)**: `firestore.rules` is edited locally and all 13 Playground scenarios pass. Ready to deploy.

- [ ] T015 [US1] Deploy Firestore rules to production by running `firebase deploy --only firestore:rules` from the repo root (diff should be reviewed one more time in the CLI confirmation prompt before confirming)
- [ ] T016 [US1] Within 10 minutes of deploy, execute SMOKE-1 from `specs/001-firestore-rules-hardening/contracts/firestore-rules.md` §Verification: perform a real admin job assignment from the current mobile admin build and confirm it succeeds
- [ ] T017 [US1] Execute SMOKE-2: perform a real dispute-resolution (complete branch) on a `receipt_disputed` job from the current mobile admin build and confirm it succeeds
- [ ] T018 [US1] Execute SMOKE-3: perform a real admin cancellation on an `active` job from the current mobile admin build and confirm it succeeds
- [ ] T019 [US1] Execute SMOKE-4: watch the Firestore debug logs for 10 minutes after deploy and confirm zero `PERMISSION_DENIED` events on `/jobs/*` from admin UIDs

**Checkpoint 2 (US1 done)**: User Story 1 is live in production. The admin job write paths are now field-restricted. This is the MVP slice — if US2 slips, US1 still delivers the first half of the spec's value.

---

## Phase 4: User Story 2 — Enforce `techProfiles` owner check (Priority: P1)

**Goal**: Change the mobile upload filename convention so every `techProfiles` upload is named `{uid}_{timestampMillis}.jpg`, ship it, wait for a safe install base, then deploy the storage rule that enforces `fileName.split('_')[0] == request.auth.uid`.

**Independent Test**: In the Storage Rules Playground, a write to `techProfiles/<uid>_<ts>.jpg` by user `<uid>` is ALLOWED and a write to `techProfiles/<otherUid>_<ts>.jpg` by `<uid>` is DENIED. Legacy `techProfiles/<ts>.jpg` files remain publicly readable. A real device running the new build can complete a profile-photo upload end-to-end.

**Dependency note**: US2 is independent of US1's implementation but shares the commit in T023. If US1 slips, US2's mobile edit can still ship on its own commit; adjust T023 accordingly.

### Implementation for User Story 2 — Sub-phase 2a: Mobile filename change

- [ ] T020 [US2] Apply the `uploadPhoto` edit in `lib/firebase_service.dart` per `specs/001-firestore-rules-hardening/contracts/upload-photo-contract.md` §After (adds two local variables and a conditional filename branch; watches that the `'techProfiles'` string matches exactly)
- [ ] T021 [US2] Diff-verify `lib/firebase_service.dart` by running `git diff lib/firebase_service.dart`; confirm changes are confined to the `uploadPhoto` method and nothing else — revert and retry otherwise
- [ ] T022 [US2] Run `flutter analyze` from the repo root and confirm zero new errors or warnings attributable to `lib/firebase_service.dart` (pre-existing warnings elsewhere are out of scope for this spec)
- [ ] T023 [US2] Stage `firestore.rules` (from US1) and `lib/firebase_service.dart` explicitly (do NOT use `git add -A`), commit with message `Harden admin job write rules and prep techProfiles filename convention`, then `git push -u origin 001-firestore-rules-hardening`
- [ ] T024 [US2] Manual smoke test of the new `uploadPhoto` on an emulator or debug build: sign in as a technician, upload a profile photo, confirm the Firebase Storage console shows the file at `techProfiles/<uid>_<millis>.jpg`

### Implementation for User Story 2 — Sub-phase 2b: Ship mobile release

- [ ] T025 [US2] Merge the branch to `main` (or whatever the mobile release process requires) following the team's existing mobile release workflow
- [ ] T026 [US2] Build release artifacts: `flutter build apk --release` and `flutter build ios --release`
- [ ] T027 [US2] Ship the release to the stores via the team's existing mobile release process
- [ ] T028 [US2] Start the install-base waiting clock: wait until either 48 hours have elapsed with no upload failures in logs OR ≥80% of technician uploads in the last 24 hours are from the new build — whichever comes first

**Checkpoint 3 (gate)**: Do NOT proceed to T029 until T028 is satisfied. Deploying the storage rule before the new build has reached a safe install base will break technician profile uploads for every not-yet-updated device.

### Implementation for User Story 2 — Sub-phase 2c: Storage rule deploy

- [ ] T029 [US2] Apply the `techProfiles` write rule edit in `storage.rules` per `specs/001-firestore-rules-hardening/contracts/storage-rules.md` §After (appends `&& fileName.split('_')[0] == request.auth.uid` to the existing `allow write` condition; public `allow read` stays intact)
- [ ] T030 [US2] Diff-verify `storage.rules` by running `git diff storage.rules`; confirm changes are confined to the `match /techProfiles/{fileName}` block and the `payment_proofs` block plus catch-all deny are untouched
- [ ] T031 [US2] Run Storage Rules Playground scenarios S1–S7 per `specs/001-firestore-rules-hardening/contracts/storage-rules.md` §Verification; all 7 must match Expected
- [ ] T032 [US2] Stage `storage.rules`, commit with message `Enforce techProfiles owner check on storage writes`, and push
- [ ] T033 [US2] Deploy storage rules to production by running `firebase deploy --only storage` from the repo root
- [ ] T034 [US2] Execute SMOKE-S1 from `specs/001-firestore-rules-hardening/contracts/storage-rules.md` §"Real device smoke test": install the shipped mobile release on a real device, sign in as a technician, change profile photo, and confirm the upload + `getDownloadURL` completes without error

**Checkpoint 4 (US2 done)**: User Story 2 is live. Technician profile photo uploads are now ownership-gated end to end.

---

## Phase 5: User Story 3 — Preserve current payments and stats behaviour (Priority: P2)

**Goal**: This story is a scope-guard rather than new capability. The goal is to verify that the changes shipped in US1 and US2 did NOT regress existing payment, stats, or activity-log flows.

**Independent Test**: The current mobile client's payment approve/reject, stats counter updates, and activity-log writes continue to succeed after both US1 and US2 have deployed — zero rule-denial errors attributable to these collections.

### Implementation for User Story 3

- [ ] T035 [US3] Execute a payment approve smoke test: using the current mobile admin build, approve a `PENDING` payment and confirm the status transitions to `CONFIRMED` with no `PERMISSION_DENIED` in Firestore debug logs
- [ ] T036 [US3] Execute a payment reject smoke test: using the current mobile admin build, reject a `PENDING` payment and confirm the status transitions to `REJECTED` with no `PERMISSION_DENIED` in Firestore debug logs
- [ ] T037 [US3] [P] Verify stats counter writes continue to succeed: trigger one of the six existing client-side stats writers (for example create a test user to increment `totalUsers` + `customers`) and confirm the `stats/global` document update lands without denial
- [ ] T038 [US3] [P] Verify activity_log writes continue to succeed: confirm that the next naturally-occurring `job_requested` or `account_created` event from a real user appears in `activity_log` within minutes of the action

**Checkpoint 5 (US3 done)**: The regression scope-guard has passed. The spec has not broken any collection outside its declared scope.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Post-deploy monitoring, spec closure, and reviewer handoff. These tasks execute after all user-story checkpoints are green.

- [ ] T039 Run the 72-hour post-deploy monitoring window: watch Firestore and Storage debug logs for `PERMISSION_DENIED` events attributable to admin UIDs on `/jobs/*` or technician UIDs on `techProfiles/*`; target is zero
- [ ] T040 [P] Cross-check all six Success Criteria (SC-001 through SC-006) in `specs/001-firestore-rules-hardening/spec.md` §"Measurable Outcomes" and confirm each evaluates to pass
- [ ] T041 [P] Update `specs/001-firestore-rules-hardening/checklists/requirements.md` §Notes with a final sign-off line stating the deploy date, the commit hashes of the two commits (T023 and T032), and the result of the 72-hour monitoring window
- [ ] T042 [P] Tick every box in `specs/001-firestore-rules-hardening/quickstart.md` Steps 0–8 to reflect actual completion
- [ ] T043 [P] Tick every box in `specs/001-firestore-rules-hardening/contracts/firestore-rules.md` §Verification
- [ ] T044 [P] Tick every box in `specs/001-firestore-rules-hardening/contracts/storage-rules.md` §Verification
- [ ] T045 Notify the reviewer that Spec 001 is ready for review with a link to the branch and the four marked-up documents

---

## Dependencies & Execution Order

### Phase dependencies

- **Phase 1 (Setup)**: no prerequisites; can start immediately.
- **Phase 2 (Foundational preflight)**: depends on Phase 1; blocks every user story.
- **Phase 3 (US1)**: depends on Phase 2.
- **Phase 4 (US2)**: depends on Phase 2. Sub-phase 2a can run in parallel with Phase 3. Sub-phase 2c is gated on T028 (install-base wait).
- **Phase 5 (US3)**: depends on Phase 3 (payments smoke) and Phase 4 (stats + activity log assurance after both deploys).
- **Phase 6 (Polish)**: depends on Phases 3, 4, and 5.

### Critical path

The critical path is driven by the install-base wait in T028 (typically 48 hours). Everything else is fast. Optimizing the critical path means starting Phase 4 Sub-phase 2a (T020–T024) as early as possible so the waiting clock starts sooner.

### Within each user story

- **US1**: edits T008→T010 are sequential (same file), then verification T011–T014 is sequential but cheap, then deploy+smoke T015–T019 is sequential.
- **US2**: mobile edit + diff + analyze (T020–T022) is sequential; commit T023 depends on US1 edits being done; ship+wait (T025–T028) is sequential; storage edit + verify + deploy + smoke (T029–T034) is sequential and gated by T028.
- **US3**: T035 and T036 must be done after US1 deploy; T037 and T038 can run in parallel with each other.

### Parallel opportunities

- **Phase 1**: T002, T003, T004 are all `[P]` and can be executed in any order.
- **Phase 2**: T006 and T007 are `[P]` relative to T005.
- **Phase 3 vs Phase 4a**: a second developer can take US1 (T008–T019) while the first developer takes the mobile filename change (T020–T024). The commit at T023 serialises them because it touches both files.
- **Phase 5**: T037 and T038 are `[P]`.
- **Phase 6**: T040, T041, T042, T043, T044 are `[P]` and can be ticked off together.

---

## Parallel Example: Phase 1 Setup

```bash
# Launch the three independent setup checks in parallel terminals:
Terminal A: git status --short
Terminal B: firebase projects:list && firebase use syana-ea75a
Terminal C: open the four contract documents in the editor
```

---

## Implementation Strategy

### MVP First (User Story 1 only)

1. Complete Phase 1: Setup (T001–T004).
2. Complete Phase 2: Foundational preflight (T005–T007).
3. Complete Phase 3: User Story 1 (T008–T019).
4. **STOP and VALIDATE**: US1 alone closes the biggest exposure — arbitrary-field admin writes on jobs. If Phase 4 has to slip (store approval delay, install-base wait), US1 is already delivering value in production.
5. Resume Phase 4 when ready.

### Incremental Delivery

- Phase 1 + 2 → preflight green.
- Phase 3 (US1) → Firestore rules hardened in production. **First deploy**.
- Phase 4 Sub-phase 2a (T020–T024) → mobile code changed and committed.
- Phase 4 Sub-phase 2b (T025–T028) → mobile release shipped. **Second deploy (mobile app stores)**.
- Phase 4 Sub-phase 2c (T029–T034) → storage rule hardened in production. **Third deploy**.
- Phase 5 → regression scope-guard passes.
- Phase 6 → sign-off.

Three backend-touching deploys total: one Firestore rules deploy (T015), one store release (T027), one storage rules deploy (T033). This matches Success Criterion SC-006 (≤ two backend deploys, plus the mobile release).

### Parallel Team Strategy

With two developers:

1. Both complete Phases 1 and 2 together.
2. Developer A takes US1 end-to-end (T008–T019).
3. Developer B takes US2 Sub-phase 2a (T020–T022) and T024 smoke test in parallel.
4. Both coordinate on the combined commit at T023.
5. Developer A runs US1 deploy (T015–T019).
6. Developer B drives the mobile release and the waiting clock (T025–T028) while Developer A takes US3 payment smoke (T035–T036).
7. Developer B finishes US2 Sub-phase 2c (T029–T034) after the gate.
8. Both split Phase 6 polish tasks.

---

## Notes

- Every `[P]` task operates on a different file or is a read-only verification; no `[P]` pair writes the same file.
- Tasks reference the contract files by full path so the implementer never has to guess what to paste.
- No automated test tasks are generated — verification is manual Playground + smoke tests (see `research.md` R-4).
- The install-base wait (T028) is the only non-deterministic checkpoint. If the team decides to shorten or lengthen it for operational reasons, document the reason in the sign-off note at T041.
- Do NOT open any files under `functions/`, `admin_web/`, `lib/admin_*`, or `stats/*` rule blocks during this spec. Those surfaces belong to later specs.
