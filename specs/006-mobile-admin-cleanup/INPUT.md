# Spec 006 Input Brief — Mobile Admin Cleanup

**Target phase in migration plan:** `WOOHOO/Migration_Implementation_Plan.md` → Phase 8 (Tasks 8-1, 8-2, 8-3).
**Depends on:** Spec 005 shipped (admin web app feature screens live on a Firebase Hosting preview/production URL, 27-scenario smoke test passed).
**Created:** 2026-04-19
**Status:** Input brief only — no `spec.md` yet. Will be authored by the implementing model via the speckit commands listed at the end of this file.

---

## Path Override (READ FIRST — non-negotiable)

- The mobile Flutter project at repo root (`lib/…`, `pubspec.yaml`, `android/`, `ios/`) is the primary target of this spec. All deletions, edits, and new files happen **in `lib/`**.
- The admin web app lives at `.claude/AdminWebApp/` (NOT `admin_web/`). Any reference to the web app in this spec — deployed URL, auth gate, etc. — MUST point at `.claude/AdminWebApp/`. Do NOT modify any file under `.claude/AdminWebApp/` in this spec; the web app is already shipped.
- Root-level touches allowed: `lib/`, `pubspec.yaml` (only to drop unused admin-only deps that become orphaned after Task 8-2), `README.md` (optional — document the new admin URL).
- Do NOT touch: `functions/`, `firestore.rules`, `firestore.indexes.json`, `storage.rules`, `.claude/AdminWebApp/`. Those are frozen for this spec.

---

## Feature Description (raw input for `/speckit.specify`)

Retire the in-mobile admin dashboard in two shipped mobile releases. By the end of this spec, the mobile binary contains zero admin UI, zero admin-only service methods, and zero admin-only imports. Admin users who sign in on mobile see a redirect screen pointing at the web dashboard, and after an observation gate, the redirect screen is removed and admin users are simply denied like any unauthorized role.

The cleanup is split across three tasks, in order:

1. **Release 1 — Admin Routing Redirect (Task 8-1).**
   - Create `lib/admin_redirect_screen.dart`: stateless, shows an icon, the text "Admin access has moved to the web dashboard.", the deployed admin web URL, and a "Copy URL" button that writes the URL to the clipboard.
   - Modify `lib/login_screen.dart`: remove `import 'admin_dashboard_screen.dart';`, add `import 'admin_redirect_screen.dart';`, and in the role-routing branch replace `dest = const AdminDashboardScreen()` with `dest = const AdminRedirectScreen()`.
   - `admin_dashboard_screen.dart` and `admin_support_chat_screen.dart` stay on disk for this release (revert safety).
   - `flutter analyze` → zero errors. Customer, technician, and admin-redirect manual smoke tests all pass.
   - Ship to both App Store and Play Store.
   - **Observation gate:** 7 consecutive days with zero admin-role logins observed in Firebase Authentication logs (or equivalent) before Release 2 is allowed.

2. **Release 2 — Admin Code Removal (Task 8-2).**
   - Delete `lib/admin_dashboard_screen.dart`.
   - Delete `lib/admin_support_chat_screen.dart`.
   - Delete `lib/admin_redirect_screen.dart`.
   - Remove the admin role branch entirely from `lib/login_screen.dart` — an authenticated user whose role is `admin` falls through to the same unauthorized path as any other unexpected role (shown a generic "Your account is not available on this app" message, no links, no copy-URL button).
   - Remove the following admin-only methods from `lib/firebase_service.dart` (migration plan §Task 8-2 inventory — line numbers as of the pre-deletion commit, to be re-verified by the implementing model):
     - `assignJob`, `adminCloseJob`, `adminResolveDispute`, `updatePaymentStatus`,
     - `closeSupportChat`, `markSupportChatReadByAdmin`,
     - `initializeStatsGlobal`,
     - `streamActiveJobsAdmin`, `streamJobsByStatus`, `streamAllPayments`,
     - `streamSupportChats`, `streamUnreadSupportCount`,
     - `fetchRecentUsers`, `fetchRecentActivity`,
     - `getAvailableTechnicianIdsByService`.
   - For each method removed: confirm via IDE "Find Usages" (or `grep -r`) that there are zero non-admin callers left in `lib/`. A method that is still called from a customer or technician flow stays — log any such exception in `plan.md` Complexity Tracking.
   - Drop any pubspec dependency that becomes orphan after the removal (only if truly unused by customer/technician flows). Do NOT drop `cloud_firestore`, `firebase_auth`, `firebase_core`, `cloud_functions`, `firebase_app_check` — those are shared.
   - `flutter analyze` → zero errors. `flutter build apk --release` and `flutter build ios --release` both succeed.
   - Record pre-deletion commit hash and post-deletion commit hash in the PR description.
   - Record binary size reduction (APK size before vs after) in the PR description.
   - Ship to both stores.

3. **Post-Migration Finalization (Task 8-3).**
   - Cloud Monitoring alert set: Cloud Functions error rate > 1% over 5 minutes → page the on-call.
   - Confirm in Firestore usage dashboard: `stats/global` is receiving ZERO client writes (all writes originate from event-driven triggers shipped in Spec 003).
   - Shared-code threshold check: if 3+ model files are duplicated and diverging between `lib/` and `.claude/AdminWebApp/lib/`, file a separate spec for extraction. Otherwise defer.
   - Migration sign-off checklist (all items MUST be checked before the migration is declared complete):
     - [ ] All admin-only methods removed from `lib/firebase_service.dart`.
     - [ ] Binary size reduction documented (before/after APK bytes).
     - [ ] Cloud Functions error-free for 14 consecutive days.
     - [ ] All admins confirmed operational on web (list names in PR).
     - [ ] Zero client writes to `stats/global` in Firestore usage dashboard for 7 days.
     - [ ] Pre-deletion and post-deletion commit hashes recorded.

Final deliverable: the migration sign-off checklist in §Task 8-3 has every box checked and is committed as `specs/006-mobile-admin-cleanup/SIGN_OFF.md`.

---

## Functional Requirements (extract from migration plan Task 8-1 → 8-3)

### Mobile app changes

**New file (Release 1 only, deleted in Release 2):**
- `lib/admin_redirect_screen.dart` — `StatelessWidget`. AppBar title "Admin Access Moved". Body: large icon (`Icons.open_in_browser`), Text "Admin access has moved to the web dashboard.", SelectableText with the deployed URL, ElevatedButton "Copy URL" that calls `Clipboard.setData(ClipboardData(text: kAdminWebUrl))` and shows a SnackBar "URL copied". The URL constant `kAdminWebUrl` is defined inline in this file (do NOT thread it through `main.dart` or `firebase_service.dart`).

**Modified files:**
- `lib/login_screen.dart` — role-routing change (Release 1) and branch removal (Release 2).
- `lib/firebase_service.dart` — delete 15 admin-only methods (Release 2 only).

**Deleted files (Release 2 only):**
- `lib/admin_dashboard_screen.dart`
- `lib/admin_support_chat_screen.dart`
- `lib/admin_redirect_screen.dart`

### Web app changes

**None.** `.claude/AdminWebApp/` is frozen for this spec. The deployed URL used in Release 1's redirect MUST be the real production URL from the Spec 005 deploy — not a placeholder, not the preview channel.

### Regression scope for each release

Before each release ships:

- [ ] Customer sign-in → home flow works.
- [ ] Customer order flow works end-to-end.
- [ ] Technician sign-in → home flow works.
- [ ] Technician job-acceptance-to-completion flow works end-to-end.
- [ ] Admin sign-in on mobile:
  - Release 1: lands on `AdminRedirectScreen` with working "Copy URL" button.
  - Release 2: lands on the generic unauthorized/denied screen, no admin UI rendered.
- [ ] `flutter analyze` → zero errors.
- [ ] Both platforms build in release mode.

---

## Non-Functional / Security & Cost Requirements (MUST be in spec.md)

The implementing model MUST address each of the following explicitly in the generated spec and plan. If an item cannot be met, write an explicit "Complexity Tracking" deviation in `plan.md`.

### A. Privilege isolation

- A-1. The mobile app, after Release 2, MUST NOT import or reference any admin-only service method. The implementing model MUST include a `flutter analyze` + grep-based acceptance check that scans `lib/` for every removed method name and asserts zero matches.
- A-2. The mobile app, after Release 2, MUST NOT render any admin screen or widget. A user whose token claims / Firestore role says `admin` sees the same denied path as any user with an unrecognized role. No URL, no copy button, no hint of admin existence.
- A-3. An admin user signing in on mobile at any stage of this spec MUST NOT be given access to any Firestore admin read or write — not via a lingering service method, not via a cached stream, not via a deep link.

### B. Code leak / secret hygiene

- B-1. The deployed admin web URL is public (it's a Firebase Hosting URL). Placing it as a `const String` in `admin_redirect_screen.dart` is acceptable. No credentials, no reCAPTCHA key, no admin UID list belongs anywhere in `lib/`.
- B-2. `print` / `debugPrint` of any admin-related information (role value, user IDs, redirect event) is forbidden in release builds. `kDebugMode`-gated logging is allowed but MUST redact `email`, `phone`, `address`.
- B-3. Commit messages and PR descriptions MUST NOT include admin user emails, UIDs, or any admin-account specifics.

### C. Firebase quota / cost guardrails

- C-1. Release 1's redirect screen MUST NOT open any Firestore stream or callable. It is a pure static widget. Rendering it MUST incur zero Firestore reads and zero Cloud Functions invocations.
- C-2. Removing admin streams from `firebase_service.dart` in Release 2 MUST measurably reduce the number of idle Firestore listeners the mobile app can open. The implementing model MUST document in `research.md` which streams were leaking (i.e., opened but never used by non-admin code paths) and confirm post-removal that none of the removed streams are referenced from customer or technician screens.
- C-3. Post-Release 2, verify via Firestore usage dashboard that no writes to `stats/global` originate from mobile clients (only from the event-driven Cloud Functions in Spec 003). The sign-off checklist (§Task 8-3) requires 7 days of zero client writes.

### D. Rollout / release safety

- D-1. Release 1 and Release 2 MUST be two separate mobile releases (two separate PRs, two separate store submissions, two separate commits tagged `v-mobile-release-1-admin-redirect` and `v-mobile-release-2-admin-removed`). The implementing model MUST NOT bundle them.
- D-2. The 7-day observation gate between Release 1 and Release 2 is measured by Firebase Authentication logs — zero sign-ins with `role == 'admin'` from a mobile client for 7 consecutive days. Calendar days alone are not sufficient. The implementing model MUST document how this metric is read and from where.
- D-3. Release 2 MUST include a documented rollback plan: the pre-deletion commit hash, the steps to `git revert` the deletion, and the confirmation that reverting restores a working build. The rollback plan goes in `specs/006-mobile-admin-cleanup/ROLLBACK.md`.
- D-4. No `--no-verify`, no `--force-push`, no hook-skipping at any point. If a pre-commit lint fails, fix the lint.

### E. Input sanitization

- E-1. The deployed admin web URL rendered on `AdminRedirectScreen` MUST be a compile-time `const String`, not a runtime-fetched value. No `RemoteConfig`, no Firestore lookup, no query-string manipulation.
- E-2. The "Copy URL" button MUST use `Clipboard.setData` from `package:flutter/services.dart`. No third-party clipboard packages.
- E-3. The redirect screen MUST render the URL via `SelectableText`, never `Html()`, `RichText` with user-controlled fragments, or `Linkify`. This is a hardcoded internal URL, but the convention in §E of Spec 005 applies here too: no HTML rendering of any text in this app.

### F. Concurrency & idempotency

- F-1. A user who signs in on mobile as `admin`, hits the redirect screen in Release 1, then has their admin role revoked mid-session MUST be signed out on next token refresh. The implementing model MUST NOT break the existing `authStateChanges()` / token-refresh behavior already in `firebase_service.dart`.
- F-2. Release 2 MUST be safe to deploy while admin users are actively using the web app. The mobile removal and the web app are decoupled; mobile cleanup cannot break web behavior. The implementing model MUST explicitly state this in `plan.md`.

### G. Observability

- G-1. Release 1 MUST emit a single `FirebaseAnalytics` custom event (or equivalent — whichever is already in use) when the redirect screen is shown, with parameter `uid` (hashed or truncated — DO NOT log the raw UID). This gives the operations team a measurable signal for the §D-2 observation gate.
- G-2. Release 2 MUST NOT emit the `admin_redirect_shown` event (the code is gone). The analytics event MUST drop to zero occurrences within 48 hours of the Release 2 rollout. The implementing model MUST describe how this is verified in `quickstart.md`.
- G-3. Release 2's `flutter build apk --release` byte size MUST be recorded. The implementing model MUST cite the before-size (from a fresh pre-deletion build on the same machine + Flutter version) and the after-size in the PR description.

---

## Out of scope for Spec 006

- Any change to `.claude/AdminWebApp/` — the web app is frozen; if a bug is discovered, it goes to a follow-up spec.
- Any change to `functions/`, `firestore.rules`, `storage.rules`, `firestore.indexes.json`.
- Any new Cloud Function.
- Service catalog management, bulk actions, export features, or any new admin feature.
- Shared-package extraction (`packages/shared_core/`) — deferred per migration plan §Task 8-3 unless the 3-file threshold is crossed.
- Refactoring or renaming of non-admin methods in `firebase_service.dart`. Only admin-only methods are removed; everything else stays bit-for-bit identical.
- Dependency upgrades. If removing admin code makes a dependency unused, it is dropped; otherwise `pubspec.yaml` is unchanged.
- Localization of the new redirect screen. English-only, matching the rest of the mobile app's current state.

---

## Dependencies already in place

- ✅ `.claude/AdminWebApp/` deployed and stable in production — Specs 004 & 005.
- ✅ All admin callables (`adminAssignJob`, `adminApprovePayment`, `adminRejectPayment`, `adminResolveDispute`, `adminCloseJob`) live and used by the web app — Spec 002.
- ✅ Event-driven stats triggers live in production — Spec 003.
- ✅ Hardened `firestore.rules` — Spec 001.
- ✅ 27-scenario operator smoke test on the web app has passed — Spec 005 acceptance.

## Known risks for the implementing model

| # | Risk | Mitigation it must build in |
|---|------|-----------------------------|
| 1 | A removed method in `firebase_service.dart` turns out to be called by a customer or technician flow → mobile app won't build | Task 8-2 step: `grep -r` every removed method name in `lib/` before the `git rm`. Any surviving non-admin caller blocks the removal and is logged in `plan.md` Complexity Tracking. |
| 2 | Release 2 shipped before the 7-day observation gate → admin users on mobile lose access without warning | D-1 two-PR rule + D-2 explicit metric. `tasks.md` MUST include the observation-gate check as its own blocking task. |
| 3 | An admin signs in on mobile during the 7-day window and is confused by the redirect | G-1 analytics event gives ops a signal. The redirect screen copy MUST include the exact web URL and a working "Copy URL" button. |
| 4 | Binary size reduction not measured → migration sign-off incomplete | G-3 required measurement in PR description. Pre- and post-deletion builds on the same machine and Flutter version. |
| 5 | `stats/global` keeps receiving client writes after Release 2 because a non-admin flow still increments it | Sign-off checklist item + 7-day Firestore dashboard verification. If a write sneaks in, the source is a customer/tech counter path that must be migrated in a follow-up spec. |
| 6 | Someone bundles Release 1 and Release 2 into a single PR / release | D-1 explicit two-PR rule. The implementing model MUST refuse to implement Task 8-2 in the same branch that ships Task 8-1. |
| 7 | Revert of Release 2 is unclear or untested | D-3 `ROLLBACK.md` deliverable. Rollback steps tested in a scratch branch before Release 2 ships. |

---

## Speckit commands to generate the artifacts

Run these in order from the repo root. Each consumes the previous step's output. After each command, stop and skim the produced file — if the model drifted from the brief above, correct it before moving to the next step.

```text
1. /speckit.specify   specs/006-mobile-admin-cleanup/INPUT.md
   → produces specs/006-mobile-admin-cleanup/spec.md

2. /speckit.clarify
   → up to 5 targeted clarifying questions, answers folded back into spec.md

3. /speckit.plan
   → produces plan.md, research.md, data-model.md (likely minimal — no new entities),
     contracts/ (likely empty — no new APIs), quickstart.md

4. /speckit.tasks
   → produces tasks.md with three phases (Release 1, Observation Gate, Release 2)
     and Task 8-3 finalization as a final phase

5. /speckit.checklist   release-safety
   → produces checklists/release-safety.md, enforcing §A–G of this brief
     with special emphasis on §D (two-release safety) and §G (observability)

6. /speckit.analyze
   → cross-artifact consistency check across spec/plan/tasks/checklist
```

Do NOT run `/speckit.implement` until:

1. All four artifacts (`spec.md`, `plan.md`, `tasks.md`, `checklists/release-safety.md`) have been reviewed.
2. The Spec 005 production deploy is confirmed stable (no rollback in the last 7 days).
3. A deploy slot exists for two separate mobile store submissions at least 7 days apart.
