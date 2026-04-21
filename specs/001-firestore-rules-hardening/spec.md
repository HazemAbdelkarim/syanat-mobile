# Feature Specification: Firestore Rules Hardening

**Feature Branch**: `001-firestore-rules-hardening`
**Created**: 2026-04-13
**Status**: Draft
**Input**: User description: "Create the first spec based on the migration plan WOOHOO/Migration_Implementation_Plan.md"

## Overview

This is the first deliverable of the Admin Web Migration programme. The migration moves admin functionality from the mobile app to a new Flutter web dashboard and a set of Cloud Functions. Before any of that can happen, the security perimeter around Firestore and Storage must be tightened so that admin writes cannot silently corrupt unrelated fields, and so that technician profile photos can only be overwritten by their owners.

This spec covers the very first phase of the plan (Phase 2: Firestore Rules Hardening). It is deliberately scoped to rule changes and one minimal mobile code change that unblocks a storage rule. It does **not** introduce Cloud Functions, stats ownership changes, or any admin web UI — those are tracked in later specs.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Restrict admin job writes to a known field set (Priority: P1)

When an admin performs one of three privileged job operations — assigning a requested job to a technician, resolving a disputed receipt, or cancelling a job — the write must be constrained so that only the fields relevant to that operation can change. Today these admin paths gate on `isAdmin()` alone, which means a compromised or buggy client could quietly flip any other field on the job document (customer, price, status history, timestamps) without detection.

**Why this priority**: This is the largest immediate security exposure. Admin accounts currently have write-everything access to jobs; every subsequent phase of the migration layers on top of this assumption. Without field-level restrictions, later phases (Cloud Functions, web dashboard) cannot claim any stronger guarantee than "we trust the current client code."

**Independent Test**: Can be fully tested in the Firebase Rules Playground by asserting that an admin write carrying only the whitelisted field set is ALLOWED, and the same write with one extra field is DENIED. No application code needs to change for this test to be meaningful.

**Acceptance Scenarios**:

1. **Given** an admin is signed in and a job is in `requested` status, **When** the admin writes an update that changes only `status`, `assignedTechnicianId`, `technicianId`, `assignedTechnicianName`, and `updatedAt`, **Then** the write is allowed.
2. **Given** the same setup, **When** the admin write additionally changes `customerId`, **Then** the write is denied.
3. **Given** a job in `receipt_disputed` status, **When** the admin writes only the dispute-resolution fields (`status`, `receiptRejected`, `disputeResolvedAt`, `updatedAt`, and optionally `amountPaid`, `price`, `adminClosedAt`), **Then** the write is allowed.
4. **Given** a job in `receipt_disputed` status, **When** the admin write adds an unrelated field such as `description`, **Then** the write is denied.
5. **Given** any active job, **When** the admin issues a cancellation write touching only `status`, `cancelledBy`, `cancelledAt`, and `updatedAt`, **Then** the write is allowed; adding any other field denies it.
6. **Given** the current production mobile admin client, **When** it performs its usual assign/resolve/cancel flows after the rules ship, **Then** none of its writes are rejected (i.e. the restriction matches today's client fields exactly).

---

### User Story 2 - Prove that technician profile photos can only be written by their owner (Priority: P1)

Technician profile photos live under `techProfiles/` in Cloud Storage. Today any authenticated user can upload or overwrite any file in that prefix, because uploads are stored as `{timestamp}.jpg` and the storage rule contains no owner check. An owner check is desired, but is impossible to enforce until filenames carry the owner's UID.

**Why this priority**: Equal priority with Story 1 because it closes a real abuse vector (a signed-in user overwriting another technician's profile photo), and because the migration plan lists it as a hard blocker. The mitigation is coupled to a mobile code change, which makes ordering critical: the new filename convention must be live in production before the tightened rule is deployed, otherwise existing upload flows break.

**Independent Test**: Can be tested by issuing a Storage upload from the emulator or Rules Playground with a filename whose UID prefix does not match the caller's `request.auth.uid`; the upload must be denied. A matching upload must be allowed. Existing files with the legacy `{timestamp}.jpg` naming must remain readable.

**Acceptance Scenarios**:

1. **Given** an authenticated technician with UID `tech_A`, **When** they upload a photo named `tech_A_1712000000000.jpg` to `techProfiles/`, **Then** the upload is allowed.
2. **Given** the same technician, **When** they attempt to upload `tech_B_1712000000000.jpg`, **Then** the upload is denied.
3. **Given** a legacy file `1700000000000.jpg` that predates the rule change, **When** any signed-out or signed-in user reads it, **Then** the read succeeds (public read is preserved).
4. **Given** the new filename convention is shipped in the mobile app, **When** a technician performs the in-app "change profile photo" flow, **Then** the upload succeeds end-to-end without any user-visible error.

---

### User Story 3 - Preserve the current payment and stats behaviour during this phase (Priority: P2)

No changes are made to payment writes or to the `stats/global` write rule in this phase. The goal is to add job and storage restrictions **in isolation** so that if a regression appears it can be attributed to exactly one rule block.

**Why this priority**: Lower than P1 because it is a scope-guard rather than a new capability. But it is important to state explicitly: later phases in the migration will replace payment status writes with a Cloud Function and lock down `stats/global` writes. Mixing those changes into this spec would make a rollback much more expensive.

**Independent Test**: After deploying the new rules, the existing mobile client's payment approve/reject flows and all existing stats counter updates continue to work without any rule-related denials in Firestore debug logs.

**Acceptance Scenarios**:

1. **Given** the hardened rules are deployed, **When** an admin approves or rejects a payment using the current mobile client, **Then** the operation succeeds exactly as it did before.
2. **Given** the hardened rules are deployed, **When** any of the six existing client-side stats writers (`createUser`, `assignJob`, `adminCloseJob`, `adminResolveDispute` complete branch, `adminResolveDispute` cancel branch, `addEarnings`) fires, **Then** the write to `stats/global` succeeds unchanged.

---

### Edge Cases

- **Mobile client drift**: If the mobile admin client starts writing a new field that was not in the whitelist at deploy time, all admin job writes from that client will begin failing. Mitigation: the field lists in the rules are derived from the current mobile client source (see Resolved Blueprint in the migration plan); any mobile admin PR that touches these paths must be reviewed against the rule whitelist before merge.
- **In-flight upload during filename cutover**: A mobile app that has not yet picked up the new filename convention will attempt to upload `{timestamp}.jpg`, which fails the owner check. Mitigation: ship the mobile update first and allow it to reach a safe install base before deploying the storage rule.
- **Legacy photos cannot be overwritten by their original owner** because their filenames do not start with a UID. This is acceptable because overwrite-in-place is not part of the supported technician flow; a new photo is always stored under a fresh filename.
- **Dispute resolution that also records `amountPaid`, `price`, and `adminClosedAt`** must still be allowed, because the `complete` branch of the current client does write these fields. The restriction is `hasOnly`, not `hasAll`, so missing optional fields are fine; extra fields are not.
- **Admin cancellation writes that touch only `status`** (the minimum the current client guarantees) must be allowed. The cancellation whitelist therefore includes `cancelledBy` and `cancelledAt` as optional additions for forward compatibility.
- **Concurrent admin writes** on the same job: the rules do not serialise anything, so two admins writing at once still produce a last-writer-wins document. Transactions are the job of the application layer and are out of scope for this spec.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Firestore rule for the admin job-assignment write path MUST require `isAdmin()` AND MUST restrict the diff to exactly the field set `{status, assignedTechnicianId, technicianId, assignedTechnicianName, updatedAt}`.
- **FR-002**: The Firestore rule for the admin dispute-resolution write path MUST require `isAdmin()` AND MUST restrict the diff to a subset of `{status, receiptRejected, disputeResolvedAt, updatedAt, amountPaid, price, adminClosedAt}`.
- **FR-003**: The Firestore rule for the admin job-cancellation write path MUST require `isAdmin()` AND MUST restrict the diff to a subset of `{status, cancelledBy, cancelledAt, updatedAt}`.
- **FR-004**: The Firestore stats write rule MUST remain unchanged in this phase. Any change to stats ownership is deferred to a later spec.
- **FR-005**: The Firestore payment write rule MUST remain unchanged in this phase. Replacing `updatePaymentStatus` with a Cloud Function is deferred to a later spec.
- **FR-006**: The Storage rule for the `techProfiles/{fileName}` write path MUST keep the existing size limit (< 5 MiB), the existing content type check (`image/*`), and MUST additionally require that `fileName.split('_')[0] == request.auth.uid`.
- **FR-007**: The Storage read rule for `techProfiles/{fileName}` MUST remain public (`allow read: if true`) so that legacy files continue to load for customers viewing technician profiles.
- **FR-008**: The mobile photo upload helper (`uploadPhoto` in `lib/firebase_service.dart`) MUST, when the target folder is `techProfiles`, generate filenames of the form `{uid}_{timestampMillis}.jpg`. For all other folders, the current `{timestampMillis}.jpg` convention MUST be preserved.
- **FR-009**: The mobile release that changes the filename convention MUST be shipped to users and reach a deploy-safe install base before the tightened `techProfiles` storage rule is deployed to production.
- **FR-010**: After the rules and mobile change ship, the existing admin flows on the current mobile client (assign, resolve dispute, cancel, payment approve/reject, stats counters) MUST continue to operate with zero rule-related denials.
- **FR-011**: Rule deployments for this phase MUST be verified in the Firebase Console Rules Playground against the scenarios listed in User Story 1 and User Story 2 before being considered complete.

### Key Entities

- **Job document (`jobs/{jobId}`)**: Represents a customer service request. Relevant attributes for this spec: `status`, `assignedTechnicianId`, `technicianId`, `assignedTechnicianName`, `cancelledBy`, `cancelledAt`, `receiptRejected`, `disputeResolvedAt`, `amountPaid`, `price`, `adminClosedAt`, `updatedAt`. Only these fields may appear in an admin-gated diff for the three restricted paths.
- **Storage object (`techProfiles/{fileName}`)**: Represents a technician profile photo. The `fileName` segment carries the owner UID as a prefix after the rule change, enabling a filename-based owner check.
- **Admin user (`users/{uid}` where `role == 'admin'`)**: The principal allowed to perform the restricted job writes. Admin identity is determined by a Firestore document read in `isAdmin()` and is unchanged by this spec.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of the Rules Playground scenarios listed in Acceptance Scenarios for User Story 1 and User Story 2 pass on the deployed ruleset.
- **SC-002**: Zero rule-denial errors attributed to admin job write paths appear in Firestore debug logs during the first 72 hours after deployment, measured against the current mobile admin client.
- **SC-003**: Zero rule-denial errors attributed to the `techProfiles` storage path appear for technicians running the mobile release that adopts the new filename convention, measured during the first 72 hours after the storage rule deploys.
- **SC-004**: Any attempt (from the Rules Playground or a test client) to write an admin-gated job path with a field outside the whitelist is denied within a single deploy cycle of the rules being published — verified by an automated or manual test before sign-off.
- **SC-005**: Existing public reads of legacy `techProfiles/{timestamp}.jpg` files continue to succeed with a 100% success rate after the rule change, measured across a sample of production reads in the first 24 hours.
- **SC-006**: The phase ships in two deployments at most: (1) a mobile release that updates the upload filename convention, (2) a single combined rules deploy that updates `firestore.rules` and `storage.rules`. No intermediate hotfix deploys are required to recover from a regression.

## Assumptions

- The existing `isAdmin()` helper in `firestore.rules` (Firestore document read against `users/{uid}.role == 'admin'`) is the authoritative admin check for the entire migration. This is architectural decision D1 in the migration plan and is out of scope for this spec.
- The field lists in FR-001 through FR-003 match what the current production mobile admin client actually writes. This is the condition that prevents FR-010 from failing; any future change to the mobile admin client's write shape must either update these rules in lockstep or route through a Cloud Function.
- Existing `techProfiles` filenames without a UID prefix will remain in place and continue to be served via the preserved public read rule. Migration or renaming of legacy files is out of scope.
- `affectedKeys().hasOnly(...)` is the correct Firestore Rules primitive for constraining a diff to a whitelist, and `request.resource.data.diff(resource.data).affectedKeys()` correctly reports the set of fields whose values changed in an update.
- The Rules Playground in the Firebase Console is an acceptable verification surface for FR-011; an automated rules test suite is desirable but not required for this phase.
- Deployment is performed via `firebase deploy --only firestore:rules` and `firebase deploy --only storage`, in that order after the mobile release reaches its install base. No parallel or atomic deploy with functions is required in this phase (unlike Phase 5 of the migration plan, which does require atomic deploy).
- The migration plan (`WOOHOO/Migration_Implementation_Plan.md`, Phase 2) is the source of truth for the precise rule block locations and field lists; this spec intentionally paraphrases the plan in business-readable terms rather than duplicating its exact rule source.
