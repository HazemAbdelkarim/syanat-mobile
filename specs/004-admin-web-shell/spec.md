# Feature Specification: Admin Web App Shell

**Feature Branch**: `004-admin-web-shell`
**Created**: 2026-04-18
**Status**: Draft
**Input**: User description: "Phase 6 of the Admin Web Migration — scaffold the Flutter Web admin app, wire Firebase + App Check, ship a placeholder deploy, build the auth gate (admin-only), add the 6-section navigation shell, declare the service layer stubs that Phase 7 feature screens will implement, and set up CI."

---

## Context & Path Override (READ FIRST — non-negotiable)

This spec implements **Phase 6** of `WOOHOO/Migration_Implementation_Plan.md` (Tasks 6-0, 6-1, 6-1b, 6-2, 6-3, 6-4).

**PATH OVERRIDE.** The migration plan writes about an `admin_web/` folder at the repo root. **This spec overrides that to `.claude/AdminWebApp/`.** Any reference in this spec or the migration plan that says `admin_web/` MUST be interpreted as `.claude/AdminWebApp/`. Rationale: the admin web app will eventually move to its own repo; `.claude/AdminWebApp/` is the agreed holding location within this repo until that move happens. `.claude/` is NOT in `.gitignore`, so the folder is tracked normally.

This spec is deliberately exhaustive because a weaker model will implement the tasks. Every field, file path, package version, and error message is stated.

**Out of scope for this spec** (deferred to later specs):
- Feature screens (Overview KPIs, Jobs list/assign, Payments review, Disputes, Support chat, Activity feed) — these are Phase 7.
- Mobile cleanup (removing admin routes from mobile) — this is Phase 8.
- App Check key procurement (must be completed by a human before Task 6-1 deploy — see Assumptions).

---

## User Scenarios & Testing

### User Story 1 — Deployed Shell Loads Without Errors (Priority: P1) MVP

An admin can open the deployed Firebase Hosting URL in a browser and see a working Flutter Web page served over HTTPS with zero JavaScript console errors. No features yet — just proof the full hosting + build pipeline works end-to-end.

**Why this priority**: This is the smallest end-to-end slice. Without a working deploy, nothing else in the migration can be tested in the real browser environment. It also de-risks the reCAPTCHA / App Check / Flutter Web renderer combination before any feature work.

**Independent Test**: Preview deploy via `firebase hosting:channel:deploy preview-shell`, visit the preview URL, confirm the placeholder page renders and the browser console shows zero errors or warnings related to the app (Firebase SDK info logs are acceptable).

**Acceptance Scenarios**:

1. **Given** the `.claude/AdminWebApp/` project exists with `main.dart` calling `Firebase.initializeApp(...)` and `FirebaseAppCheck.instance.activate(...)`, **When** `flutter build web --web-renderer html --release` runs from `.claude/AdminWebApp/`, **Then** the build exits 0 and produces `.claude/AdminWebApp/build/web/index.html`.
2. **Given** `firebase.json` has a hosting block pointing to `.claude/AdminWebApp/build/web` with site `syanat-admin`, **When** `firebase hosting:channel:deploy preview-shell` runs, **Then** the command succeeds and prints a preview URL.
3. **Given** the preview URL is opened in Chrome, **When** the page finishes loading, **Then** the page displays the text "Syanat Admin" (or similar placeholder) and the browser console shows zero errors from the app itself.
4. **Given** App Check is activated with a real reCAPTCHA Enterprise site key, **When** the app makes any Firebase call, **Then** no App-Check-related 403 errors appear in the network tab.

---

### User Story 2 — Admin-Only Authentication Gate (Priority: P1)

Only users whose `users/{uid}` document has `role == 'admin'` can access the dashboard. Unauthenticated visitors see a login screen. Authenticated users whose role is not `'admin'` are signed out immediately and shown an "Access denied" page — they never reach the dashboard shell.

**Why this priority**: Without this gate, any authenticated user (customer, technician) could open the admin web URL and query Firestore from the browser console. This is the primary access-control boundary for the admin app.

**Independent Test**: Sign in with a known admin account → dashboard shell renders. Sign out, sign in with a customer account → "Access denied" shows, `FirebaseAuth.instance.currentUser` is `null` immediately after the denied page renders.

**Acceptance Scenarios**:

1. **Given** no user is signed in, **When** the user opens the app, **Then** the Login screen is shown.
2. **Given** the Login screen, **When** the user enters valid admin email+password and submits, **Then** the app verifies `users/{uid}.role == 'admin'` and transitions to the Dashboard shell.
3. **Given** the Login screen, **When** the user clicks "Sign in with Google" and completes the Google consent flow with an admin account, **Then** the app transitions to the Dashboard shell.
4. **Given** a user signs in successfully at the Firebase Auth layer with a non-admin account (`role == 'customer'` or `role == 'technician'` or missing role), **When** the admin-role check runs, **Then** `FirebaseAuth.instance.signOut()` is called BEFORE the "Access denied" screen renders, and `FirebaseAuth.instance.currentUser` is `null` within 200ms of the denied screen appearing.
5. **Given** a signed-in admin is on the Dashboard, **When** their ID token fails to refresh (e.g., account disabled), **Then** the `authStateChanges()` stream emits `null` and the app navigates back to the Login screen.
6. **Given** invalid credentials are entered, **When** the Login form submits, **Then** the form displays the Firebase Auth error message inline and does NOT crash or navigate.
7. **Given** a user tries to submit the Login form while a previous submission is in flight, **When** they click the submit button, **Then** the button is disabled and shows a loading indicator.

---

### User Story 3 — Six-Section Navigation Shell (Priority: P1)

Once authenticated, the admin sees a persistent left-side navigation rail with exactly six destinations: Overview, Jobs, Payments, Disputes, Support, Activity. Clicking a destination switches the main content area to a placeholder identifying that section. No real feature content yet — the placeholders are intentional (Phase 7 replaces them).

**Why this priority**: This is the skeleton Phase 7 feature screens plug into. Shipping the nav rail in Phase 6 means Phase 7 can deliver one screen at a time without re-architecting navigation.

**Independent Test**: After sign-in, the sidebar shows six items. Clicking each shows a centered text placeholder (e.g., "Overview — coming soon"). Window resize to 1280×800 shows no overflow warnings in debug mode.

**Acceptance Scenarios**:

1. **Given** an admin is signed in, **When** the Dashboard renders, **Then** the left side shows a `NavigationRail` with six destinations in this exact order: Overview, Jobs, Payments, Disputes, Support, Activity. Each destination has an icon and a label.
2. **Given** the Dashboard is open, **When** the admin clicks "Jobs", **Then** the selected index updates to 1 and the right content area shows a placeholder identifying the Jobs section.
3. **Given** the Dashboard is open, **When** the admin clicks "Overview" again after clicking another section, **Then** the Overview placeholder is shown.
4. **Given** the browser window is at least 1280×800, **When** the Dashboard renders, **Then** no Flutter layout overflow warnings appear and the nav rail + content area fit without horizontal scrolling.
5. **Given** the admin is on any section, **When** they refresh the browser, **Then** auth persists (they remain signed in) and the Dashboard re-renders. (The currently selected section does NOT need to persist across refresh for Phase 6.)

---

### User Story 4 — Service Layer Contract Stubs (Priority: P2)

Two Dart service classes are declared with all the method signatures that Phase 7 will implement. One method — `streamStats()` — is fully implemented because the Overview placeholder may optionally use it as a smoke test. Every other method throws `UnimplementedError`. The whole file must compile cleanly and be importable.

**Why this priority**: Phase 7 feature specs (separate spec per section) will each implement one or more of these methods. Declaring the contract in Phase 6 means Phase 7 specs can reference exact signatures without re-negotiating them.

**Independent Test**: `cd .claude/AdminWebApp && flutter analyze` exits 0. A scratch import of `AdminFirebaseService` and `AdminCloudFunctions` compiles. Calling any stub method at runtime throws `UnimplementedError` with a recognizable message.

**Acceptance Scenarios**:

1. **Given** `.claude/AdminWebApp/lib/services/admin_firebase_service.dart` exists with the declared method signatures, **When** `flutter analyze` runs, **Then** it reports zero issues.
2. **Given** `.claude/AdminWebApp/lib/services/admin_cloud_functions.dart` exists with the declared method signatures, **When** `flutter analyze` runs, **Then** it reports zero issues.
3. **Given** a test instantiates `AdminFirebaseService()` and calls `.streamActiveJobsAdmin()`, **When** the call executes, **Then** it throws `UnimplementedError('AdminFirebaseService.streamActiveJobsAdmin not implemented (Phase 7)')`.
4. **Given** a test instantiates `AdminFirebaseService()` and calls `.streamStats()`, **When** the call executes, **Then** it returns a `Stream<DocumentSnapshot<Map<String, dynamic>>>` that emits snapshots of `stats/global`.
5. **Given** a test instantiates `AdminCloudFunctions()` and calls `.assignJob('x', 'y')`, **When** the call executes, **Then** it throws `UnimplementedError('AdminCloudFunctions.assignJob not implemented (Phase 7)')`.

---

### User Story 5 — CI Validates Every Admin-Web PR (Priority: P3)

Any pull request that touches `.claude/AdminWebApp/**` triggers a GitHub Actions workflow that runs `flutter analyze` and `flutter build web --web-renderer html --release`. A failing build blocks the PR.

**Why this priority**: Catches broken imports and type errors before merge. Lower than P1/P2 because it's a developer-experience improvement, not a functional feature — a failing CI can be worked around temporarily by reverting.

**Independent Test**: Open a PR that intentionally adds a type error inside `.claude/AdminWebApp/lib/main.dart`. The workflow runs and fails with a red check. Revert the error, push again, workflow passes.

**Acceptance Scenarios**:

1. **Given** `.github/workflows/admin-web.yml` exists and is configured, **When** a PR modifies any file under `.claude/AdminWebApp/**`, **Then** the workflow is triggered.
2. **Given** the workflow is triggered, **When** it runs, **Then** it checks out the repo, sets up Flutter stable channel (whose Dart SDK satisfies the mobile project's `environment.sdk` constraint `^3.5.3` — the pin lives in `.claude/AdminWebApp/pubspec.yaml`, not in the GitHub Actions YAML), runs `flutter pub get` inside `.claude/AdminWebApp/`, runs `flutter analyze`, and runs `flutter build web --web-renderer html --release`.
3. **Given** a PR introduces a compile error inside `.claude/AdminWebApp/lib/`, **When** the workflow runs, **Then** it fails at the `flutter analyze` or `flutter build web` step and marks the PR check red.
4. **Given** a PR touches only files outside `.claude/AdminWebApp/`, **When** it is opened, **Then** the workflow does NOT run (to save CI minutes).

---

### Edge Cases

- **`stats/global` document does not exist when Overview placeholder loads**: `streamStats()` MUST handle the missing-doc case gracefully — the `StreamBuilder` consumer (when wired up in Phase 7) should be able to render an empty state. For Phase 6 we only need the stream to not throw.
- **Browser tab left open across token expiry**: The `authStateChanges()` stream handles this — when the token cannot refresh, the stream emits `null`, and the `AuthGate` falls back to the Login screen.
- **reCAPTCHA key is still the placeholder `YOUR_RECAPTCHA_V3_SITE_KEY`**: App Check activation call MUST fail loudly at app startup (not silently) so the deploy is visibly broken until a real key is installed. This means: do not wrap the `FirebaseAppCheck.instance.activate(...)` call in a silent try/catch.
- **Flutter tooling cross-contamination**: Never run `flutter pub get` / `flutter analyze` / `flutter build` at the repo root expecting it to affect `.claude/AdminWebApp/`. Always `cd .claude/AdminWebApp/` first. CI must also `cd` into the directory.
- **A user lands on the Dashboard URL but is already signed in as a non-admin from the mobile app**: The AuthGate's admin check re-runs on every mount, so this case is handled — they get the "Access denied" screen on web and stay signed in on mobile.
- **Clicking the same nav rail destination twice**: The rebuild must be cheap — do not re-create the content widget from scratch on every tap.
- **Flutter web renderer fallback**: Always build with `--web-renderer html`. The CanvasKit renderer is NOT supported by this spec (larger bundle, slower first paint, no benefit for a data-heavy admin UI).

---

## Requirements

### Functional Requirements

#### Project scaffold (Task 6-0)

- **FR-001**: The project MUST be created by running `flutter create --platforms web admin_web` from the repo root, then moving the resulting `admin_web/` folder to `.claude/AdminWebApp/`. After the move — but before any source or config edits (pubspec changes, new Dart files, etc.) — the raw Flutter scaffold at its final path MUST be committed to give a clean revert point. The `mv` itself is not considered "further modification"; only edits to file *contents* are.
- **FR-002**: `.claude/AdminWebApp/web/` directory MUST exist.
- **FR-003**: `.claude/AdminWebApp/pubspec.yaml` MUST declare only these dependencies (exact list, no extras, no mobile-only packages): `firebase_core`, `firebase_auth`, `cloud_firestore`, `cloud_functions`, `google_sign_in`, `google_fonts`, `firebase_app_check`. The Flutter SDK constraint MUST match the mobile project's `pubspec.yaml`.
- **FR-004**: `.claude/AdminWebApp/pubspec.yaml` MUST NOT declare any of these forbidden packages: `image_picker`, `flutter_image_compress`, `location`, `geolocator`, `video_player`, `flutter_local_notifications`, `sign_in_with_apple`, `workmanager`, `flutter_native_splash`.
- **FR-005**: `.claude/AdminWebApp/` MUST have its own `.dart_tool/` and `.flutter-plugins` after `flutter pub get`, distinct from the mobile project's.

#### Firebase config + placeholder deploy (Task 6-1)

- **FR-006**: `.claude/AdminWebApp/lib/main.dart` MUST call `WidgetsFlutterBinding.ensureInitialized()`, then `await Firebase.initializeApp(options: ...)` with the exact web config from `WOOHOO/Migration_Implementation_Plan.md` lines 67-78 (`projectId: syana-ea75a`, `apiKey: AIzaSyBDZlSoKBy_MWYeCUc27PVxBH7KYAfKfZ0`, `authDomain: syana-ea75a.firebaseapp.com`, `storageBucket: syana-ea75a.appspot.com`, `messagingSenderId: 850445794682`, `appId: 1:850445794682:web:0a05be4e3e0ccb1d5caac3`, `measurementId: G-KYNSN89SZS`).
- **FR-007**: `main.dart` MUST call `await FirebaseAppCheck.instance.activate(webProvider: ReCaptchaV3Provider('<SITE_KEY>'))` where `<SITE_KEY>` is a real reCAPTCHA Enterprise key (NOT the placeholder `YOUR_RECAPTCHA_V3_SITE_KEY`). If the key is still the placeholder at implementation time, the task MUST be paused until a real key is provided — do not ship with a placeholder.
- **FR-008**: The root `firebase.json` MUST contain a hosting block with `"public": ".claude/AdminWebApp/build/web"`, `"site": "syanat-admin"`, `"ignore": ["firebase.json", "**/.*", "**/node_modules/**"]`, and a single rewrite `[{ "source": "**", "destination": "/index.html" }]`.
- **FR-009**: The build command that CI and operators run MUST be exactly `flutter build web --web-renderer html --release` (run from `.claude/AdminWebApp/`). The CanvasKit renderer MUST NOT be used.
- **FR-010**: A preview channel deploy MUST be executed first via `firebase hosting:channel:deploy preview-shell` and verified before any `firebase deploy --only hosting:syanat-admin` is run.

#### CI (Task 6-1b)

- **FR-011**: A GitHub Actions workflow at `.github/workflows/admin-web.yml` MUST be triggered on pull requests whose changed paths include `.claude/AdminWebApp/**` or the workflow file itself.
- **FR-012**: The workflow MUST: checkout the repo, install Flutter (stable channel), run `flutter pub get` inside `.claude/AdminWebApp/`, run `flutter analyze` inside `.claude/AdminWebApp/`, and run `flutter build web --web-renderer html --release` inside `.claude/AdminWebApp/`. Any non-zero exit code MUST fail the workflow.
- **FR-013**: The workflow MUST NOT run on PRs that do not touch `.claude/AdminWebApp/**`.

#### Auth gate (Task 6-2)

- **FR-014**: `.claude/AdminWebApp/lib/auth/login_screen.dart` MUST render a login form constrained to `maxWidth: 400px`, with: email field, password field, "Sign in" button, "Sign in with Google" button, and an inline error-display area.
- **FR-015**: The email "Sign in" button MUST be disabled while a submission is in flight and MUST show a circular loading indicator.
- **FR-016**: The Google sign-in button MUST use `google_sign_in` + `FirebaseAuth.instance.signInWithCredential(...)`.
- **FR-017**: `.claude/AdminWebApp/lib/auth/auth_gate.dart` MUST define an `AuthGate` widget that wraps the app. It MUST use a `StreamBuilder<User?>` on `FirebaseAuth.instance.authStateChanges()`. When the stream emits `null`, it MUST show `LoginScreen`. When the stream emits a non-null `User`, it MUST render an internal `_AdminCheck` widget that performs the admin-role check.
- **FR-018**: `_AdminCheck` MUST, in `initState`, do a one-shot read of `users/{currentUser.uid}` via `FirebaseFirestore.instance`. If the document does not exist OR the `role` field is not equal to the string `'admin'`, it MUST call `await FirebaseAuth.instance.signOut()` BEFORE displaying the "Access denied" screen, so that `currentUser` is `null` by the time the denied screen is visible.
- **FR-019**: `_AdminCheck` MUST show a centered `CircularProgressIndicator` while the role check is in flight, an "Access denied" message if the check rejects the user, and the Dashboard shell if the check passes.
- **FR-020**: Login errors from Firebase Auth MUST be surfaced to the user as the raw `FirebaseAuthException.message` (or a friendly mapping thereof). They MUST NOT crash the app.

#### Navigation shell (Task 6-3)

- **FR-021**: `.claude/AdminWebApp/lib/dashboard/dashboard_screen.dart` MUST define a `DashboardScreen` widget that renders, inside a `Row`: a `NavigationRail` on the left with six destinations, a `VerticalDivider(thickness: 1)`, and an `Expanded` content area on the right.
- **FR-022**: The `AdminSection` enum MUST be declared with exactly these six values in this exact order: `overview`, `jobs`, `payments`, `disputes`, `support`, `activity`.
- **FR-023**: Each `NavigationRailDestination` MUST have an icon and a label: Overview → `Icons.dashboard`, Jobs → `Icons.work_outline`, Payments → `Icons.payments_outlined`, Disputes → `Icons.gavel`, Support → `Icons.support_agent`, Activity → `Icons.history`.
- **FR-024**: The content area MUST swap based on the selected destination. For this spec, each destination MAY render a simple placeholder `Text("<SectionName> — coming soon")` centered in its area. Phase 7 will replace these placeholders.
- **FR-025**: The Dashboard MUST NOT overflow at a 1280×800 viewport. No horizontal scrolling, no yellow-and-black overflow stripes in debug mode.

#### Service layer stubs (Task 6-4)

- **FR-026**: `.claude/AdminWebApp/lib/services/admin_firebase_service.dart` MUST declare a class `AdminFirebaseService` with a no-arg constructor and these methods (exact names and signatures — documented in the Key Entities section below). All methods except `streamStats()` MUST throw `UnimplementedError('AdminFirebaseService.<methodName> not implemented (Phase 7)')`.
- **FR-027**: `streamStats()` MUST return `Stream<DocumentSnapshot<Map<String, dynamic>>>` and MUST be implemented as `FirebaseFirestore.instance.doc('stats/global').snapshots()`.
- **FR-028**: `.claude/AdminWebApp/lib/services/admin_cloud_functions.dart` MUST declare a class `AdminCloudFunctions` with a no-arg constructor and these methods (exact names and signatures — see Key Entities). All methods MUST throw `UnimplementedError('AdminCloudFunctions.<methodName> not implemented (Phase 7)')`.
- **FR-029**: Both service files MUST compile under `flutter analyze` with zero errors and zero warnings.

#### Cross-cutting

- **FR-030**: The app's top-level widget MUST be a `MaterialApp` with `debugShowCheckedModeBanner: false` and a sensible default theme. Google Fonts usage is allowed but not required.
- **FR-031**: Every file created by this spec MUST live under `.claude/AdminWebApp/` (exception: `.github/workflows/admin-web.yml`, root `firebase.json` edits).
- **FR-032**: The mobile app at the repo root (`lib/`) MUST NOT be modified by this spec. Any change to `lib/` is out of scope and MUST be rejected during code review.
- **FR-033**: No service-account JSON files MUST be committed. `.gitignore` already covers `serviceAccountKey*.json` from Spec 002 — verify that coverage is still in place.

---

### Key Entities

- **`AdminFirebaseService`** — Dart class in `.claude/AdminWebApp/lib/services/admin_firebase_service.dart`. Phase 6 declares the full method list; Phase 7 fills in implementations. Methods:
  - `Stream<DocumentSnapshot<Map<String, dynamic>>> streamStats()` — IMPLEMENTED in Phase 6. Returns snapshots of `stats/global`.
  - `Stream<QuerySnapshot<Map<String, dynamic>>> streamActiveJobsAdmin()` — stub.
  - `Stream<QuerySnapshot<Map<String, dynamic>>> streamJobsByStatus(String status)` — stub.
  - `Stream<QuerySnapshot<Map<String, dynamic>>> streamAllPayments()` — stub.
  - `Stream<QuerySnapshot<Map<String, dynamic>>> streamSupportChats()` — stub. (Exact name — NOT `streamAllSupportChats`.)
  - `Stream<int> streamUnreadSupportCount()` — stub.
  - `Future<void> markSupportChatReadByAdmin(String chatId)` — stub.
  - `Future<void> closeSupportChat(String chatId)` — stub.
  - `Future<void> sendSupportMessage({required String chatId, required String text})` — stub.
  - `Future<List<Map<String, dynamic>>> fetchRecentUsers({int limit = 10})` — stub.
  - `Future<List<Map<String, dynamic>>> fetchRecentActivity({int limit = 50})` — stub.
  - `Future<List<String>> getAvailableTechnicianIdsByService(String serviceKey)` — stub.
  - `Future<void> initializeStatsGlobal()` — stub.

- **`AdminCloudFunctions`** — Dart class in `.claude/AdminWebApp/lib/services/admin_cloud_functions.dart`. Phase 6 declares the full method list; Phase 7 fills in implementations. All methods are stubs throwing `UnimplementedError`. Methods:
  - `Future<void> assignJob(String jobId, String technicianId)` — stub.
  - `Future<void> approvePayment(String paymentId)` — stub.
  - `Future<void> rejectPayment(String paymentId, String reason)` — stub.
  - `Future<void> resolveDispute(String jobId, String resolution, String reason, {double? overrideAmount})` — stub.
  - `Future<void> closeJob(String jobId, double amountPaid)` — stub.

- **`AdminSection` enum** — Dart enum in `.claude/AdminWebApp/lib/dashboard/dashboard_screen.dart`. Values: `overview`, `jobs`, `payments`, `disputes`, `support`, `activity` (exact order).

- **`AuthGate` widget** — Top-level auth boundary. Wraps the entire app below `MaterialApp`.

- **`LoginScreen` widget** — Email/password + Google sign-in form. Lives in `.claude/AdminWebApp/lib/auth/login_screen.dart`.

- **`DashboardScreen` widget** — Post-auth shell with nav rail and content area. Lives in `.claude/AdminWebApp/lib/dashboard/dashboard_screen.dart`.

---

## Success Criteria

### Measurable Outcomes

- **SC-001**: An admin can visit the deployed preview URL (`hosting:channel:deploy preview-shell`) and complete sign-in → dashboard within 30 seconds in a first-time browser session.
- **SC-002**: Browser console shows ZERO error-level messages from the app on a cold load of the deployed shell with zero interactions.
- **SC-003**: A non-admin account signing in is signed out and shown "Access denied" within 2 seconds; `FirebaseAuth.instance.currentUser` is `null` within 200ms of the denied screen rendering.
- **SC-004**: `flutter analyze` (run from `.claude/AdminWebApp/`) reports zero issues after every task in this spec lands.
- **SC-005**: `flutter build web --web-renderer html --release` (run from `.claude/AdminWebApp/`) exits 0 and produces `build/web/` on any developer OS (Windows, Linux, or macOS). CI verifies the Linux build on every PR; Windows/macOS are verified by local developer builds and are NOT required to be part of the CI matrix for Phase 6.
- **SC-006**: The GitHub Actions workflow triggered by the first PR against `.claude/AdminWebApp/**` runs to completion in under 10 minutes and reports the correct pass/fail status.
- **SC-007**: A PR that does NOT touch `.claude/AdminWebApp/**` does NOT trigger the admin-web workflow.
- **SC-008**: All six nav-rail destinations render their placeholder without layout overflow at a 1280×800 viewport.

---

## Assumptions

- **A-1**: A real reCAPTCHA Enterprise site key for `syana-ea75a` is registered in Firebase Console and available to whoever implements FR-007 before Task 6-1 deploy. If not, implementation pauses there.
- **A-2**: The Firebase project `syana-ea75a` already has an admin user (`users/{admin-uid}` with `role: 'admin'`) that the implementer can use to test sign-in end-to-end.
- **A-3**: The Firebase Hosting site `syanat-admin` either already exists in the Firebase project or will be created by the implementer via `firebase hosting:sites:create syanat-admin` before the first `firebase deploy --only hosting:syanat-admin`.
- **A-4**: `.claude/` is and remains not-gitignored. If this changes, CI breaks and FR-011 / FR-013 must be revisited.
- **A-5**: The Flutter SDK version on developer machines and CI matches the version already pinned by the mobile project's `pubspec.yaml`. No version upgrade is introduced by this spec.
- **A-6**: The mobile admin flows (`login_screen.dart` admin route, `admin_dashboard_screen.dart`, etc.) remain untouched by this spec. They will be removed in Phase 8, not here.
- **A-7**: `google_sign_in` is configured in the Firebase Console for the web app (OAuth 2.0 client ID, authorized domains). If not, Google sign-in will fail at runtime and the implementer must flag this to a human before shipping Task 6-2.
- **A-8**: The implementer has authority to run `firebase hosting:channel:deploy` and `firebase deploy --only hosting:syanat-admin` (Firebase CLI is authenticated to the project).
- **A-9**: No existing hosting block in `firebase.json` needs to be preserved. If one exists and serves a different app, the implementer pauses and asks a human — multi-site hosting setup is out of scope.
- **A-10**: The two new state-machine clauses added in Spec 003 (`technician-cancel-before-acceptance`, `customer-soft-delete-terminal-jobs`) are either approved by product or rolled back BEFORE this spec runs. This spec does not depend on them, but they affect the shape of data the Phase 7 feature screens will read, so their status should be known.
