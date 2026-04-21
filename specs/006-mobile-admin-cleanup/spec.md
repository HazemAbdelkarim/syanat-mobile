# Feature Specification: Mobile Admin Cleanup

**Feature Branch**: `006-mobile-admin-cleanup`
**Created**: 2026-04-20
**Status**: Draft
**Input**: User description: "spec 006 based on the migration plan" — authored from `specs/006-mobile-admin-cleanup/INPUT.md` and `WOOHOO/Migration_Implementation_Plan.md` §Phase 8.

---

## Overview

Retire the in-mobile admin dashboard in two shipped mobile releases separated by a 7-day observation gate. By the end of this feature, the mobile binary contains zero admin UI, zero admin-only service methods, and zero admin-only imports. Admin users who sign in on mobile during the transition see a static redirect screen pointing at the web dashboard; after the observation gate passes, the redirect screen is removed and admin users fall through to the generic unauthorized path like any unrecognized role.

The web admin dashboard (already shipped as Specs 004 + 005) is the sole operator surface after this cleanup. This spec does not modify the web app — it is frozen for the duration of this work.

---

## Clarifications

### Session 2026-04-20

- Q: What does "admin falls through to the generic unauthorized path" mean for Release 2, given the current login-screen code routes every unrecognized role to the customer home? → A: Release 2 introduces a new shared `UnauthorizedScreen` stateless widget ("Your account is not available on this app"). Both `admin` and any unknown role route to it — not to the customer home.
- Q: Where does Release 1's "admin redirect shown" signal go? The mobile project has no `firebase_analytics` dependency today. → A: Release 1 adds `firebase_analytics` to `pubspec.yaml` and logs a single `admin_redirect_shown` event per redirect render, parameterized by a hashed/truncated UID. Operations reads the 7-day observation gate from the Firebase Analytics console filtered on that event name.
- Q: When a mobile admin sign-in occurs during the observation window, does the 7-day counter reset on a single event or only on sustained activity? → A: Any single `admin_redirect_shown` event resets the 7-day clock. An exception may be claimed in writing in the release log if Operations attests the event was a known test sign-in, with the hashed UID recorded verbatim; only then is the event disregarded for gating.
- Q: If Release 2 has to be rolled back, what state does it revert to? → A: The Release 1 commit. Admin users see the redirect screen again; the 15 service methods and three admin screen files are restored from that commit. Rolling back further (to the pre-Release-1 admin dashboard) is explicitly not a supported rollback path for Release 2.
- Q: What counts as "diverging" in Task 8-3's 3-file shared-code duplication threshold? → A: Schema/contract drift only. Two files count as "diverging" duplicates when they model the same logical entity but their field names, field types, or Firestore parse logic differ. Formatting, whitespace, comments, and trivial refactors are disregarded.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Admin Redirect on Mobile (Release 1) (Priority: P1)

An operator whose account has the `admin` role opens the mobile app expecting to reach their workflow. Because admin workflows have moved to the web dashboard, mobile must give them a clear, actionable signal: which URL to use and a one-tap way to copy it. This must happen on every admin sign-in during the transition window so that every admin is informed at least once before the mobile admin code is removed.

**Why this priority**: Without this redirect, admins who sign in after the mobile app ships without admin UI would experience a silent failure (no UI, no explanation). The redirect is the contract with admin users during the deprecation window and the signal source for the 7-day observation gate.

**Independent Test**: Ship mobile Release 1 to a device. Sign in with an admin account → the redirect screen renders with (a) a clear message stating admin access has moved to the web dashboard, (b) the full deployed web URL visible as selectable text, (c) a working "Copy URL" button that places the URL on the system clipboard and surfaces a confirmation. Sign in with customer and technician accounts → neither sees the redirect; both land on their normal home screens. No backend queries are issued to render the redirect screen (verifiable via Firebase console read counters).

**Acceptance Scenarios**:

1. **Given** Release 1 is installed and the signed-in user's role is `admin`, **When** the role-routing step completes, **Then** the admin redirect screen renders within 2 seconds and no Firestore reads or Cloud Functions calls are issued as a side effect.
2. **Given** the redirect screen is on-screen, **When** the operator taps the "Copy URL" button, **Then** the clipboard contains the exact deployed admin web URL and a confirmation message appears.
3. **Given** Release 1 is installed and the signed-in user's role is `customer` or `technician`, **When** sign-in completes, **Then** the user lands on their existing home flow and never sees the redirect screen.
4. **Given** an admin user signs in on mobile during Release 1, **When** the redirect screen renders, **Then** a single analytics event is recorded with a hashed or truncated user identifier (never the raw value), so Operations can count admin mobile sign-ins against the 7-day observation gate.

---

### User Story 2 — Admin Code Removal (Release 2) (Priority: P1)

After the 7-day observation gate confirms that admins have migrated to the web dashboard, the mobile binary is stripped of all admin-facing code: the redirect screen, the two admin screen files, and every admin-only method in the service layer. An admin who still signs in on mobile thereafter sees the same generic unauthorized message as any unrecognized role — no URL, no copy button, no hint that admin existed.

**Why this priority**: Leaving admin code in the mobile binary indefinitely keeps a privilege surface attached to a platform that is no longer authorised to reach it, inflates the binary, and leaks information about internal roles. Release 2 is the terminal state of the migration.

**Independent Test**: On the pre-deletion commit, record the APK size. Ship mobile Release 2. Sign in with an admin account → the generic unauthorized screen renders with no URL, no copy button, no admin hints. Code search the mobile project for each removed method name and each removed screen class name → zero matches in the application source tree. `flutter analyze` returns zero issues. `flutter build apk --release` and `flutter build ios --release` both succeed. The Release 2 APK is measurably smaller than the Release 1 APK.

**Acceptance Scenarios**:

1. **Given** Release 2 is installed and the signed-in user's role is `admin`, **When** the role-routing step completes, **Then** the user sees the same generic unauthorized screen as any user with an unrecognized role, with no reference to the web dashboard URL.
2. **Given** the Release 2 source tree, **When** the application code is scanned for each of the 15 named admin-only service methods and the admin screen class names, **Then** zero matches are found in the mobile project source.
3. **Given** the pre-deletion APK size and the Release 2 APK size are both captured on the same build machine and toolchain version, **When** they are compared, **Then** the Release 2 APK is smaller by a positive byte count recorded in the release notes.
4. **Given** Release 2 is being shipped, **When** the branch is prepared, **Then** the observation gate evidence (7 consecutive days of zero mobile admin sign-ins in the authentication logs) is attached to the release record and the release is refused if the evidence is missing.
5. **Given** Release 2 is shipped, **When** an Operations engineer checks the Firestore usage dashboard 7 days later, **Then** the counter document receives zero client writes during that window (all writes originate from backend event-driven triggers).

---

### User Story 3 — Customer and Technician Regression Safety (Priority: P1)

Neither release may disturb the customer or technician flows. Ordering, browsing, job acceptance, and job completion must continue to work bit-for-bit identically. No service method used by non-admin flows may be removed. No admin-removal change may require a customer or technician data migration.

**Why this priority**: Customer and technician flows are the revenue path. A regression here caused by admin cleanup would invalidate the entire migration value proposition and force an emergency rollback.

**Independent Test**: For each release, run the customer end-to-end flow (sign-in, browse, create an order, track status) and the technician end-to-end flow (sign-in, accept a requested job, progress it to completion, submit a receipt). Both must pass without any error or user-visible regression. `flutter analyze` returns zero issues.

**Acceptance Scenarios**:

1. **Given** Release 1 or Release 2 is installed, **When** a customer signs in and completes their end-to-end ordering flow, **Then** every step succeeds identically to the pre-release behavior.
2. **Given** Release 1 or Release 2 is installed, **When** a technician signs in and completes their end-to-end job-acceptance-to-completion flow, **Then** every step succeeds identically to the pre-release behavior.
3. **Given** the set of service methods being removed in Release 2, **When** the removal candidate list is validated, **Then** every method is confirmed to have zero non-admin callers in the mobile source; any method still referenced by a customer or technician flow is kept and documented in the plan's Complexity Tracking.

---

### User Story 4 — Two-Release Observation Gate (Priority: P2)

Operations needs a measurable, auditable signal that confirms admins have moved to the web dashboard before the mobile admin redirect screen is removed. The signal is 7 consecutive days of zero admin-role sign-ins from the mobile client, read from authentication logs or equivalent telemetry.

**Why this priority**: Without an enforced gate, the team risks shipping Release 2 before admins have been informed, leaving active admins unable to reach their workflow on their existing devices.

**Independent Test**: During Release 1 production, read the analytics event stream or authentication logs filtered to mobile + `role == 'admin'`. The gate passes when this filter returns zero events for 7 consecutive days. Document the query, the source, and the evidence file in the release checklist; the gate blocks Release 2 until all three are recorded.

**Acceptance Scenarios**:

1. **Given** Release 1 has been live for fewer than 7 days, **When** someone attempts to merge the Release 2 pull request, **Then** the observation-gate checklist item fails and merge is blocked.
2. **Given** Release 1 has been live for at least 7 consecutive days with zero admin-role mobile sign-ins, **When** the observation-gate checklist item is reviewed, **Then** the evidence source, query used, and zero-result window are recorded and the item passes.
3. **Given** a mobile admin sign-in event occurs during the observation window, **When** the observation-gate counter is reset, **Then** the 7-day window restarts from the day after the observed event — unless Operations records a written test-sign-in exception in the release log naming the hashed UID, in which case that specific event is disregarded and the clock is not reset.

---

### User Story 5 — Post-Migration Finalization (Priority: P3)

After Release 2 ships, the migration is closed out: a Cloud Monitoring alert watches backend error rate, the counter document is confirmed to receive zero client writes, the shared-code duplication threshold is evaluated (and either a follow-up spec is filed or the decision is deferred in writing), and the sign-off checklist is committed to the repository.

**Why this priority**: This story is the terminal state of the migration; skipping it leaves operational blind spots and no artifact of completion. It is P3 because none of its items gate the mobile releases — they follow Release 2.

**Independent Test**: After Release 2 has been live for 14 consecutive days, confirm: (a) Cloud Monitoring alert exists and would fire on backend error rate above 1% over a 5-minute window; (b) the counter document has received zero client writes for 7 consecutive days; (c) a written decision on the shared-code duplication threshold exists (either "defer" with reason or a filed follow-up spec); (d) the sign-off checklist is committed with every box checked and the pre- and post-deletion commit hashes recorded.

**Acceptance Scenarios**:

1. **Given** Release 2 has been live for 14 days, **When** the sign-off checklist is reviewed, **Then** every box is checked and the pre- and post-deletion commit hashes are recorded verbatim.
2. **Given** the Cloud Monitoring alert is in place, **When** the backend error rate exceeds 1% over a 5-minute window, **Then** the on-call is paged (validated via a controlled test firing during a maintenance window).
3. **Given** the shared-code duplication count between the mobile project and the web app is evaluated, **When** the count is 3 or more diverging duplicated model files, **Then** a follow-up spec is filed; otherwise a written "deferred" note is recorded in the plan's Complexity Tracking.

---

### Edge Cases

- **Admin role revoked mid-session**: An admin user who is signed in and viewing the redirect screen (Release 1) has their role revoked remotely. On the next token refresh they are signed out or re-routed like any other role — the redirect screen must not become a dead-end loop.
- **Admin sign-in attempt during Release 2**: An admin user who was not informed during the observation window signs in on mobile after Release 2 ships. They see the generic unauthorized screen and receive no URL. Operations must have an out-of-band channel (email, support contact) to direct them — the mobile app will not.
- **Offline sign-in**: A returning admin user on Release 1 signs in while offline. The redirect screen must still render because it performs no network calls; the "Copy URL" button must still work because the URL is compiled into the binary.
- **Service method still in use**: A removal candidate in Release 2 turns out to be referenced by a customer or technician flow. The removal is aborted for that method and the exception is documented in the plan's Complexity Tracking — the method stays in the binary and the rest of the cleanup proceeds.
- **Analytics event over-counted or under-counted**: The redirect-shown event is instrumented to fire exactly once per redirect render. Rapid sign-out/sign-in cycling by the same admin must still generate one event per redirect view, but not more (no duplicate firing from re-renders of the same screen).
- **A newly created admin account after Release 2**: A user is granted the `admin` role after Release 2 has shipped. They open the mobile app and see the generic unauthorized screen. They are onboarded to the web dashboard via the operations team's out-of-band channel.
- **Release 2 ships while admins are actively using the web dashboard**: The web dashboard is decoupled from the mobile binary; shipping Release 2 must not cause any observable change on the web side.

---

## Requirements *(mandatory)*

### Functional Requirements

**Release 1 — Admin redirect screen**

- **FR-001**: On Release 1, the mobile app MUST route any signed-in user whose role is `admin` to a static redirect screen instead of the admin dashboard.
- **FR-002**: The redirect screen MUST display a human-readable message stating admin access has moved to the web dashboard and MUST display the full deployed admin web URL as selectable text.
- **FR-003**: The redirect screen MUST provide a "Copy URL" action that writes the URL to the system clipboard and surfaces a confirmation to the user.
- **FR-004**: The redirect screen MUST perform zero backend reads and zero backend callable invocations as a side effect of rendering or of the copy action.
- **FR-005**: The admin web URL MUST be a compile-time constant defined inline in the redirect screen's source; it MUST NOT be fetched from a runtime configuration source or query string.
- **FR-006**: The redirect screen MUST render the URL using a plain selectable-text control; it MUST NOT render HTML, rich-text, or auto-linkified content.
- **FR-007**: On Release 1, the mobile app MUST emit a single `admin_redirect_shown` analytics event each time the redirect screen is shown to an admin user. The event's user identifier parameter MUST be hashed or truncated (no raw user identifier). The event MUST be routed through Firebase Analytics; Release 1 MUST add `firebase_analytics` to the mobile project's dependency manifest if it is not already present.
- **FR-008**: On Release 1, no admin-related logging statement in the mobile app MUST emit raw personal data (email, phone number, address). Debug-mode logging that redacts those fields is permitted; release-mode emission of the same is forbidden.
- **FR-009**: On Release 1, the two admin screen source files MUST remain on disk unmodified — Release 1 changes only the routing and adds the redirect screen source file.

**Release 2 — Admin code removal**

- **FR-010**: On Release 2, the mobile app MUST contain zero references to the admin dashboard screen, the admin support chat screen, and the redirect screen. Scanning the mobile project source for each class name MUST return zero matches.
- **FR-011**: On Release 2, the mobile app MUST remove the following admin-only service methods: `assignJob`, `adminCloseJob`, `adminResolveDispute`, `updatePaymentStatus`, `closeSupportChat`, `markSupportChatReadByAdmin`, `initializeStatsGlobal`, `streamActiveJobsAdmin`, `streamJobsByStatus`, `streamAllPayments`, `streamSupportChats`, `streamUnreadSupportCount`, `fetchRecentUsers`, `fetchRecentActivity`, `getAvailableTechnicianIdsByService`. Scanning the mobile project source for each method name MUST return zero matches.
- **FR-012**: Before any method is removed under FR-011, the implementer MUST confirm by source search that the method has zero non-admin callers in the mobile project. A method that is still referenced by a customer or technician flow MUST be kept and the exception MUST be documented in the plan's Complexity Tracking.
- **FR-013**: On Release 2, a signed-in user whose role is `admin` MUST land on a shared unauthorized screen that is also used by any role the login flow does not explicitly recognize. The unauthorized screen MUST be a static widget displaying a generic message of the form "Your account is not available on this app" and MUST NOT contain the admin web URL, a copy button, or any reference to the web dashboard.
- **FR-013a**: Release 2 MUST add the shared unauthorized screen as a new source file in the mobile project. The current login flow routes every role that is not `admin` or `technician` to the customer home screen; Release 2 MUST change that default so `admin` and any unknown role route to the new shared unauthorized screen, while `customer` explicitly (not by fallthrough) routes to the customer home.
- **FR-014**: On Release 2, the admin-routing branch in the login flow MUST be removed entirely; no code path may exist that previously routed role `admin` to a dedicated screen.
- **FR-015**: On Release 2, the mobile app MUST NOT emit the `admin_redirect_shown` analytics event; occurrences of that event in Firebase Analytics MUST drop to zero within 48 hours of Release 2 rollout.
- **FR-016**: Dependencies that become unused as a consequence of Release 2's removals MUST be dropped from the mobile project's dependency manifest. Dependencies that remain shared with customer or technician flows MUST NOT be dropped.

**Both releases — quality gates**

- **FR-017**: Both releases MUST pass the mobile project's static analysis (`flutter analyze`) with zero errors and zero warnings.
- **FR-018**: Both releases MUST produce a successful release build for both supported mobile platforms.
- **FR-019**: Both releases MUST pass a manual regression of the customer end-to-end flow and the technician end-to-end flow before store submission.

**Release safety and rollout**

- **FR-020**: Release 1 and Release 2 MUST ship as two separate pull requests, two separate store submissions, and two separate version-control tags. They MUST NOT be bundled.
- **FR-021**: The 7-day observation gate between Release 1 and Release 2 MUST be measured by the Firebase Analytics `admin_redirect_shown` event count: the gate passes when the daily count is zero for 7 consecutive days. Any single non-zero day resets the clock. Operations MAY record a written test-sign-in exception in the release log, naming the hashed UID from the event; only events whose hashed UIDs appear in the exception list are disregarded. Calendar time alone is not sufficient.
- **FR-022**: Release 2 MUST be preceded by a committed rollback plan (`ROLLBACK.md`) that records the Release 1 commit hash as the rollback target, the exact steps to revert Release 2 back to that commit, and a confirmation note — produced on a scratch branch — that the revert restores a working release-mode build on both supported platforms. The rollback target MUST be the Release 1 commit; rolling back to any earlier state (e.g., restoring the original `AdminDashboardScreen`) is explicitly not a supported path for Release 2.
- **FR-023**: The pre-deletion and post-deletion commit hashes MUST be recorded in Release 2's pull request description.
- **FR-024**: The Release 1 and Release 2 release-mode binary sizes MUST both be recorded (same build machine and toolchain version) so the reduction can be attested.
- **FR-025**: Neither release may skip version-control hooks, bypass commit signing, or force-push to a shared branch.

**Post-migration finalization**

- **FR-026**: After Release 2 ships, a Cloud Monitoring alert MUST exist on backend error rate that pages the on-call when the rate exceeds 1% over a 5-minute window.
- **FR-027**: After Release 2 ships, the counter document MUST receive zero client writes for 7 consecutive days, verified via the usage dashboard.
- **FR-028**: After Release 2 ships, the shared-code duplication threshold MUST be evaluated: if 3 or more model files are duplicated and diverging between the mobile project and the web app, a follow-up spec MUST be filed; otherwise a written "deferred" decision MUST be recorded. A file pair is counted as "diverging" only when it models the same logical entity but the two copies differ in at least one of: (a) field names, (b) field types, or (c) Firestore parse / serialization logic. Differences limited to formatting, whitespace, comments, or trivial refactors MUST NOT be counted.
- **FR-029**: The final sign-off checklist MUST be committed to the feature folder with every item checked, the pre- and post-deletion commit hashes recorded, and the binary size delta recorded. The migration is not declared complete until this file exists in the main branch.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On Release 1, 100% of admin sign-ins on mobile land on the redirect screen within 2 seconds of role-routing completion and surface the deployed admin web URL in copyable form.
- **SC-002**: On Release 1, rendering the redirect screen produces zero incremental backend reads and zero backend callable invocations (verified from console read/invocation counters over a representative test session).
- **SC-003**: On both releases, the customer end-to-end flow and the technician end-to-end flow pass regression without any user-visible change from the pre-release behavior.
- **SC-004**: On both releases, static analysis (`flutter analyze`) returns zero errors and zero warnings.
- **SC-005**: On both releases, the mobile project produces a successful release build for both supported platforms on the CI or on a clean local build.
- **SC-006**: The 7-day observation gate passes exactly once before Release 2 ships: 7 consecutive days with zero admin-role mobile sign-ins in authentication telemetry, with the query and evidence attached to the release record.
- **SC-007**: The analytics event emitted by the Release 1 redirect screen drops to zero occurrences within 48 hours of Release 2 rollout.
- **SC-008**: The Release 2 release-mode binary on the primary platform is smaller than the Release 1 release-mode binary by a positive byte count recorded in the release notes.
- **SC-009**: After Release 2, the counter document receives zero client writes for 7 consecutive days as verified in the usage dashboard.
- **SC-010**: After Release 2, the backend error rate remains below 1% over any rolling 5-minute window for 14 consecutive days; any breach pages the on-call within the same window.
- **SC-011**: A source-tree scan for each of the 15 named admin-only service methods and for the three admin-screen class names returns zero matches in the mobile project on the Release 2 commit.
- **SC-012**: The sign-off checklist file exists on the main branch with every item checked, pre- and post-deletion commit hashes recorded verbatim, and the binary size delta recorded.

---

## Assumptions

- The admin web dashboard is already shipped and stable in production per Specs 004 and 005. The 27-scenario operator smoke test on the web app has already passed on the production deploy. No changes to the web app are made in this spec.
- The deployed admin web URL is the Firebase Hosting site `syanat-admin` and its fully qualified URL is confirmed by the implementing engineer at Release 1 implementation time. The URL is hard-coded as a compile-time constant in the redirect screen's source and is never fetched at runtime.
- The mobile project currently contains an admin dashboard screen, an admin support chat screen, an admin role-routing branch in the login flow, and the 15 named admin-only service methods listed in FR-011. The line numbers cited in the brief are re-verified at implementation time rather than trusted blindly.
- The 7-day observation gate is measured by the `admin_redirect_shown` event count in Firebase Analytics (clarified 2026-04-20). The canonical query is: Firebase Analytics console → Events → filter `admin_redirect_shown` → daily count. The gate passes when that count is zero for 7 consecutive days. `firebase_analytics` is added to the mobile project in Release 1; no other authentication-log cross-reference is required.
- The two releases are scheduled with at least a 7-day observation window plus store-review time between them. The team has two available store submission slots spaced accordingly.
- English-only copy for the redirect screen is acceptable (matches the rest of the mobile app's current state). Localization is out of scope for this spec.
- The Cloud Monitoring alert already exists from earlier migration phases OR will be created as part of Task 8-3 post-Release-2. Either way, its configuration and a successful test firing are recorded before the migration is declared complete.
- No new cloud functions, no firestore rules changes, no storage rules changes, and no firestore index changes are introduced by this spec. The backend is frozen.
- The "generic unauthorized" screen does NOT yet exist in the mobile project — Release 2 introduces it as a new shared stateless widget used by `admin` and any unrecognized role (clarified 2026-04-20). The login flow's current default-to-customer-home behavior is changed so `customer` is routed explicitly; only explicitly-recognized roles reach their home screens.

---

## Out of Scope

- Any modification of the admin web app source tree (`.claude/AdminWebApp/`). If a bug is discovered, it is triaged to a follow-up spec.
- Any modification of backend cloud functions, firestore rules, firestore indexes, or storage rules.
- Any new admin feature, bulk action, export, or service-catalog management on either mobile or web.
- Shared-package extraction (e.g., a `shared_core` package) unless the 3-file duplication threshold is crossed during Task 8-3 evaluation.
- Refactoring or renaming of non-admin methods in the mobile service layer. Only admin-only methods are removed; everything else stays bit-for-bit identical.
- Non-essential dependency upgrades. Dependencies are only dropped if a removal strictly orphans them.
- Localization of the redirect screen copy.
- Migrating the admin web app source tree into its own repository. That is a one-time post-Spec-006 operation prepared by the standalone artifacts already in `.claude/AdminWebApp/` (`firebase.json`, `.firebaserc`) but executed outside any spec.

---

## Dependencies

- Spec 001 (hardened firestore rules) — shipped.
- Spec 002 (admin cloud functions in `europe-west1`) — shipped and used by the web app.
- Spec 003 (event-driven counter triggers) — shipped; the counter document's sole writer is the backend.
- Spec 004 (admin web shell) — shipped.
- Spec 005 (admin web feature screens) — shipped; 27-scenario operator smoke test passed; production deploy stable for at least 7 consecutive days before Release 1 of this spec ships.

---

## Risks

| # | Risk | Mitigation it must build in |
|---|------|-----------------------------|
| 1 | A removal candidate turns out to be called by a non-admin flow → Release 2 build breaks | FR-012: every removal confirmed by source scan before deletion; any surviving non-admin caller documented in Complexity Tracking and the method kept. |
| 2 | Release 2 ships before the 7-day observation gate passes | FR-020 two-release rule + FR-021 measurable telemetry gate, enforced by a blocking checklist item. |
| 3 | An admin signs in on mobile during the observation window and is confused by the redirect | FR-002 clear copy, FR-003 working copy action, FR-007 analytics event gives Operations a signal to follow up out-of-band. |
| 4 | Binary size reduction not measured → sign-off cannot be closed | FR-024 explicit measurement requirement with same build machine and toolchain version; SC-008 positive-byte-count assertion. |
| 5 | The counter document keeps receiving client writes after Release 2 | FR-027 7-day verification window + SC-009 zero writes outcome; any observed write triggers a follow-up spec to find the remaining client source. |
| 6 | The two releases are bundled into one pull request | FR-020 explicit two-pull-request rule; the implementer refuses to add Release 2 changes to the Release 1 branch. |
| 7 | Rollback of Release 2 is unclear or untested | FR-022 committed rollback plan including a revert-smoke-test confirmation. |
| 8 | Admin role revoked mid-session causes a stuck redirect loop | Edge case documented; the existing auth-state change path already handles role revocation — this spec must not break it. |
