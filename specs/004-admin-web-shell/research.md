# Phase 0 Research — Admin Web Shell (Spec 004)

**Date**: 2026-04-18
**Input**: [spec.md](./spec.md), [plan.md](./plan.md), `WOOHOO/Migration_Implementation_Plan.md` Phase 6 section, `.specify/memory/constitution.md` v1.1.0

This document resolves every NEEDS CLARIFICATION raised by Technical Context and records the final decisions that implementation tasks will follow. Each entry has the shape **Decision / Rationale / Alternatives considered**.

---

## R1. Admin role verification mechanism

**Decision**: Firestore document read against `users/{uid}.role == 'admin'`, performed by `AuthGate._AdminCheck` on every mount using `FirebaseFirestore.instance.doc('users/${user.uid}').get()`. If the doc does not exist OR the `role` field is not `'admin'`, call `FirebaseAuth.instance.signOut()` and only then render "Access denied".

**Rationale**: Migration Plan Decision D1 and Constitution Principle IX both mandate Firestore doc read over Custom Claims. Doing the `signOut()` before the denied-screen render is required verbatim by Principle IX — "A 'denied' UI rendered while the Firebase session is still alive is a defect, because the user can open a browser console and query Firestore directly."

**Alternatives considered**:
- **Firebase Custom Claims**: Out of scope per D1 — would require rewriting admin management and a constitution amendment.
- **Keep the user signed in and rely only on Firestore rules to block reads**: Rejected — attacker with the admin URL + a valid customer account could still call `firebase.firestore().doc('stats/global').get()` from the browser console; rules allow it because stats is world-readable. We must kill the session.

---

## R2. reCAPTCHA Enterprise v3 site-key procurement

**Decision**: The key MUST be a real, Firebase-Console-registered reCAPTCHA Enterprise v3 site key for the `syana-ea75a` project, tied to the domain that the Firebase Hosting site `syanat-admin` resolves to (default: `syanat-admin.web.app` plus the `*.firebaseapp.com` alias, and any preview-channel domain Firebase auto-registers). Implementation Task 6-0b (new task to be added by `/speckit.tasks`) reads the key value from a human operator and substitutes it into `main.dart`. The placeholder string `YOUR_RECAPTCHA_V3_SITE_KEY` is FORBIDDEN in any shipped build (Principle VIII).

**Rationale**: Principle VIII: "Shipping, committing, or previewing the literal placeholder YOUR_RECAPTCHA_V3_SITE_KEY to any deployed channel (including preview) is forbidden." Spec FR-007 + Edge Case in spec.md make this failure loud on startup.

**Alternatives considered**:
- **reCAPTCHA v3 Free tier**: Rejected — Firebase App Check Web only supports reCAPTCHA Enterprise v3 (not the free v3 or v2) as of 2024+. The constitution explicitly names "reCAPTCHA Enterprise v3."
- **Skip App Check for Phase 6 preview and add it in Phase 7**: Rejected — Principle VIII says public web config without App Check is "treated as a leaked secret." We do not ship even a preview without App Check.
- **Hard-code the key in source control**: Allowed — reCAPTCHA site keys ARE public by design (domain-bound). We do NOT store the secret key (only the server verifies that), only the site key. The key still must be a real one, not the placeholder.

---

## R3. Firebase Hosting site creation

**Decision**: The Hosting site `syanat-admin` is assumed to already exist in project `syana-ea75a` (spec Assumption A-3). If a `firebase deploy --only hosting:syanat-admin` fails with "site not found," the operator runs `firebase hosting:sites:create syanat-admin` once and re-tries. The first deploy MUST be a preview channel (`firebase hosting:channel:deploy preview-shell`), not a production deploy (FR-010).

**Rationale**: Migration Plan Decision D11 pins the site name. The preview-first gate is Principle IV: "Every production deploy must be preceded by a Firebase preview channel deploy."

**Alternatives considered**:
- **Use the default hosting site (`syana-ea75a.web.app`)**: Rejected — that site is currently unused but the constitution names `syanat-admin` explicitly, and a dedicated site simplifies future DNS/custom-domain setup.

---

## R4. Flutter SDK / channel pin

**Decision**: Flutter stable channel. Dart SDK constraint `^3.5.3` (matches the mobile project's `pubspec.yaml` line 22). No explicit Flutter version pin beyond "stable channel" — `actions/flutter-action@v2` on the `stable` channel will pull whatever stable release is current at CI run time.

**Rationale**: Constitution Principle VI + Technology Constraints. Assumption A-5 says "no version upgrade is introduced by this spec."

**Alternatives considered**:
- **Pin a specific Flutter version in CI**: Optional enhancement, not required. If CI ever breaks because `stable` moved, we pin at that point — not pre-emptively (Principle VII).
- **Beta/master channel**: Rejected — no business justification.

---

## R5. Google sign-in on Flutter Web

**Decision**: Use `google_sign_in` package + `FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(...))`. OAuth 2.0 Web client ID and authorized domains MUST be configured in the Firebase Console under Authentication → Sign-in method → Google. Assumption A-7 covers this.

**Rationale**: Standard Firebase web Google sign-in pattern. `google_sign_in` is on the constitution's allow-list.

**Alternatives considered**:
- **`signInWithPopup(GoogleAuthProvider())`** (using FirebaseAuth's built-in popup, no `google_sign_in` package): Technically simpler — zero deps beyond `firebase_auth`. **Rejected** because the migration plan's Resolved Blueprint pins `google_sign_in` in the allow-list, the mobile app's login flow uses the same package, and Phase 7 feature work is easier if both codebases share the same Google-auth ergonomics. This decision is final for Specs 004–006; revisit only via a constitution amendment.
- **Email-only (no Google)**: Rejected — FR-014/FR-016 require both.

---

## R6. Navigation approach

**Decision**: `Scaffold(body: Row([NavigationRail, VerticalDivider(thickness: 1), Expanded(IndexedStack)]))`, state owned by a single `StatefulWidget` (`DashboardScreen`). Selected index is `int` held in `_DashboardScreenState._selectedIndex`, defaulting to `0` (Overview). The `IndexedStack` keeps each placeholder alive to avoid rebuild cost when the same destination is re-tapped (Edge Case: "Clicking the same nav rail destination twice: the rebuild must be cheap").

**Rationale**: No routing package needed for a 6-destination shell where each destination is a single placeholder widget. `IndexedStack` gives the "rebuild is cheap" property for free. Adding `go_router` or `auto_route` in Phase 6 would be premature abstraction (Principle VII).

**Alternatives considered**:
- **`go_router` with 6 top-level routes**: Rejected — introduces a dependency not on the allow-list and adds URL-bar state management that Phase 6 doesn't need (per US3 AS5, selected-section persistence across refresh is explicitly NOT required).
- **`Navigator` with named routes**: Rejected — same reason; more boilerplate than value for a single-shell app.

---

## R7. Theme / visual design

**Decision**: `MaterialApp` with `ThemeData.light(useMaterial3: true)`, `debugShowCheckedModeBanner: false` (FR-030). The `useMaterial3` flag MUST be set explicitly — Flutter's default toggled from Material 2 to Material 3 around Flutter 3.16, and leaving the flag implicit would make the shell's visuals silently shift across Flutter upgrades. Phase 6 locks Material 3 so CI snapshots are deterministic. No `GoogleFonts` usage in Phase 6 — the `google_fonts` dependency stays in `pubspec.yaml` (it is on the constitution allow-list and Phase 7 features may use it) but no Phase 6 widget invokes it.

**Rationale**: Phase 6 is a shell; visual polish is premature (Principle VII). Using a built-in theme means zero risk of a styling regression in Phase 7.

**Alternatives considered**:
- **Port the mobile app's exact theme**: Rejected — unnecessary work; the two apps need not match pixel-for-pixel and coupling them now would require refactoring in Phase 7.

---

## R8. CI workflow shape

**Decision**: `.github/workflows/admin-web.yml`, triggered on `pull_request` events with `paths: ['.claude/AdminWebApp/**', '.github/workflows/admin-web.yml']`. Steps: `actions/checkout@v4` → `subosito/flutter-action@v2` (channel: `stable`) → `flutter --version` (debug output) → `flutter pub get` (cwd: `.claude/AdminWebApp`) → `flutter analyze` (cwd: `.claude/AdminWebApp`) → `flutter build web --web-renderer html --release` (cwd: `.claude/AdminWebApp`). Runs on `ubuntu-latest`. No caching in Phase 6 (add later if CI runs exceed SC-006's 10-minute budget).

**Rationale**: Minimal workflow that satisfies FR-011, FR-012, FR-013, SC-006, SC-007. No deploy step — deploys are manual via Firebase CLI until Spec 005+ needs automation.

**Alternatives considered**:
- **Also run on `push` to main**: Rejected — PR-only is enough for FR-011/FR-013 and avoids duplicate runs on merge.
- **Use `pub.dev/setup-flutter` instead of `subosito/flutter-action`**: `subosito/flutter-action@v2` is the community-standard action and is what Flutter's own docs recommend. No reason to deviate.

---

## R9. Error-display UX for login failures

**Decision**: A `Text` widget in the login form shows the `FirebaseAuthException.message` string when the last sign-in attempt failed. The widget is hidden when no error is present. No friendly-message mapping in Phase 6 (mapping is deferred to Phase 7 polish).

**Rationale**: FR-020, Principle XIII — "Error messages shown in the admin web UI on a failed CF call MUST use the `HttpsError.message` field only." `FirebaseAuthException.message` is the equivalent for auth failures and is already English and human-readable.

**Alternatives considered**:
- **SnackBar for errors**: Rejected — harder to scan during rapid-fire login attempts than inline text, and harder to grep in a screenshot during bug triage.

---

## R10. Optional Overview smoke test wiring

**Decision**: The Overview placeholder MAY wrap its text in a `StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>` over `AdminFirebaseService().streamStats()`. The builder renders the placeholder text regardless of stream state — it is a smoke test, not a feature. If the stream errors, the placeholder still renders.

**Rationale**: FR-027 requires `streamStats()` to be implemented; wiring it to the Overview placeholder gives the preview-channel deploy (US1) an easy visual confirmation that Firestore reads are reaching the client through App Check. Non-mandatory because FR-024 says "Each destination MAY render a simple placeholder."

**Alternatives considered**:
- **Call `streamStats()` eagerly in `main.dart`**: Rejected — wastes a read on every boot even when the admin never navigates to Overview.

---

## R11. Firestore web security: what is locked, what is open

**Decision**: This spec does NOT modify `firestore.rules`. The rules deployed by Specs 001 and 003 already enforce that `users/{uid}` is readable by its owner (so `_AdminCheck` reads the admin's own user doc as themselves) and that `stats/global` is world-readable for authenticated users (`streamStats()` succeeds under any signed-in account, not just admin). No new index is added because all reads are by primary key.

**Rationale**: Keeping the rules file out of this spec preserves Principle IV (atomic deploys coupling rules + code) — there is no code here that needs a new rule. Verified by reading `firestore.rules` from the current branch.

**Alternatives considered**:
- **Lock `stats/global` to admin-only read**: Rejected — out of scope; would break the mobile app's existing stats usage (Principle V, Backward Compatibility).

---

## R12. `firebase.json` hosting block shape

**Decision**: Add a top-level `hosting` object (new; `firebase.json` currently has no hosting block — verified):

```json
"hosting": {
  "site": "syanat-admin",
  "public": ".claude/AdminWebApp/build/web",
  "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
  "rewrites": [{ "source": "**", "destination": "/index.html" }]
}
```

Placed alongside the existing `firestore`, `storage`, `functions`, and `emulators` keys. No existing hosting block to merge with (Assumption A-9).

**Rationale**: Exact match with FR-008. The `ignore` list is the Firebase CLI default plus `firebase.json` itself (standard practice).

**Alternatives considered**:
- **Multi-site hosting (array form)**: Rejected — Assumption A-9 forbids adding a second site in this spec. If a second hosting site ever materializes, this block is upgraded to an array at that time.

---

## R13. google_sign_in web config file

**Decision**: On Flutter Web, `google_sign_in` discovers the OAuth client ID via a `<meta name="google-signin-client_id" content="<CLIENT_ID>.apps.googleusercontent.com">` tag injected into `.claude/AdminWebApp/web/index.html`. The client ID comes from the Firebase Console (Auth → Google provider → Web SDK config). If the meta tag is missing, Google sign-in fails at runtime with a confusing error — Assumption A-7 in the spec warns the implementer.

**Rationale**: This is the documented Flutter Web path for `google_sign_in`. It pairs with the Firebase Auth Google provider being enabled in the console.

**Alternatives considered**:
- **Pass `clientId:` argument to `GoogleSignIn()` constructor**: Possible, but requires another compile-time constant; the meta tag is the canonical Flutter Web config surface.

---

## R14. Deferred / out-of-scope for this spec

The following items are explicitly deferred and MUST NOT be added by the Phase 6 implementer:

- **Feature screens** (Overview KPIs, Jobs list/assign, Payments review, Disputes, Support chat, Activity feed) — Phase 7 (Spec 005).
- **Mobile admin route removal** — Phase 8 (Spec 006).
- **Custom domain for `syanat-admin`** — operational, no spec coupling.
- **Sentry / Crashlytics wiring** — not required by Principle XIII, which only forbids certain content in logs.
- **Widget/unit tests** — not required by this spec; CI validates via `analyze + build`.
- **Production App Check enforcement toggle** (Monitor-only → Enforced) — must be flipped in Firebase Console by operator before Spec 005 per Principle XII; tracked in Spec 005's plan.

---

## Outstanding questions

**None** — every NEEDS CLARIFICATION from Technical Context is resolved above.
