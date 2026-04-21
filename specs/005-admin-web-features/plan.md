# Implementation Plan: Admin Web App Feature Screens

**Branch**: `005-admin-web-features` | **Date**: 2026-04-19 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/005-admin-web-features/spec.md`

## Summary

Replace the six Phase-6 placeholder sections of the admin web shell at `.claude/AdminWebApp/` (see Complexity Tracking row 1 for the Principle II deviation re: path) with real, production-ready feature screens: Overview (P1 MVP — `stats/global` KPIs), Jobs (P1 — 3 sub-tabs plus technician assignment), Payments (P1 — review + approve/reject), Disputes (P2 — 3-option resolve panel), Support (P2 — inbox + real-time chat + unread badge), and Activity (P3 — audit feed + force-close). Every privileged write is invoked through an existing `onCall` callable deployed in Spec 002 in region `europe-west1` — never a direct Firestore write — except the three Low-risk support operations (`markSupportChatReadByAdmin`, `closeSupportChat`, `sendSupportMessage`), which rely on the already-deployed `firestore.rules` throttle + admin gate from Spec 001 (verified: lines 370–425 of `firestore.rules`, 10 s cooldown + 50-message cap + 2000-char length limit on the admin-unrestricted path).

Technical approach: flesh out the stubs in `.claude/AdminWebApp/lib/services/admin_firebase_service.dart` and `.claude/AdminWebApp/lib/services/admin_cloud_functions.dart`, add six feature-screen folders under `.claude/AdminWebApp/lib/`, wire every callable to `FirebaseFunctions.instanceFor(region: 'europe-west1')` (confirmed during research), map the Spec-002 audit-log `type` strings (`job_assigned`, `job_force_closed`, `dispute_resolved`, `payment_approved`, `payment_rejected`) plus the Spec-003 event-driven types (`account_created`, `job_requested`, `job_completed`, `job_cancelled`) to a client-side icon/color table, and re-use the existing Spec-004 `AuthGate` as the mount-point for every screen. No routing package, no new callables, no new Cloud Functions, no `lib/` (mobile) touches, no Firestore rules changes.

## Technical Context

**Language/Version**: Dart (Flutter stable channel). Dart SDK constraint `^3.5.3`, unchanged from Spec 004 `pubspec.yaml`.
**Primary Dependencies**: Allow-listed from Constitution §Technology Constraints — `firebase_core ^3.6.0`, `firebase_auth ^5.3.1`, `cloud_firestore ^5.4.4`, `cloud_functions ^5.1.3`, `firebase_app_check ^0.3.1+6`, `google_sign_in ^6.2.1`, `google_fonts ^6.2.1`. No new dependencies introduced by this spec.
**Storage**: Firestore in existing project `syana-ea75a`. Reads: `stats/global` (stream, single doc), `jobs/*` (3 bounded streams, all `.limit(50)`), `payments/*` (one stream, `.limit(100)`), `support_chats/*` (inbox stream `.limit(50)` + unread-count stream `.limit(100)`), `support_chats/{chatId}/messages/*` (per-chat stream `.limit(50)` with `startAfterDocument` pagination on scroll), `activity_log/*` (one stream, `.limit(50)`), `users/*` (one-shot `.get()` with `.limit(100)` for available-technician lookup). Writes: zero direct writes to `jobs/*`, `payments/*`, `stats/*`, `activity_log/*`. Direct writes allowed ONLY on `support_chats/*` fields `unreadByAdmin`, `status`, `closedAt`, `lastMessageAt` and the `messages/*` subcollection create — matching the rules in `firestore.rules` lines 370–425.
**Testing**: `flutter analyze` (zero-issues gate, SC-008). `flutter build web --web-renderer html --release` (SC-009). The real acceptance gate is the 27-scenario operator smoke test from migration-plan Task 7-7 run against a Firebase Hosting preview channel (SC-001). No unit/widget tests are required by this spec; if the implementing model adds them opportunistically they MUST live under `.claude/AdminWebApp/test/` and MUST NOT reach into production Firebase (use `firebase-functions-test` emulator targets only).
**Target Platform**: Flutter Web, `--web-renderer html` ONLY (constitution §Technology Constraints; CanvasKit is forbidden for this project). Deploy target: Firebase Hosting site `syanat-admin` under project `syana-ea75a`. Browsers: latest Chrome / Edge / Firefox on desktop ≥ 1280×800.
**Project Type**: Web application (layered onto the Phase-6 shell). Still within the monorepo until the admin web extraction (post-Spec-006).
**Performance Goals**:
- First paint of real data per section ≤ 3 s on a broadband connection (SC-002).
- KPI / list updates reflect Firestore changes within 5 s without a page refresh (SC-002).
- Callable round-trip p95 ≤ 2 s from click to success toast (button stays disabled + spinner visible for the full interval + 500 ms post-success per FR-033).
**Constraints**:
- MUST build and deploy with `--web-renderer html`.
- MUST NOT import any forbidden package (Constitution §Technology Constraints).
- MUST live entirely under `.claude/AdminWebApp/` — no file touches under root `lib/` (FR-043).
- MUST NOT add any new Cloud Function; all five admin callables plus the three Spec-003 stats triggers already exist (FR-044, verified: `functions/src/admin/*.ts`, `functions/src/stats/*.ts`).
- MUST NOT modify `firestore.rules` except for the narrow new-composite-index case in FR-032 (and that case is expected to be empty — see research R-4).
- Admin check remains a Firestore doc read against `users/{uid}.role == 'admin'` via the already-mounted Spec-004 `AuthGate` (Constitution Principle IX + Decision D1).
- Every callable invocation MUST use `FirebaseFunctions.instanceFor(region: 'europe-west1')`. Forgetting the region defaults to `us-central1` and silently produces `not-found` errors — caught in research R-1.
- Every `StreamSubscription` stored in `State` MUST be cancelled in `dispose()` (FR-029, SC-005).
- Every Firestore query MUST carry an explicit `.limit(N)` (FR-027, SC-004).
**Scale/Scope**: Single-tenant admin app; expected concurrent admin users ≤ 5. Scope in this spec: six feature-screen folders, thirteen service-layer methods filled in (from stubs), five callable wrappers filled in (from stubs), one icon/color mapping table, one client-side constants module for resolution strings and status enums, one sidebar-badge stream wiring. Expected code size: ~2,000–3,000 LOC of Dart under `.claude/AdminWebApp/lib/`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principles I–VII

| # | Principle | Compliance |
|---|-----------|------------|
| I | Migration Plan is Source of Truth | Every query, callable name, field name, and status string in this plan is traceable to `WOOHOO/Migration_Implementation_Plan.md` Phase 7 (Tasks 7-1 through 7-7) or to a read of an already-deployed file (`functions/src/admin/*.ts`, `firestore.rules`, `.claude/AdminWebApp/lib/services/*`). Any deviation from the migration plan (e.g. renaming an audit `type`) is escalated in research.md — not silently introduced. ✅ |
| II | Workspace Boundary | **DEVIATION** — admin web code continues to live at `.claude/AdminWebApp/` (same deviation already accepted in Spec 004). See Complexity Tracking row 1. Mobile `lib/` is explicitly untouched (FR-043). `functions/` is untouched (FR-044). ⚠️ |
| III | No Guessing — Read First | Every callable shape was cross-read from `functions/src/admin/*.ts` during research (see research R-1 and R-2). The `support_chats` throttle shape was read from `firestore.rules` lines 370–425 (see research R-5). `activity_log` `type` values were read from the callable source, not guessed from the migration plan wording. ✅ |
| IV | Deploy Safety | No Firestore rules, Cloud Functions, or storage rules are deployed by this spec. The only deploy is `firebase deploy --only hosting:syanat-admin` after a mandatory `firebase hosting:channel:deploy preview-e2e` that hosts the 27-scenario smoke test (SC-001). ✅ |
| V | Backward Compatibility | The mobile app is not touched (FR-043). No Firestore document schema is changed. No status enum is added. No rule is relaxed. Spec 006 (mobile cleanup) is the earliest spec that is allowed to reach into `lib/`. ✅ |
| VI | Flutter Tooling Isolation | **DEVIATION** — every `flutter ...` command in this spec runs from inside `.claude/AdminWebApp/`, direct consequence of the II deviation. `.dart_tool/`, `.flutter-plugins`, `pubspec.lock` stay inside `.claude/AdminWebApp/` and are never shared with the mobile project. See Complexity Tracking row 2. ⚠️ |
| VII | No Premature Abstraction | No shared Dart package is created. Models (`Job`, `Payment`, `SupportChat`, `ActivityEntry`) live directly under `.claude/AdminWebApp/lib/models/` and are copied fields — not extracted — from mobile code. Spec 006 will evaluate whether 3+ files have diverged and justify extraction at that time. ✅ |

### Principles VIII–XIII (Security Review Gate — MANDATORY for Specs 002–006)

| # | Principle | Control this spec implements | File path | Verification |
|---|-----------|------------------------------|-----------|--------------|
| VIII | Secrets & Credential Hygiene | (a) No service-account JSON, reCAPTCHA key, or new Firebase config value is introduced (FR-025). Only the public Web SDK config already embedded in Spec-004 `main.dart` is referenced. (b) `print` and `debugPrint` of Firestore document contents are forbidden in release builds (FR-026). `kDebugMode`-gated logs redact `email`, `phone`, `address`, `screenshotUrl`. (c) No CI credential is introduced by this spec; the Spec-004 `.github/workflows/admin-web.yml` runs `analyze` + `build` only. | `.claude/AdminWebApp/lib/**`, `.gitignore` (pre-existing) | Code review: grep `kDebugMode` call sites and confirm each redacts the PII list; grep `print(` and `debugPrint(` in non-test code — must be zero in UI files. Preview-deploy the production build and grep the minified JS for `apiKey`, `reCaptcha`, `serviceAccount` — only the expected public `apiKey` must match. |
| IX | Least Privilege & Explicit Authorization | (a) Every feature screen is mounted beneath the Spec-004 `AuthGate` (FR-022). A screen declared outside the gate is a defect. (b) Zero direct admin Firestore writes outside the three Low-risk support operations (FR-013, FR-021). Every write on `jobs/*`, `payments/*`, `stats/*`, `activity_log/*` goes through a callable whose first executable line is `verifyAdmin(request)` (confirmed at `functions/src/admin/*.ts` line 15 in each file). (c) Every read query is bounded: `.limit(50)` or `.limit(100)` (FR-027). There is no "fetch all X" method anywhere in the admin web codebase. (d) `getAvailableTechnicianIdsByService` is a one-shot `.get()` with `.limit(100)` — not a stream, not unbounded. | `.claude/AdminWebApp/lib/dashboard/dashboard_screen.dart` (mounting), `.claude/AdminWebApp/lib/services/admin_firebase_service.dart` (bounded queries), `.claude/AdminWebApp/lib/services/admin_cloud_functions.dart` (callable wrappers). | Code review: grep `FirebaseFirestore.instance` in `.claude/AdminWebApp/lib/**` — every match that is a `collection(...)` or `collectionGroup(...)` call MUST be followed by a chain that ends in `.limit(N)`. Manual test: sign in as customer → confirm denied screen AND `FirebaseAuth.instance.currentUser == null` within 200 ms (inherits Spec-004 US2 AS4). |
| X | Input Validation & Transactional Integrity | This spec is client-side only; the server-side validation + transactional precondition checks live in the already-deployed Spec-002 callables (confirmed: `functions/src/admin/assign-job.ts`, `close-job.ts`, `resolve-dispute.ts`, `approve-payment.ts`, `reject-payment.ts` all call `verifyAdmin` first, then `HttpsError('invalid-argument', ...)` on malformed input, then `db.runTransaction(...)` for the precondition read). Client-side, this spec adds defense-in-depth: trim + length-cap (500/1000/2000 chars) on reasons (FR-036); reject NaN/Infinity/negative and cap 1,000,000 EGP on numeric inputs (FR-038); regex guard on doc IDs rendered in confirmation dialogs (FR-039); enumerated `resolution` constants (FR-011). | `.claude/AdminWebApp/lib/services/admin_cloud_functions.dart` (wrapper-level validation), feature-screen dialog widgets (form-level validation) | Code review: grep `.trim()` — every free-text reason input in a dialog must trim before passing to the callable. Grep the regex `^[A-Za-z0-9_-]{10,80}$` — must appear in `utils/doc_id_guard.dart` and be the sole source of truth for the check. Emulator test: try to call `rejectPayment` with a whitespace-only reason — callable returns `invalid-argument` (pre-existing Spec-002 behaviour); UI must also disable the Confirm button client-side. |
| XI | Audit Trail & Accountability | (a) Every privileged admin write produces exactly one `activity_log` entry (SC-011). This is the Spec-002 server-side responsibility — this spec verifies it via the Activity screen and the 27-scenario smoke test. (b) No audit field (`assignedBy`, `reviewedBy`, `resolvedBy`, `adminClosedBy`, `*At`) is ever sent from the client; callables derive all of them server-side. The admin web codebase MUST NOT pass any of those field names in a callable `data` payload. (c) The Activity screen is the operator-facing audit trail (FR-019). It renders one row per `activity_log` doc with icon, description, timestamp, and acting admin UID. | `.claude/AdminWebApp/lib/activity/activity_screen.dart`, `.claude/AdminWebApp/lib/services/admin_cloud_functions.dart` | Code review: grep every callable wrapper's `data` map — must NOT contain the audit field names listed above. Smoke test (SC-011): run the 27-scenario test, then audit the Activity screen — one entry per write, no duplicates, acting UID visible. |
| XII | Defense in Depth | (a) App Check is already Enforced for Firestore, Storage, and Cloud Functions (set up in Spec 004). This spec does not change that. (b) Firestore rules remain the second-layer gate: the rules in `firestore.rules` continue to restrict `jobs/*`, `payments/*`, `stats/*`, `activity_log/*` admin writes through `affectedKeys()` (Spec 001). The admin web app does NOT rely on "CF handles it" to bypass rules — the admin web never makes those direct writes. (c) `authStateChanges()` re-verification runs on every dashboard mount via the Spec-004 `AuthGate`. (d) If any query in this spec needs a composite index, it MUST be declared in `firestore.indexes.json` with a one-line comment and deployed atomically with the code (FR-032). Research R-4 determined NO new indexes are required. (e) `cd .claude/AdminWebApp && flutter pub outdated` is reviewed at Phase 0 (see quickstart.md); known-vulnerable packages MUST be upgraded before the preview deploy. | `.claude/AdminWebApp/lib/**` (queries), `firestore.indexes.json` (verified no-change), Firebase Console App Check page (operator verification) | Research R-4: enumerate every query in the service layer and confirm each matches an existing single-field or composite index. Operator verification before preview deploy: App Check dashboard shows Firestore + Cloud Functions in "Enforce" mode. |
| XIII | Safe Error Reporting & Logging | (a) UI error paths surface `FirebaseFunctionsException.code` + `.message` only; `.details` is NEVER rendered (FR-023, SC-006). (b) No raw JSON blob or network fetch error is rendered — every catch site maps to a user-friendly `SnackBar` or inline error. (c) No `print(data)` / `debugPrint(data)` that dumps a callable payload or a Firestore document (FR-026). Debug logs emit field names, not values, and respect the redaction list from VIII. (d) No Crashlytics on web. (e) `release` builds strip `kDebugMode` logging by compile-time constant. | `.claude/AdminWebApp/lib/**` (every catch site), `.claude/AdminWebApp/lib/services/**` (no raw payload logs) | Code review: grep `.details` on any `FirebaseFunctionsException` handle — must return zero in UI code (SC-006). Grep `print(`/`debugPrint(` outside `kDebugMode` guards — must return zero. Manual test: trigger a callable failure, confirm the UI shows only `code` + `message`. |

**Gate verdict:** All 13 principles have a row filled. Two deviations (II and VI — both path-related and inherited from Spec 004) are reproduced verbatim from Spec-004's accepted justification and weaken no underlying rule. The Security Review Gate is complete with concrete file paths and verification steps for VIII–XIII.

## Project Structure

### Documentation (this feature)

```text
specs/005-admin-web-features/
├── plan.md              # This file
├── spec.md              # Already written (see ./spec.md)
├── INPUT.md             # Source brief that produced spec.md
├── research.md          # Phase 0 output (this command)
├── data-model.md        # Phase 1 output (this command)
├── quickstart.md        # Phase 1 output (this command)
├── contracts/
│   ├── admin-firebase-service.md       # Service-layer method contracts
│   ├── admin-cloud-functions.md        # Callable wrapper contracts
│   ├── screen-contracts.md             # Per-screen behaviour + widget tree
│   └── constants.md                    # Resolution strings, status enums, icon mapping
├── checklists/
│   └── requirements.md                 # Already written by /speckit.specify
└── tasks.md             # Phase 2 output (/speckit.tasks command — NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
# Admin web app (path OVERRIDE of constitution Principle II — see Complexity Tracking row 1)
.claude/AdminWebApp/
├── pubspec.yaml                                  # Unchanged (no new deps)
├── analysis_options.yaml                         # Unchanged
├── web/                                          # Unchanged
├── lib/
│   ├── main.dart                                 # Unchanged from Spec 004
│   ├── auth/                                     # Unchanged from Spec 004
│   │   ├── auth_gate.dart
│   │   └── login_screen.dart
│   ├── dashboard/
│   │   └── dashboard_screen.dart                 # MODIFIED — replace 6 placeholders with real screens
│   ├── overview/                                 # NEW
│   │   ├── overview_screen.dart                  # StreamBuilder over streamStats() + 6 KpiCard widgets
│   │   └── widgets/
│   │       └── kpi_card.dart
│   ├── jobs/                                     # NEW
│   │   ├── jobs_screen.dart                      # TabBar host (Requested, Active, Completed) — wraps 3 JobListPage
│   │   ├── job_detail_screen.dart                # force-close button + receipt/summary
│   │   ├── assign_dialog.dart                    # technician picker + calls assignJob()
│   │   ├── force_close_dialog.dart               # jobId-guarded dialog + calls closeJob()
│   │   └── widgets/
│   │       ├── job_list_page.dart                # Generic tab body: StreamBuilder<QuerySnapshot> + empty/loading/error
│   │       └── job_list_item.dart                # One row of a job list — reused by all three tabs
│   ├── payments/                                 # NEW
│   │   ├── payments_screen.dart
│   │   ├── reject_dialog.dart                    # required reason + calls rejectPayment()
│   │   └── widgets/
│   │       ├── payment_list_item.dart
│   │       └── status_badge.dart
│   ├── disputes/                                 # NEW
│   │   ├── disputes_screen.dart
│   │   └── resolve_panel.dart                    # 3 buttons + reason + optional override
│   ├── support/                                  # NEW
│   │   ├── support_inbox_screen.dart
│   │   ├── support_chat_screen.dart              # Real-time messages + Send + Close-chat
│   │   └── widgets/
│   │       └── chat_list_item.dart
│   ├── activity/                                 # NEW
│   │   └── activity_screen.dart
│   ├── models/                                   # NEW — copied shapes, not extracted (Principle VII)
│   │   ├── job.dart
│   │   ├── payment.dart
│   │   ├── support_chat.dart
│   │   ├── support_message.dart
│   │   ├── activity_entry.dart
│   │   └── technician_option.dart
│   ├── constants/                                # NEW — resolution strings, status enums, icon map
│   │   ├── resolutions.dart                      # 'reopen' | 'complete' | 'cancel'
│   │   ├── payment_status.dart                   # PENDING | CONFIRMED | REJECTED + color map
│   │   ├── job_status.dart                       # status ↔ display-label ↔ color
│   │   └── activity_icons.dart                   # type → (IconData, Color, label template)
│   ├── utils/                                    # NEW
│   │   ├── doc_id_guard.dart                     # regex ^[A-Za-z0-9_-]{10,80}$
│   │   ├── callable_errors.dart                  # maps FirebaseFunctionsException → UI strings (code+message only)
│   │   └── numeric_input.dart                    # rejects NaN/Infinity/negative, caps 1,000,000 EGP
│   └── services/
│       ├── admin_firebase_service.dart           # MODIFIED — replace 12 stubs with real bounded queries
│       └── admin_cloud_functions.dart            # MODIFIED — replace 5 stubs with real region-scoped callables
├── test/                                         # OPTIONAL; none required
└── (standard Flutter scaffold files, unchanged)

# UNCHANGED by this spec
lib/                                              # Mobile app — MUST NOT be modified (FR-043)
functions/                                        # Cloud Functions — MUST NOT be modified (FR-044)
firestore.rules                                   # Unchanged (FR-045)
firestore.indexes.json                            # Unchanged (research R-4 confirms zero new indexes)
storage.rules                                     # Unchanged
firebase.json                                     # Unchanged (hosting block already set by Spec 004)
.github/workflows/admin-web.yml                   # Unchanged (reuses Spec 004 CI)
```

**Structure Decision**: Web application layered onto the Spec-004 shell. Each feature screen is a self-contained folder under `.claude/AdminWebApp/lib/` that owns its screen + widgets + dialogs. Shared infrastructure (models, constants, utils, services) sits at sibling folders. No routing package is added — the Spec-004 `NavigationRail` + `IndexedStack` remain the top-level navigation; screens swap in place. Flutter tooling isolation (Principle VI) is unchanged — every `flutter` command still runs from inside `.claude/AdminWebApp/`.

## Complexity Tracking

> Filled because Constitution Check surfaced two deviations (both path-related, both inherited verbatim from Spec 004 and previously accepted).

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Principle II path: admin web code at `.claude/AdminWebApp/` instead of `admin_web/` | Inherited from Spec 004. The admin web app will eventually move to its own repo (Principle VII); `.claude/AdminWebApp/` is the agreed staging location. Moving the code to `admin_web/` just to match the constitution literally would force one PR renaming every path filter in CI and every `cd` in operator runbooks — with zero benefit and one additional source of merge conflict during the migration. | Repo-root `admin_web/` is the literal path; rejected in Spec 004 for the reasons above. No re-evaluation in this spec — decision is unchanged. |
| Principle VI tooling commands: run Flutter commands from `.claude/AdminWebApp/` instead of `admin_web/` | Direct consequence of row 1. Every `flutter analyze` / `flutter build web --web-renderer html --release` in this spec, in CI, and in operator runbooks MUST `cd .claude/AdminWebApp/` first. The isolation invariant (distinct `.dart_tool/`, `.flutter-plugins`, `pubspec.lock`) is preserved verbatim. | N/A — cannot be avoided once row 1 is accepted. Documented so reviewers do not flag it as a defect. |

**Follow-up constitution amendment (non-blocking, tracked for after Spec 006 mobile cleanup):** bump to v1.2.0 with a single-sentence clarification on Principles II and VI stating the `.claude/AdminWebApp/` override for Specs 004–005. Orthogonal to this spec — do not block implementation on it.

---

## Post-Design Constitution Re-check

Re-ran all 13 principles against the Phase-1 design artifacts (`research.md`, `data-model.md`, `contracts/*`, `quickstart.md`). No new deviations surfaced — both inherited row-1 and row-2 entries in Complexity Tracking remain the only gaps.

| Principle | Post-design status | Evidence in artifacts |
|-----------|---------------------|-----------------------|
| I. User-first product | PASS | `spec.md` §User Scenarios keeps US1–US3 at P1 (the operator-critical path). `screen-contracts.md` renders a skeleton loading state and an inline retry banner for every stream (User Story AS4 across sections). |
| II. Repository Path Discipline | DEVIATION (inherited) | `quickstart.md` §0 and §3 both `cd .claude\AdminWebApp`. Tracked in Complexity row 1. |
| III. No Guessing — Read First | PASS | `research.md` R-1…R-5 cite exact file+line evidence (`functions/src/admin/*.ts`, `firestore.rules:377-422`, `firestore.indexes.json`). R-3 reconciles audit type `payment_rejected` (not `receipt_rejected`) against `functions/src/admin/reject-payment.ts:50`. |
| IV. Spec-Driven Development | PASS | Every section in `spec.md` has a matching FR or SC; every FR has a matching contract line (services, callables, screens, constants). No implementation work planned outside these artifacts. |
| V. Security Review Gate | PASS | `contracts/admin-cloud-functions.md` §Forbidden patterns forbids `.details` reads (FR-023, SC-006 grep gate); `admin-firebase-service.md` §Common invariants requires `.limit(N)` on every query (SC-004 grep gate). `screen-contracts.md` mandates `Text()` widgets for user-controlled text (SC-007). App Check + reCAPTCHA Enterprise v3 inherited from Spec 004, unchanged. |
| VI. Tooling isolation | DEVIATION (inherited) | `quickstart.md` §1, §2, §4 all `cd .claude\AdminWebApp` before `flutter analyze` / `flutter build web`. Tracked in Complexity row 2. |
| VII. Minimal Dependencies | PASS | Zero new packages introduced. `research.md` R-8 requires `flutter pub outdated` audit in pre-flight. `data-model.md` entities use `cloud_firestore` types already vendored by Spec 004. |
| VIII. Server is the source of truth | PASS | `admin-cloud-functions.md` forbids direct Firestore writes to `jobs/*`, `payments/*`, `stats/*`, `activity_log/*`. Three Low-risk direct writes on `support_chats/*` are all covered by existing rules at `firestore.rules:370-425`. |
| IX. Single-writer invariant | PASS | All admin state changes on jobs/payments/disputes route through one of the five callables in `admin-cloud-functions.md`. Support-chat writes go through `admin_firebase_service.dart` methods only — no widget writes directly. |
| X. Callable idempotency | PASS | `admin-cloud-functions.md` §`closeJob` documents the idempotent `{ok: true}` repeat-close behavior (aligns with `functions/src/admin/close-job.ts:41–45`). UI surfaces the same SnackBar on both first-time and repeat close (FR-040). |
| XI. App Check + region discipline | PASS | Single `_functions = FirebaseFunctions.instanceFor(region: 'europe-west1')` field in `admin-cloud-functions.md` §Shared setup. Every `httpsCallable(...)` goes through it. App Check inherited from Spec 004 web init. |
| XII. Quota guardrails | PASS | `admin-firebase-service.md` §Common invariants requires `.limit(N)` on every chain. `streamUnreadSupportCount` is a bounded `.limit(100)` stream, NOT an `.count()` aggregation (research R-7, FR-006). Unread-badge stream lives at shell scope with explicit `dispose()` cancellation (SC-005). |
| XIII. No exception-detail leakage | PASS | `admin-cloud-functions.md` §Error handling defines one `CallableErrorView` helper that intentionally never reads `error.details`; every screen surfaces `"${code}: ${message}"` only. `screen-contracts.md` repeats this at §Cross-screen invariants. |

**Gate outcome**: GREEN. Both remaining deviations are the two inherited path items already in Complexity Tracking. No blocker to `/speckit.tasks`.
