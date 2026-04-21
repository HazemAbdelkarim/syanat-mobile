# Phase 0 Research: Mobile Admin Cleanup

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-04-20

All five clarification questions in the spec's `## Clarifications > ### Session 2026-04-20` section have been answered; no `NEEDS CLARIFICATION` markers remain in the Technical Context. This document resolves the remaining implementation-choice unknowns that the plan exposes.

---

## R1: Which `firebase_analytics` package version is compatible with the mobile project's pinned `firebase_core ^3.1.1` family?

**Decision**: Use the `firebase_analytics` version that the FlutterFire compatibility matrix lists as paired with the `firebase_core ^3.1.x` line at Release 1 implementation time. The exact version is re-verified via `flutter pub outdated firebase_analytics` before the Release 1 PR merges, and the resolved version is pinned in `pubspec.yaml` with a caret constraint (e.g., `firebase_analytics: ^11.x.y`, matching the FlutterFire sibling version the Firebase team published alongside `firebase_core ^3.1.1`).

**Rationale**:
- The FlutterFire packages are published together; mixing a `firebase_core ^3.1.1` with an incompatible `firebase_analytics` causes either a pub resolution failure or a runtime platform-channel mismatch on iOS/Android.
- Pinning at implementation time (not planning time) avoids stale version choices; `flutter pub outdated` is a standard tool in the existing workflow.
- Using a caret constraint (not `any` and not a literal `=`) matches the pattern already used for every other FlutterFire dependency in `pubspec.yaml`.

**Alternatives considered**:
- Hard-coding a specific version in this plan: rejected because the correct version is a moving target over the ~7–14 days between Release 1 planning and store submission.
- Upgrading the entire `firebase_core` family to the latest release: rejected because this spec's brief explicitly forbids non-essential dependency upgrades (see Out of Scope). The scope is strictly to add one analytics dependency compatible with the current core.

---

## R2: How should the redirect screen hash or truncate the UID for the `admin_redirect_shown` event so Operations can still attribute a test sign-in exception to a single UID without the raw value being emitted?

**Decision**: SHA-256 the raw UID, then encode the first 12 hex characters of the digest. Emit the result as the event parameter `uid_hash` (string). Operations records the same 12-hex-char prefix verbatim in the release log when claiming a test-sign-in exception.

**Rationale**:
- SHA-256 is available in the existing `crypto ^3.0.3` dependency already in `pubspec.yaml` — no new library required.
- 12 hex characters = 48 bits of entropy, collision-resistant enough to distinguish every expected admin across the entire observation window (at most a handful of admin accounts), while being short enough to read and transcribe on a release-log line.
- Emitting only the hash prefix means Firebase Analytics never receives the raw UID, so the parameter is non-PII-equivalent and satisfies FR-007 ("hashed or truncated, never the raw value") and Principle XIII ("analytics events on mobile MUST NOT include PII beyond the signed-in UID, and even the UID is only included when strictly required for debugging" — the hashed prefix is the operationally-required minimum, not the full UID).
- Matching the test-exception UID on the hash prefix is deterministic: the same raw UID always produces the same 12-hex prefix, so Operations can reproduce the match from the release log.

**Alternatives considered**:
- Truncating the raw UID to its first 8 characters: rejected because Firebase UIDs follow a predictable character distribution and the prefix alone is still attributable to one account (it is effectively the raw UID's head, not a hash).
- Using a UUIDv4 per session: rejected because the observation gate requires that the same admin signing in repeatedly generates the same tag (so Operations can distinguish "one admin signed in five times" from "five different admins signed in once") — a per-session UUID would over-count.
- Full SHA-256 hex digest: rejected as unnecessarily long for a release-log identifier; 12 hex chars is sufficient for this project's scale.

---

## R3: How does the redirect screen guarantee "exactly one event per redirect render" in the face of hot-reload, route push/pop, and offline buffered emit?

**Decision**: Emit the event from `initState()` of the `AdminRedirectScreen` `StatefulWidget`. Use a `bool _eventEmitted = false` instance field to guard the call so that any framework-driven re-render (theme change, locale change) does not re-emit. The emit call uses the `firebase_analytics` default pipeline, which handles offline buffering internally; the mobile client is not responsible for retry or batching.

**Rationale**:
- `initState()` is called exactly once per widget instance, which maps 1:1 to a distinct navigation to the redirect screen.
- The `_eventEmitted` guard is defensive against future maintenance that might move the emit out of `initState()` — code review should reject any future change that removes it without replacing it with an equally-idempotent guard.
- Offline support is already guaranteed by the Firebase Analytics SDK (events are buffered on-device and flushed when connectivity returns), so the offline-sign-in edge case in the spec (admin opens the app offline, redirect screen renders, event fires later when online) works without additional mobile-side logic.

**Alternatives considered**:
- Emitting from `build()`: rejected — `build()` can run multiple times per widget lifecycle (for any rebuild) and would over-count.
- Emitting from the login screen's success-path branch rather than the redirect screen: rejected because the login screen does not know whether the redirect rendered successfully; it only knows the role was admin. Moving the emit there breaks the "per render" semantic.
- Using `didChangeDependencies()`: rejected — it can fire multiple times per widget instance.

---

## R4: What is the exact behavior of the Release 2 `UnauthorizedScreen` for an admin who is already signed in? Does it sign them out?

**Decision**: The `UnauthorizedScreen` is a pure display widget — it performs no action, emits no events, and does NOT sign the user out. A signed-in admin who reaches it remains signed in; the login flow already branched at role-detection time and navigated here instead of to the admin-only screen (which no longer exists in the binary). The user can tap the system back gesture to return to the login screen, where they may sign out manually.

**Rationale**:
- The mobile app surface no longer uses admin privileges for anything (all 15 admin methods are deleted in Release 2), so leaving the Firebase session alive has no exploit surface on mobile.
- Signing the user out automatically would conflict with the web-app's defense-in-depth control (Principle IX: web app MUST sign out before rendering the denied screen) — but the web app's concern is that a denied user could still query Firestore via the browser console. The mobile binary has no equivalent console, so the automatic sign-out is not required.
- Keeping the screen stateless and side-effect-free matches the spec's intent of a "static widget displaying a generic message" (FR-013) and avoids introducing a new failure mode (a sign-out network call that could time out while offline).

**Alternatives considered**:
- Automatic sign-out on mount: rejected as unnecessary (see rationale) and risky (introduces a network-dependent side effect in a screen the spec explicitly names "static").
- Adding a "Sign out" button on the screen: rejected — the screen's purpose is a dead-end for unauthorized roles; adding affordances broadens its scope beyond the spec.

---

## R5: How does the login flow cleanly route `admin` to `UnauthorizedScreen` without accidentally routing legitimate customer users there during the Release 2 rollout?

**Decision**: The Release 2 `_routeByRole(String role)` function in `lib/login_screen.dart` is rewritten to three explicit branches:

```dart
void _routeByRole(String role) {
  if (!mounted) return;
  Widget dest;
  if (role == 'customer') {
    dest = const UserHomeScreen();
  } else if (role == 'technician') {
    dest = const TechHomeScreen();
  } else {
    dest = const UnauthorizedScreen();
  }
  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => dest));
}
```

`admin` explicitly falls through the final `else` branch to `UnauthorizedScreen`. Any other unrecognized role also lands there — which is the intended behavior per the spec's clarification (Q1 → A: shared UnauthorizedScreen for `admin` and any unknown role).

**Rationale**:
- The current code's `else → UserHomeScreen` fallthrough (see `lib/login_screen.dart:46–56`) silently routes unknown roles to the customer home. That is the defect FR-013a is written to close: an unknown role should never land on a privileged surface it was not authorized for.
- Making `customer` an explicit branch (not the default) means adding a new role in the future (e.g., `auditor`, `support`) does not accidentally give them the customer experience — it gives them the unauthorized screen until the login flow is updated explicitly.
- The Firestore security rules already gate data access by role independently of what screen the mobile app renders, so a user who lands on UserHomeScreen would not be able to read/write things they are not authorized for — but the UX path would be wrong and the migration plan's spirit (single source of truth for role routing) would be violated. Release 2 closes the UX side of that gap.

**Alternatives considered**:
- A `switch (role) { ... }` with an explicit `default:` branch: functionally equivalent; the `if/else if/else` form is chosen to match the existing code style in `login_screen.dart`.
- A `Map<String, Widget Function()>` registry: rejected as premature abstraction (Principle VII). Three branches are not enough to justify a lookup table.

---

## R6: What is the canonical source-tree scan for FR-010 and FR-011 verification, and how is it run?

**Decision**: The canonical scan is performed with the project's installed `grep` (or ripgrep `rg`) from the repository root, restricted to the `lib/` directory tree. The exact commands are:

```bash
# FR-010: admin screen class names MUST return zero matches post-Release-2
rg -n --type dart 'AdminDashboardScreen|AdminSupportChatScreen|AdminRedirectScreen' lib/

# FR-011: each of the 15 admin-only service method names MUST return zero matches post-Release-2
rg -n --type dart 'assignJob|adminCloseJob|adminResolveDispute|updatePaymentStatus|closeSupportChat|markSupportChatReadByAdmin|initializeStatsGlobal|streamActiveJobsAdmin|streamJobsByStatus|streamAllPayments|streamSupportChats|streamUnreadSupportCount|fetchRecentUsers|fetchRecentActivity|getAvailableTechnicianIdsByService' lib/
```

Both commands MUST return zero matches on the Release 2 commit. The scan is performed from the Release 2 PR description's "verification" section and its output is captured in the sign-off checklist.

**Pre-verification (current state as of 2026-04-20)**: the method-name grep returns three files: `lib/firebase_service.dart` (the definitions), `lib/admin_dashboard_screen.dart` (callers), and `lib/admin_support_chat_screen.dart` (callers). No customer or technician file matches. This confirms FR-012's precondition: all 15 methods have zero non-admin callers; they are safe to delete together.

**Rationale**:
- Ripgrep (or equivalent) is fast, deterministic, and gives line numbers suitable for the PR description.
- Restricting to `lib/` excludes the admin web app (`.claude/AdminWebApp/`), which is out of scope for the mobile source scan. The web app legitimately uses some of the same names (`fetchRecentUsers`, `streamSupportChats`, etc.) — those are expected and unrelated.
- Restricting to `--type dart` excludes spec markdown, the migration plan, and historical logs where the method names also appear (for documentation) — spec documentation is not production code and does not need to be cleansed.

**Alternatives considered**:
- `flutter analyze` alone: insufficient — it would flag unreferenced methods as "unused" but would not flag lingering text references to deleted names (e.g., a TODO comment saying "remove `assignJob` later").
- Recursive manual file inspection: rejected for scale and determinism.

---

## R7: How is Release 1 rolled back if a defect is found before the 7-day gate completes?

**Decision**: Release 1 rollback is by standard store-submission revert, not by this spec's `ROLLBACK.md`. If Release 1 is found defective after ship but before Release 2 starts, the team ships a patch release (Release 1b) that reverts the offending change to a pre-Release-1 state. The 7-day observation clock resets to the day after Release 1b goes live, because the `admin_redirect_shown` event stream is the source of truth and a reverted binary does not emit it.

`ROLLBACK.md` (committed in Release 2's PR per FR-022) governs Release 2 rollback specifically — its target is the Release 1 commit, not pre-Release-1 state. Release 1 rollback is a separate, implicit concern handled by normal store-update workflow.

**Rationale**:
- Spec FR-022 is explicit: the rollback target for Release 2 is the Release 1 commit. Attempting to roll Release 2 further back to pre-Release-1 is outside the supported path (per spec clarification Q4 → A).
- Release 1 is additive (a new screen + a dependency); reverting it cleanly is much easier than reverting Release 2 (which is destructive). Release 1 rollback does not need a committed plan document — the ordinary git revert + store resubmission is sufficient.
- The observation-gate clock is driven by event count, not calendar time (FR-021), so a rolled-back Release 1 binary automatically "stops the clock" because it emits no events.

**Alternatives considered**:
- Committing a separate `ROLLBACK_R1.md` for Release 1: rejected as unneeded ceremony. The spec does not require it and the migration plan explicitly scopes `ROLLBACK.md` to Release 2.
- Treating Release 1 defects as "forward-fix only" (no rollback option): rejected because it would leave admins with a broken redirect screen for the full store-review cycle.

---

## Summary of Phase 0 outcomes

- All clarifications from the spec are resolved in writing.
- No `NEEDS CLARIFICATION` remains in `plan.md` Technical Context.
- Dependency version pinning is deferred to implementation-time (`flutter pub outdated`), consistent with every other FlutterFire dependency in the project.
- The hash-UID strategy uses the existing `crypto` package (no new dependency beyond `firebase_analytics`).
- The pre-verified grep confirms all 15 admin service methods are safely deletable — zero non-admin callers exist today.
- Release 1 rollback is handled by normal store-update flow; Release 2 rollback is governed by a committed `ROLLBACK.md` whose target is the Release 1 commit.

Phase 1 (data model, contracts, quickstart) can proceed.
