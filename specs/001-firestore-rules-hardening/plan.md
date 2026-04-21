# Implementation Plan: Firestore Rules Hardening

**Branch**: `001-firestore-rules-hardening` | **Date**: 2026-04-14 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/001-firestore-rules-hardening/spec.md`

> **For the implementer**: this plan is written so a weaker model (or a less experienced engineer) can execute it end-to-end without judgement calls. Every choice has already been made. If you find yourself improvising — STOP and re-read. The contracts in `contracts/` are the source of truth; this plan tells you which contract to apply, in what order, and how to know when you're done.

## Summary

Tighten the security perimeter around three admin-gated Firestore write paths and one Cloud Storage write path so that:

1. An admin who assigns / resolves-dispute / cancels a job can only change the specific fields that operation needs, not arbitrary fields on the document.
2. A technician profile photo can only be written by the technician who owns it (filename-based owner check).

The change is **three rule edits + one mobile method edit**, nothing else. No new collections, no new fields, no Cloud Functions, no UI. Verification is done in the Firebase Rules Playground against the 13 scenarios listed in `contracts/firestore-rules.md` and the 7 scenarios in `contracts/storage-rules.md`.

The full step-by-step execution script lives in [quickstart.md](./quickstart.md). This plan covers the *why* and the *gates*; quickstart covers the *what to type*.

## Technical Context

**Language/Version**: Firestore Security Rules v2 (CEL); Dart / Flutter 3.41.0 for the one mobile edit
**Primary Dependencies**: Firebase CLI (rules deploy); existing `firebase_storage` Dart SDK already in `lib/firebase_service.dart`
**Storage**: Cloud Firestore (`syana-ea75a` project) and Cloud Storage default bucket
**Testing**: Firebase Console Rules Playground (manual). No automated harness is added in this spec — see research.md §R-4.
**Target Platform**: Production Firebase project `syana-ea75a` (Firestore + Storage); mobile app on iOS + Android
**Project Type**: Backend rules change + minimal mobile patch (no admin web yet)
**Performance Goals**: N/A — rule evaluation overhead is negligible compared to existing checks
**Constraints**:
- Backward compatible with the current production mobile admin client (FR-010).
- Storage rule MUST NOT deploy until the mobile filename-convention release reaches a safe install base (FR-009 / R-5).
- ≤ 2 deploys total: one mobile release, one combined rules deploy (SC-006).
**Scale/Scope**: ~5 lines of Firestore rule changes, ~6 lines of Storage rule changes, ~10 lines of Dart changes. No new files.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The repo constitution at `.specify/memory/constitution.md` (v1.1.0) defines 13 principles. This plan must enumerate compliance with **all** of them. Per the constitution's Security Review Gate clause, Principles VIII–XIII additionally need a row in the Security Review Gate table below.

| # | Principle | Compliance | Evidence |
|---|---|---|---|
| I | Migration Plan Is the Source of Truth | ✅ | Field lists in FR-001/002/003 are copied verbatim from `WOOHOO/Migration_Implementation_Plan.md` Phase 2, Task 2-1, Blocks A/B/C. |
| II | Workspace Boundary | ⚠ Justified violation | This spec touches root `lib/firebase_service.dart` (the mobile app), which the constitution says is reserved for Spec 006. Justified in **Complexity Tracking** below. |
| III | No Guessing — Read First | ✅ | Every field name was confirmed against `lib/firebase_service.dart` HEAD before being added to a whitelist. The implementer MUST re-confirm with `grep -n` before pasting. |
| IV | Deploy Safety | ✅ | Two deploys, in order: mobile release → combined `firebase deploy --only firestore:rules,storage`. Quickstart Steps 5–6 enforce the gate. |
| V | Backward Compatibility During Migration | ✅ | Whitelists were derived from the *current* production mobile client's writes (not the future CF). The `hasOnly` primitive permits subsets, so optional fields the client doesn't always write (e.g., `cancelledBy`) cause no denials. |
| VI | Flutter Tooling Isolation | ✅ | Only `flutter analyze` from the repo root is invoked, and only against the mobile project. No `admin_web/` is touched. |
| VII | No Premature Abstraction | ✅ | No helpers extracted, no shared packages introduced. The single mobile edit is in-place. |
| VIII | Secrets & Credential Hygiene | ✅ | No secrets touched. Public Firebase web config is not affected. The deploy command uses the engineer's already-authenticated CLI. |
| IX | Least Privilege & Explicit Authorization | ✅ | This spec is *itself* a Principle IX implementation — it adds the field whitelists that Principle IX requires. See Security Review Gate row IX. |
| X | Input Validation & Transactional Integrity | ✅ (N/A) | No Cloud Function in scope. Rules cannot perform `runTransaction` — irrelevant. |
| XI | Audit Trail & Accountability | ✅ (forward-compat) | Block C whitelist includes `cancelledBy` and `cancelledAt` slots so the future Cloud Function in Spec 002 can stamp them without a rule change. See research.md §R-2. |
| XII | Defense in Depth | ✅ | The new rules are the *first* of two independent layers Principle XII requires. The second layer (Cloud Functions calling `verifyAdmin`) lands in Spec 002. Storage rule keeps existing size + content-type checks AND adds the owner check — three independent constraints. |
| XIII | Safe Error Reporting & Logging | ✅ (N/A) | No log statements added or removed. Rule denial messages are framework-generated, not formatted by this spec. |

### Security Review Gate

Required by the constitution for every spec from 001 onward.

| Principle | Control implemented in this spec | File path | Verification |
|---|---|---|---|
| VIII | None — no secrets or credentials touched | n/a | n/a |
| IX | `affectedKeys().hasOnly(...)` whitelists on the 3 admin job branches; `fileName.split('_')[0] == request.auth.uid` owner check on `techProfiles/{fileName}` | `firestore.rules` (3 blocks under `match /jobs/{jobId}`); `storage.rules` (`match /techProfiles/{fileName}`) | Rules Playground scenarios A1–A4, B1–B5, C1–C4 (Firestore), S1–S7 (Storage). Listed in `contracts/firestore-rules.md` and `contracts/storage-rules.md`. |
| X | None — no Cloud Function in scope | n/a | Deferred to Spec 002. |
| XI | Forward-compat slots for `cancelledBy` / `cancelledAt` in Block C whitelist; no audit *writes* added in this spec | `firestore.rules` Block C | Verified by scenario C2 (write that includes `cancelledBy`/`cancelledAt` is allowed). |
| XII | Storage rule retains size (< 5 MiB) + content-type (`image/.*`) + auth-required AND adds owner check — three independent layers on the same path | `storage.rules` `match /techProfiles/{fileName}` | Scenarios S1–S7. Each scenario varies one constraint at a time. |
| XIII | None — no log statements added | n/a | n/a |

If any row above changes from "not applicable" to "applicable" mid-implementation, STOP and re-attach a security-review note before continuing.

## Project Structure

### Documentation (this feature)

```text
specs/001-firestore-rules-hardening/
├── plan.md                           # This file
├── spec.md                           # Feature spec (what & why)
├── research.md                       # 5 design decisions (R-1 .. R-5)
├── data-model.md                     # Field whitelists per rule block
├── quickstart.md                     # Linear execution script (Steps 0..8)
├── contracts/
│   ├── firestore-rules.md            # Exact before/after diff for the 3 rule edits + 13 verification scenarios
│   ├── storage-rules.md              # Exact before/after diff for the storage edit + 7 verification scenarios
│   └── upload-photo-contract.md      # Exact before/after diff for the uploadPhoto Dart method
└── checklists/
    └── requirements.md               # Audit log + reviewer notes (do not delete)
```

### Source files actually edited by this spec

```text
firestore.rules                  # 3 edits inside `match /jobs/{jobId}` only — see contracts/firestore-rules.md
storage.rules                    # 1 edit inside `match /techProfiles/{fileName}` only — see contracts/storage-rules.md
lib/firebase_service.dart        # 1 edit inside the `uploadPhoto` method only — see contracts/upload-photo-contract.md
```

**Structure Decision**: This spec does NOT create any new files. It does NOT introduce `admin_web/` or `functions/`. Every edit is an in-place modification of an existing file. The implementer should never `git add .` — only `git add` the three files listed above explicitly (quickstart Step 4.2).

## Implementation Phases (high level)

The detailed execution lives in `quickstart.md`. This is the map.

1. **Phase 2-A — Firestore rules (Steps 1–2 of quickstart)**: apply the three `affectedKeys().hasOnly(...)` additions, verify in the Rules Playground.
2. **Phase 2-B — Mobile filename change (Step 3 of quickstart)**: apply the `uploadPhoto` body replacement, run `flutter analyze`.
3. **Phase 2-C — Commit + push (Step 4 of quickstart)**: stage exactly the two files, commit with the prescribed message.
4. **Phase 2-D — Deploy mobile, then Firestore rules (Step 5 of quickstart)**: ship the mobile release first, then deploy `firebase deploy --only firestore:rules`. Run the SMOKE-1..4 tests.
5. **Phase 2-E — Wait for install base (Step 5b.4 gate)**: 48 hours OR ≥ 80% of technician uploads come from the new build.
6. **Phase 2-F — Storage rules (Step 6 of quickstart)**: apply the `storage.rules` edit, verify the 7 Storage Playground scenarios, deploy `firebase deploy --only storage`.
7. **Phase 2-G — Monitor 72h (Step 7 of quickstart)**: zero `PERMISSION_DENIED` events from admin UIDs on `/jobs/*` or technician UIDs on `techProfiles/*`.
8. **Phase 2-H — Sign-off (Step 8 of quickstart)**: tick every checkbox; reviewer takes over.

There is no Phase 0 or Phase 1 work left for this plan to schedule — `research.md`, `data-model.md`, `contracts/`, and `quickstart.md` are already complete and have been reviewer-approved.

## How to use this plan if you are the implementer

1. Read `spec.md` end to end. Don't skim.
2. Read this plan end to end. Re-read the Constitution Check table — you are accountable for those rows.
3. Read `research.md` (5 short decisions, ~10 min). It explains *why* the whitelists look the way they do.
4. Read `data-model.md` (the field tables). Cross-reference field names against `lib/firebase_service.dart` HEAD.
5. Read each file in `contracts/` once before touching anything.
6. Open `quickstart.md` and execute it top-to-bottom, ticking boxes. **Do not skip steps. Do not reorder them.** If a step's command fails, stop and escalate — do not improvise.
7. If at any point you find yourself wanting to "clean up nearby code" or "also fix this related thing", STOP. That is scope creep and it is forbidden. The reviewer will notice and will reject the work.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| **Principle II — touching root `lib/` before Spec 006** | The `techProfiles` storage rule (`fileName.split('_')[0] == request.auth.uid`) cannot be safely deployed until production filenames already start with the owner's UID. The only place that produces those filenames is `lib/firebase_service.dart` → `uploadPhoto`. Without this one mobile edit, FR-006 cannot ship without breaking every technician's profile-photo upload. | **Alt 1** — defer the storage rule to Spec 006: rejected, because the migration plan classifies the missing owner check as a hard blocker for Phase 2 sign-off. **Alt 2** — implement filename rewriting inside a Cloud Function: rejected, because no Cloud Functions exist yet and Spec 002 hasn't shipped. **Alt 3** — change the storage path layout to `techProfiles/{uid}/{file}`: rejected per research.md §R-3 because it would break the legacy public-read URLs that customers' app already cached. The single in-place `uploadPhoto` edit is the smallest possible change that unblocks the rule. |

The mobile edit is in-place, has no new dependencies, and is fully covered by the contract in `contracts/upload-photo-contract.md`. The reviewer signed off on this deviation.

## Open questions

None. All decisions are resolved in `research.md`. If you find what looks like an open question while implementing, it is almost certainly already answered in research.md or data-model.md — re-read those before asking.

## Out of scope (stated explicitly so it cannot be re-litigated)

- Cloud Functions of any kind.
- Stats collection (`stats/global`) rule changes.
- Payments collection rule changes.
- Activity log creation or rule changes.
- Admin web UI (`admin_web/`).
- Rules unit-test harness (`@firebase/rules-unit-testing`). Deferred per research.md §R-4.
- Any change to `users/{uid}` documents.
- Any new field on any existing document.
- Migration or renaming of legacy `techProfiles/` files.
