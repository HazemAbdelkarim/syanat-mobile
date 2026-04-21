---

description: "Task list for Mobile Admin Cleanup (Spec 006, Migration Plan Phase 8)"
---

# Tasks: Mobile Admin Cleanup

**Input**: Design documents from `/specs/006-mobile-admin-cleanup/`
**Prerequisites**: plan.md (✓), spec.md (✓), research.md (✓), data-model.md (✓), contracts/README.md (✓), quickstart.md (✓)

**Tests**: No automated test tasks are generated. The spec does not request automated tests; the existing root project has no `test/` suite and this deletion-scoped spec does not introduce one. Quality gates are `flutter analyze`, release-mode builds on both platforms, and **manual** end-to-end regression for customer and technician flows before each store submission (per FR-017, FR-018, FR-019).

**Organization**: Tasks are grouped by user story. The story sequence is **sequentially gated** — Release 1 (US1 + first US3 cut) ships first; the observation gate (US4) blocks Release 2 (US2 + second US3 cut) until it passes; US5 finalizes after Release 2. The MVP is US1 + US3-R1 + US4 (everything needed to ship Release 1 and enter the observation window). Full delivery is US1 → US3-R1 → US4 → US2 → US3-R2 → US5.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel with other [P] tasks in the same phase (different files, no shared dependency).
- **[Story]**: `[US1]`–`[US5]` maps each task to its user story. Setup, Foundational, and Polish tasks carry no story label.
- File paths are absolute to the repo root (e.g., `lib/...`, `specs/006-mobile-admin-cleanup/...`).

## Path Conventions

- **Mobile app**: `lib/` at repo root (the only source tree this spec modifies).
- **Feature docs**: `specs/006-mobile-admin-cleanup/`.
- **Frozen (MUST NOT be touched)**: `.claude/AdminWebApp/`, `functions/`, `firestore.rules`, `firestore.indexes.json`, `storage.rules`.

---

## Phase 1: Setup (Shared Prerequisites)

**Purpose**: Confirm external preconditions and verify the working branch state before any code change.

- [ ] T001 Confirm Spec 005 has been live in production for ≥7 consecutive days with no open incident and the 27-scenario admin-web operator smoke test recorded as passed; attach evidence link to Release 1 PR draft.
- [ ] T002 [P] Confirm two mobile store-submission slots are reserved ≥7 calendar days apart (Play + App Store), accounting for expected review time; record slots in the Release 1 PR description.
- [ ] T003 [P] Verify the fully qualified deployed admin web URL by opening the Firebase Hosting console for project `syana-ea75a`, site `syanat-admin`; record the exact URL string (expected default: `https://syanat-admin.web.app`) in a scratch note to be copied verbatim into `lib/admin_redirect_screen.dart`.
- [ ] T004 Confirm the current git branch is `006-mobile-admin-cleanup` and it is up-to-date with `origin/main`; if not, rebase or merge from `main` before proceeding.

---

## Phase 2: Foundational (Pre-verification Baselines)

**Purpose**: Read-first verifications required by Principle III before any deletion. MUST complete before any user story phase starts.

**⚠️ CRITICAL**: No US1 or US2 implementation work begins until Phase 2 is complete.

- [ ] T005 Run the canonical deletion grep (research.md R6) from repo root against `lib/` and record the output verbatim in this spec folder's `research.md` R6 pre-verification note; expected output: the 15 method names appear only in `lib/firebase_service.dart`, `lib/admin_dashboard_screen.dart`, and `lib/admin_support_chat_screen.dart` — no customer or technician file matches. Any additional match triggers a Complexity Tracking entry in `plan.md` and aborts the deletion of that specific method (FR-012).
- [ ] T006 [P] Record pre-Release-1 baseline APK size by running `flutter build apk --release` from repo root on the current branch HEAD and recording the byte count; save the number in the Release 1 PR description (for SC-008 comparison later).
- [ ] T007 [P] Record pre-Release-1 baseline iOS IPA size (or framework archive size on macOS build host) and save alongside the APK size.
- [ ] T008 [P] Capture the current `_routeByRole` function in `lib/login_screen.dart` (lines 46–57 as of 2026-04-20) as a verbatim snippet in the Release 1 PR description, so reviewers can see the before/after delta clearly.

**Checkpoint**: Baselines recorded. US1 implementation can begin.

---

## Phase 3: User Story 1 - Admin Redirect on Mobile (Release 1) (Priority: P1) 🎯 MVP

**Goal**: Ship a mobile release that routes every signed-in `admin` user to a static redirect screen pointing at the web dashboard, emits a single `admin_redirect_shown` analytics event per render with a hashed UID, and leaves the 15 admin service methods + 2 admin screen files on disk (they are deleted in Release 2, not here).

**Independent Test**: Sideload/install the Release 1 build on a device; sign in as an admin account → redirect screen renders within 2 seconds with the full web URL as selectable text and a working "Copy URL" button; sign in as customer and technician → neither sees the redirect and both reach their normal home screens; the Firebase Analytics console shows exactly one `admin_redirect_shown` event per admin redirect render with a `uid_hash` parameter (no raw UID visible anywhere); zero incremental Firestore reads or Cloud Functions invocations recorded while the redirect screen is on-screen.

### Implementation for User Story 1

- [ ] T009 [US1] Resolve the `firebase_analytics` version compatible with the pinned `firebase_core ^3.1.1` by running `flutter pub outdated firebase_analytics` from repo root; record the resolved caret version (e.g., `^11.x.y`) in `pubspec.yaml`.
- [ ] T010 [US1] Add `firebase_analytics: ^<resolved version>` under `dependencies:` in `pubspec.yaml`, preserving the existing dependency order (insert after `firebase_app_check`); run `flutter pub get` and confirm the lockfile resolves without error.
- [ ] T011 [US1] Create `lib/admin_redirect_screen.dart` as a `StatefulWidget` named `AdminRedirectScreen`. Its `State` class holds `bool _eventEmitted = false`. In `initState()`: call `super.initState()`, guard on `!_eventEmitted`, compute `uidHash = sha256.convert(utf8.encode(FirebaseAuth.instance.currentUser!.uid)).toString().substring(0, 12)` using the existing `crypto` package, set `_eventEmitted = true`, then call `FirebaseAnalytics.instance.logEvent(name: 'admin_redirect_shown', parameters: {'uid_hash': uidHash})`. The file MUST NOT import `cloud_firestore` or `cloud_functions`.
- [ ] T012 [US1] In `lib/admin_redirect_screen.dart`, implement `build()` to render a centered column containing: a title (localized English/Arabic per the existing app pattern), a static message stating admin access has moved to the web dashboard, a `SelectableText` displaying the full admin web URL from a `const String adminWebUrl = '...'` declared at file top (value from T003), and a `TextButton` labeled "Copy URL" / "نسخ الرابط" whose `onPressed` calls `Clipboard.setData(ClipboardData(text: adminWebUrl))` and shows a `SnackBar` confirming the copy.
- [ ] T013 [US1] Modify `lib/login_screen.dart` `_routeByRole` (around line 49): change `dest = const AdminDashboardScreen();` to `dest = const AdminRedirectScreen();`. Update imports: keep the existing import of `admin_dashboard_screen.dart` only if something else in the file uses it (it does not); remove that line and add `import 'admin_redirect_screen.dart';`. Leave the `else` fallthrough to `UserHomeScreen` UNCHANGED in Release 1 (it is rewritten in Release 2 under US2).
- [ ] T014 [US1] Run `flutter analyze` from repo root; fix any new errors or warnings until the output is `No issues found!` (per FR-017). Run `flutter pub run dart_code_metrics:metrics analyze lib/admin_redirect_screen.dart` IF (and only if) the project already uses metrics — do not introduce new tooling.
- [ ] T015 [US1] Run `flutter build apk --release` from repo root; confirm build success and record the Release 1 APK byte count (for SC-008 comparison in Release 2).
- [ ] T016 [US1] Run `flutter build ios --release` on a macOS build host (or document a teammate's verified run); confirm build success.
- [ ] T017 [US1] Install the Release 1 build on a physical device; sign in with an admin test account; verify: (a) redirect screen renders within 2 seconds, (b) `SelectableText` shows the exact URL, (c) "Copy URL" writes to clipboard and a confirmation SnackBar appears, (d) Firebase Analytics console (Realtime → Events) shows exactly one `admin_redirect_shown` event with parameter `uid_hash` matching the first 12 hex chars of SHA-256 of the test account's UID. Screenshot each verification step into the Release 1 PR description.
- [ ] T017b [US1] Manual edge-case scenario test — admin role revoked mid-session (covers spec.md §Edge Cases "admin role revoked mid-session" / analyze C4). While the Release 1 redirect screen is rendered to a signed-in admin test account on a physical device, open the Firebase console → Firestore → `users/{uid}` for that same test account and edit the `role` field from `admin` to `customer` (or delete the document). Without force-killing the app, trigger the next user action (e.g., tap "Copy URL" once, then background and foreground the app, or cold-restart). Verify the app does NOT enter a stuck/dead-end loop: either the redirect screen persists because cached auth state remains, or on the next sign-in attempt the user is routed per the updated role. Record the observed transition (step-by-step screenshots) in the Release 1 PR description; if a dead-end is observed, STOP and file a defect before proceeding to T018.
- [ ] T018 [US1] Install the Release 1 build on a device, enable airplane mode, sign in from a cached session as an admin; verify the redirect screen renders and "Copy URL" still works offline (URL is a compile-time constant per FR-005). Re-enable networking after a few minutes; confirm the buffered `admin_redirect_shown` event flushes to Firebase Analytics.
- [ ] T019 [US1] Verify zero Firebase side-effects while the redirect screen is rendered: open Firebase console → Firestore → Usage, note the reads counter; keep the redirect screen on-screen for 60 seconds without interaction; confirm the reads counter has not advanced. Open Cloud Functions → Logs; confirm no callable invocation was logged by the admin test session while the screen was visible (per FR-004, SC-002).
- [ ] T019b [US1] Release-mode log audit for PII (FR-007, FR-008 / analyze C1). From repo root, run `rg -n --type dart '(print|debugPrint|developer\.log|log)\s*\(' lib/admin_redirect_screen.dart lib/login_screen.dart lib/firebase_service.dart` plus a broader sweep `rg -n --type dart '(print|debugPrint)\s*\(.*(uid|email|phone|displayName|ClipboardData|currentUser)' lib/`. For each hit, confirm the statement is either (a) removed entirely, (b) guarded by `if (kDebugMode)` / `assert()` so it is tree-shaken out of release builds, or (c) emits only the SHA-256 first-12-hex `uid_hash` (never the raw UID, email, or phone). Also confirm the Release 1 APK built in T015 contains no PII log strings by running `strings build/app/outputs/flutter-apk/app-release.apk | rg -i '(email|phone|displayName|uid:)'` and verifying no user-identifier format strings leak. Paste the grep outputs (with zero offenders) into the Release 1 PR description.

**Checkpoint**: User Story 1 is internally verified. It is NOT shipped yet — the regression safety phase (US3 cut for Release 1) MUST pass before Release 1 can be submitted.

---

## Phase 4: User Story 3 - Customer & Technician Regression Safety (Release 1 cut) (Priority: P1)

**Goal**: Confirm Release 1 has not disturbed the customer or technician flows in any way. This is the FR-019 / SC-003 gate for Release 1 and MUST pass before the Release 1 PR is merged.

**Independent Test**: Manual end-to-end exercise of each non-admin flow on the Release 1 build; every step matches pre-release behavior exactly.

### Implementation for User Story 3 (Release 1 cut)

- [ ] T020 [US3] Install the Release 1 build on a device; sign in as a customer test account and complete the full end-to-end ordering flow: sign-in → browse catalog → create an order → reach the confirmation/tracking screen. Confirm every step succeeds identically to pre-release behavior and no error snackbar or dialog appears. Record step-by-step screenshots in the Release 1 PR description.
- [ ] T021 [US3] Install the Release 1 build on a device; sign in as a technician test account and complete the full end-to-end job flow: sign-in → view requested jobs → accept one → progress it through the receipt/approval steps → submit it to completion. Confirm every step succeeds identically to pre-release behavior. Record step-by-step screenshots in the Release 1 PR description.
- [ ] T022 [US3] Confirm `flutter analyze` output from T014 is still `No issues found!` on the final Release 1 commit (re-run if any code changed after T014); record the clean output in the PR description.
- [ ] T023 [US3] Open the Release 1 pull request against `main` as its OWN PR — it MUST NOT contain any Release 2 changes (no deletions, no `UnauthorizedScreen`, no ROLLBACK.md). PR description MUST include: pre-Release-1 APK/IPA sizes (from T006/T007), Release 1 APK/IPA sizes (from T015/T016), admin scenario screenshots (T017/T017b/T018), customer regression screenshots (T020), technician regression screenshots (T021), zero-backend-side-effect evidence (T019), release-mode log-audit grep output (T019b), resolved `firebase_analytics` version, and a link to Spec 005's 7-day stability evidence (T001).
- [ ] T023b [US3] Version-control hygiene verification (FR-025 / analyze C2) — executed ONCE before T024 for Release 1, then AGAIN before T049 for Release 2 (same task, re-run with the R2 branch/tag as argument). From repo root, on the PR branch with `origin/main` up-to-date, run the three checks: (a) `git log --show-signature origin/main..HEAD` — every commit MUST show a valid signature line (`Good signature from ...`); any `gpg: Can't check signature` or unsigned commit is a FAIL and MUST be re-signed (via `git rebase --exec 'git commit --amend --no-edit -S'` or equivalent) before the PR is merged; (b) inspect each commit message and its diff for evidence of skipped hooks — if the repo's pre-commit hook runs `dart format` / `flutter analyze`, any commit that contains unformatted Dart or analyze-introducible issues indicates `--no-verify` was used and MUST be re-committed with hooks run; (c) run `git reflog show origin/main` and `git reflog show <release-tag>` (after T024 / T049) — confirm no force-push occurred to `main` or to the release tag between branch-point and merge (no entries of the form `forced-update`). Paste the three check outcomes (all PASS) into the release PR description; a FAIL on any check BLOCKS the tag creation in T024 / T049.
- [ ] T024 [US3] After Release 1 PR review + merge AND T023b verification PASS, create an annotated version-control tag on the merge commit (e.g., `v1.1.0-R1-mobile-admin-redirect`) and record the commit hash in `specs/006-mobile-admin-cleanup/plan.md`'s Complexity Tracking (so Release 2's rollback target is unambiguous per FR-022).
- [ ] T025 [US3] Submit the Release 1 build to Google Play and to the App Store as two separate submissions. Do not submit to only one store — FR-020 requires both platforms ship Release 1 before the observation clock is considered to start on a rollout-wide basis. Record submission IDs and expected review windows.

**Checkpoint**: Release 1 is shipped to both stores and its tag is on `main`. The observation window starts the day Release 1 is generally available on the later-of-two stores.

---

## Phase 5: User Story 4 - Two-Release Observation Gate (Priority: P2, BLOCKING)

**Goal**: Prove by Firebase Analytics that admin mobile sign-ins have dropped to zero for 7 consecutive days before any Release 2 implementation work starts.

**Independent Test**: On day 7 of the observation window, open the Firebase Analytics console filtered on event `admin_redirect_shown`; confirm the daily count is zero for each of the 7 preceding 24-hour (UTC) windows; any non-zero day must have a matching written test-sign-in exception with the hashed UID recorded in the release log, or the clock resets.

### Implementation for User Story 4

- [ ] T026 [US4] Record the exact timestamp (UTC) when Release 1 became generally available on the later-of-two stores (Play or App Store); this is Day 0 of the observation window. Log it in `specs/006-mobile-admin-cleanup/plan.md` under a new "Observation Window" note.
- [ ] T027 [US4] Each day of the observation window, read the Firebase Analytics console → Events → filter event name `admin_redirect_shown` → daily count. Post the day-by-day count to the team's shared release channel. Format: `Day N: count=X, any exceptions: [yes/no]`.
- [ ] T028 [US4] If any day's count is non-zero, inspect the event's `uid_hash` parameter; compare against the team's expected test-account hashed UID list. If the hash matches a known test sign-in, record a written exception in the release log citing: date, hashed UID (verbatim), engineer name, and reason ("known test sign-in for <purpose>"); only these events are disregarded for gating purposes. If the hash does NOT match a known test sign-in, reset the observation clock to Day 0 on the day following that event.
- [ ] T029 [US4] When 7 consecutive 24-hour windows have zero unexplained events, record the gate PASS evidence in the Release 2 PR draft: the exact query (`event_name == 'admin_redirect_shown'`, scope: last 7 days), a screenshot of the 7-day zero-count view, the full list of any recorded test-sign-in exceptions (hashed UID + engineer + date). Gate passes only when all three are attached (FR-021).
- [ ] T030 [US4] BLOCKING: explicitly confirm in the Release 2 PR checklist "Observation gate passed on <date>; evidence attached". Release 2 implementation (Phase 6 onward) MUST NOT start before this task is complete. If the gate has not yet passed by the planned Release 2 start date, Release 2 is postponed and Phase 6 is delayed.

**Checkpoint**: Observation gate has passed with recorded evidence. Release 2 implementation can begin.

---

## Phase 6: User Story 2 - Admin Code Removal (Release 2) (Priority: P1)

**Goal**: Delete all admin-facing code from the mobile binary: the two admin screen files, the redirect screen added in Release 1, and the 15 admin-only service methods. Introduce a shared `UnauthorizedScreen` for `admin` and any unrecognized role. Ship Release 2 as a separate PR with `ROLLBACK.md`.

**Independent Test**: On the Release 2 build, an admin sign-in lands on `UnauthorizedScreen` with no URL, no copy button, and no admin hint; the canonical deletion grep returns zero matches for all 15 method names and all 3 admin screen class names in `lib/`; `flutter analyze` is clean; both release builds succeed; Release 2 APK is measurably smaller than Release 1 APK.

### Implementation for User Story 2

- [ ] T031 [US2] Create a scratch git branch from the Release 1 commit; apply a fabricated Release 2 revert (the steps in `ROLLBACK.md` draft) to verify the revert restores a working release-mode build on both platforms. Run `flutter build apk --release` and `flutter build ios --release` on the reverted branch; confirm both succeed. Discard the scratch branch when done; record the attempt in `specs/006-mobile-admin-cleanup/ROLLBACK.md` as "revert-smoke-test: PASS on <date>".
- [ ] T032 [US2] Create `specs/006-mobile-admin-cleanup/ROLLBACK.md` containing: (a) rollback target = Release 1 commit hash from T024, (b) exact revert steps (e.g., `git revert <merge-commit-of-R2-PR>` + `flutter pub get` + re-deploy), (c) the revert-smoke-test PASS note from T031, (d) an explicit statement that rolling back further than the Release 1 commit is NOT a supported path (per FR-022 and spec clarification Q4).
- [ ] T033 [US2] Create `lib/unauthorized_screen.dart` as a `StatelessWidget` named `UnauthorizedScreen`. Its `build()` renders a centered column containing: a title (localized English "Access Denied" / Arabic equivalent per existing app pattern), a single-line message "Your account is not available on this app" / Arabic equivalent. The widget MUST NOT contain: the admin web URL, any button, any network call, any Firebase Analytics event, any import of `cloud_firestore` / `cloud_functions` / `firebase_analytics`.
- [ ] T034 [US2] Rewrite `_routeByRole(String role)` in `lib/login_screen.dart` to three explicit branches per research.md R5: `if (role == 'customer') → UserHomeScreen()`; `else if (role == 'technician') → TechHomeScreen()`; `else → UnauthorizedScreen()`. The `admin` case falls through to the `else` branch (the shared UnauthorizedScreen per FR-013). Update imports: remove `import 'admin_dashboard_screen.dart';` and `import 'admin_redirect_screen.dart';`; add `import 'unauthorized_screen.dart';`.
- [ ] T035 [P] [US2] Delete `lib/admin_dashboard_screen.dart`. Verify `flutter analyze` reports no dangling import or reference errors in files other than `admin_support_chat_screen.dart` (which is deleted in the next task).
- [ ] T036 [P] [US2] Delete `lib/admin_support_chat_screen.dart`. Verify `flutter analyze` is clean after T035 + T036 together.
- [ ] T037 [P] [US2] Delete `lib/admin_redirect_screen.dart` (created in Release 1 under US1). Verify no surviving references via `rg -n 'AdminRedirectScreen' lib/` returning zero matches.
- [ ] T038 [US2] In `lib/firebase_service.dart`, delete each of the 15 admin-only methods listed in data-model.md §5: `assignJob`, `adminCloseJob`, `adminResolveDispute`, `updatePaymentStatus`, `closeSupportChat`, `markSupportChatReadByAdmin`, `initializeStatsGlobal`, `streamActiveJobsAdmin`, `streamJobsByStatus`, `streamAllPayments`, `streamSupportChats`, `streamUnreadSupportCount`, `fetchRecentUsers`, `fetchRecentActivity`, `getAvailableTechnicianIdsByService`. Remove any `import` statement at the file top that is orphaned by the deletions. Do NOT delete any method still referenced by a customer or technician flow; if one is found during this task, abort that method's deletion, document the exception in `plan.md` Complexity Tracking, and leave that method in the file.
- [ ] T039 [US2] Prune orphaned dependencies from `pubspec.yaml` per FR-016: for each dependency, grep the current `lib/` tree for its import path; remove any dependency with zero imports. In particular, if `firebase_analytics` has no remaining call site (the only call was in the deleted `admin_redirect_screen.dart`), remove it. Leave every dependency still used by customer or technician flows intact. Run `flutter pub get` after edits.
- [ ] T040 [US2] Run the canonical deletion grep from research.md R6 twice, from repo root: `rg -n --type dart 'AdminDashboardScreen|AdminSupportChatScreen|AdminRedirectScreen' lib/` and `rg -n --type dart 'assignJob|adminCloseJob|adminResolveDispute|updatePaymentStatus|closeSupportChat|markSupportChatReadByAdmin|initializeStatsGlobal|streamActiveJobsAdmin|streamJobsByStatus|streamAllPayments|streamSupportChats|streamUnreadSupportCount|fetchRecentUsers|fetchRecentActivity|getAvailableTechnicianIdsByService' lib/`. Both MUST return zero matches. Paste the empty output into the Release 2 PR description as verification.
- [ ] T041 [US2] Run `flutter analyze` from repo root on the final Release 2 commit; fix any errors or warnings until output is `No issues found!` (FR-017).
- [ ] T042 [US2] Run `flutter build apk --release` from repo root; confirm success and record the Release 2 APK byte count; subtract from T015 to compute the size delta (MUST be positive — Release 2 smaller than Release 1, per SC-008). Record the numbers and delta in the Release 2 PR description.
- [ ] T043 [US2] Run `flutter build ios --release` on a macOS build host; confirm success; record the Release 2 IPA size.
- [ ] T044 [US2] Install the Release 2 build on a device; sign in with an admin test account; verify: (a) `UnauthorizedScreen` renders, (b) the screen shows the generic "Your account is not available on this app" message with no URL and no copy button, (c) no `admin_redirect_shown` event is emitted to Firebase Analytics. Screenshot each verification step into the Release 2 PR description.
- [ ] T045 [US2] Install the Release 2 build on a device; sign in with a user whose role value is neither `customer` nor `technician` nor `admin` (e.g., create a synthetic role `auditor`); verify they also land on `UnauthorizedScreen`, confirming FR-013a's behavior that any unrecognized role routes there — not to the customer home.

**Checkpoint**: User Story 2 is internally verified. Release 2 is not yet shipped — the second US3 regression cut MUST pass before the PR is merged.

---

## Phase 7: User Story 3 - Customer & Technician Regression Safety (Release 2 cut) (Priority: P1)

**Goal**: Confirm the deletions in Release 2 did not disturb the customer or technician flows. This is the FR-019 / SC-003 gate for Release 2.

**Independent Test**: Re-exercise the customer and technician end-to-end flows on the Release 2 build; every step matches pre-deletion behavior bit-for-bit.

### Implementation for User Story 3 (Release 2 cut)

- [ ] T046 [US3] Install the Release 2 build on a device; sign in as a customer test account and complete the full end-to-end ordering flow (same script as T020): sign-in → browse → create order → reach confirmation/tracking. Every step must succeed identically to pre-release behavior. Record screenshots in the Release 2 PR description.
- [ ] T047 [US3] Install the Release 2 build on a device; sign in as a technician test account and complete the full end-to-end job flow (same script as T021): accept → progress → submit receipt → completion. Every step must succeed identically. Record screenshots in the Release 2 PR description.
- [ ] T048 [US3] Open the Release 2 pull request against `main` as its OWN PR — it MUST NOT be bundled with any other feature. PR description MUST include: pre-deletion commit hash (Release 1 merge commit from T024), post-deletion commit hash (Release 2 head), Release 2 APK/IPA sizes and positive byte delta vs Release 1 (from T042/T043), the two zero-match grep outputs (from T040), `flutter analyze` clean output (from T041), admin scenario screenshots (T044), unknown-role scenario screenshots (T045), customer regression screenshots (T046), technician regression screenshots (T047), a link to the passed observation-gate evidence (T029), the version-control hygiene verification outcomes from the Release 2 re-run of T023b, and `ROLLBACK.md` linked as a file in the PR.
- [ ] T049 [US3] After Release 2 PR review + merge AND the Release-2 re-run of T023b verification PASS, create an annotated version-control tag on the merge commit (e.g., `v1.2.0-R2-mobile-admin-cleanup`). Record the commit hash in `plan.md` Complexity Tracking alongside the Release 1 commit hash.
- [ ] T050 [US3] Submit the Release 2 build to Google Play and App Store as two separate submissions; record submission IDs.

**Checkpoint**: Release 2 is shipped to both stores and tagged on `main`. The post-migration finalization window opens.

---

## Phase 8: User Story 5 - Post-Migration Finalization (Priority: P3)

**Goal**: Verify backend-side and project-wide signals that confirm the migration is complete; commit the sign-off checklist to `main`.

**Independent Test**: 14 days after Release 2 goes generally available, verify: Cloud Monitoring alert in place and test-fired; `stats/global` has received zero client writes for 7 consecutive days; `admin_redirect_shown` event rate has dropped to zero within the first 48 hours after Release 2 rollout (SC-007); shared-code duplication threshold evaluated with a written decision; `SIGN_OFF.md` committed to `main` with all boxes checked and commit hashes recorded verbatim.

### Implementation for User Story 5

- [ ] T051 [P] [US5] Verify a Cloud Monitoring alert exists on the project's backend error rate that fires when the rate exceeds 1% over a 5-minute rolling window (FR-026). If missing, create it via Google Cloud Console → Monitoring → Alerting. Test-fire during an announced maintenance window by forcing a controlled 1.5% error rate for 5 minutes on a staging endpoint; confirm the on-call is paged within the same window. Record the alert name, conditions, and test-fire result in a follow-up note in `plan.md`.
- [ ] T052 [P] [US5] Verify `stats/global` receives zero client writes for 7 consecutive days after Release 2 rollout. Open Firebase Console → Firestore → Usage; filter by path `stats/global`; observe the writes-per-day counter. Any day with ≥1 client write triggers a follow-up spec to identify the remaining client source. Record the 7 zero-write days and screenshot the usage view for the `SIGN_OFF.md` attachment.
- [ ] T053 [P] [US5] Verify `admin_redirect_shown` event count drops to zero within 48 hours of Release 2 rollout (FR-015, SC-007). Open Firebase Analytics console; chart the event count over the Release 2 rollout window; confirm zero-count by hour 48. If non-zero after 48 hours, inspect the `uid_hash` parameters — lingering events from devices still on Release 1 are expected for several weeks and do not block sign-off; only events attributable to devices claiming to be on Release 2 (via app version) indicate a defect. Record the zero-count-by-48h confirmation plus any stale-binary-explained residual in `SIGN_OFF.md`.
- [ ] T054 [US5] Evaluate shared-code duplication threshold per FR-028 and spec clarification Q5. For each model file in `.claude/AdminWebApp/lib/` whose counterpart exists in root `lib/`, compare the two files. Count a pair as "diverging" ONLY if they differ in (a) field names, (b) field types, or (c) Firestore parse/serialization logic — NOT if they differ only in formatting, whitespace, comments, or trivial refactors. If the diverging count is ≥3, file a follow-up spec for shared-package extraction and record the spec number in `SIGN_OFF.md`. If <3, record a written "deferred" note in `plan.md` Complexity Tracking listing the evaluated file pairs and the judgment for each.
- [ ] T055 [US5] Create `specs/006-mobile-admin-cleanup/SIGN_OFF.md` containing: every item from FR-026, FR-027, FR-028, FR-029 as a checked box; pre-deletion and post-deletion commit hashes recorded verbatim (from T024 and T049); pre-deletion and post-deletion APK/IPA sizes and the positive byte delta (from T006/T007/T015/T016/T042/T043); the Cloud Monitoring alert configuration (from T051); the 7-day zero-write evidence for `stats/global` (from T052); the 48-hour `admin_redirect_shown` zero-count evidence (from T053); the duplication-threshold decision or follow-up spec reference (from T054); and a final declaration "Migration closed on <date>" signed by the implementing engineer and an approver.
- [ ] T056 [US5] Open a small PR adding `SIGN_OFF.md` (and any Complexity Tracking updates to `plan.md`) to `main`. This PR is not version-tagged as a release — it is documentation only — and is merged after review.

**Checkpoint**: Migration is closed. `SIGN_OFF.md` is on `main`.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Final documentation hygiene and no-regret cleanup items that apply across the whole feature.

- [ ] T057 [P] Update `CLAUDE.md` "Recent Changes" section to note Spec 006 complete status, if it has not auto-updated.
- [ ] T058 [P] Run `quickstart.md` top-to-bottom as a sanity check — confirm each numbered step corresponds to a task in this file and each "record in release PR" instruction has been honored. File a follow-up issue for any drift between `quickstart.md` and the actual completed work.
- [ ] T059 Archive any scratch PowerShell/bash scripts in the root (`edit_home.ps1`, `fix_brackets.ps1`, `fix_card.ps1`, `fix_card_end.ps1`, `fix_empty.ps1`) unrelated to this migration; this is independent cleanup, do NOT bundle into the Release 1 or Release 2 PRs.
- [ ] T060 After `SIGN_OFF.md` lands on `main` and the 14-day post-Release-2 window closes with no incident, execute the out-of-scope one-off: migrate `.claude/AdminWebApp/*` into its own git repository using the standalone `firebase.json` and `.firebaserc` already in that folder. This is NOT part of Spec 006's scope — it is a one-time operation enabled by Spec 006's completion, performed outside any spec.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies. Starts immediately.
- **Phase 2 (Foundational)**: Depends on Phase 1 complete. BLOCKS Phase 3 onward.
- **Phase 3 (US1 — Release 1 impl)**: Depends on Phase 2 complete.
- **Phase 4 (US3 — R1 regression)**: Depends on Phase 3 complete. Ships Release 1.
- **Phase 5 (US4 — Observation Gate)**: Depends on Phase 4 complete + Release 1 live in both stores. **BLOCKS Phase 6** — Phase 6 MUST NOT start until gate passes.
- **Phase 6 (US2 — Release 2 impl)**: Depends on Phase 5 PASS (T030 complete).
- **Phase 7 (US3 — R2 regression)**: Depends on Phase 6 complete. Ships Release 2.
- **Phase 8 (US5 — Finalization)**: Depends on Phase 7 complete + Release 2 live for 14 days.
- **Phase 9 (Polish)**: Depends on Phase 8 complete.

### User Story Dependencies

- **US1 (P1)**: Needs Foundational complete (T005 verification specifically). No other story dependencies.
- **US3 (P1)** — this is the only story that appears in TWO phases (Phase 4 for Release 1, Phase 7 for Release 2). The Release 1 cut depends on US1 complete; the Release 2 cut depends on US2 complete.
- **US4 (P2)**: Depends on Release 1 (US1 + US3 R1 cut) being live in both stores. Blocks US2.
- **US2 (P1)**: Depends on US4 PASS. Non-independent from US1 because US2 deletes `AdminRedirectScreen` which US1 created.
- **US5 (P3)**: Depends on US2 + US3 R2 cut being live in both stores for 14 days.

**Note on independence**: unlike a typical spec where each P1 story is independently shippable, this migration's P1 stories are sequentially gated by nature (Release 1 → observation → Release 2). This is intentional and is documented in the spec's Assumptions. The independent-test criteria above still apply within each release scope.

### Within Each User Story Phase

- Phase 3 (US1): T009 → T010 (pubspec add then get) — sequential. T011 + T012 same file — sequential. T013 sequential after T011. T014/T015/T016 depend on T011–T013. Device tests T017/T018/T019 depend on T015/T016.
- Phase 4 (US3 R1): T020 and T021 different accounts but same device install — can be parallel if two devices available, sequential on one device. T022 depends on full Phase 3. T023/T024/T025 sequential.
- Phase 6 (US2): T031 depends on Release 1 shipped. T032 depends on T031. T033/T034 sequential (T034 imports T033). T035/T036/T037 marked [P] — different files. T038 sequential (same file as T036 via imports). T039 depends on T038. T040/T041 after all edits. T042/T043 release builds after T041. T044/T045 device tests after T042.
- Phase 8 (US5): T051/T052/T053 marked [P] — independent verifications. T054 independent of all. T055 depends on T051–T054. T056 depends on T055.

### Parallel Opportunities

- **Phase 1**: T002 and T003 can run in parallel with T001.
- **Phase 2**: T006, T007, T008 can run in parallel after T005.
- **Phase 6**: T035, T036, T037 can run in parallel (three independent file deletions, separate files).
- **Phase 8**: T051, T052, T053 can run in parallel (three independent backend verifications).
- **Phase 9**: T057, T058 can run in parallel.

### Cannot Be Parallelized

- Phase 3 onward within a single release — most tasks touch `lib/login_screen.dart`, `lib/firebase_service.dart`, `pubspec.yaml`, or depend on a device build, and thus must be sequential.
- The two Releases (Phases 3–4 vs Phases 6–7) MUST NOT be parallelized — FR-020 (two separate PRs, two separate store submissions) plus FR-021 (7-day observation gate) make this a hard constraint.

---

## Parallel Example: Phase 2 (Foundational)

```text
# After T005 (which is sequential and must complete first), launch the three
# baseline-capture tasks together:
Task: "T006 [P] Record pre-Release-1 APK size via flutter build apk --release"
Task: "T007 [P] Record pre-Release-1 iOS IPA size via flutter build ios --release"
Task: "T008 [P] Capture current _routeByRole snippet from lib/login_screen.dart"
```

## Parallel Example: Phase 6 (File Deletions)

```text
# After T032 (ROLLBACK.md written) and T033/T034 (UnauthorizedScreen + routing), the
# three file deletions target different files and can run together:
Task: "T035 [P] [US2] Delete lib/admin_dashboard_screen.dart"
Task: "T036 [P] [US2] Delete lib/admin_support_chat_screen.dart"
Task: "T037 [P] [US2] Delete lib/admin_redirect_screen.dart"
# Then T038 (firebase_service.dart edit) is sequential because it depends on a clean analyze after T035–T037.
```

## Parallel Example: Phase 8 (Finalization Verifications)

```text
# Three independent backend verifications — different consoles, different data sources:
Task: "T051 [P] [US5] Verify Cloud Monitoring alert + test-fire"
Task: "T052 [P] [US5] Verify stats/global zero-write 7-day window"
Task: "T053 [P] [US5] Verify admin_redirect_shown drops to zero within 48 hours"
```

---

## Implementation Strategy

### MVP (Ship Release 1)

Complete phases in order: **Phase 1 → Phase 2 → Phase 3 → Phase 4**. This ships Release 1 to both stores and starts the observation gate. The admin redirect is live; the cleanup has not happened yet. No backend changes. No customer/technician impact.

This is a deliverable state: admins on mobile are informed, Operations has a signal, the 7-day clock is running.

### Full delivery

MVP + **Phase 5 (observation gate, 7 days minimum)** + **Phase 6 → Phase 7** to ship Release 2. Admin code is now physically removed from the mobile binary; APK is smaller; admin sign-ins land on a generic dead-end screen.

Then **Phase 8** (14-day finalization window) + **Phase 9** (polish) closes out the migration.

### Why sequential, not parallel

Unlike typical feature specs where P1 stories can be parallelized across developers, this migration's P1 stories are inherently sequential:

- US1 (Release 1 redirect) must ship and soak for 7 days before US2 (Release 2 deletion) can even start.
- US3's regression checks must be run against each release's actual build, not against an in-progress branch.
- US4 is time-gated by design — it cannot be shortened by throwing engineers at it.
- US5 requires a 14-day observation window post-Release-2.

A single engineer can own the entire spec end-to-end in ~21 calendar days (Day 0 = Release 1 merged; Day 7 = gate pass; Day 7–9 = Release 2 PR; Day 10 = Release 2 merged; Day 24 = sign-off). Adding more engineers does not shorten the critical path because the critical path is the observation gate plus store review, not code-review bandwidth.

---

## Notes

- [P] tasks touch different files or consoles, with no shared dependency inside the same phase.
- [Story] labels map each task to its user story; setup/foundational/polish phases carry no story label.
- No automated tests are generated in this file — quality is enforced by `flutter analyze`, release-mode builds, manual regression, and the canonical deletion grep.
- Every task references exact file paths rooted at the repo root.
- Release 1 PR and Release 2 PR MUST be separate (FR-020). Bundling them is a rejection-worthy violation regardless of review timing.
- The observation window's duration is measured in analytics event counts, not calendar days (FR-021). Calendar days are the minimum floor; a single non-exception event resets the clock regardless of how many calendar days have passed.
- Do NOT touch `.claude/AdminWebApp/`, `functions/`, `firestore.rules`, `firestore.indexes.json`, or `storage.rules` from any task in this file.
- After Spec 006 closes, the one-off web-app-to-own-repo migration (T060) is executed outside the spec-kit flow.
