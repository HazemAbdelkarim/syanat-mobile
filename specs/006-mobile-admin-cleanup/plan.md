# Implementation Plan: Mobile Admin Cleanup

**Branch**: `006-mobile-admin-cleanup` | **Date**: 2026-04-20 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/006-mobile-admin-cleanup/spec.md`

## Summary

Retire the in-mobile admin dashboard across two separately shipped mobile releases, gated by a 7-day observation window. Release 1 adds a static `AdminRedirectScreen` (plus `firebase_analytics` dependency) that routes any signed-in `admin` user away from the mobile app to the deployed web dashboard URL, emits a single `admin_redirect_shown` event per render (hashed UID), and preserves all customer/technician flows bit-for-bit. After the gate passes (7 consecutive zero-count days of `admin_redirect_shown` in Firebase Analytics), Release 2 deletes the redirect screen, the two admin screen files (`admin_dashboard_screen.dart`, `admin_support_chat_screen.dart`), all 15 admin-only service methods in `firebase_service.dart`, and introduces a new shared `UnauthorizedScreen` so `admin` plus any unknown role route to a single dead-end widget — the login flow's fallthrough-to-customer-home default is eliminated. Technical approach is deletion-first: zero new backend work, zero rule changes, zero function changes, zero web-app changes. The two releases ship as two separate PRs, two separate store submissions, two separate tags, with a committed `ROLLBACK.md` whose target is the Release 1 commit.

## Technical Context

**Language/Version**: Dart (Flutter stable channel). Dart SDK constraint `^3.5.3`, unchanged from the existing root `pubspec.yaml`.
**Primary Dependencies**: Existing mobile app dependencies (unchanged list): `flutter`, `google_fonts ^6.2.1`, `video_player ^2.8.6`, `location ^6.0.2`, `flutter_local_notifications ^17.1.2`, `firebase_core ^3.1.1`, `firebase_auth ^5.1.1`, `cloud_firestore ^5.0.2`, `firebase_storage ^12.1.1`, `firebase_app_check ^0.3.1`, `geolocator ^12.0.0`, `image_picker ^1.0.7`, `flutter_image_compress ^2.3.0`, `google_sign_in ^6.2.1`, `sign_in_with_apple ^6.1.0`, `crypto ^3.0.3`. **Release 1 adds**: `firebase_analytics` (stable pub.dev version matching the pinned `firebase_core ^3.1.1` family — verified at implementation time). No other dependency additions, upgrades, or removals in either release unless a deletion strictly orphans a package (FR-016).
**Storage**: Firestore in existing project `syana-ea75a`. **Release 1**: zero Firestore reads or writes originate from the redirect screen (FR-004). **Release 2**: mobile client emits zero writes to `stats/global`; no rule changes, no index changes, no new collections. Telemetry store is Firebase Analytics (not Firestore) for the `admin_redirect_shown` event.
**Testing**: Manual regression for customer end-to-end and technician end-to-end flows before each store submission (FR-019); `flutter analyze` zero errors and zero warnings on both releases (FR-017); `flutter build apk --release` and `flutter build ios --release` must succeed on both releases (FR-018). No new automated test infrastructure introduced — the existing root project has no `test/` suite and this spec does not add one (would be out of scope per the migration plan's deletion-first stance).
**Target Platform**: Android and iOS, mobile. Both platforms must produce a passing release-mode build for both releases.
**Project Type**: Mobile app (root `lib/`). The admin web app at `.claude/AdminWebApp/` is out of scope for this spec and MUST NOT be touched.
**Performance Goals**: Redirect screen renders within 2 seconds of role-routing completion (SC-001). Zero incremental Firestore reads or Cloud Functions invocations on redirect render (SC-002). `admin_redirect_shown` event count drops to zero within 48 hours of Release 2 (SC-007).
**Constraints**: Backend frozen for the duration of this feature — no cloud functions, no firestore rules, no firestore indexes, no storage rules changes. Web app frozen — `.claude/AdminWebApp/*` MUST NOT be modified. Two-PR, two-tag, two-store-submission rule (FR-020). 7-day observation gate measured by Firebase Analytics event count, not calendar time (FR-021). Rollback target is the Release 1 commit, not the pre-Release-1 admin dashboard (FR-022). No bundled PR combining both releases. No `--no-verify` / no force-push / no signing bypass (FR-025).
**Scale/Scope**: Single mobile project, one new screen file (Release 1: `admin_redirect_screen.dart`), one new screen file (Release 2: `unauthorized_screen.dart`), two deleted screen files (Release 2: `admin_dashboard_screen.dart`, `admin_support_chat_screen.dart`), 15 deleted service methods, one modified routing function (`_routeByRole` in `login_screen.dart`), one dependency addition (`firebase_analytics` in Release 1). ROLLBACK.md and sign-off checklist committed alongside Release 2. Total shipped source delta: approximately +150 LOC (Release 1) followed by −2500 LOC (Release 2) net, yielding a smaller Release 2 binary than Release 1 (SC-008). No changes to Firestore collections, indexes, rules, functions, or the web app.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principles I–VII

| # | Principle | Compliance |
|---|-----------|------------|
| I | Migration Plan Is the Source of Truth | PASS — plan anchors every change to `WOOHOO/Migration_Implementation_Plan.md` §Phase 8 (Tasks 8-1, 8-2, 8-3). The 15 method names in FR-011 are copied verbatim from the plan's Resolved Blueprint; line numbers are re-verified at implementation time per Principle III. |
| II | Workspace Boundary | **DEVIATION (expected)** — Spec 006 is the only spec authorized by this principle to touch root `lib/`. The constitution explicitly states: "touch it only in Spec 006 (Mobile Cleanup)." No admin web files are created or modified (`.claude/AdminWebApp/*` is frozen); no Cloud Functions files are created or modified (`functions/*` is frozen). Documented here as authorized, not as a violation. |
| III | No Guessing — Read First | PASS — before deletion, the implementer runs a source-wide grep for each of the 15 method names and confirms zero non-admin callers (FR-012). Any method still referenced by a customer/technician flow stays in the binary and the exception is documented in Complexity Tracking. The pre-verified grep in Phase 0 research confirms current state: all 15 methods are referenced only in `admin_dashboard_screen.dart`, `admin_support_chat_screen.dart`, and `firebase_service.dart` itself. |
| IV | Deploy Safety | PASS (N/A) — no `firebase deploy` is invoked by either release. No Firestore rules, Cloud Functions, hosting, or storage rules deploys occur in this spec. The store-submission gate replaces the deploy-safety gate for this mobile-only feature. |
| V | Backward Compatibility During Migration | PASS — no job-status values change, no `affectedKeys()` restrictions change, no stats rule changes. Customer and technician flows must pass regression (FR-019, SC-003) bit-for-bit identically on both releases. |
| VI | Flutter Tooling Isolation | PASS — mobile-only changes, no admin_web/ touch. Root `flutter analyze` and `flutter build` remain the mobile commands; the web app keeps its own isolated toolchain at `.claude/AdminWebApp/`. |
| VII | No Premature Abstraction | PASS — the shared-code duplication threshold is evaluated (FR-028) but no shared package is extracted in this spec unless 3 or more model files meet the "diverging" definition (schema/contract drift, not formatting). If met, the follow-up is filed as a separate spec — not bundled into this one. |

### Principles VIII–XIII (Security Review Gate)

See the Security Review Gate table below. One row per principle, each stating: the control this spec implements, the file path, and the verification method.

| Principle | Control | File | Verification |
|-----------|---------|------|--------------|
| VIII — Secrets & Credential Hygiene | The deployed admin web URL is public and is compiled into the redirect screen as a plain-text constant — not a secret. The `admin_redirect_shown` event hashes or truncates the UID before emission (FR-007), so no raw identifier enters Firebase Analytics. No admin-related log statement in mobile emits raw PII in release mode (FR-008). No service account keys, no reCAPTCHA keys, no ID tokens are introduced. | `lib/admin_redirect_screen.dart` (Release 1); scan of `lib/` for `print(` / `debugPrint(` statements touching admin data in release mode. | Code review: grep for the URL constant to confirm it is a literal, not a runtime lookup; grep for `hash` / `substring` wrapping the UID parameter on the event emit; confirm `kReleaseMode` or `kDebugMode` guards on any log touching admin data. |
| IX — Least Privilege & Explicit Authorization | No new write paths introduced. The login flow's role check remains a Firestore read of `users/{uid}.role`. Release 2 tightens the authorization surface: the current default-to-customer-home behavior is replaced so `admin` and any unrecognized role route to the new shared `UnauthorizedScreen` (FR-013, FR-013a) — `customer` becomes an explicit match, not a fallthrough. No Custom Claims introduced. | `lib/login_screen.dart` (`_routeByRole`); `lib/unauthorized_screen.dart` (Release 2, new). | Code review: confirm Release 2 `_routeByRole` has three explicit branches (admin → UnauthorizedScreen, technician → TechHomeScreen, customer → UserHomeScreen) and any role that matches none routes to UnauthorizedScreen. No `else → UserHomeScreen` fallthrough survives. |
| X — Input Validation & Transactional Integrity | No Cloud Functions changes. No Firestore transactional writes changed. Not applicable to this spec by construction. | N/A | N/A — the Security Review Gate table row is recorded as "no surface changed by this spec" rather than left blank. |
| XI — Audit Trail & Accountability | No admin privileged writes remain on the mobile surface after Release 2 — all admin audit records are written by the web app and Cloud Functions, both of which are frozen for this feature. Release 1 redirect and Release 2 unauthorized screens perform zero writes. The `admin_redirect_shown` analytics event is instrumentation, not an audit record, and uses a hashed UID so it is not personally accountable — it is an observation-gate signal. | `lib/admin_redirect_screen.dart`; `lib/unauthorized_screen.dart`. | Code review: grep either screen file for `FirebaseFirestore.instance` / `FirebaseFunctions.instance` → expect zero matches. |
| XII — Defense in Depth | Existing App Check is unchanged on mobile. Firestore rules are unchanged — they continue to deny client writes to `stats/global` and to gate admin-only document mutations. Deleting the 15 admin-only service methods from mobile strictly reduces the attack surface and does not relax any control elsewhere. Release 2 additionally closes the information-leak path that a mobile-side admin hint would create. | Firestore rules (frozen); mobile binary surface post-Release-2. | Code review: diff Firestore rules between Release 1 and Release 2 commits → expect zero rule changes. Post-Release-2 source scan for "admin" (case-insensitive) in `lib/` returns only the unchanged English/Arabic copy strings ("Your account is not available on this app" in `unauthorized_screen.dart`) — no references to the deleted classes or methods. |
| XIII — Safe Error Reporting & Logging | The redirect screen and the unauthorized screen use static copy only — no dynamic error-message rendering, no network-error surfacing. The `admin_redirect_shown` event parameter set is fixed: event name plus a hashed/truncated UID string. No raw `context.auth.token`, no ID tokens, no reCAPTCHA tokens, no raw email or phone number can enter the event or the screen's rendered text. Release-mode logging emits no admin-related raw PII (FR-008). | `lib/admin_redirect_screen.dart`; `lib/unauthorized_screen.dart`; analytics event construction site. | Code review: the analytics call takes two arguments — event name (`admin_redirect_shown`) and a `{ 'uid_hash': ... }` params map. Confirm the params map does not include the raw UID, the user's email, phone, or the Firebase ID token. |

**Gate result (pre-Phase-0)**: PASS. The only deviation is the authorized touch of root `lib/` under Principle II, which the constitution explicitly permits in Spec 006. All other principles hold; rows X and XI are marked "no surface changed" because this feature is deletion-scoped and touches no privileged-write code path.

### Post-Phase-1 re-check (2026-04-20)

After generating `research.md`, `data-model.md`, `contracts/README.md`, and `quickstart.md`, the Constitution Check is re-evaluated: **PASS (unchanged)**.

- Phase 1 introduced no new surfaces, no new dependencies beyond `firebase_analytics` (already accounted for in the pre-check), and no new privileged-write paths. The data model explicitly documents that no Firestore collection, rule, index, or callable changes.
- `research.md` R2 confirms the event parameter schema uses only a 12-char SHA-256 prefix — reinforcing compliance with Principle XIII (no raw PII in telemetry).
- `research.md` R6's pre-verified grep confirms FR-012's precondition (zero non-admin callers for every method in the deletion list), so Principle III's "no guessing" is preserved — the deletion list is read-verified, not assumed.
- `contracts/README.md` records that zero new external contracts are introduced, closing out Principles VIII, IX, X, XI, XII, XIII on the "no new write-surface" basis that was asserted in the pre-check.
- Complexity Tracking is unchanged: the two justified deviations (touching root `lib/`, adding `firebase_analytics`) are both constitutionally authorized and do not require escalation.

## Project Structure

### Documentation (this feature)

```text
specs/006-mobile-admin-cleanup/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (empty — no API contracts change)
├── checklists/
│   └── requirements.md  # Spec quality checklist (already written)
├── spec.md              # Feature specification (already clarified)
├── INPUT.md             # Source brief (read-only)
└── tasks.md             # Phase 2 output (NOT produced by /speckit.plan)
```

### Source Code (repository root)

```text
lib/                                     # Mobile app (the only surface changed by this spec)
├── admin_dashboard_screen.dart          # DELETED in Release 2
├── admin_support_chat_screen.dart       # DELETED in Release 2
├── admin_redirect_screen.dart           # NEW in Release 1; DELETED in Release 2
├── unauthorized_screen.dart             # NEW in Release 2
├── login_screen.dart                    # MODIFIED in both releases (routing only)
├── firebase_service.dart                # MODIFIED in Release 2 (15 admin-only methods removed)
├── main.dart                            # Unchanged
├── user_home_screen.dart                # Unchanged (customer flow)
├── tech_home_screen.dart                # Unchanged (technician flow)
├── ... (~30 other files)                # Unchanged customer and technician surface

.claude/AdminWebApp/                     # Admin web app — FROZEN (out of scope)
functions/                               # Cloud Functions — FROZEN (out of scope)
firestore.rules                          # FROZEN
firestore.indexes.json                   # FROZEN
storage.rules                            # FROZEN

pubspec.yaml                             # Release 1: add firebase_analytics
                                         # Release 2: drop dependencies iff strictly orphaned (FR-016)

specs/006-mobile-admin-cleanup/ROLLBACK.md     # Committed alongside Release 2
specs/006-mobile-admin-cleanup/SIGN_OFF.md     # Committed after 14-day post-Release-2 window
```

**Structure Decision**: Mobile app (single root project at `lib/`). No sub-projects created. No tests/ tree added — the root project does not currently contain one and this deletion-scoped spec does not introduce one. The admin web app remains at `.claude/AdminWebApp/` unchanged and is not touched by any file in this feature. The Spec 006 documentation folder adds two ship-time artifacts: `ROLLBACK.md` (committed before Release 2 merges) and `SIGN_OFF.md` (committed after the 14-day post-Release-2 observation closes).

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|-----------|-------------------------------------|
| Constitution Principle II: root `lib/` is touched | This spec IS the one and only spec the constitution authorizes to touch root `lib/`. The admin-cleanup migration cannot be executed from the web app or the functions directory — the code being removed lives in the mobile project. | Not applicable — the constitution anticipates this touch and names Spec 006 as the authorized scope. Any simpler alternative would leave dead admin code in the mobile binary indefinitely, violating the migration plan's §Phase 8 goal. |
| `firebase_analytics` added as a new dependency in Release 1 | The observation gate requires a telemetry signal independent of authentication logs, since Firebase Authentication does not expose a "mobile client + role == admin" query without a custom event log. A new lightweight dependency is the simplest way to record the gate's source of truth. | Logging the event to Firestore was rejected: it would add client writes to a collection that would outlive Release 2, conflicting with the spirit of SC-009 (zero client writes post-Release-2) and with Principle IX's "no new write path." A Cloud Function trigger-based counter was rejected because it would introduce new backend work, conflicting with the spec's explicit Assumption that the backend is frozen. |
| Android Gradle scaffold migration (tooling debt surfaced by Spec 006, not in spec scope) | `flutter build apk --release` refused to run on Flutter 3.41 against the project's pre-Spec-006 Gradle scaffold with the error "Your app is using an unsupported Gradle project." Root causes (all pre-existing): `android/app/build.gradle` was missing the `dev.flutter.flutter-gradle-plugin` plugin + `flutter { source = "../.." }` block; `android/build.gradle` used the legacy `buildscript { classpath ... }` style in conflict with the already-declarative `settings.gradle`; AGP was pinned at 8.1.0 (Flutter 3.41 minimum is 8.1.1, effective minimum 8.6.0); Kotlin was pinned at 1.9.0 (Google Play Services measurement-impl 22.5.0 is compiled with Kotlin 2.1.0 metadata); `flutter_local_notifications` requires core-library desugaring; `compileSdk` needed to be raised to 36 for the current plugin graph; the `workmanager ^0.5.1` dev-dependency (unreferenced anywhere in `lib/`) uses removed Flutter v1 embedding APIs. 2026-04-20 changes applied to unblock Release 1 builds: `android/settings.gradle` bumped AGP to 8.3.0, Kotlin to 2.1.0, added `com.google.gms.google-services 4.4.4 apply false`; `android/build.gradle` reduced to the canonical root-project form (no `buildscript`); `android/app/build.gradle` rewritten in declarative form (adds `dev.flutter.flutter-gradle-plugin`, adds `coreLibraryDesugaringEnabled true` + `coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'`, adds explicit `shrinkResources false`, uses `flutter.versionCode`/`flutter.versionName`/`flutter.minSdkVersion`, bumps `compileSdk` from 34 to 36, sets `minSdk` via `flutter.minSdkVersion` which resolves to 23 per firebase-bom 34.6.0 requirements); `android/gradle/wrapper/gradle-wrapper.properties` bumped 8.3→8.9; `pubspec.yaml` removed the orphan `workmanager` dev-dep. Minimum supported Android version rises from API 19 (Android 4.4 KitKat) to API 23 (Android 6.0 Marshmallow) — devices below Android 6 would not have installed successfully under firebase-bom 34.6.0 regardless, so this is a correction, not a regression. `flutter build apk --debug` and `flutter build apk --release` both succeed post-migration. | "Leave it for the human on the build host" was rejected because the spec's quality gates (T015, T016) cannot be run at all without this migration, which would have blocked the whole Release 1 PR. Pinning to an older Flutter version was rejected because the constitution explicitly names Flutter 3.41.0 as the target. Splitting this migration into its own spec was rejected because it would create a circular dependency: Spec 006 blocks on a tooling-upgrade spec, which blocks on a buildable baseline, which this spec's own Phase 2 `flutter build` is supposed to establish. The migration is logged here so any reviewer can see the delta was intentional, reproducible, and bounded to the `android/` tree plus one orphan-dep removal. |

