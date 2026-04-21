# Implementation Plan: Admin Web App Shell

**Branch**: `004-admin-web-shell` | **Date**: 2026-04-18 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/004-admin-web-shell/spec.md`

## Summary

Scaffold a Flutter Web admin application at `.claude/AdminWebApp/` (override of constitution's `admin_web/` path — see Complexity Tracking), wire it to Firebase project `syana-ea75a` with App Check enforced via real reCAPTCHA Enterprise v3, deploy a placeholder shell through Firebase Hosting site `syanat-admin`, ship an admin-only auth gate (Firebase Auth + Firestore role doc read per decision D1), add a six-destination `NavigationRail` shell, declare the Phase-7 service-layer contract (one class with one real `streamStats()` method plus 12 `UnimplementedError` stubs, one Cloud Functions client class with 5 `UnimplementedError` stubs), and wire a GitHub Actions workflow that runs `flutter analyze` + `flutter build web --web-renderer html --release` scoped to `.claude/AdminWebApp/**` path filters.

The technical approach is to reuse the existing Firebase web config baked into `lib/firebase_service.dart`, mirror the mobile project's Dart SDK constraint (`^3.5.3`), and rely exclusively on the allow-listed package set from Constitution §Technology Constraints. No feature screens are built in this spec — every Phase 7 feature screen will plug into the `AdminSection` enum and the `AdminFirebaseService` / `AdminCloudFunctions` contracts declared here.

## Technical Context

**Language/Version**: Dart (Flutter stable channel). Dart SDK constraint `^3.5.3`, matching the mobile project's `pubspec.yaml`.
**Primary Dependencies**: `firebase_core`, `firebase_auth`, `cloud_firestore`, `cloud_functions`, `google_sign_in`, `google_fonts`, `firebase_app_check` — exact allow-list from Constitution §Technology Constraints. No routing package (single-route shell + `AuthGate` + nav-rail `IndexedStack`).
**Storage**: Firestore in existing project `syana-ea75a`. Reads only in Phase 6: `users/{uid}` (one-shot read for admin role), `stats/global` (stream for optional Overview placeholder smoke test). No writes initiated from this shell.
**Testing**: `flutter analyze` (zero-issues gate). No unit/widget tests required by this spec — the real acceptance is a live preview-channel deploy plus the CI `analyze + build` gate. Any Phase 6 widget tests are optional.
**Target Platform**: Flutter Web, `--web-renderer html` ONLY (CanvasKit explicitly forbidden by FR-009 and constitution §Technology Constraints). Deploy target: Firebase Hosting site `syanat-admin` under project `syana-ea75a`. Browsers: latest Chrome / Edge / Firefox (no IE).
**Project Type**: Web application (separate from the mobile app at repo root). Will later move to its own repo — see Principle VII.
**Performance Goals**: First sign-in to dashboard render ≤ 30 s on a cold browser session (SC-001). Non-admin sign-out → denied screen ≤ 2 s (SC-003). Dashboard renders at 1280×800 without layout overflow (SC-008). No explicit bundle-size target in Phase 6.
**Constraints**:
- MUST build and deploy with `--web-renderer html`.
- MUST NOT import any forbidden package from the constitution list.
- MUST live entirely under `.claude/AdminWebApp/` (path override) and MUST NOT modify anything under root `lib/` (FR-032).
- App Check activation MUST use a real reCAPTCHA Enterprise v3 site key; shipping the placeholder `YOUR_RECAPTCHA_V3_SITE_KEY` is forbidden (Principle VIII).
- The admin check is a Firestore doc read against `users/{uid}.role == 'admin'` — NOT Custom Claims (D1 in Migration Plan; Principle IX).
**Scale/Scope**: Single-tenant admin app; expected concurrent admin users ≤ 5. Scope in this spec: one `main.dart`, one `AuthGate`, one `LoginScreen`, one `DashboardScreen` with 6 placeholder sections, one `AdminFirebaseService` stub file, one `AdminCloudFunctions` stub file, one GitHub Actions workflow, one `firebase.json` hosting-block edit.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principles I–VII

| # | Principle | Compliance |
|---|-----------|------------|
| I | Migration Plan is Source of Truth | Every field/path in this plan is traceable to `WOOHOO/Migration_Implementation_Plan.md` (Phase 6 section, Resolved Blueprint, and Decisions D1/D10/D11). Firebase web config values come verbatim from `lib/firebase_service.dart`. ✅ |
| II | Workspace Boundary | **DEVIATION** — admin web code lives in `.claude/AdminWebApp/` instead of `admin_web/`. See Complexity Tracking row 1. Functions/mobile boundaries respected. ⚠️ |
| III | No Guessing — Read First | Admin web config read from `lib/firebase_service.dart`, `pubspec.yaml` for SDK constraint, `firebase.json` for current hosting shape, migration plan for method names. No field guessed. ✅ |
| IV | Deploy Safety | FR-010 mandates `firebase hosting:channel:deploy preview-shell` before any production deploy; every deploy is gated on diff review. ✅ |
| V | Backward Compatibility | Mobile `lib/` is explicitly untouched (FR-032). The mobile admin routes remain live until Phase 8. No Firestore rule or Cloud Function changes in this spec. ✅ |
| VI | Flutter Tooling Isolation | **DEVIATION** — isolation rule holds, but the path is `.claude/AdminWebApp/` not `admin_web/`. All `flutter pub get / analyze / build` commands MUST run from inside `.claude/AdminWebApp/`. See Complexity Tracking row 2. ⚠️ |
| VII | No Premature Abstraction | No shared packages, no monorepo tooling, no extracted models. `AdminFirebaseService` and `AdminCloudFunctions` are declared directly in the admin-web tree; Phase 7 implements them in place. ✅ |

### Principles VIII–XIII (Security Review Gate — MANDATORY for Specs 002–006)

| # | Principle | Control this spec implements | File path | Verification |
|---|-----------|------------------------------|-----------|--------------|
| VIII | Secrets & Credential Hygiene | (a) No service-account JSON introduced; `.gitignore` already covers them (FR-033). (b) Firebase **public** web config is embedded in `main.dart` — paired with active App Check (see XII). (c) Real reCAPTCHA Enterprise v3 key used for App Check activation; placeholder string `YOUR_RECAPTCHA_V3_SITE_KEY` MUST NOT appear in any shipped build. (d) GitHub Actions workflow (FR-011) uses `actions/setup-flutter` and does NOT require a deploy credential; any future deploy credential MUST come from GH Actions Secrets. | `.claude/AdminWebApp/lib/main.dart` (App Check call), `.gitignore` (pre-existing), `.github/workflows/admin-web.yml` | Code review: grep the built bundle for the literal `YOUR_RECAPTCHA_V3_SITE_KEY` — must return zero matches before a production deploy. `git diff --cached` review before every commit that touches `firebase.json` or `.claude/AdminWebApp/**`. |
| IX | Least Privilege & Explicit Authorization | (a) `AuthGate._AdminCheck` reads `users/{uid}` and rejects on missing doc OR `role != 'admin'`. (b) **On reject, `FirebaseAuth.instance.signOut()` is called BEFORE the denied screen renders** (FR-018 — required by Principle IX verbatim). (c) Admin check runs on every mount of the dashboard shell AND on every `authStateChanges()` emission. (d) No unbounded reads are introduced in this spec; `streamStats()` reads a single doc. | `.claude/AdminWebApp/lib/auth/auth_gate.dart`, `.claude/AdminWebApp/lib/auth/login_screen.dart` | Manual test per US2 AS4: sign in as a non-admin user, confirm the denied screen renders AND `FirebaseAuth.instance.currentUser == null` within 200 ms. Repeat after a browser refresh to verify re-check on mount. |
| X | Input Validation & Transactional Integrity | Not applicable at the shell layer — no Cloud Function calls are exercised in Phase 6 (all callable wrappers are `UnimplementedError` stubs per FR-028). Transaction + input-validation guarantees are the responsibility of Spec 002's Cloud Functions, which are already deployed. | `.claude/AdminWebApp/lib/services/admin_cloud_functions.dart` | `flutter analyze` confirms every method in `AdminCloudFunctions` throws `UnimplementedError` with a recognizable message. Phase 7 feature specs will re-assert Principle X when they implement these methods. |
| XI | Audit Trail & Accountability | Not applicable at the shell layer — no server writes originate from this spec. The Firebase Auth UID is established via sign-in and will be used by Phase 7 callables for `context.auth.uid`-based audit writes. | — (no audit writes in Phase 6) | N/A this spec. Reassessed in Spec 005. |
| XII | Defense in Depth | (a) **App Check is activated** via `FirebaseAppCheck.instance.activate(webProvider: ReCaptchaV3Provider(<real-key>))` on every app boot (FR-007). (b) The Firestore rules (Spec 001/003, already deployed) are the second independent layer gating every admin read. (c) `authStateChanges()` stream triggers a re-check on every emission (FR-017). (d) No implicit Firestore indexes are introduced; `stats/global` is a doc read. (e) `cd .claude/AdminWebApp && flutter pub outdated` is reviewed before the first deploy (see quickstart.md). | `.claude/AdminWebApp/lib/main.dart`, `.claude/AdminWebApp/lib/auth/auth_gate.dart`, `firestore.rules` (pre-existing) | App Check enforcement must be **Enforced** (not Monitor-only) in Firebase Console before Spec 005. Preview-channel smoke test (US1 AS4): confirm no App-Check-related 403 responses in the browser network tab. |
| XIII | Safe Error Reporting & Logging | (a) The `LoginScreen` surfaces `FirebaseAuthException.message` only — raw stack traces and non-`HttpsError` response bodies are never displayed (FR-020). (b) No `console.log(data)` calls that dump full payloads. (c) The app has no Crashlytics integration and no PII is logged. | `.claude/AdminWebApp/lib/auth/login_screen.dart` (error-display area) | Code review: grep for `debugPrint` / `print` in `.claude/AdminWebApp/lib/**` before merge — must be zero. Manual test: enter wrong password, confirm only the `message` field is shown. |

**Gate verdict:** All 13 principles have a row filled. Two deviations (II and VI — both path-related) are justified in Complexity Tracking below with no weakening of the underlying rule.

## Project Structure

### Documentation (this feature)

```text
specs/004-admin-web-shell/
├── plan.md              # This file (/speckit.plan command output)
├── spec.md              # Already written (see ./spec.md)
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output — UI contracts + service contracts
│   ├── admin-firebase-service.md
│   ├── admin-cloud-functions.md
│   └── ui-contracts.md
└── tasks.md             # Phase 2 output (/speckit.tasks command — NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
# Admin web app (path OVERRIDE of constitution Principle II — see Complexity Tracking)
.claude/AdminWebApp/
├── pubspec.yaml
├── analysis_options.yaml
├── web/
│   ├── index.html
│   ├── manifest.json
│   └── favicon.png
├── lib/
│   ├── main.dart                              # Firebase init + App Check activate + runApp
│   ├── app.dart                               # MaterialApp + AuthGate root (optional split)
│   ├── auth/
│   │   ├── auth_gate.dart                     # StreamBuilder<User?> + _AdminCheck
│   │   └── login_screen.dart                  # email/password + Google sign-in
│   ├── dashboard/
│   │   └── dashboard_screen.dart              # AdminSection enum + NavigationRail + IndexedStack
│   └── services/
│       ├── admin_firebase_service.dart        # streamStats() + 12 UnimplementedError stubs
│       └── admin_cloud_functions.dart         # 5 UnimplementedError stubs
├── test/                                      # OPTIONAL — none required by this spec
└── (standard Flutter scaffold files)

# CI — lives in the repo (not inside .claude/AdminWebApp/) because Actions workflows must be at .github/
.github/
└── workflows/
    └── admin-web.yml                          # Path-filtered: .claude/AdminWebApp/** only

# Root-level edits (minimal)
firebase.json                                  # Adds hosting block (see FR-008)

# UNCHANGED by this spec
lib/                                           # Mobile app — MUST NOT be modified (FR-032)
functions/                                     # Cloud Functions — unchanged
firestore.rules                                # Unchanged
storage.rules                                  # Unchanged
```

**Structure Decision**: Web application layout, with the admin web project isolated under `.claude/AdminWebApp/` and the mobile app untouched at repo root. Flutter tooling isolation (Principle VI) is preserved — the admin web project owns its own `.dart_tool/`, `.flutter-plugins`, and `pubspec.lock`. CI workflows live at `.github/workflows/` (the only location GitHub Actions recognizes) with path filters that scope them to `.claude/AdminWebApp/**`.

## Complexity Tracking

> Filled because Constitution Check surfaced two deviations (both on Principle II and Principle VI, which together dictate the `admin_web/` path).

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Principle II path: admin web code at `.claude/AdminWebApp/` instead of `admin_web/` | The admin web app is planned to move to its own repository after the migration (Principle VII, "the `admin_web/` extraction to its own repo happens after migration, not during"). The user directive is to stage it under `.claude/AdminWebApp/` until that move — `.claude/` is a pre-existing holding folder for in-flight sub-projects in this repo, is NOT gitignored, and cleanly signals "contents belong to a future repo." | Putting the project at repo root `admin_web/` is the literal constitution path, but was rejected because operators have signaled they want the folder visibly separated from the mobile app and co-located with other staged sub-projects under `.claude/`. Moving `admin_web/` later would force one extra PR touching every CI path filter. The isolation guarantee of Principle VI (distinct `.dart_tool/` and `.flutter-plugins`, `cd` before every Flutter command) is fully preserved — only the directory name changes. |
| Principle VI tooling commands: run Flutter commands from `.claude/AdminWebApp/` instead of `admin_web/` | Direct consequence of the Principle II deviation above. Every `flutter pub get`, `flutter analyze`, `flutter build web --web-renderer html --release` in this spec, in CI, and in operator runbooks MUST `cd .claude/AdminWebApp/` first. The isolation invariant that `.dart_tool/` and `.flutter-plugins` are never shared with the mobile project is unchanged. | N/A — cannot be avoided once row 1 is accepted. Documented here so reviewers do not read the constitution literally and flag it as a defect. |

**Recommended constitution amendment (follow-up, non-blocking for this spec):** bump constitution to v1.2.0 to add a one-sentence clarification to Principles II and VI that reads: _"For Spec 004 and until the admin web extraction, the path `admin_web/` refers to `.claude/AdminWebApp/`."_ That amendment is orthogonal to this spec's implementation and should be tracked as a follow-up PR, not a blocker.
