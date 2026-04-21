# Research: Firestore Rules Hardening

**Feature**: `001-firestore-rules-hardening`
**Date**: 2026-04-13
**Status**: Complete — zero open clarifications

This document captures the non-obvious decisions the implementer needs to trust. Each entry follows `Decision / Rationale / Alternatives considered`.

---

## R-1 — Three separate `affectedKeys()` blocks, not one generic admin whitelist

**Decision**: Add three independent `affectedKeys().hasOnly([...])` restrictions, one per admin-gated branch in `match /jobs/{jobId}`:
1. Admin assignment (requested → active)
2. Admin dispute resolution (receipt_disputed → reopen / complete / cancel)
3. Admin cancellation (any non-terminal → cancelled)

**Rationale**: The three operations touch different sets of fields. Assignment writes `assignedTechnicianId` / `technicianId` / `assignedTechnicianName` (never `receiptRejected`). Dispute resolution writes `receiptRejected` / `disputeResolvedAt` / possibly `amountPaid` (never `assignedTechnicianId`). Cancellation writes `status` plus optional `cancelledBy` / `cancelledAt`. A union whitelist would allow an admin "assignment" write to silently set `receiptRejected = true`, which defeats the purpose of the restriction.

**Alternatives considered**:
- *One combined whitelist* covering every field any admin branch could touch. Rejected: it is no narrower than the current "admins can write anything" rule for cross-operation misuse.
- *Generic `isAdmin()` + status transition check with no field whitelist*. That is the current state. Rejected because the spec explicitly exists to add the field whitelist on top of the existing status checks.

**Reference**: Migration plan Task 2-1, Block A / Block B / Block C.

---

## R-2 — Why `{cancelledBy, cancelledAt}` are in the cancellation whitelist even though the current mobile client does not write them

**Decision**: Include `cancelledBy` and `cancelledAt` in the Block C whitelist (`{status, cancelledBy, cancelledAt, updatedAt}`) even though today's mobile admin client only writes `status`.

**Rationale**: `hasOnly` allows any **subset** of the whitelist to be present in the diff. A write that sets only `status` still passes `hasOnly(['status', 'cancelledBy', 'cancelledAt', 'updatedAt'])`, so backward compatibility with the current client is preserved. At the same time, the whitelist documents which fields are permitted forward — when Spec 002 introduces a Cloud Function that stamps `cancelledBy` and `cancelledAt`, no rule change is needed in that spec.

**Alternatives considered**:
- *Whitelist only `{status}`*. Rejected because it forces a rule change in Spec 002, creating a deploy coupling that would otherwise be unnecessary.
- *Whitelist only `{status, cancelledBy, cancelledAt}`* (omit `updatedAt`). Rejected because the current mobile client does bump `updatedAt` in most paths and omitting it could cause intermittent denials.

**Reference**: Migration plan Task 2-1 Block C.

---

## R-3 — Why the storage rule uses `fileName.split('_')[0]` and not a path variable

**Decision**: The `techProfiles` storage rule uses `fileName.split('_')[0] == request.auth.uid`, applied to `match /techProfiles/{fileName}`. The match path keeps a single `{fileName}` wildcard.

**Rationale**: Firebase Storage rule `match` statements do not support arbitrary string splitting in the path pattern. The path template `match /techProfiles/{uid}_{ts}.jpg` is not valid storage-rules syntax. Applying a `split('_')[0]` inside the `allow write` condition is the documented idiom.

**Alternatives considered**:
- *A nested match like `match /techProfiles/{uid}/{fileName}`*. Rejected because it would require changing the upload path, not just the filename, and would break existing stored files (which all live under the flat `techProfiles/` prefix).
- *A metadata-based owner claim* using custom Storage metadata. Rejected because metadata cannot be trusted from the client without an additional rules check, yielding the same complexity for weaker guarantees.

**Reference**: Migration plan Task 2-2, §"Storage Rules — Tech Profile Upload Convention".

---

## R-4 — No rules unit test harness in this spec

**Decision**: Verification of the three Firestore rule changes and the one Storage rule change is done manually in the Firebase Console Rules Playground. No `@firebase/rules-unit-testing` harness is added in this spec.

**Rationale**: Introducing a harness would require adding a Node project, a Jest/Vitest runner, and a CI workflow — all of which are explicitly out of scope for a Phase 2 rules-hardening sprint. The Playground already covers the scenarios listed in `contracts/firestore-rules.md` §Verification. A harness may be added in a later spec if the maintenance cost of Playground-based verification grows.

**Alternatives considered**:
- *Add `@firebase/rules-unit-testing` under a new `tests/rules/` directory*. Deferred. The cost-benefit does not justify the scope expansion in this spec. Revisit after Spec 002 ships.

**Reference**: Migration plan Task 2-1, Deploy and test steps.

---

## R-5 — Deploy ordering: mobile release FIRST, then rules

**Decision**: Ship in this exact order:
1. Mobile release that updates `uploadPhoto` to produce `{uid}_{timestampMillis}.jpg` for the `techProfiles` folder. Wait until this release has reached an install-base threshold the team is comfortable with (suggested: 48 hours after release, or ≥ 80% adoption, whichever comes first).
2. Single combined rules deploy: `firebase deploy --only firestore:rules,storage`.

**Rationale**: If the storage rule deploys before the mobile release is live, every technician still running the old client will fail their profile-photo upload (their filename does not start with their UID). If the rules deploy fires before the Firestore rules change is also ready, the deploy is still a two-file atomic deploy, so it is safe to combine. The Firestore rules piece is backward-compatible on its own (FR-010), so it could in principle ship before the mobile release — but bundling them reduces the number of deploy windows to two: mobile, then rules.

**Alternatives considered**:
- *Deploy Firestore rules first, mobile second, storage rules third (three deploys)*. Rejected because it triples the ops surface for no benefit — the Firestore rules change does not require the mobile release as a prerequisite.
- *Deploy rules first, trust the client-side regression to be caught in QA*. Rejected: it is a known bad state and FR-009 forbids it.

**Reference**: Migration plan Task 2-2, Step 2 "Ship the mobile update", Step 3 "Update `storage.rules`".

---

## Open questions

None. All inputs are resolved against the migration plan and the current `firestore.rules` / `storage.rules` / `lib/firebase_service.dart` files on `HEAD`.
