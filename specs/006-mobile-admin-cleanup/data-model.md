# Phase 1 Data Model: Mobile Admin Cleanup

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md) | **Date**: 2026-04-20

This feature is deletion-scoped and introduces **zero new Firestore collections, zero new documents, zero schema changes, and zero new indexes**. The "data model" for this spec is therefore almost entirely a record of what is removed, what is preserved, and what telemetry is emitted.

---

## 1. Firestore collections — no change

| Collection | Change in this spec | Rationale |
|-----------|---------------------|-----------|
| `users/{uid}` | None | Role detection continues to read `role` on sign-in. |
| `jobs/{jobId}` | None | Customer and technician flows are preserved bit-for-bit. |
| `payments/{paymentId}` | None | No mobile admin write path existed that wrote here; removing unused admin methods in mobile does not affect web or Cloud Functions writes. |
| `activity_log/{entryId}` | None | Read/written only by backend; mobile client has no write path here. |
| `support_chats/{chatId}` and `support_chats/{chatId}/messages/*` | None | Admin-side writes are done from the web app; mobile deletes the `closeSupportChat` / `markSupportChatReadByAdmin` caller code only. |
| `stats/global` | None | No client writes in either release (SC-009 confirms zero writes post-Release-2). |
| `_event_dedup/{eventId}` | None | Backend-only. |

No new collections are created. No existing collections are renamed, sharded, or migrated.

---

## 2. Firestore indexes — no change

`firestore.indexes.json` is unchanged by this spec. The deletions in Release 2 remove *callers* of existing indexed queries from the mobile client — they do not change the set of queries that exist in the system overall (the same queries continue to run from the admin web app).

---

## 3. Firestore security rules — no change

`firestore.rules` is unchanged by this spec. The mobile client's removal of admin-facing code strictly reduces the set of writes the rules ever have to evaluate on mobile traffic; it does not change what the rules permit. Principle IX's "when a CF takes ownership of a write path, the corresponding client-direct path in the rules MUST be closed" is a constraint on earlier specs (001–003), not this one — the admin-only client-direct paths were already closed in those specs.

---

## 4. Mobile app source-file inventory

### 4a. Files created in Release 1

| File | Purpose | Lifetime |
|------|---------|----------|
| `lib/admin_redirect_screen.dart` | New `StatefulWidget` (stateful only so its `initState()` can emit the analytics event exactly once). Displays the generic "admin has moved to the web dashboard" message, the deployed web URL as `SelectableText`, and a "Copy URL" `TextButton` whose `onPressed` writes the URL to the system clipboard and surfaces a `SnackBar` confirmation. Holds an `_eventEmitted` guard. Holds no Firestore or Functions references. | Present in Release 1; DELETED in Release 2. |

### 4b. Files created in Release 2

| File | Purpose | Lifetime |
|------|---------|----------|
| `lib/unauthorized_screen.dart` | New `StatelessWidget`. Displays a generic message ("Your account is not available on this app" in English; existing Arabic localization pattern applied) and nothing else. No URL, no buttons, no network I/O, no analytics event. | Present from Release 2 onwards. |

### 4c. Files modified

| File | Release 1 change | Release 2 change |
|------|------------------|------------------|
| `lib/login_screen.dart` | `_routeByRole` replaces `role == 'admin'` branch's target from `AdminDashboardScreen` to `AdminRedirectScreen`. The `else` fallthrough to `UserHomeScreen` remains unchanged in Release 1. | `_routeByRole` rewritten to three explicit branches (see research.md R5). The `admin` branch and the default branch both route to `UnauthorizedScreen`; `customer` becomes explicit. The import of `AdminDashboardScreen` is removed (the import of `AdminRedirectScreen` that Release 1 added is also removed). |
| `lib/firebase_service.dart` | No change. | The 15 admin-only methods are deleted (see §5). All imports rendered orphaned by the deletion are removed from the file. The file stays on disk because non-admin flows continue to depend on it. |
| `pubspec.yaml` | `firebase_analytics` added as a new dependency, with the caret constraint resolved at implementation time via `flutter pub outdated` (see research.md R1). | Any dependency whose only in-tree callers were in the deleted admin screens and deleted admin methods is removed (FR-016). A dependency that is also used by customer or technician flows is preserved. |

### 4d. Files deleted in Release 2

| File | Why it is deleted | Caller removed? |
|------|-------------------|-----------------|
| `lib/admin_dashboard_screen.dart` | The mobile admin entry point is gone. | Release 2's `_routeByRole` no longer references it. |
| `lib/admin_support_chat_screen.dart` | Admin-side support chat is gone; admins use the web app. | The only caller was inside `admin_dashboard_screen.dart`, which is also deleted. |
| `lib/admin_redirect_screen.dart` | The redirect screen is a Release 1 artifact. Release 2's `_routeByRole` routes admin to `UnauthorizedScreen` instead. | Release 2's `_routeByRole` no longer imports it. |

---

## 5. `firebase_service.dart` admin-only method inventory (deleted in Release 2)

Per **FR-011**. These are the objects of deletion — the plan copies the exact names verbatim so the PR's verification grep is unambiguous.

| # | Method | Line in spec's Assumption ref | Current caller file(s) | Safe to delete? |
|---|--------|------------------------------|------------------------|-----------------|
| 1 | `assignJob` | `firebase_service.dart:1048` | `admin_dashboard_screen.dart` | Yes — confirmed by grep 2026-04-20 |
| 2 | `adminCloseJob` | `:1109` | `admin_dashboard_screen.dart` | Yes |
| 3 | `adminResolveDispute` | `:1596` | `admin_dashboard_screen.dart` | Yes |
| 4 | `updatePaymentStatus` | `:912` | `admin_dashboard_screen.dart` | Yes |
| 5 | `closeSupportChat` | `:704` | `admin_support_chat_screen.dart` | Yes |
| 6 | `markSupportChatReadByAdmin` | `:712` | `admin_support_chat_screen.dart` | Yes |
| 7 | `initializeStatsGlobal` | `:1711` | `admin_dashboard_screen.dart` | Yes |
| 8 | `streamActiveJobsAdmin` | `:1169` | `admin_dashboard_screen.dart` | Yes |
| 9 | `streamJobsByStatus` | `:1154` | `admin_dashboard_screen.dart` | Yes |
| 10 | `streamAllPayments` | `:920` | `admin_dashboard_screen.dart` | Yes |
| 11 | `streamSupportChats` | `:647` | `admin_support_chat_screen.dart` | Yes |
| 12 | `streamUnreadSupportCount` | `:661` | `admin_dashboard_screen.dart` | Yes |
| 13 | `fetchRecentUsers` | `:1318` | `admin_dashboard_screen.dart` | Yes |
| 14 | `fetchRecentActivity` | `:1690` | `admin_dashboard_screen.dart` | Yes |
| 15 | `getAvailableTechnicianIdsByService` | `:1198` | `admin_dashboard_screen.dart` | Yes |

**Line numbers** are quoted from the migration plan's Phase 8 task detail and are re-verified at implementation time (Principle III — No Guessing). If any line has shifted, the implementer re-grep's on the method name and updates this table in the Release 2 PR description.

**Pre-verification** (2026-04-20): the source grep in research.md R6 confirms every listed method is referenced only inside the two admin screen files (which are themselves deleted) and its own definition. None is called from a customer or technician flow. All 15 meet FR-012's precondition.

---

## 6. Analytics event schema (Release 1 only)

### Event: `admin_redirect_shown`

Emitted exactly once per render of `AdminRedirectScreen` (from `initState()`, guarded by an instance-local `_eventEmitted` flag).

**Parameters:**

| Field | Type | Required | Value semantics |
|-------|------|----------|-----------------|
| `uid_hash` | String | Yes | First 12 hex characters of `sha256(uid)`. Lowercase. Never the raw UID. Never the raw email. |

**Non-parameters (MUST NOT be emitted):**

- The raw Firebase UID.
- The user's email, phone, or display name.
- Any portion of the Firebase ID token.
- Any device identifier beyond what Firebase Analytics emits by default for all mobile events in this project.
- Any Firestore document content.

**Release 2 expectation**: event rate drops to zero globally within 48 hours of Release 2 rollout across the installed base (SC-007, FR-015). Lingering emissions after the 48-hour window indicate users on stale binaries — this is expected for several weeks but does not block sign-off provided the gate was evidenced before Release 2 shipped.

---

## 7. Validation & state transitions

There are no state transitions in this feature. No field changes in any Firestore document. No callable invocations. The only "state transition" is mobile-client-local routing:

1. User signs in (existing flow, unchanged).
2. Login screen reads `users/{uid}.role` (existing behavior, unchanged).
3. Release 1: `admin → AdminRedirectScreen`, `technician → TechHomeScreen`, everything else → `UserHomeScreen`.
4. Release 2: `customer → UserHomeScreen`, `technician → TechHomeScreen`, everything else (including `admin`) → `UnauthorizedScreen`.

Step 2's Firestore read is the same read that Release 0 (pre-feature) performed; it is not introduced by this spec.

---

## 8. What this feature explicitly does NOT model

- No new callables.
- No new Firestore collections or subcollections.
- No new indexes.
- No rule changes.
- No new storage paths.
- No shared package, no new mono-repo artifact.
- No batch job, no migration script.
- No data migration (user documents are unchanged; role values are unchanged).
- No changes to auth providers or sign-in methods.

If a future spec needs to add any of those, it MUST be filed as a separate spec. This one is exclusively a deletion and a routing change, with one small telemetry addition to measure the observation gate.
