# Feature Specification: Event-Driven Stats

**Feature Branch**: `003-event-driven-stats`  
**Created**: 2026-04-16  
**Status**: Draft  
**Input**: User description: "Event-driven stats Cloud Functions that replace all client-side stats writes to stats/global with server-side Firestore triggers, then lock down the collection rule to allow write: if false"

## User Scenarios & Testing

### User Story 1 — Server-Side User Counter (Priority: P1) 🎯 MVP

When a new user signs up (customer or technician), the system automatically increments the correct counters in `stats/global` without any client-side stats write. The mobile app no longer writes to `stats/global` on signup — the server handles it.

**Why this priority**: User creation is the simplest trigger (onCreate, no previous-state diffing) and exercises the entire pipeline: trigger fires, Admin SDK writes `stats/global`. If this works, the pattern is proven for the more complex job triggers.

**Independent Test**: Create a user document in the emulator with `role: 'customer'`. Within seconds, `stats/global.totalUsers` increments by 1 and `stats/global.customers` increments by 1. Creating a user with `role: 'technician'` increments `totalUsers` and `technicians` instead. Creating a user with an unrecognized role increments only `totalUsers`.

**Acceptance Scenarios**:

1. **Given** `stats/global` exists with `totalUsers: 10, customers: 7`, **When** a new user doc is created with `role: 'customer'`, **Then** `stats/global` reads `totalUsers: 11, customers: 8` and no other counter changes.
2. **Given** `stats/global` exists with `totalUsers: 10, technicians: 3`, **When** a new user doc is created with `role: 'technician'`, **Then** `stats/global` reads `totalUsers: 11, technicians: 4`.
3. **Given** `stats/global` exists with `totalUsers: 10`, **When** a new user doc is created with `role: 'admin'` (or any non-customer, non-technician role), **Then** `stats/global.totalUsers` increments to 11 but `customers` and `technicians` are unchanged.
4. **Given** the `stats/global` document does not yet exist, **When** a new user doc is created, **Then** the function creates `stats/global` via a merge-write (increment on a missing doc initializes the field to the increment value).

---

### User Story 2 — Server-Side Job Status Counters (Priority: P1)

When a job transitions from one status to another, the system automatically decrements the counter for the old status bucket and increments the counter for the new status bucket in `stats/global`. No client-side stats write is needed.

**Why this priority**: Job status transitions are the highest-volume stats event. Most of the `stats/global` fields relate to jobs. This story eliminates the majority of client stats writes.

**Independent Test**: Seed a job with `status: 'requested'`. Update it to `status: 'active'`. Verify `stats/global.jobsRequested` decremented by 1 and `stats/global.jobsOngoing` incremented by 1. Then update to `status: 'completed'` with `amountPaid: 200`. Verify `jobsOngoing` decremented, `jobsCompleted` incremented, and `totalEarnings` increased by 200.

**Acceptance Scenarios**:

1. **Given** a job with `status: 'requested'`, **When** status changes to `'active'`, **Then** `jobsRequested` decrements by 1 and `jobsOngoing` increments by 1.
2. **Given** a job with `status: 'active'`, **When** status changes to `'completed'` and `amountPaid` is `150`, **Then** `jobsOngoing` decrements by 1, `jobsCompleted` increments by 1, and `totalEarnings` increments by 150.
3. **Given** a job with `status: 'active'`, **When** status changes to `'cancelled'`, **Then** `jobsOngoing` decrements by 1 and `jobsCancelled` increments by 1.
4. **Given** a job update where `status` did not change (e.g., only `notes` was edited), **When** the trigger fires, **Then** the function returns early with no stats write (no-op guard).
5. **Given** a job transitioning from `'active'` to `'completed'` with `amountPaid: 0`, **Then** counters update normally but `totalEarnings` does not change (zero-amount case).
6. **Given** a job transitioning from `'active'` to `'completed'` with no `amountPaid` field, **Then** counters update normally and `totalEarnings` is not touched.
7. **Given** a job with `status: 'awaiting_customer_approval'` (an intermediate ongoing status), **When** status changes to `'completed'`, **Then** `jobsOngoing` decrements by 1 and `jobsCompleted` increments by 1 — intermediate ongoing statuses all map to the `jobsOngoing` bucket.

---

### User Story 3 — Server-Side New Job Counter (Priority: P1)

When a new job document is created (always in `requested` status), the system automatically increments `stats/global.jobsRequested` by 1. This covers the job-creation case that the update trigger (US2) cannot handle.

**Why this priority**: Without this, newly requested jobs would not be counted — the `onJobStatusChanged` trigger only fires on updates, not creates. This is the gap that would leave `jobsRequested` permanently undercounted.

**Independent Test**: Create a new job document with `status: 'requested'` in the emulator. Verify `stats/global.jobsRequested` increments by 1 with no other counter changes.

**Acceptance Scenarios**:

1. **Given** `stats/global` exists with `jobsRequested: 5`, **When** a new job doc is created with `status: 'requested'`, **Then** `stats/global.jobsRequested` reads 6.
2. **Given** a new job doc is created with a status other than `'requested'` (abnormal but possible), **When** the trigger fires, **Then** the appropriate counter for that status is incremented by 1.

---

### User Story 4 — Lock Down Client Stats Writes (Priority: P1)

After the event-driven functions are deployed, the Firestore security rule for `stats/{docId}` is changed to `allow write: if false` so that no client can write to the stats collection. Only the server-side Admin SDK (which bypasses rules) can update stats.

**Why this priority**: Without this lockdown, stats could be double-counted — once by the trigger and once by the client. This MUST ship atomically with the triggers to prevent a window where both paths are active.

**Independent Test**: After deploy, attempt a direct client-side write to `stats/global` using a signed-in user (admin or non-admin). The write MUST be denied.

**Acceptance Scenarios**:

1. **Given** the updated rules are deployed, **When** a signed-in non-admin user attempts to write to `stats/global`, **Then** the write is denied.
2. **Given** the updated rules are deployed, **When** a signed-in admin user attempts to write to `stats/global` directly via client SDK, **Then** the write is denied.
3. **Given** the updated rules are deployed, **When** any signed-in user reads `stats/global`, **Then** the read succeeds (read rule unchanged).
4. **Given** the Cloud Functions use the Admin SDK, **When** any trigger writes to `stats/global`, **Then** the write succeeds (Admin SDK bypasses security rules).

---

### User Story 5 — Remove Client-Side Stats Writes from Mobile App (Priority: P1)

All existing client-side code that writes to `stats/global` is removed from the mobile app. This eliminates the double-counting risk and reduces the mobile app's Firestore write volume.

**Why this priority**: Leaving the client writes in place after the triggers are live would cause failed writes (due to the rule lockdown). While the mobile code wraps these in try/catch (making failures silent), dead code should be removed for clarity.

**Independent Test**: After removal, grep the mobile codebase for `stats/global` — zero incremental write references should remain. `initializeStatsGlobal()` may remain as an admin bootstrap tool. The mobile app should still function correctly for all job and payment flows.

**Acceptance Scenarios**:

1. **Given** all client stats writes are removed, **When** a user signs up, **Then** no `stats/global` write is attempted by the mobile client.
2. **Given** all client stats writes are removed, **When** a job is assigned, closed, or cancelled, **Then** no `stats/global` write is attempted by the mobile client.
3. **Given** all client stats writes are removed, **When** `addEarnings()` is called, **Then** no `stats/global` write occurs from the client. Earnings update via the job completion trigger.
4. **Given** `initializeStatsGlobal()` still exists, **When** an admin calls it, **Then** it still works as an admin bootstrap tool (this will be migrated to the admin web app in a later spec).

---

### Edge Cases

- **Rapid successive status changes**: A job goes `requested → active → completed` in quick succession. Each trigger invocation is independent and uses atomic increments, so they do not conflict.
- **Stats document missing**: Atomic increment on a non-existent document with merge-write creates the document and initializes the field to the increment value. No special handling needed.
- **Replay / retry of trigger**: Cloud Functions may retry on transient failure. Since increments are not idempotent by nature, the function must deduplicate using the event ID to prevent double-counting.
- **`amountPaid` is negative or non-numeric**: The function must guard against corrupted data. If `amountPaid` is not a positive finite number on a `completed` transition, `totalEarnings` should not be updated.
- **Status value not in the known mapping**: If a job transitions to an unknown status, the function logs a warning and skips the stats update rather than throwing an error.
- **Old mobile app versions**: After the rule lockdown, old app versions still running the removed stats-write code will get silent failures (already wrapped in try/catch). This is harmless — the triggers handle stats correctly regardless.
- **`activeChats` counter**: No chat-status trigger is included in this spec. `activeChats` will go stale after the rule lockdown. This is an accepted trade-off until a future spec adds a chat trigger.

## Requirements

### Functional Requirements

- **FR-001**: The system MUST implement an `onUserCreated` Firestore trigger that fires on `users/{uid}` document creation and increments `stats/global.totalUsers` by 1, plus `customers` or `technicians` by 1 based on the `role` field.
- **FR-002**: The system MUST implement an `onJobStatusChanged` Firestore trigger that fires on `jobs/{jobId}` document updates and adjusts `stats/global` counters by decrementing the old status bucket and incrementing the new status bucket, using the status-to-bucket mapping defined in Key Entities.
- **FR-003**: The system MUST implement an `onJobCreated` Firestore trigger that fires on `jobs/{jobId}` document creation and increments the counter for the job's initial status (typically `jobsRequested`).
- **FR-004**: When a job transitions to `completed` status and the document contains a positive finite `amountPaid` value, the `onJobStatusChanged` trigger MUST additionally increment `stats/global.totalEarnings` by that amount.
- **FR-005**: All three triggers MUST run in the `europe-west1` region, matching the Spec 002 admin callables.
- **FR-006**: The Firestore security rule for `stats/{docId}` MUST be changed to `allow write: if false`, blocking all direct client writes. The read rule (`allow read: if isSignedIn()`) MUST remain unchanged.
- **FR-007**: Each trigger MUST be idempotent to handle Cloud Functions retry behavior. The function MUST use an event-ID-based deduplication mechanism to prevent double-counting on retry.
- **FR-008**: All client-side `stats/global` write locations in the mobile app MUST be removed. The `initializeStatsGlobal()` method MAY remain as an admin bootstrap tool.
- **FR-009**: The `onJobStatusChanged` trigger MUST include a no-op guard: if the `status` field did not change between the before/after snapshots, the function returns immediately without any stats write.
- **FR-010**: The rules change (FR-006) and function deployment (FR-001 through FR-005) MUST be deployed in a single atomic deploy command to prevent a double-counting window.
- **FR-011**: All three triggers MUST be covered by automated tests running against the Firebase emulator, following the same test harness pattern established in Spec 002.
- **FR-012**: The trigger functions MUST NOT import or depend on any admin callable module. They live in `functions/src/stats/` and share only the Admin SDK initialization.
- **FR-013**: If a status value is not present in the known mapping, the trigger MUST log a warning (including the job ID and unknown status) and return without modifying stats. It MUST NOT throw an error.

### Key Entities

- **`stats/global`**: Single Firestore document holding aggregate counters. Fields: `totalUsers`, `customers`, `technicians`, `jobsRequested`, `jobsOngoing`, `jobsCompleted`, `jobsCancelled`, `totalEarnings`, `activeChats`. All fields are numeric. Updated exclusively by server-side triggers after this spec ships.
- **`users/{uid}`**: User documents whose creation triggers `onUserCreated`. Key field: `role` (`'customer'` | `'technician'` | other).
- **`jobs/{jobId}`**: Job documents. Creation triggers `onJobCreated`; status updates trigger `onJobStatusChanged`. Key fields: `status` (string), `amountPaid` (number, optional).
- **Status-to-bucket mapping**: `requested → jobsRequested`; `active`, `technician_accepted`, `technician_arrived`, `work_finished`, `awaiting_customer_approval`, `receipt_disputed` → `jobsOngoing`; `completed → jobsCompleted`; `cancelled → jobsCancelled`.

## Success Criteria

### Measurable Outcomes

- **SC-001**: After deployment, zero client-side writes to `stats/global` occur — verified by observing zero rule denials on the stats collection over a 72-hour window (old clients) and zero stats-write code paths in the updated mobile app.
- **SC-002**: Counter accuracy for users: after creating 5 test users (3 customers, 2 technicians), `stats/global` reflects exactly `+5 totalUsers`, `+3 customers`, `+2 technicians` with no manual correction.
- **SC-003**: Counter accuracy for jobs: after running 3 complete job lifecycle transitions in the emulator, all counter fields match expected values within 5 seconds of each transition.
- **SC-004**: The `totalEarnings` field increases by exactly the `amountPaid` value on each job completion — verified across test completions with different amounts including zero.
- **SC-005**: A direct client write to `stats/global` from any authenticated user (including admins) is denied by security rules.
- **SC-006**: Trigger idempotency: replaying the same event does not produce duplicate counter increments — verified by the automated test suite.
- **SC-007**: All automated tests pass with zero failures before deploy.
- **SC-008**: The deploy is a single atomic command covering both functions and rules.

## Assumptions

- **Spec 002 is code-complete**: The `functions/` project scaffold, Admin SDK initialization in `index.ts`, the `stats/index.ts` stub, and the test harness all exist from Spec 002.
- **Spec 002 deploy is deferred**: Spec 002's production deploy is blocked on Blaze plan upgrade. Spec 003 code will be written and tested locally via emulator. Both specs will deploy together when Blaze is enabled.
- **`stats/global` document exists in production**: It was seeded by `initializeStatsGlobal()`. If it doesn't exist, atomic increment with merge-write will create it, but initial values will start from the increment rather than from the true aggregate.
- **`activeChats` counter is out of scope**: No chat-status trigger is defined in this spec. `activeChats` will go stale after the rule lockdown. This is an accepted trade-off; a future spec will add a chat trigger.
- **Mobile app release coordination**: Removing client stats writes requires a mobile app update. Until all users update, old app versions will silently fail on stats writes (already wrapped in try/catch). The triggers handle stats correctly regardless of client version.
- **The `.claude/AdminWebApp` folder is the designated location for admin web code** (per user override). This spec does not create any files there.
