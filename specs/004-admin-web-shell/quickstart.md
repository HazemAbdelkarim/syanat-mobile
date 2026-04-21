# Quickstart — Admin Web Shell (Spec 004)

**Audience**: The engineer (or LLM) implementing Phase 6 tasks. Run every command from the repo root unless told to `cd`.

**Prerequisite tools**:
- Flutter stable channel (matches mobile's `pubspec.yaml` Dart SDK constraint `^3.5.3`).
- Firebase CLI authenticated against project `syana-ea75a` (`firebase login`; confirm with `firebase projects:list`).
- GitHub repo access with Actions enabled.

**Prerequisite human input**:
- A real reCAPTCHA Enterprise v3 site key for `syana-ea75a`, obtained from Firebase Console → App Check → Web apps → Register site key. If you don't have one, STOP — do not proceed past Task 6-1 with the placeholder.
- Confirmation that Hosting site `syanat-admin` exists (run `firebase hosting:sites:list` and look for it). If missing: `firebase hosting:sites:create syanat-admin` (once).

---

## Step-by-step

### Step 1 — Scaffold the Flutter Web project (Task 6-0)

```bash
flutter create --platforms web admin_web
# Move the scaffold to its final home:
mkdir -p .claude
mv admin_web .claude/AdminWebApp
# Commit the raw scaffold before any edits, as a clean revert point.
git add .claude/AdminWebApp
git commit -m "Spec 004: scaffold Flutter Web admin app at .claude/AdminWebApp"
```

Edit `.claude/AdminWebApp/pubspec.yaml` to:
- Match the Dart SDK constraint from the repo-root `pubspec.yaml` (`environment: sdk: ^3.5.3`).
- Declare ONLY these dependencies: `firebase_core`, `firebase_auth`, `cloud_firestore`, `cloud_functions`, `google_sign_in`, `google_fonts`, `firebase_app_check`.
- Forbidden packages (MUST NOT appear): `image_picker`, `flutter_image_compress`, `location`, `geolocator`, `video_player`, `flutter_local_notifications`, `sign_in_with_apple`, `workmanager`, `flutter_native_splash`.

Then:

```bash
cd .claude/AdminWebApp && flutter pub get
```

Expect `.claude/AdminWebApp/.dart_tool/` and `.claude/AdminWebApp/.flutter-plugins` to be created — distinct from the mobile project's equivalents. If they appear at repo root instead, you forgot the `cd` — revert and retry.

### Step 2 — Write `main.dart`, `auth_gate.dart`, `login_screen.dart`, `dashboard_screen.dart`, service stubs (Tasks 6-2, 6-3, 6-4)

Follow [data-model.md](./data-model.md) and [contracts/ui-contracts.md](./contracts/ui-contracts.md) verbatim. In particular:
- `main.dart` embeds the exact Firebase web config from FR-006.
- `main.dart` activates App Check with the **real** reCAPTCHA Enterprise v3 key — NOT the placeholder.
- `_AdminCheck` calls `await FirebaseAuth.instance.signOut()` BEFORE rendering the denied screen.
- `AdminSection` enum has exactly 6 values in the order `overview, jobs, payments, disputes, support, activity`.
- `AdminFirebaseService.streamStats()` is the ONLY implemented service method; every other method throws `UnimplementedError` with the message template `'AdminFirebaseService.<methodName> not implemented (Phase 7)'`.
- `AdminCloudFunctions` has 5 methods, all throwing `UnimplementedError` with the template `'AdminCloudFunctions.<methodName> not implemented (Phase 7)'`.

Edit `.claude/AdminWebApp/web/index.html` to add the `<meta name="google-signin-client_id" content="<CLIENT_ID>.apps.googleusercontent.com">` tag inside `<head>`. The client ID is in Firebase Console → Auth → Sign-in method → Google → Web SDK config.

Verify the build locally:

```bash
cd .claude/AdminWebApp && flutter analyze
# Expect: "No issues found!"
cd .claude/AdminWebApp && flutter build web --web-renderer html --release
# Expect: ".claude/AdminWebApp/build/web/" is created, exit code 0.
```

### Step 3 — Add hosting block to `firebase.json` (Task 6-1)

Edit `firebase.json` (repo root) and add a top-level `hosting` key alongside the existing `firestore`, `storage`, `functions`, `emulators` keys:

```json
"hosting": {
  "site": "syanat-admin",
  "public": ".claude/AdminWebApp/build/web",
  "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
  "rewrites": [{ "source": "**", "destination": "/index.html" }]
}
```

### Step 4 — Preview-channel deploy (Task 6-1, Principle IV)

```bash
firebase hosting:channel:deploy preview-shell --project syana-ea75a
# Expect: a preview URL printed, e.g., https://syanat-admin--preview-shell-xxxx.web.app
```

Open the preview URL in Chrome, then run the seven smoke tests from [contracts/ui-contracts.md § Smoke tests](./contracts/ui-contracts.md#4-smoke-tests-developer-facing-not-ci--ci-is-analyze--build).

### Step 5 — Production deploy (ONLY after preview passes)

```bash
firebase deploy --only hosting:syanat-admin --project syana-ea75a
# Expect: https://syanat-admin.web.app is live with the shell.
```

### Step 6 — CI workflow (Task 6-1b)

Create `.github/workflows/admin-web.yml` matching the shape described in [research.md R8](./research.md#r8-ci-workflow-shape). Minimum:

```yaml
name: Admin Web
on:
  pull_request:
    paths:
      - '.claude/AdminWebApp/**'
      - '.github/workflows/admin-web.yml'
jobs:
  analyze-and-build:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: .claude/AdminWebApp
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - run: flutter --version
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter build web --web-renderer html --release
```

Verify by opening a PR that intentionally adds a type error inside `.claude/AdminWebApp/lib/main.dart` — the workflow MUST fail red. Revert, push, and confirm the workflow goes green.

Then open a PR that touches only a file outside `.claude/AdminWebApp/` (e.g., `README.md`) — the workflow MUST NOT trigger (FR-013, SC-007).

---

## Local developer loop

```bash
# Inside the admin web project:
cd .claude/AdminWebApp

# Run locally against the production Firebase project (watch: this uses real auth):
flutter run -d chrome --web-renderer html

# Quick static-check loop:
flutter analyze

# Full build (mimics CI):
flutter build web --web-renderer html --release
```

**Never** run `flutter pub get` or `flutter analyze` at the repo root expecting it to affect the admin web project. Principle VI.

---

## Troubleshooting

| Symptom | Root cause | Fix |
|--------|------------|-----|
| Browser console shows `AppCheck: Error: ReCAPTCHA: ... invalid-key` | Placeholder `YOUR_RECAPTCHA_V3_SITE_KEY` still in `main.dart`. | Replace with the real key obtained from Firebase Console App Check. |
| `flutter build web` fails with "Unknown option --web-renderer" | Flutter version too new (option removed in later versions) or too old. | Match the mobile project's Flutter version. If the option truly no longer exists at your version, escalate — the constitution's requirement must be addressed by amendment, not by silently dropping it. |
| Google sign-in button does nothing | Missing `<meta name="google-signin-client_id">` in `web/index.html`, OR Google provider not enabled in Firebase Console Auth. | Add the meta tag (see Step 2). Enable Google provider in Firebase Console. |
| Signed in as admin but always see "Access denied" | Admin user's `users/{uid}` doc is missing or `role` field is not exactly the string `'admin'`. | Fix the doc in Firestore console. Remember: the check is exact-string compare. |
| Non-admin user is signed in AND sees denied screen — but `currentUser` is NOT null | Code path orders `setState` before `signOut()`. | Move `await FirebaseAuth.instance.signOut()` BEFORE `setState`. Principle IX defect if left unfixed. |
| CI times out | Flutter install is slow (no caching). SC-006 allows up to 10 minutes; if repeatedly over, add `actions/cache@v4` for `~/.pub-cache` and `.dart_tool/`. | Add caching in a follow-up; not required by this spec. |
| Horizontal scroll or yellow overflow stripes at 1280×800 | `NavigationRailLabelType.all` + too many labels competing for width. | Switch to `labelType: NavigationRailLabelType.selected` as a narrower fallback. |
| `firebase deploy` says "site not found" | Hosting site `syanat-admin` not yet created. | `firebase hosting:sites:create syanat-admin --project syana-ea75a`. |

---

## Definition of done

All of the following MUST be true before `/speckit.implement` reports complete:

1. `cd .claude/AdminWebApp && flutter analyze` → zero issues.
2. `cd .claude/AdminWebApp && flutter build web --web-renderer html --release` → exit 0, `build/web/index.html` present.
3. `firebase hosting:channel:deploy preview-shell` produced a live URL and all seven smoke tests pass on it.
4. `firebase deploy --only hosting:syanat-admin` has published the production URL (`https://syanat-admin.web.app`).
5. `.github/workflows/admin-web.yml` exists, triggers on `.claude/AdminWebApp/**` PRs, and a test PR confirmed both the green and red paths.
6. `grep -R "YOUR_RECAPTCHA_V3_SITE_KEY" .claude/AdminWebApp/ firebase.json` returns zero matches.
7. `grep -R "serviceAccountKey" .claude/AdminWebApp/` returns zero matches; `.gitignore` still covers `**/serviceAccountKey*.json`.
8. Root `lib/` is untouched (`git diff origin/main -- lib/` shows no changes).
9. **[F-006]** In Google Cloud Console → **APIs & Services → Credentials**, locate the Syanat **Web API key** (same value embedded at `lib/main.dart` `apiKey:`). Under **Application restrictions**, choose **HTTP referrers** and add exactly these entries, then **Save**:
   - `https://syanat-admin.web.app/*`
   - `https://syanat-admin--*.web.app/*` (preview channels)
   - `https://syana-ea75a.firebaseapp.com/*`
   - `http://localhost:*/*` (dev only — remove before declaring production done if not needed)

   Without referrer restrictions the API key is usable from any origin, which defeats App Check.
10. **[F-007]** Confirm App Check enforcement is actually on:

    ```bash
    firebase appcheck:products:list --project syana-ea75a
    ```

    Both `firestore.googleapis.com` and `cloudfunctions.googleapis.com` MUST appear with `enforcement: ENFORCED`. If either shows `UNENFORCED` or `OFF`, run `firebase appcheck:products:update --project syana-ea75a ...` to flip it. Enforcement without a verified enforcement state is advisory only and does not prevent quota drain from clients without tokens.

When all 10 items are true, proceed to `/speckit.tasks` (the very next command) and then `/speckit.implement`.
