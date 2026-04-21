# Quickstart: Mobile Admin Cleanup

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Data Model**: [data-model.md](./data-model.md) | **Date**: 2026-04-20

This quickstart is the implementer's "do these things in this order" guide. It does not replace `tasks.md` (produced by `/speckit.tasks`) — it is the high-level lane map.

---

## Prerequisites (before ANY implementation work)

- [ ] Spec 005 (admin web features) has been deployed to production and stable for **at least 7 consecutive days**. No in-flight incident. Operator smoke test (27 scenarios) passed on the production deploy.
- [ ] Two mobile store-submission slots are reserved at least 7 calendar days apart, with store-review padding.
- [ ] The deployed admin web URL is confirmed. Default per spec Assumption: `https://syanat-admin.web.app` (the Firebase Hosting site named `syanat-admin`). The implementer verifies the fully qualified URL in the Firebase console before hardcoding it.
- [ ] Current git branch is `006-mobile-admin-cleanup` and it is up to date with `main`.

---

## Release 1 — Admin Redirect Screen

### R1.1 Add the `firebase_analytics` dependency

1. Run `flutter pub outdated firebase_analytics` from repo root to identify the current stable version compatible with `firebase_core ^3.1.1`.
2. Add `firebase_analytics: ^<resolved version>` under `dependencies:` in `pubspec.yaml`, preserving the existing order.
3. Run `flutter pub get`.
4. `flutter analyze` must still return zero issues.

### R1.2 Create `lib/admin_redirect_screen.dart`

1. Implement as a `StatefulWidget` with one instance field `bool _eventEmitted = false`.
2. In `initState()`:
   - Guard on `!_eventEmitted`.
   - Set `_eventEmitted = true`.
   - Compute `uidHash = sha256(FirebaseAuth.instance.currentUser!.uid)` using the existing `crypto` package, take the first 12 hex chars.
   - Call `FirebaseAnalytics.instance.logEvent(name: 'admin_redirect_shown', parameters: {'uid_hash': uidHash})`.
3. `build()` renders:
   - A static title matching the English/Arabic localization pattern already in use elsewhere in the app.
   - A static message stating admin access has moved to the web dashboard.
   - A `SelectableText` showing the full deployed admin web URL, hardcoded inline as a `const String`.
   - A `TextButton` labeled "Copy URL" whose `onPressed` writes the URL to `Clipboard.setData` and shows a `SnackBar` confirmation.
4. The screen MUST NOT import `cloud_firestore` or `cloud_functions`. Verify with a local grep of the new file.

### R1.3 Update `lib/login_screen.dart`

1. Replace the `role == 'admin'` branch target in `_routeByRole` from `AdminDashboardScreen()` to `AdminRedirectScreen()`.
2. Update imports: keep the `admin_dashboard_screen.dart` import only if something else in the file uses it (it does not); otherwise remove it and add `admin_redirect_screen.dart`.
3. Do NOT change the `else` fallthrough in Release 1 — that is a Release 2 change.

### R1.4 Release 1 quality gate

- [ ] `flutter analyze` returns zero errors and zero warnings.
- [ ] `flutter build apk --release` succeeds.
- [ ] `flutter build ios --release` succeeds on a macOS build host (or documented manual verification via a teammate).
- [ ] **Manual regression**: sign in as a customer account; complete an end-to-end order flow. Sign in as a technician account; accept a requested job and progress it to completion. Both flows succeed without user-visible change from pre-release behavior.
- [ ] **Admin scenario test**: sign in as an admin account; verify the redirect screen renders within 2 seconds; tap "Copy URL"; confirm the clipboard and the confirmation snackbar; confirm the Firebase Analytics console shows exactly one `admin_redirect_shown` event with a `uid_hash` parameter whose first characters match the expected SHA-256 prefix.
- [ ] **Offline scenario test**: put device in airplane mode; sign in as admin from a cached-session state; verify the redirect screen still renders and "Copy URL" still works.
- [ ] Release 1 PR is opened, reviewed, and merged as its OWN PR — it MUST NOT be bundled with Release 2 changes.
- [ ] Release 1 version-control tag is created on the merge commit.
- [ ] Release 1 is submitted to both store fronts (Play + App Store).

### R1.5 Observation gate begins when Release 1 lands in production

- Operations monitors the Firebase Analytics console for the `admin_redirect_shown` event.
- The 7-day gate is continuous: every 24-hour window (UTC) with zero events advances the clock.
- A single non-zero day resets the clock, unless Operations records a written test-exception in the release log naming the hashed UID (FR-021 and spec clarification Q3).
- The gate status (day count, event evidence, any recorded exceptions) is posted to the team's shared release channel daily.

---

## Release 2 — Admin Code Removal (blocked until the observation gate passes)

### R2.0 Gate check (BLOCKING)

- [ ] 7 consecutive days of zero `admin_redirect_shown` events in Firebase Analytics, OR every non-zero event in that window has a matching written test-exception with the hashed UID recorded.
- [ ] The gate evidence (query, source console URL, day-by-day count, any exception records) is attached to the release record.
- [ ] If the gate fails, Release 2 is postponed. Do not start R2.1 until the gate passes.

### R2.1 Create `ROLLBACK.md` in `specs/006-mobile-admin-cleanup/`

Records the Release 1 commit hash as the rollback target, the exact steps to revert Release 2 to that commit, and a note that the revert-smoke-test has succeeded on a scratch branch on both platforms (FR-022). ROLLBACK.md is committed in the Release 2 PR, not in a follow-up PR.

### R2.2 Create `lib/unauthorized_screen.dart`

`StatelessWidget` with a single message ("Your account is not available on this app" in English plus existing Arabic localization). No buttons, no URL, no analytics event, no network I/O.

### R2.3 Rewrite `_routeByRole` in `lib/login_screen.dart`

Three explicit branches:

- `role == 'customer'` → `UserHomeScreen()`
- `role == 'technician'` → `TechHomeScreen()`
- everything else (including `admin`) → `UnauthorizedScreen()`

Remove the imports of `admin_dashboard_screen.dart` and `admin_redirect_screen.dart`. Add import of `unauthorized_screen.dart`.

### R2.4 Delete admin surface

Delete (in this order to minimize transient compile failures):

1. `lib/admin_dashboard_screen.dart`
2. `lib/admin_support_chat_screen.dart`
3. `lib/admin_redirect_screen.dart`

### R2.5 Remove admin-only service methods from `lib/firebase_service.dart`

Remove each of the 15 methods listed in `data-model.md §5`. Remove any import that is orphaned by the deletion. Do NOT remove any method that a customer or technician flow still calls (FR-012) — if the implementer finds such a case during grep, they abort that method's deletion and document the exception in this plan's Complexity Tracking.

### R2.6 Prune orphaned dependencies in `pubspec.yaml`

Per FR-016: if a dependency in `pubspec.yaml` was used only by the deleted admin screens and deleted admin methods, remove it. If it is still used by customer or technician flows, keep it. The `firebase_analytics` dependency added in Release 1 stays in Release 2 if any non-admin screen plans to use it in future; otherwise it is removed — the implementer confirms the one call site (the deleted redirect screen) was the only caller and prunes accordingly.

### R2.7 Verify deletion

Run the canonical grep (research.md R6):

```bash
rg -n --type dart 'AdminDashboardScreen|AdminSupportChatScreen|AdminRedirectScreen' lib/
rg -n --type dart 'assignJob|adminCloseJob|adminResolveDispute|updatePaymentStatus|closeSupportChat|markSupportChatReadByAdmin|initializeStatsGlobal|streamActiveJobsAdmin|streamJobsByStatus|streamAllPayments|streamSupportChats|streamUnreadSupportCount|fetchRecentUsers|fetchRecentActivity|getAvailableTechnicianIdsByService' lib/
```

Both MUST return zero matches. Attach the output to the Release 2 PR description.

### R2.8 Release 2 quality gate

- [ ] `flutter analyze` returns zero errors and zero warnings.
- [ ] `flutter build apk --release` succeeds; size recorded in bytes.
- [ ] `flutter build ios --release` succeeds.
- [ ] Binary size comparison: Release 2 APK smaller than Release 1 APK by a positive byte count, recorded in the Release 2 PR description.
- [ ] Manual regression: customer end-to-end and technician end-to-end flows pass (same as R1.4).
- [ ] Admin scenario test: signing in as admin lands on `UnauthorizedScreen` with no URL and no copy button; `admin_redirect_shown` is NOT emitted.
- [ ] Pre-deletion and post-deletion commit hashes recorded in Release 2 PR description (FR-023).
- [ ] Release 2 PR is reviewed, ROLLBACK.md is attached in the same PR, and it is merged as its OWN PR (not bundled with Release 1 or any other feature).
- [ ] Release 2 version-control tag is created on the merge commit.
- [ ] Release 2 is submitted to both store fronts.

---

## Post-Release 2 — Finalization (Task 8-3)

- [ ] Verify the Cloud Monitoring alert on backend error rate exists and fires within 5 minutes on >1% error rate. Test-fire it once in a maintenance window and record the result.
- [ ] Verify `stats/global` receives zero client writes for 7 consecutive days after Release 2 (SC-009).
- [ ] Verify `admin_redirect_shown` event count drops to zero within 48 hours of Release 2 rollout (SC-007).
- [ ] Evaluate shared-code duplication: count model files in `.claude/AdminWebApp/lib/` whose logical-entity copies in root `lib/` DIFFER in field names, field types, or Firestore parse logic (per spec clarification Q5). If ≥3, file a follow-up spec for shared-package extraction. Otherwise, write a "deferred" note in the Complexity Tracking section of this plan.
- [ ] Commit `specs/006-mobile-admin-cleanup/SIGN_OFF.md` to main. Every box checked. Pre- and post-deletion commit hashes recorded verbatim. Binary size delta recorded.
- [ ] After 14 days post-Release-2 with no incidents, the migration is declared complete.

---

## Rollback paths

- **Release 1 defect pre-gate**: Ship Release 1b (store patch) that reverts the offending change. Observation clock stops while reverted binary is installed; resumes when a corrected Release 1 is redeployed. No committed `ROLLBACK.md` required for Release 1.
- **Release 2 defect post-ship**: Execute the `ROLLBACK.md` playbook. The rollback target is the Release 1 commit — admin users see the redirect screen again; 15 methods and 3 admin files are restored from that commit. Further rollback (to pre-Release-1 admin dashboard) is NOT a supported path.

---

## Out-of-scope (re-state for the implementer)

- Localization of the redirect screen copy beyond the existing English/Arabic pattern.
- Any change to `.claude/AdminWebApp/*`.
- Any change to `functions/*`.
- Any change to `firestore.rules`, `firestore.indexes.json`, or `storage.rules`.
- Extraction of a shared package (`shared_core`) — happens only if the 3-file diverging threshold is crossed, and then as its own follow-up spec.
- Migration of the admin web app into its own repository — a one-time post-Spec-006 operation outside any spec, enabled by the `firebase.json` + `.firebaserc` already added to `.claude/AdminWebApp/`.
