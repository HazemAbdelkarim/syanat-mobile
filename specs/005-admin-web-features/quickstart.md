# Quickstart — Spec 005 (Admin Web Feature Screens)

**Audience**: the implementing model (and any human reviewer) running the build / analyze / deploy cycle for this spec.

**Prerequisites** (verified once at the start of Phase 2):

1. ✅ Git branch: `005-admin-web-features` (already created by `/speckit.git.feature`).
2. ✅ Spec 004 merged to `main`; `.claude/AdminWebApp/` exists with `main.dart`, `auth/`, `dashboard/`, `services/` (stubs).
3. ✅ Spec 002 (admin callables) deployed to `europe-west1`. Confirm via Firebase Console → Functions → region filter.
4. ✅ Spec 003 (event-driven stats) deployed. Confirm `stats/global` updates when a test user is created.
5. ✅ Real reCAPTCHA Enterprise v3 key is active in Firebase Console App Check (inherited from Spec 004).
6. ✅ `.claude/` is NOT in `.gitignore` — `grep -nE '^\.claude(/|$)' .gitignore` returns zero matches.

**All commands assume the repo root** `C:\users\ltc\Downloads\Syanat-main-mine\Syanat-lastupdate\`. PowerShell (`powershell.exe`) is the default shell on this machine (see `.specify/init-options.json → "script": "ps"`).

---

## 0. Pre-flight (one-off)

Run these four checks in parallel; any failure STOPS the spec. Do not proceed until all four return the expected result.

```bash
# 1. Branch is correct
git branch --show-current
# → 005-admin-web-features

# 2. Folder exists and has the Spec-004 shell
ls .claude/AdminWebApp/lib
# → auth, dashboard, main.dart, services  (at minimum)

# 3. Callables exist in europe-west1
# Open Firebase Console → Functions → filter region "europe-west1"
# Confirm exactly 5 callables: adminAssignJob, adminApprovePayment, adminRejectPayment,
#   adminResolveDispute, adminCloseJob

# 4. Stats triggers exist and have fired
# Open Firebase Console → Firestore → stats/global
# Confirm the 6 fields are present and non-null.
```

Dependency audit (Principle XII, research R-8) — run from inside the web app:

```powershell
cd .claude\AdminWebApp
flutter pub outdated
cd ..\..
```

If any package has a known CVE published since the Spec-004 lock, upgrade it in a dedicated commit before writing any feature code.

---

## 1. Implement the service-layer methods

**File**: `.claude/AdminWebApp/lib/services/admin_firebase_service.dart`
**Contract**: `specs/005-admin-web-features/contracts/admin-firebase-service.md`
**Rule**: every method replaces its Spec-004 `UnimplementedError` body with the exact query from the contract. No method adds a new dependency.

Remove three methods that are no longer in scope:
- `fetchRecentUsers`
- `fetchRecentActivity`
- `initializeStatsGlobal`

After the edits, this must pass:

```powershell
cd .claude\AdminWebApp
flutter analyze
```

Expected: `No issues found!`. Fix any error before moving to step 2.

---

## 2. Implement the callable-wrapper methods

**File**: `.claude/AdminWebApp/lib/services/admin_cloud_functions.dart`
**Contract**: `specs/005-admin-web-features/contracts/admin-cloud-functions.md`
**Rule**: every method lives behind `FirebaseFunctions.instanceFor(region: 'europe-west1')` (research R-1). No method uses `FirebaseFunctions.instance` — that default is `us-central1` and silently breaks every call.

Signatures are tightened per FR-011 (`resolveDispute` takes a `Resolution` enum) and FR-012 (`closeJob` uses named parameters).

After edits:

```powershell
cd .claude\AdminWebApp
flutter analyze
```

---

## 3. Implement the six feature screens

Follow the order in `specs/005-admin-web-features/contracts/screen-contracts.md`:

1. **Overview** (P1 MVP) — `lib/overview/`.
2. **Jobs** (P1) — `lib/jobs/`.
3. **Payments** (P1) — `lib/payments/`.
4. **Disputes** (P2) — `lib/disputes/`.
5. **Support** (P2) — `lib/support/`.
6. **Activity** (P3) — `lib/activity/`.

Per screen:
- Add screen file + widgets under `lib/<section>/`.
- Update `lib/dashboard/dashboard_screen.dart` to replace the Spec-004 placeholder for that section with the real screen widget.
- Run `flutter analyze` after each screen (keeps the zero-issue gate green throughout).

Create the shared modules first (data-model.md entities + constants):
- `lib/models/` — six model files.
- `lib/constants/` — four constants files.
- `lib/utils/` — three util files (`doc_id_guard.dart`, `callable_errors.dart`, `numeric_input.dart`).

Add the sidebar unread badge wiring in `dashboard_screen.dart` (research R-7): one `StreamSubscription<int>? _unreadSub`, initialized in `initState`, cancelled in `dispose`.

---

## 4. Local sanity — build the web bundle

```powershell
cd .claude\AdminWebApp
flutter build web --web-renderer html --release
cd ..\..
```

Expected: exit code 0; `.claude/AdminWebApp/build/web/index.html` exists.

---

## 5. Preview-channel deploy

```powershell
# From repo root
firebase hosting:channel:deploy preview-e2e --only hosting:syanat-admin
```

Expected output: a preview URL (e.g. `https://syanat-admin--preview-e2e-<hash>.web.app`).

---

## 6. Operator smoke test (the acceptance gate — SC-001)

Run the 27-scenario checklist from migration plan Task 7-7 against the preview URL. Each scenario must pass without a browser console error:

1. Admin sign-in (email)
2. Admin sign-in (Google)
3. Non-admin rejection + forced sign-out
4. Browser refresh on all 6 routes (auth persists)
5. Overview KPI cards match Firebase Console values
6. Real-time: create user → totalUsers increments
7. Jobs list renders (all 3 tabs)
8. Job assignment via CF (success)
9. Assignment of non-requested job (error)
10. Payments list renders
11. Approve PENDING payment (success)
12. Reject without reason (button disabled)
13. Reject with reason (success)
14. Dispute queue shows receipt_disputed jobs
15. Resolve without reason (buttons disabled)
16. Resolve complete with amount
17. Resolve reopen
18. Resolve cancel
19. Support inbox renders
20. Unread badge shows count
21. Open unread chat → badge decrements
22. Send message (appears in real time)
23. Close chat (confirmation + status change)
24. Activity feed renders events
25. Force-close dialog shows job ID
26. Force-close with valid amount (success)
27. Zero browser console errors across all screens

If all 27 pass, the spec is green. If any fails, fix before shipping to production.

---

## 7. Production deploy (only after smoke-test green)

```powershell
# Still from repo root
firebase deploy --only hosting:syanat-admin
```

**Do NOT run** `firebase deploy --only functions` or `firebase deploy --only firestore:rules` from this spec. Those deploys belong to Specs 002/003/001 respectively — this spec's deploy surface is hosting only.

---

## 8. Post-deploy verification

- Open the production URL in Chrome. Confirm sign-in, nav to each of 6 sections, no console errors.
- Open Firebase Console → Firestore → `activity_log` ordered by `createdAt desc`. Trigger one admin action; confirm a new entry appears with the acting admin UID (SC-011).
- Grep SC gates one more time:
  - SC-004: `rg '\.snapshots\(\)' .claude/AdminWebApp/lib` — every match's preceding chain ends in `.limit(`.
  - SC-005: count of `StreamSubscription<` fields equals count of `.cancel()` calls inside `dispose()`.
  - SC-006: `rg '\.details' .claude/AdminWebApp/lib` — zero UI-code matches.
  - SC-007: `rg 'Html\(|RichText\(' .claude/AdminWebApp/lib` — zero matches.

---

## Rollback

If a critical bug surfaces after production deploy:

```powershell
firebase hosting:clone syanat-admin:live syanat-admin:live
# or promote a previous preview channel if one was healthy:
firebase hosting:channel:clone preview-last-good live --only hosting:syanat-admin
```

The mobile admin path is NOT removed by this spec (FR-043), so operators can fall back to the mobile admin dashboard for up to the next spec (Spec 006) without code changes.

---

## When implementation is done

Hand the branch off for review. Review artifacts: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/*`, `quickstart.md` (this file), `checklists/requirements.md`, and — after `/speckit.tasks` — `tasks.md`. The reviewer grades against §Measurable Outcomes (SC-001 … SC-012) and the Security Review Gate table in `plan.md`.
