---
description: "Task list for Spec 004 — Admin Web App Shell"
---

# Tasks: Admin Web App Shell

**Input**: Design documents from `/specs/004-admin-web-shell/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅

**Tests**: The spec does NOT request unit/widget tests. Verification is via `flutter analyze`, `flutter build web`, CI workflow, preview-channel deploy, and the 7-item operator smoke-test checklist from `contracts/ui-contracts.md`. No test tasks are generated.

**Organization**: Tasks are grouped by user story (US1–US5). Each user story is an independently testable vertical slice. The checkpoints at the end of each phase correspond to the spec's Acceptance Scenarios.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on another incomplete task)
- **[Story]**: The user story this task serves — US1 (P1/MVP), US2 (P1), US3 (P1), US4 (P2), US5 (P3)

## Path Conventions

- Admin web project root: `.claude/AdminWebApp/` (path OVERRIDE of constitution Principle II — see plan.md Complexity Tracking)
- Every `flutter` command in this task list MUST be run from inside `.claude/AdminWebApp/`.
- Root-level touches: `firebase.json` and `.github/workflows/admin-web.yml` only. **Do NOT modify `lib/` (mobile app) — FR-032.**

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Scaffold the Flutter Web project, move it into its final location, declare dependencies, and run the initial `pub get`.

- [ ] T001 Pre-flight: confirm `.claude` is NOT listed as a gitignore entry (Assumption A-4). Run `grep -nE '^\.claude(/|$)' .gitignore` — MUST return zero matches. If it returns anything, STOP and escalate: CI path filters depend on `.claude/AdminWebApp/**` being tracked. Then run `flutter create --platforms web admin_web` from repo root `C:\Users\LTC\Downloads\Syanat-main-mine\Syanat-lastupdate\` to scaffold a bare Flutter Web project at `admin_web/`.
- [X] T002 Move the scaffolded directory to its final location: `mkdir -p .claude && mv admin_web .claude/AdminWebApp`. Final path: `C:\Users\LTC\Downloads\Syanat-main-mine\Syanat-lastupdate\.claude\AdminWebApp\`.
- [ ] T003 Commit the raw, unmodified scaffold as a clean revert point: `git add .claude/AdminWebApp && git commit -m "Spec 004: scaffold Flutter Web admin app at .claude/AdminWebApp (Task 6-0)"`.
- [X] T004 Edit `.claude/AdminWebApp/pubspec.yaml` — set `environment.sdk: ^3.5.3` (matching repo-root `pubspec.yaml` line 22), and replace the `dependencies:` block with ONLY these packages (no version pins — let pub resolve): `firebase_core`, `firebase_auth`, `cloud_firestore`, `cloud_functions`, `google_sign_in`, `google_fonts`, `firebase_app_check`. Keep `flutter: sdk: flutter`. Explicitly verify NONE of these appear: `image_picker`, `flutter_image_compress`, `location`, `geolocator`, `video_player`, `flutter_local_notifications`, `sign_in_with_apple`, `workmanager`, `flutter_native_splash` (FR-003, FR-004).
- [ ] T005 Run `flutter pub get` from inside `.claude/AdminWebApp/`. Confirm `.claude/AdminWebApp/.dart_tool/` and `.claude/AdminWebApp/.flutter-plugins` are created. If they landed at repo root, revert and re-run from inside the project directory (Principle VI).
- [X] T006 [P] Edit `.claude/AdminWebApp/web/index.html` — inside `<head>`, add `<meta name="google-signin-client_id" content="<WEB_CLIENT_ID>.apps.googleusercontent.com">`. The `<WEB_CLIENT_ID>` value comes from Firebase Console → Auth → Sign-in method → Google → Web SDK config. (FR-016, research.md R13.)
- [X] T007 [P] Verify `.gitignore` at repo root already covers service-account JSONs (`serviceAccountKey*.json`, `**/serviceAccountKey*.json`). If not, add those lines (FR-033, Principle VIII).

**Checkpoint**: `.claude/AdminWebApp/` is a valid Flutter Web project with the exact allow-listed dependencies installed.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Everything required by all three P1 user stories: Firebase init + App Check activation, MaterialApp root, `firebase.json` hosting block, and a passing `flutter analyze`.

**⚠️ CRITICAL**: US1, US2, US3 cannot be implemented until this phase completes.

**⚠️ GATE** (Principle VIII): A real reCAPTCHA Enterprise v3 site key MUST be obtained from Firebase Console before T009. If the key is not yet available, STOP — do not substitute the placeholder `YOUR_RECAPTCHA_V3_SITE_KEY` even for local testing. Shipping or even previewing the placeholder is forbidden.

- [X] T008 Create `.claude/AdminWebApp/lib/main.dart` (overwriting the scaffold default). Add imports for `package:flutter/material.dart`, `package:firebase_core/firebase_core.dart`, `package:firebase_app_check/firebase_app_check.dart`. Implement `Future<void> main()` that calls `WidgetsFlutterBinding.ensureInitialized()`, then `await Firebase.initializeApp(options: const FirebaseOptions(...))` with the EXACT values from FR-006 / data-model.md §7: `apiKey: 'AIzaSyBDZlSoKBy_MWYeCUc27PVxBH7KYAfKfZ0'`, `appId: '1:850445794682:web:0a05be4e3e0ccb1d5caac3'`, `messagingSenderId: '850445794682'`, `projectId: 'syana-ea75a'`, `authDomain: 'syana-ea75a.firebaseapp.com'`, `storageBucket: 'syana-ea75a.appspot.com'`, `measurementId: 'G-KYNSN89SZS'`.
- [X] T009 In `.claude/AdminWebApp/lib/main.dart`, after the `Firebase.initializeApp` await, add `await FirebaseAppCheck.instance.activate(webProvider: ReCaptchaV3Provider('<REAL_KEY>'))` using the real reCAPTCHA Enterprise v3 site key obtained for `syana-ea75a`. DO NOT wrap this call in a try/catch — failure must propagate (spec Edge Case). The literal string `YOUR_RECAPTCHA_V3_SITE_KEY` MUST NOT appear anywhere in the file (FR-007, Principle VIII).
- [X] T010 In `.claude/AdminWebApp/lib/main.dart`, define a private `_AdminApp extends StatelessWidget` whose `build` returns `MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData.light(useMaterial3: true), home: <PLACEHOLDER>)`. The `useMaterial3: true` flag is REQUIRED (not optional) — without it the shell's visuals will silently shift as Flutter's default flips across versions (research R7). `<PLACEHOLDER>` is a temporary centered `Text('Syanat Admin')` scaffold for US1; US2 replaces it with `AuthGate`. Call `runApp(const _AdminApp())` from `main`. (FR-030.)
- [X] T011 Pre-flight: confirm `firebase.json` does NOT already have a `hosting` block (Assumption A-9). Run `node -e "const j=require('./firebase.json'); if(j.hosting){console.error('hosting exists — pause per A-9'); process.exit(1)} else {console.log('ok')}"` — MUST print `ok`. If it fails, STOP and ask a human; merging a second hosting config is out of scope for Spec 004. Then edit `firebase.json` at repo root and add a top-level `"hosting"` key alongside the existing `firestore`, `storage`, `functions`, `emulators` keys, with exact content: `{"site": "syanat-admin", "public": ".claude/AdminWebApp/build/web", "ignore": ["firebase.json", "**/.*", "**/node_modules/**"], "rewrites": [{"source": "**", "destination": "/index.html"}]}`. (FR-008, research.md R12.)
- [ ] T012 Run `cd .claude/AdminWebApp && flutter analyze` and confirm "No issues found!" (SC-004). Fix any issues before proceeding. Then run `cd .claude/AdminWebApp && flutter build web --web-renderer html --release` and confirm exit code 0 and presence of `.claude/AdminWebApp/build/web/index.html` (FR-009, SC-005).

**Checkpoint**: Foundation ready. US1 can now ship a preview deploy; US2 and US3 can be built in parallel afterward.

---

## Phase 3: User Story 1 — Deployed Shell Loads Without Errors (Priority: P1) 🎯 MVP

**Goal**: Prove the full Firebase-Hosting + App Check + Flutter Web pipeline works end-to-end. A browser visits the preview URL, the placeholder renders, zero console errors, zero App Check 403s.

**Independent Test**: `firebase hosting:channel:deploy preview-shell --project syana-ea75a` → open preview URL → confirm page renders `Syanat Admin` placeholder AND browser devtools Console shows zero error-level messages from the app AND Network tab shows zero 403s on Firebase endpoints.

### Implementation for User Story 1

- [ ] T013 [US1] Re-verify `.claude/AdminWebApp/lib/main.dart` renders the `Text('Syanat Admin')` placeholder (the one installed in T010) and that `flutter build web --web-renderer html --release` still produces `.claude/AdminWebApp/build/web/` with that text reachable in the built bundle. (`grep -l "Syanat Admin" .claude/AdminWebApp/build/web/main.dart.js` should succeed.)
- [ ] T014 [US1] From repo root, run `firebase hosting:channel:deploy preview-shell --project syana-ea75a`. Capture the printed preview URL. If the command fails with "site not found", run `firebase hosting:sites:create syanat-admin --project syana-ea75a` (one-time, per Assumption A-3) and re-deploy. (FR-010, Principle IV.)
- [ ] T015 [US1] Open the preview URL in Chrome. Open devtools → Console. Reload the page. Acceptance criteria (US1 AS1–AS4, SC-002): (a) Page shows the `Syanat Admin` placeholder within 30 s. (b) Console has zero error-level messages from the app. (c) Network tab shows zero 403 responses from App Check (`*.googleapis.com/firebase/*/appCheck*`). (d) `grep -R "YOUR_RECAPTCHA_V3_SITE_KEY" .claude/AdminWebApp/build/web/` returns zero matches.

**Checkpoint**: US1 is deployable and independently demoable. The migration has a live preview URL. Stop here for an MVP demo if needed.

---

## Phase 4: User Story 2 — Admin-Only Authentication Gate (Priority: P1)

**Goal**: Gate the app behind Firebase Auth. Non-admin authenticated users get signed out before seeing a denied screen.

**Independent Test**: Visit preview URL (built after this phase) → see `LoginScreen`. Sign in as admin → transition to placeholder dashboard. Sign out. Sign in as a customer → "Access denied" shows; `FirebaseAuth.instance.currentUser` is `null` within 200 ms of that screen rendering (checked in devtools console).

### Implementation for User Story 2

- [X] T016 [P] [US2] Create `.claude/AdminWebApp/lib/auth/login_screen.dart`. Implement `class LoginScreen extends StatefulWidget` per `contracts/ui-contracts.md §2` and `data-model.md §5`: `Scaffold` with centered `ConstrainedBox(maxWidth: 400)`, email `TextFormField`, password `TextFormField(obscureText: true)`, inline red error `Text` driven by `_errorMessage`, "Sign in" `ElevatedButton` wired to `FirebaseAuth.instance.signInWithEmailAndPassword`, "Sign in with Google" `OutlinedButton` wired via `google_sign_in` + `FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(idToken: ..., accessToken: ...))`. Disable submit button while `_submitting == true` and render `CircularProgressIndicator` inside it. Dispose both `TextEditingController`s in `dispose()`. On `FirebaseAuthException`, set `_errorMessage = e.message` — NEVER show stack traces or raw JSON (Principle XIII). (FR-014, FR-015, FR-016, FR-020.)
- [X] T017 [US2] Create `.claude/AdminWebApp/lib/auth/auth_gate.dart`. Implement `class AuthGate extends StatelessWidget` using `StreamBuilder<User?>` over `FirebaseAuth.instance.authStateChanges()`. On `ConnectionState.waiting`: centered `CircularProgressIndicator`. On `snap.data == null`: `const LoginScreen()`. On `snap.data != null`: `_AdminCheck(user: snap.data!, key: ValueKey(snap.data!.uid))`. (FR-017.)
- [X] T018 [US2] In the same file `.claude/AdminWebApp/lib/auth/auth_gate.dart`, implement private `class _AdminCheck extends StatefulWidget`. In `initState`, launch a one-shot `FirebaseFirestore.instance.doc('users/${widget.user.uid}').get()`. While pending: centered `CircularProgressIndicator`. On resolve: if `snap.exists && snap.data()?['role'] == 'admin'` → render `const DashboardScreen()` (import from `../dashboard/dashboard_screen.dart` — US3 will create this file, so US2 temporarily uses a `Scaffold(body: Center(child: Text('Admin placeholder')))` and US3 swaps it). **If check fails for ANY reason** (missing doc, wrong role, thrown exception): `await FirebaseAuth.instance.signOut()` BEFORE the `setState` that shows "Access denied". On any exception, fail closed. (FR-018, FR-019, Principle IX — the signOut-before-setState ordering is non-negotiable.)
- [X] T019 [US2] Edit `.claude/AdminWebApp/lib/main.dart`. Replace the US1 placeholder in `_AdminApp.build()` with `home: const AuthGate()`. Add the `import 'auth/auth_gate.dart';`. (FR-017.)
- [ ] T020 [US2] Run `cd .claude/AdminWebApp && flutter analyze` — zero issues. Run `flutter build web --web-renderer html --release` — exit 0. Deploy to preview: `firebase hosting:channel:deploy preview-shell --project syana-ea75a`. Perform US2 smoke tests from `contracts/ui-contracts.md §4` items 1–4: unauthed → Login, bad creds → inline error no crash, admin sign-in → (Admin placeholder) appears, non-admin sign-in → "Access denied" visible AND `FirebaseAuth.instance.currentUser === null` in devtools console. (FR-018, Principle IX verification.)

**Checkpoint**: US2 independently verified. Non-admin session is provably dead before the denied screen renders.

---

## Phase 5: User Story 3 — Six-Section Navigation Shell (Priority: P1)

**Goal**: A post-auth dashboard with a left `NavigationRail` of six destinations and a content area that swaps placeholders.

**Independent Test**: Sign in as admin (via US2) → `DashboardScreen` appears with `NavigationRail` showing Overview/Jobs/Payments/Disputes/Support/Activity. Click each → content area swaps to that section's placeholder. At 1280×800, no overflow warnings. Refresh → auth persists.

### Implementation for User Story 3

- [X] T021 [US3] Create `.claude/AdminWebApp/lib/dashboard/dashboard_screen.dart`. At file scope (not inside the class), declare `enum AdminSection { overview, jobs, payments, disputes, support, activity }` — exactly these six values in exactly this order. (FR-022, data-model.md §3.)
- [X] T022 [US3] In the same file, implement `class DashboardScreen extends StatefulWidget` with `_DashboardScreenState` holding `int _selectedIndex = 0`. Build method returns `Scaffold(body: Row(children: [NavigationRail(...), const VerticalDivider(thickness: 1, width: 1), Expanded(child: IndexedStack(index: _selectedIndex, children: [...6 placeholders...]))]))`. (FR-021, FR-025, research.md R6.)
- [X] T023 [US3] Configure the `NavigationRail` per FR-023 / data-model.md §6: `labelType: NavigationRailLabelType.all`, `selectedIndex: _selectedIndex`, `onDestinationSelected: (i) => setState(() => _selectedIndex = i)`, and `destinations` as six `const NavigationRailDestination(icon: Icon(...), label: Text('...'))` entries in the exact order and with the exact icons: `Icons.dashboard`/"Overview", `Icons.work_outline`/"Jobs", `Icons.payments_outlined`/"Payments", `Icons.gavel`/"Disputes", `Icons.support_agent`/"Support", `Icons.history`/"Activity".
- [X] T024 [US3] Add six private `const` placeholder widgets inside the same file (e.g., `class _SectionPlaceholder extends StatelessWidget { final String name; const _SectionPlaceholder(this.name); ... }` returning `Center(child: Text('$name — coming soon'))`). Wire them into the `IndexedStack.children` in the same order as `AdminSection.values`. The Overview placeholder MAY optionally wrap its text in a `StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>` over `AdminFirebaseService().streamStats()` once US4 ships — leave a TODO comment for US4 to wire it. (FR-024, research.md R10.)
- [X] T025 [US3] Edit `.claude/AdminWebApp/lib/auth/auth_gate.dart`. In `_AdminCheckState.build()`, replace the temporary "Admin placeholder" widget from T018 with `const DashboardScreen()`. Add `import '../dashboard/dashboard_screen.dart';`.
- [ ] T026 [US3] Run `cd .claude/AdminWebApp && flutter analyze` — zero issues. Run `flutter build web --web-renderer html --release` — exit 0. Deploy to preview, sign in as admin, resize window to 1280×800, click each of the six rail destinations. Confirm: no yellow-and-black overflow stripes in debug, no horizontal scrollbar, content area swaps correctly. (US3 AS1–AS5, SC-008.)

**Checkpoint**: US3 independently verified. The 6-section shell is the target Phase 7 features will plug into.

---

## Phase 6: User Story 4 — Service Layer Contract Stubs (Priority: P2)

**Goal**: Declare the full Phase 7 service-method surface so feature specs can reference exact signatures. `streamStats()` is real; everything else throws `UnimplementedError`.

**Independent Test**: `cd .claude/AdminWebApp && flutter analyze` exits 0. A scratch main() importing both classes and calling each stub throws `UnimplementedError` with a recognizable message containing the method name. Calling `.streamStats()` returns a live Firestore stream.

### Implementation for User Story 4

- [X] T027 [P] [US4] Create `.claude/AdminWebApp/lib/services/admin_firebase_service.dart`. Import `package:cloud_firestore/cloud_firestore.dart`. Implement `class AdminFirebaseService` with no-arg constructor and the 13 methods from `data-model.md §1` / `contracts/admin-firebase-service.md`. `streamStats()` returns `FirebaseFirestore.instance.doc('stats/global').snapshots()`. All 12 other methods throw `UnimplementedError('AdminFirebaseService.<methodName> not implemented (Phase 7)')` — exact template, method name substituted. Method names: `streamActiveJobsAdmin`, `streamJobsByStatus`, `streamAllPayments`, `streamSupportChats` (NOT `streamAllSupportChats`), `streamUnreadSupportCount`, `markSupportChatReadByAdmin`, `closeSupportChat`, `sendSupportMessage`, `fetchRecentUsers`, `fetchRecentActivity`, `getAvailableTechnicianIdsByService`, `initializeStatsGlobal`. (FR-026, FR-027.)
- [X] T028 [P] [US4] Create `.claude/AdminWebApp/lib/services/admin_cloud_functions.dart`. Import `package:cloud_functions/cloud_functions.dart`. Implement `class AdminCloudFunctions` with no-arg constructor and 5 methods from `data-model.md §2` / `contracts/admin-cloud-functions.md`: `assignJob(String, String)`, `approvePayment(String)`, `rejectPayment(String, String)`, `resolveDispute(String, String, String, {double? overrideAmount})`, `closeJob(String, double)`. All 5 throw `UnimplementedError('AdminCloudFunctions.<methodName> not implemented (Phase 7)')`. Do NOT call `FirebaseFunctions.instance` anywhere — the package import is there only so Phase 7 doesn't need to edit the import list. (FR-028.)
- [X] T029 [US4] (Optional smoke-test wiring.) In `.claude/AdminWebApp/lib/dashboard/dashboard_screen.dart`, change the Overview placeholder to wrap its text in `StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(stream: AdminFirebaseService().streamStats(), builder: (c, s) => Center(child: Text('Overview — coming soon')))`. The builder ignores stream state — this is purely a smoke test that the Firestore read path works through App Check. (research.md R10.)
- [ ] T030 [US4] Run `cd .claude/AdminWebApp && flutter analyze` — zero issues and zero warnings (FR-029). Add a throwaway `.claude/AdminWebApp/test_stub_smoketest.dart` (NOT in `test/`, just scratch) that instantiates both classes and calls two stubs inside try/catch, then `flutter run -d chrome` briefly to confirm the `UnimplementedError.message` contains the method name. Delete the scratch file. Do NOT commit it.

**Checkpoint**: US4 independently verified. Phase 7 feature specs can now reference exact method signatures.

---

## Phase 7: User Story 5 — CI Validates Every Admin-Web PR (Priority: P3)

**Goal**: A GitHub Actions workflow runs `flutter analyze` + `flutter build web --web-renderer html --release` on PRs touching `.claude/AdminWebApp/**`. Path filter prevents it running on unrelated PRs.

**Independent Test**: Open a PR that introduces a compile error inside `.claude/AdminWebApp/lib/main.dart` → workflow runs and fails red. Revert the error → workflow passes green. Open a PR touching only `README.md` → workflow does NOT trigger.

### Implementation for User Story 5

- [X] T031 [US5] Create `.github/workflows/admin-web.yml` (absolute path: `C:\Users\LTC\Downloads\Syanat-main-mine\Syanat-lastupdate\.github\workflows\admin-web.yml`). Shape per `research.md R8` / `quickstart.md Step 6`: trigger on `pull_request` with `paths: ['.claude/AdminWebApp/**', '.github/workflows/admin-web.yml']`. Job `analyze-and-build` on `ubuntu-latest` with `defaults: run: working-directory: .claude/AdminWebApp`. Steps: `actions/checkout@v4`, `subosito/flutter-action@v2` with `channel: stable`, `flutter --version`, `flutter pub get`, `flutter analyze`, `flutter build web --web-renderer html --release`. No caching in Phase 6 — add later if the run exceeds SC-006's 10-minute budget. (FR-011, FR-012, FR-013.)
- [ ] T032 [US5] Verify RED path: open a PR that adds a deliberate compile error inside `.claude/AdminWebApp/lib/main.dart` (e.g., a stray `;;` or a reference to an undefined identifier). Confirm the workflow triggers, runs, and fails at the `flutter analyze` or `flutter build web` step, marking the PR check red (US5 AS3). Then revert the error with another commit on the same PR branch and confirm the workflow re-runs and goes green (US5 AS2). **Timing assertion (SC-006)**: read the green-run duration from the GH Actions UI (or `gh run view <run-id> --json durationMs`) and confirm it is under 10 minutes. If it exceeds 10 min, add `actions/cache@v4` caching for `~/.pub-cache` in T031 before merging.
- [ ] T033 [US5] Verify SCOPE filter: open a separate PR that touches ONLY a file outside `.claude/AdminWebApp/` (e.g., editing `README.md` or any file at repo root other than the workflow itself). Confirm the `Admin Web` workflow does NOT appear in the PR's check list (US5 AS4, SC-007). If it triggers, the `paths:` filter is wrong and must be corrected.

**Checkpoint**: US5 independently verified. CI now blocks regressions on the admin web project before merge.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final security sweep, production deploy, housekeeping.

- [X] T034 [P] Security sweep — no placeholder reCAPTCHA: `grep -R "YOUR_RECAPTCHA_V3_SITE_KEY" .claude/AdminWebApp/ firebase.json` MUST return zero matches (Principle VIII, quickstart.md Definition-of-Done #6).
- [X] T035 [P] Security sweep — no service-account keys anywhere in the admin web tree: `grep -R "serviceAccountKey" .claude/AdminWebApp/` MUST return zero matches; `.gitignore` still covers `**/serviceAccountKey*.json`. (FR-033.)
- [X] T036 [P] Scope sweep — `git diff origin/main -- lib/` MUST show zero changes (FR-032 / Principle II — mobile app untouched).
- [ ] T037 [P] Dependency review — run `cd .claude/AdminWebApp && flutter pub outdated` and review output. If any package is marked as having a known-vulnerable version, upgrade before deploy (Principle XII).
- [X] T037a [P] Logging sweep — Principle XIII verification from plan.md Security Review Gate: `grep -RnE "^[[:space:]]*(print|debugPrint)[[:space:]]*\(" .claude/AdminWebApp/lib/` MUST return zero matches. If any match is found, remove the offending `print` / `debugPrint` call (the Phase 6 shell has no legitimate logging; Phase 7 features will introduce structured logging via `package:logging` or similar).
- [X] T037b [P] Scope sweep — FR-031 verification: every file changed by this branch MUST live under one of the allow-listed roots. Run `git diff --name-only origin/main...HEAD \| grep -v -E '^(\.claude/AdminWebApp/\|\.github/workflows/admin-web\.yml$\|firebase\.json$\|specs/004-admin-web-shell/\|CLAUDE\.md$)'` and confirm it returns zero lines. Any line returned indicates a rogue file that violates FR-031; investigate and revert.
- [ ] T038 Production deploy: `firebase deploy --only hosting:syanat-admin --project syana-ea75a`. Expect the production URL `https://syanat-admin.web.app` to be live. DO NOT run this until T015, T020, T026, and T034–T037b have all passed (Principle IV — preview-first, diff-reviewed deploys).
- [ ] T039 [P] Production smoke tests — run the seven-item checklist from `contracts/ui-contracts.md §4` against the PRODUCTION URL (not the preview). Document pass/fail for each; any fail blocks sign-off.
- [X] T040 Update `CLAUDE.md` already handled by the agent-context script during `/speckit.plan`. Verify the Spec 004 entry is present. If missing, re-run `.specify/scripts/powershell/update-agent-context.ps1 -AgentType claude`.
- [ ] T041 Final commit — stage any remaining unstaged changes (T003 already committed the raw scaffold in Phase 1; T041 only picks up anything still pending): `git add specs/004-admin-web-shell .claude/AdminWebApp .github/workflows/admin-web.yml firebase.json CLAUDE.md && git status` → if nothing is staged, skip the commit; otherwise `git commit -m "Spec 004: admin web shell with auth gate, nav shell, service stubs, CI"`. Open PR against `main`.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup, T001–T007)**: No external dependencies. T001 → T002 → T003 → T004 → T005 must run in strict order (each touches state the next reads). T006 and T007 are `[P]` with each other and with T005 once T005 completes.
- **Phase 2 (Foundational, T008–T012)**: Depends on Phase 1 complete. T008 → T009 → T010 in sequence (all touch `main.dart`). T011 is `[P]` with T008–T010 (different file: `firebase.json`). T012 requires T008–T011.
- **Phase 3 (US1, T013–T015)**: Depends on Phase 2.
- **Phase 4 (US2, T016–T020)**: Depends on Phase 2. US2 is unit-testable in isolation via `flutter run -d chrome` — it does NOT strictly require US1 (T013–T015) to have shipped a preview. In practice, running T014 first is cheap insurance that the full hosting pipeline works before you add auth complexity, so sequencing US1 → US2 is recommended but not mandatory. T016 is `[P]` with T017–T018 (different files). T019 depends on T017. T020 depends on T016–T019.
- **Phase 5 (US3, T021–T026)**: Depends on Phase 2. Can run in parallel with US2 if two engineers are available (T017/T018 in US2 reference `DashboardScreen` but US3 creates it — if working in parallel, use a temporary `Scaffold(body: Center(child: Text('Admin placeholder')))` in US2 as documented in T018, and US3 swaps it in T025). If sequential: US2 first, then US3.
- **Phase 6 (US4, T027–T030)**: Depends on Phase 2. T027 and T028 are `[P]` (different files). T029 depends on T021–T024 (US3 must exist before wiring the Overview StreamBuilder). T030 depends on T027–T029.
- **Phase 7 (US5, T031–T033)**: Depends on Phase 1 existing (so the workflow has a project to build). Can run in parallel with US2/US3/US4 — no source-code dependency.
- **Phase 8 (Polish, T034–T041)**: Depends on all user stories complete. T034, T035, T036, T037, T037a, T037b are all `[P]` with each other (independent grep/diff/CLI commands on disjoint surfaces). T038 depends on ALL of T034–T037b passing. T039 depends on T038. T040 and T041 are sequential housekeeping after T039.

### User Story Dependencies

- **US1 (T013–T015)**: Needs only Phase 2. Placeholder page, no auth, no nav.
- **US2 (T016–T020)**: Needs Phase 2. References `DashboardScreen` but works with a temporary placeholder until US3 ships — independently testable with that placeholder.
- **US3 (T021–T026)**: Needs Phase 2. Does not require US2 to be tested in isolation if the implementer temporarily sets `home: const DashboardScreen()` directly — but the final wiring goes through `AuthGate._AdminCheck`.
- **US4 (T027–T030)**: Needs Phase 2. Independent of US2/US3 for the contract itself; the optional Overview smoke-test wiring in T029 touches US3's file.
- **US5 (T031–T033)**: Needs Phase 1 only (can actually run CI even with a half-finished US1/US2/US3, since `flutter analyze + build` will pass on any valid project). Fully independent.

### Parallel Opportunities

- **Setup `[P]` block**: T006 + T007 once T005 is done.
- **Foundational `[P]`**: T011 (`firebase.json`) alongside T008–T010 (main.dart).
- **Multi-engineer split once Phase 2 ends**: Engineer A = US1 → US2, Engineer B = US3, Engineer C = US4, Engineer D = US5. Merge when all complete.
- **Within US4**: T027 `[P]` T028 (different files).
- **Within US2**: T016 `[P]` T017 (different files).
- **Polish `[P]`**: T034 + T035 + T036 + T037 + T037a + T037b all independent grep/diff commands, safe to run concurrently.

---

## Parallel Example: Phase-2 Foundational

```bash
# After Phase 1 completes, run these in parallel across two engineers:
Engineer 1: T008 → T009 → T010   # main.dart (sequential — same file)
Engineer 2: T011                  # firebase.json (independent file)

# After both finish, T012 runs the analyze + build gate.
```

## Parallel Example: US4

```bash
# Two engineers after Phase 2:
Engineer A: T027  # admin_firebase_service.dart
Engineer B: T028  # admin_cloud_functions.dart

# Then serially: T029 (touches US3's file), T030 (verification).
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 Setup (T001–T007).
2. Phase 2 Foundational (T008–T012).
3. Phase 3 US1 (T013–T015).
4. **STOP and VALIDATE**: preview URL is live, browser console clean.
5. Demo if ready. This is the smallest shippable Phase 6 artifact.

### Incremental Delivery (Recommended)

1. Setup + Foundational (Phases 1–2).
2. US1 (Phase 3) → preview deploy → demo MVP.
3. US2 (Phase 4) → re-preview → admin can sign in.
4. US3 (Phase 5) → re-preview → nav rail visible.
5. US4 (Phase 6) → re-preview → Overview smoke test green.
6. US5 (Phase 7) → CI active.
7. Polish (Phase 8) → production deploy.

### Parallel Team Strategy

With 3–4 engineers, after Phase 2 finishes:
- **Engineer A**: US1 → US2 (sequential, both P1).
- **Engineer B**: US3.
- **Engineer C**: US4 (note T029 touches US3's file — coordinate with B).
- **Engineer D**: US5 (no source-code coupling).
Merge sequentially in the order: US1, US2, US3, US4, US5.

---

## Notes

- `[P]` marker = different files, no dependency on an incomplete task. When in doubt, do NOT mark a task `[P]`.
- Every Flutter command in every task MUST run from inside `.claude/AdminWebApp/` (Principle VI — tooling isolation).
- The path `.claude/AdminWebApp/` is a deliberate override of the constitution's `admin_web/` — documented in plan.md Complexity Tracking. CI path filters must match this override.
- T009 and T010 and T017 and T018 each contain a security-review-gate-critical assertion (real reCAPTCHA key, no placeholder; signOut-before-setState). Reviewers MUST check these specifically in code review, not just rely on `flutter analyze` passing.
- Commit cadence: one commit per task group (Phase 1, Phase 2, US1, US2, US3, US4, US5, Polish) is fine; one commit per individual task is also fine. Do NOT bundle Phase 2 into the same commit as US1 because the Phase-2 commit is a natural revert point if App Check activation fails.
- If CI ever times out beyond SC-006's 10-minute budget, add `actions/cache@v4` for `~/.pub-cache` — follow-up, not in scope here.
