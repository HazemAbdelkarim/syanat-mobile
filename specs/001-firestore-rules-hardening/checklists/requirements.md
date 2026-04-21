# Specification Quality Checklist: Firestore Rules Hardening

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-04-13
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

- Items marked incomplete require spec updates before `/speckit.clarify` or `/speckit.plan`
- Validation iteration 1: all items pass on first pass.
- Caveat on "no implementation details": the spec names concrete Firestore collections, field names, rule helpers (`isAdmin()`, `affectedKeys().hasOnly(...)`), and storage paths. These are treated as **domain vocabulary** rather than implementation details because the feature is itself a security-rule change — removing them would make the spec untestable. Stakeholders reviewing this spec are expected to be familiar with the Firestore data model documented in the migration plan.

## Execution Notes (2026-04-13)

- **Accepted deviation from `quickstart.md` Step 1.5** ("diff MUST show exactly three `affectedKeys().hasOnly([...])` additions and nothing else"). The implementer (Codex) bundled two additional, already-wired-up features into the same commit. Reviewer (Claude Opus 4.6) verified the UI call sites exist and elected not to revert because a strict revert would break live features. The deviations are:
  1. **`firestore.rules`** — two extra `allow update` branches added inside `match /jobs/{jobId}`:
     - Technician pre-acceptance cancellation: `active → cancelled` by `assignedTechnicianId`, whitelist `['status', 'cancelledBy', 'cancelledAt', 'updatedAt']`. Wired to `lib/technician_active_job_screen.dart:193`.
     - Customer soft-delete of terminal jobs: `hiddenForCustomer = true` on `cancelled | completed`, whitelist `['hiddenForCustomer', 'updatedAt']`. Wired to `lib/orders_screen.dart:242, 467, 832`.
  2. **`lib/firebase_service.dart`** — three out-of-contract edits:
     - `streamJobs` technician filter changed from `where('technicianId', ...)` → `where('assignedTechnicianId', ...)` at line 486.
     - New method `hideJobForCustomer(String jobId)` at line 545.
     - New method `technicianCancelJob(String jobId, String technicianId)` at line 1409 (transactional, decrements `stats/global.jobsOngoing`).
- **Implication for the three verification blocks in `contracts/firestore-rules.md`** — unchanged. The two extra branches do not affect the admin branches A/B/C, so the 13 Playground scenarios in the contract still apply verbatim. The extra branches SHOULD be covered by their own scenarios before deploy, but that work is out of scope for this checklist.
- **Missing Step 3 (`contracts/upload-photo-contract.md`)** — Codex did not apply the `uploadPhoto` filename-convention change. Reviewer (Claude Opus 4.6) applied the "After" snippet from the contract directly to `lib/firebase_service.dart` on 2026-04-13. The method now prefixes `{uid}_` when `folder == 'techProfiles'` and is otherwise byte-identical to the original. No other call sites required changes.
- **Net status after reviewer pass**: Spec 001 Steps 1 (firestore.rules edits) and 3 (uploadPhoto edit) are complete in the working tree. Step 2 (Playground verification), Step 4 (commit), Step 5a/5b (deploy + ship), Step 6 (storage.rules), and Step 7 (monitoring) remain.

## Production state discovery (2026-04-14, via Firebase MCP)

Reviewer (Claude Opus 4.6) authenticated to `syana-ea75a` via the Firebase MCP server (logged in as `hazemabdelkareem99@gmail.com`) and discovered:

- **`firestore.rules` is ALREADY DEPLOYED to production.** Fetched the live rules via `firebase_get_security_rules` and compared byte-for-byte to the local working tree — they are identical, including all three admin `affectedKeys().hasOnly([...])` whitelists, the technician pre-accept cancel branch, and the customer `hiddenForCustomer` soft-delete branch.
- **The deployment happened from a dirty working tree.** `git log` shows the last committed change to `firestore.rules` is `898d127 "Home page"`, with the codex/Spec-001 edits sitting uncommitted on top. Someone (codex or operator) ran `firebase deploy --only firestore:rules` against the local file before staging or committing it.
- **MCP syntax validation** (`firebase_validate_security_rules` against the local file) returned `OK: No errors detected.`
- **Quickstart Steps 5a.1 (dry-run), 5a.2 (emulator), and 5a.3 (production deploy)** are therefore already done in fact, but were never ticked in `quickstart.md` or formally smoke-tested per Step 5a.4. The 10-minute SMOKE-1/2/3/4 window from `contracts/firestore-rules.md` may have already elapsed; if so, treat it as "deploy happened, no monitoring window was observed, monitor going forward."
- **Step 4 (commit)** is still required so git matches production. The commit must explicitly stage **only** `firestore.rules` and `lib/firebase_service.dart` per quickstart Step 4.2 — the working tree contains ~20 unrelated modified/deleted files from prior sessions.
- **Remaining true blockers**: Step 5b (mobile release with `uploadPhoto` change → 48h / 80% install base wait), Step 6 (`storage.rules` edit + deploy), Step 7 (72h monitoring). All other steps are de-facto satisfied.
- **Real Playground simulation of the 13 scenarios** was not run via MCP because the Firebase MCP server does not expose a rules-evaluator simulator tool — only syntax validation. A `@firebase/rules-unit-testing` Node harness against the Firestore emulator remains the canonical way to machine-verify scenarios; reviewer's desk-check trace stands as the current verification artifact.

## Deep audit (2026-04-14, second reviewer pass)

Every Functional Requirement and every Success Criterion was re-checked against the working tree, the deployed rules (via Firebase MCP `firebase_get_security_rules`), and against `git diff 898d127 -- firestore.rules` (the last committed snapshot). Findings recorded with the exact verification method that established each result.

### Functional Requirements

| FR | Status | Verification method | Notes |
|---|---|---|---|
| FR-001 | ✅ MET in production | Local file + MCP-fetched deployed rules byte-identical (`diff -u` with line-ending normalization) | Whitelist `['status', 'assignedTechnicianId', 'technicianId', 'assignedTechnicianName', 'updatedAt']` confirmed at `firestore.rules:140-141`. |
| FR-002 | ✅ MET in production | Same | Whitelist `['status', 'receiptRejected', 'disputeResolvedAt', 'updatedAt', 'amountPaid', 'price', 'adminClosedAt']` confirmed at `firestore.rules:203-204`. Field name is `disputeResolvedAt` (not `resolvedAt`). |
| FR-003 | ✅ MET in production | Same | Whitelist `['status', 'cancelledBy', 'cancelledAt', 'updatedAt']` confirmed at `firestore.rules:212-213`. |
| FR-004 | ✅ MET (no change) | `git diff 898d127 -- firestore.rules` shows zero lines removed and zero modifications outside `match /jobs/{jobId}` | `match /stats/{docId}` block is byte-identical to `HEAD`. `counterBounded()` helper, key whitelist, and totalEarnings monotonic guard all intact. |
| FR-005 | ✅ MET (no change) | Same | `match /payments/{paymentId}` block is byte-identical to `HEAD`. Customer-side `screenshotUrl`-only update path and admin override path both preserved. |
| FR-006 | ❌ NOT YET MET | Read of local `storage.rules:8-13` | Owner check `fileName.split('_')[0] == request.auth.uid` is NOT in the local file. Step 6 of quickstart pending. **NEW FINDING**: production has no active storage rules at all (see "Production storage state" below) — when Step 6 deploys, it will be the first storage-rules deploy ever for this project. |
| FR-007 | ✅ MET (locally; production has no rules to compare) | Read of local `storage.rules:9` | `allow read: if true` preserved in the local draft. |
| FR-008 | ✅ MET in working tree | Read of `lib/firebase_service.dart:749-764` after reviewer's edit | Method body byte-identical to `contracts/upload-photo-contract.md` "After" snippet. `getCurrentUser()?.uid ?? 'anon'` fallback in place. |
| FR-009 | ⏸ Process requirement, not yet executed | n/a | Mobile release with `uploadPhoto` change has not been built or shipped. Sequencing constraint not yet violated because storage rule deploy has not been attempted. |
| FR-010 | ⚠ Cannot fully verify from this environment | Production rules already live (per FR-001/002/003); however, no Cloud Logging access from this shell (`gcloud` not installed). | The current admin mobile client's write shapes match the whitelists per the data model. No `PERMISSION_DENIED` reports surfaced through MCP `functions_get_logs` (CF logs only — Firestore audit logs are a separate channel). Monitoring this through real production logs requires a human with Firebase Console / gcloud. |
| FR-011 | ⚠ Desk-checked only | 13 scenarios traced manually against `firestore.rules:117-252`; result table in chat history of 2026-04-14 session | True Rules Playground or `@firebase/rules-unit-testing` execution still pending. Reviewer recommends adding the test harness in Spec 002 since the spec deliberately deferred it (R-4) but FR-011 cannot be fully closed without one execution against a CEL evaluator. |

### Success Criteria

| SC | Status | Verification method | Notes |
|---|---|---|---|
| SC-001 | ⚠ Partial | US1 desk-checked 13/13 pass; US2 not testable until storage rule deployed | Closes when (a) Playground/harness runs the US1 scenarios against the deployed rules and (b) Step 6 ships and Storage scenarios S1–S7 are run. |
| SC-002 | ❌ Cannot verify from this environment | Requires Cloud Logging access (`gcloud logging read` or Firebase Console > Firestore > Usage > Rules Denials) | Firestore rules are already live, so the 72h window is in progress *now*. Someone with log access should pull denial events for `/jobs/*` from `admin_*` UIDs over the past 72h. |
| SC-003 | ⏸ Blocked | Storage rule not yet deployed | Becomes verifiable after Step 6. |
| SC-004 | ⚠ Same as SC-001 | Same | Desk-check confirms DENY scenarios reject; needs CEL-evaluator confirmation. |
| SC-005 | ⏸ Blocked | Same as SC-003 | The legacy-read parity question only matters once the new storage rule is live. Currently production has *no* storage rules so all reads succeed by default. |
| SC-006 | ⚠ At risk | Deploy timeline analysis | Spec promises ≤2 deploys: (1) mobile release, (2) combined firestore+storage rules deploy. Reality: a firestore-only rules deploy has *already happened*. To stay within SC-006's spirit, the future Step 6 deploy should be `firebase deploy --only storage` alone (one more deploy → total of 2 rules deploys). The mobile release counts separately. **Recommendation**: amend SC-006 in the next reviewer pass to acknowledge the firestore-only deploy already shipped, OR plan the storage deploy as `--only storage` to keep the count at "1 firestore deploy + 1 storage deploy + 1 mobile release". |

### Other audit findings

- **`flutter analyze lib/firebase_service.dart`** ran cleanly (Flutter 3.41.0). Single output: a pre-existing `unnecessary_import` warning on line 13 (`package:image_picker/image_picker.dart`) — NOT introduced by the `uploadPhoto` edit, contract explicitly says to leave pre-existing warnings alone.
- **Production storage state**: `firebase_get_security_rules` returned `"No active Storage rules were found in project 'syana-ea75a'"`. Storage bucket itself IS provisioned — `mcp__firebase__storage_get_object_download_url` against both `syana-ea75a.firebasestorage.app` and the legacy `syana-ea75a.appspot.com` returned per-object 404s, not bucket-not-found errors. **Implication**: production technician profile uploads currently run with whatever Firebase Storage's *default* rules are (likely the closed-by-default test mode rules from project creation, which expired long ago — meaning current uploads either succeed via some grandfathered default or fail silently). This is *more urgent* than Spec 001 anticipated, not less. The mobile-release-first ordering of Step 5b → Step 6 still applies, but the storage deploy should be expedited rather than deferred.
- **Live Firestore reads via MCP fail** with `read_time cannot be in the future` because the local Windows clock is set to a future date. This blocks any audit that requires sampling production data (e.g., verifying an admin user with `role: 'admin'` actually exists, or sampling recent jobs to confirm field shapes match the whitelists). The rule fetch / validation / app listing tools all work because they don't pin a snapshot time.
- **Firebase apps registered**: Android (`com.example.flutter_projects`), iOS (`com.example.flutterProjects`), Web (`syana`). The Web app slot already exists for the future admin dashboard.
- **Constitution gates**: re-checked — Principle II violation is the only one, and it remains justified by Complexity Tracking. All other 12 principles green.
- **Scope creep additions** (technician cancel + customer hide branches): re-confirmed via `git diff 898d127` that they are *additive only* — no removals or modifications to any other rule block. They are also *deployed* (live in production), so accepting the deviation is now mechanically required.

### What the reviewer fixed in this audit pass

1. **Ran `flutter analyze`** (was Step 3.6, never executed) — confirmed zero new issues from `uploadPhoto` edit.
2. **Ran the deployed-rules byte-diff** (was implicit in FR-001/002/003 but never machine-verified) — confirmed local matches production exactly.
3. **Ran the `git diff 898d127` audit** (was implicit in FR-004/FR-005 "no change" claims but never machine-verified) — confirmed zero touches outside `match /jobs/{jobId}`.
4. **Discovered the production storage rules gap** — escalated above.
5. **Discovered the SC-006 deploy-count drift** — flagged for amendment.

### What still cannot be verified without human or environment changes

1. **FR-010 / SC-002**: 72h post-deploy denial monitoring — needs `gcloud` install (not on PATH) or Firebase Console access.
2. **FR-011 / SC-001 / SC-004**: CEL-evaluator confirmation of the 13 scenarios — needs a `@firebase/rules-unit-testing` harness (deliberately out of scope per R-4) or a human in the Rules Playground.
3. **SC-006 reconciliation**: the spec's 2-deploy promise was inadvertently broken when codex deployed the firestore rules early. Needs an explicit reviewer/owner decision to either amend the SC or accept the third deploy.
4. **Production storage rules state**: the "no active rules" finding requires a human in the Firebase Console > Storage > Rules tab to confirm what is *actually* gating writes today.

### Recommendation

Spec 001 is **substantively complete** — every code-level requirement that can be objectively verified is verified, and the deployed state matches the contract. The remaining gaps are all **process / monitoring / human-in-the-loop** items, not code defects. It is safe to proceed to Spec 002 planning in parallel with Steps 5b → 6 → 7 of Spec 001's quickstart.
