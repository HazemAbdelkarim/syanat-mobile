# Pre-Handoff Requirements Quality Checklist: Admin Cloud Functions

**Purpose**: Requirements-quality review gate run before handing execution off to a cheaper model (Codex). Each item tests whether the WRITTEN requirements are complete, unambiguous, consistent, and measurable in the dimensions where a cheaper executor is most likely to silently misinterpret. NOT an implementation test.
**Created**: 2026-04-15
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md) · [tasks.md](../tasks.md) · [research.md](../research.md) · [data-model.md](../data-model.md) · [contracts/callable-signatures.md](../contracts/callable-signatures.md)
**Grounded in**: `/speckit.analyze` findings (2026-04-15) — I1, I2, I3, I4, C1, C2, U1, U2, U3, U4, A1, D1

---

## Requirement Completeness

- [ ] CHK001 Are callable function signatures (request shape, response shape, error codes) specified for all five admin functions in a single authoritative place? [Completeness, Spec §FR-005..FR-009 + contracts/callable-signatures.md]
- [ ] CHK002 Is the full `HttpsError` code set (`unauthenticated`, `permission-denied`, `invalid-argument`, `failed-precondition`, `not-found`, `internal`) enumerated exhaustively, including `internal` as the top-level catch-all? [Completeness, Spec §FR-010]
- [ ] CHK003 Are the input-validation rules for every user-supplied parameter (non-empty after `.trim()`, finite non-negative number, enum `as const`) stated per-parameter rather than as a single global sentence? [Completeness, Spec §FR-005..FR-009]
- [ ] CHK004 Are the fixed `activity_log.description` templates for all five `type` values written out verbatim (not paraphrased) in exactly one authoritative location? [Completeness, Spec §FR-003a + data-model.md §3.1]
- [ ] CHK005 Are the status transitions for `jobs/*` enumerated as (source, target, function, guard) tuples in at least one artifact? [Completeness, data-model.md §1.1]
- [ ] CHK006 Are the status transitions for `payments/*` (`PENDING` → `CONFIRMED`/`REJECTED`) enumerated with the same rigor as the job transitions? [Completeness, data-model.md §2.1]
- [ ] CHK007 Is the `.gitignore` pattern set required for FR-020 compliance complete vs. constitution Principle VIII's enumeration (`.env`, `.env.*`, `*.jks`, `google-services.json.local`, `GoogleService-Info.plist.local`, `.flaskenv`, `.npmrc`)? [Completeness, Spec §FR-020 + Principle VIII → see Analyze finding C2]
- [ ] CHK008 Are rollback requirements defined for the case where post-deploy smoke or the 72-hour monitor reveals a regression? [Gap, Spec §FR-016]

## Requirement Clarity

- [ ] CHK009 Is the ordering constraint on `verifyAdmin` ("first executable line of the handler" AND "before any Firestore read") specified unambiguously enough that a cheaper executor cannot silently reorder it? [Clarity, Spec §FR-002 + Principle IX]
- [ ] CHK010 Is the pre-production deploy gate described as a single deterministic command producing an exit code, rather than a manual procedure? [Clarity, Spec §FR-015 post-clarification]
- [ ] CHK011 Is "audit write inside the same transaction" stated as a hard requirement for all five functions, not just the ones explicitly mentioned in acceptance scenarios? [Clarity, Spec §FR-003 + research R-6]
- [ ] CHK012 Is the distinction between free-text user input (which lives on its own audit field) and fixed template strings (which live in `description`) stated explicitly enough to prevent a cheaper executor from interpolating `reason` into `description`? [Clarity, Spec §FR-003a + research R-12]
- [ ] CHK013 Is the idempotency guard on `adminCloseJob` specified with all three of its load-bearing properties: (a) guard field is `adminClosedAt != null`, (b) read happens inside the transaction snapshot, (c) a second call writes zero bytes? [Clarity, Spec §FR-009 + research R-3]
- [ ] CHK014 Is it clear that `status='completed'` (NOT `'force_closed'`) is the terminal state for force-close, and is the backward-compat reason documented? [Clarity, Spec §FR-009 + Principle V]
- [ ] CHK015 Is `verifyAdmin`'s "Firestore doc read (NOT Custom Claims)" mechanism stated with enough force that a cheaper executor cannot "optimize" it to a Custom Claims check? [Clarity, Spec §FR-002 + research R-5 + Principle IX]

## Requirement Consistency

- [ ] CHK016 Is the Node.js runtime version consistent between `spec.md` §FR-001 (Node 20), `plan.md` Technical Context (Node 20), `plan.md` §Complexity Tracking (Node 20 flagged as deviation), and constitution §Technology Constraints (Node 18)? [Conflict, Spec §FR-001 ↔ constitution → see Analyze finding C1]
- [ ] CHK017 Is the `firebase emulators:exec` emulator list consistent across spec FR-015 (`functions,firestore`), tasks T029 (`functions,firestore,auth`), and quickstart §5 (`functions,firestore,auth`)? [Conflict, Spec §FR-015 vs tasks.md/quickstart.md → see Analyze finding I2]
- [ ] CHK018 Is the `adminCloseJob` short-circuit guard consistent between `data-model.md` §1.1 ("adminClosedAt == null AND status not already closed") and spec FR-009 + tasks T025 ("adminClosedAt != null alone")? [Conflict, data-model.md §1.1 vs FR-009 → see Analyze finding I3]
- [ ] CHK019 Is the `safeLog(fnName, request)` invocation treated consistently — either required for all five callables or required in the helper definition only — without per-task drift? [Consistency, Spec §FR-011 vs tasks T016/T020/T021/T023/T025 → see Analyze finding U1]
- [ ] CHK020 Are the `affectedKeys().hasOnly([...])` field lists for the admin-assignment rule consistent between spec §FR-012, tasks T026, and data-model.md? [Consistency, Spec §FR-012]
- [ ] CHK021 Is the canonical field name `disputeResolvedAt` (NOT `resolvedAt`) used consistently in spec FR-008, FR-019, data-model.md §1, and contracts §4? [Consistency, Spec §FR-019]
- [ ] CHK022 Does the `types` / `description` template table in `data-model.md` §3.1 match verbatim the one in `research.md` §R-12 and `spec.md` §FR-003a? [Consistency, three-way match]

## Measurability / Acceptance Criteria

- [ ] CHK023 Can every SC (SC-001..SC-008) be objectively measured by either an emulator test, a Firebase Console observation, or a log query — rather than by a judgment call? [Measurability, Spec §Success Criteria]
- [ ] CHK024 Is SC-003 ("100% audit log match within 72 hours") paired with a concrete reconciliation mechanism (which log source, which query, which tool)? [Gap, Spec §SC-003 → see Analyze finding U2]
- [ ] CHK025 Is the "second `adminCloseJob` call produces zero observable change" contract in SC-005 specified with observable criteria (no `activity_log` delta, no field mutation, timestamp unchanged)? [Measurability, Spec §SC-005 + §US4 Scenario 2]
- [ ] CHK026 Is the 72-hour window in SC-003/SC-005/SC-006 expressed as a wall-clock timeframe from a named starting event (first production smoke test)? [Clarity, Spec §Success Criteria]
- [ ] CHK027 Is the `adminCloseJob` idempotency acceptance criterion testable without inspecting internal state (i.e., via observable Firestore reads and log queries only)? [Measurability, Spec §SC-005]

## Scenario Coverage

- [ ] CHK028 Is the `unauthenticated` scenario explicitly enumerated in the FR-013 test matrix, or only mentioned in §US1 Scenario 3? [Coverage, Spec §FR-013 → see Analyze finding U3]
- [ ] CHK029 Are the `unauthenticated` + `non-admin` + `wrong-status` + `invalid-argument` scenario classes required symmetrically for all five callables in FR-013 (not just the three that spec acceptance scenarios enumerate)? [Coverage, Spec §FR-013 + §US2/§US3/§US4 → see Analyze finding U4]
- [ ] CHK030 Are the three `adminResolveDispute` resolution branches (`reopen`, `complete`, `cancel`) each specified as distinct test scenarios with their own field-level assertions? [Coverage, Spec §US3 + data-model.md §1.1]
- [ ] CHK031 Is the `adminResolveDispute` complete-branch edge case (no `overrideAmount` AND no existing `price`) specified as a `failed-precondition` rather than left implicit? [Coverage, Spec §Edge Cases]
- [ ] CHK032 Is the transaction-contention race (two admins assigning the same `requested` job) specified with a defined winner-loser outcome rather than as "undefined"? [Coverage, Spec §Edge Cases]

## Edge Cases & Failure Modes

- [ ] CHK033 Is the behavior specified when `users/{technicianId}` is missing or deleted between the admin's fetch and the transaction? [Edge Case, Spec §US1 Scenario 5 + research R-2]
- [ ] CHK034 Is the cold-start latency expectation ("several seconds") documented with a named rationale so a cheaper executor does not "optimize" it via a warmer? [Edge Case, Spec §Edge Cases]
- [ ] CHK035 Is the coexistence contract (mobile admin client still writes directly during Spec 002) spelled out with the specific guarantee that no double-audit can occur? [Edge Case, Spec §Edge Cases + §FR-017]
- [ ] CHK036 Is the behavior specified when the `activity_log` write would fail (e.g., transaction aborted mid-way), and is it explicit that partial commit is impossible? [Edge Case, Spec §Edge Cases + research R-6]

## Non-Functional: Security

- [ ] CHK037 Is the "defense in depth" rationale (why Firestore rules remain load-bearing even though the Admin SDK bypasses them) documented inside Spec 002 rather than left implicit from the constitution? [Completeness, Spec §US5 + research R-4 + Principle XII]
- [ ] CHK038 Is the forbidden-log-fields set (tokens, full `users/*`, `payments.screenshotUrl`, `reason > 200 chars`) enumerated in Spec 002 — not just assumed from Principle XIII? [Coverage, Spec §FR-011 + Principle XIII]
- [ ] CHK039 Is the Security Review Gate table (one row per Principles VIII–XIII) attached to `plan.md` with no blank rows? [Completeness, plan.md §Security Review Gate + constitution §Governance]
- [ ] CHK040 Is the prohibition on committing `serviceAccountKey*.json`, `functions/.env`, and `functions/.runtimeconfig.json` enforced via both a spec FR (FR-020) AND a concrete task action (T004), not just one of the two? [Consistency, Spec §FR-020 + tasks T004]

## Non-Functional: Audit Trail

- [ ] CHK041 Is it specified — in spec, not just constitution — that `userId` on every `activity_log` entry MUST come from `context.auth.uid` and MUST NEVER be accepted from `data.*`? [Clarity, Spec §FR-003 + Principle XI]
- [ ] CHK042 Is it specified that all `*At` timestamps in `jobs/*`, `payments/*`, and `activity_log/*` MUST use `FieldValue.serverTimestamp()` and not `Date.now()`? [Clarity, Spec §FR-003 + Principle XI]
- [ ] CHK043 Is the `activity_log` immutability contract (`allow update, delete: if false`) referenced in Spec 002 as a pre-existing invariant, so a cheaper executor knows not to touch the rule? [Traceability, Spec §Assumptions + §FR-018]

## Non-Functional: Deploy Safety

- [ ] CHK044 Is the atomic single-deploy requirement (`firebase deploy --only functions,firestore:rules`) stated as a hard rule with a documented consequence for splitting it? [Clarity, Spec §FR-014 + Principle IV]
- [ ] CHK045 Are the post-deploy smoke-test scenarios enumerated per function rather than described at a single high level? [Completeness, Spec §FR-016]
- [ ] CHK046 Is the "no hotfix deploy required in first 72 hours" success criterion paired with a documented fallback procedure if a hotfix IS required? [Gap, Spec §SC-007]
- [ ] CHK047 Is the deployment region (`europe-west1`) specified with a rationale that prevents silent reversion to the Firebase default `us-central1`? [Clarity, Spec §FR-004a + research R-9]

## Dependencies & Assumptions

- [ ] CHK048 Are prerequisite Spec 001 artifacts (Firestore rules deployed to production) named explicitly as a precondition, with a named deployment date? [Dependency, Spec §Assumptions]
- [ ] CHK049 Are assumptions about existing field names (`users.fullName`, `payments.status` enum values) flagged as must-be-verified-against-codebase before function bodies are written? [Assumption, Spec §Assumptions]
- [ ] CHK050 Is the assumption that `activity_log` rules are already in place (Spec 001 line 444–465) stated with a file + line reference that can be independently verified? [Traceability, Spec §Assumptions]

## Ambiguities & Conflicts

- [ ] CHK051 Is every term that could have multiple readings (`closed`, `resolved`, `admin`, `rejection`, `completed`) anchored to a single canonical definition in the spec? [Ambiguity, Spec terminology]
- [ ] CHK052 Is the constitutional conflict between plan Node 20 and constitution §Technology Constraints Node 18 documented somewhere a cheaper executor will read (plan Complexity Tracking exists; is the tasks.md aware of it)? [Conflict, plan.md §Complexity Tracking + tasks.md T002 → see Analyze finding C1]
- [ ] CHK053 Is the FR-020 `.gitignore` list stated as "minimum required for this spec" rather than "complete audit of Principle VIII" so a cheaper executor does not over-interpret the scope? [Ambiguity, Spec §FR-020 → see Analyze finding C2]

---

## How to use this checklist

- Walk it top-to-bottom **before** running `/speckit.implement` or delegating to Codex.
- Tick `[x]` when a requirement passes the quality test. If an item fails, prefer fixing the spec/plan/tasks text over waiving the item — the point is to remove ambiguity before the cheaper executor encounters it.
- Items that reference `→ see Analyze finding X` map to the 11 findings from the 2026-04-15 `/speckit.analyze` pass; fixing those findings will close multiple checkboxes at once.
- Items marked `[Gap]` are checking for absent requirements. Resolving them means **adding** the missing requirement to the appropriate artifact, not deciding the gap is acceptable.
- Items marked `[Conflict]` are pointing at requirements that already contradict each other across artifacts. Resolving them means **editing one or both sides** so the text agrees.

## Notes

- This is a quality gate on the WRITTEN requirements, not on the eventual implementation. The implementation gate is the FR-013 + FR-015 emulator test suite (`tasks.md` T029).
- Traceability: 51 of the 53 items (~96%) include an explicit spec/plan/tasks/data-model/research reference or a `[Gap]`/`[Conflict]`/`[Ambiguity]`/`[Assumption]`/`[Traceability]` marker. Well above the 80% floor.
- Count of items flagging analyze findings directly: 6 (CHK007 → C2, CHK016 → C1, CHK017 → I2, CHK018 → I3, CHK019 → U1, CHK024 → U2, CHK028 → U3, CHK029 → U4, CHK052 → C1, CHK053 → C2). Fixing the four HIGH/MEDIUM findings (I1 separately in tasks.md, I2, U1, U2, C1 amendment note, C2) should clear most of them.
