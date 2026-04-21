# Syanat-lastupdate Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-04-20

## Active Technologies
- TypeScript 5.x (strict mode) on **Node.js 20** runtime **[Clarified 2026-04-15]** — supersedes Node 18 referenced in constitution §Technology Constraints (see Complexity Tracking). + `firebase-functions` (2nd-gen), `firebase-admin` (SDK), `firebase-functions-test` (unit harness), `jest` + `ts-jest` (runner), `@firebase/rules-unit-testing` (optional, for FR-012 rule scenario). No HTTP framework — Firebase callable protocol only. No external SDKs — every write goes through the Firebase Admin SDK. (002-cloud-functions)
- Firestore (`jobs/*`, `payments/*`, `activity_log/*`, `users/*`) in the existing `syana-ea75a` project. No new collections. No new composite indexes (all admin-function writes are by primary key). (002-cloud-functions)
- TypeScript 5.x (strict mode) on Node.js 20 runtime — same engine as Spec 002. No runtime bump is introduced by this spec; the `functions/package.json` already pins `engines.node = "20"`. + `firebase-functions` (2nd-gen Firestore triggers — `onDocumentCreated`, `onDocumentUpdated`), `firebase-admin` (SDK for counter writes + event-ID dedup), `firebase-functions-test` + `jest` + `ts-jest` (existing harness from Spec 002). No new dependencies. No external SDKs. (003-event-driven-stats)
- Firestore in existing `syana-ea75a` project. Collections read: `users/{uid}`, `jobs/{jobId}`. Collection written: `stats/global` (single doc, merge-write). New collection introduced: `_event_dedup/{eventId}` — short-TTL marker documents for idempotency (FR-007). No new composite indexes (all writes are by primary key). (003-event-driven-stats)
- Dart (Flutter stable channel). Dart SDK constraint `^3.5.3`, matching the mobile project's `pubspec.yaml`. + `firebase_core`, `firebase_auth`, `cloud_firestore`, `cloud_functions`, `google_sign_in`, `google_fonts`, `firebase_app_check` — exact allow-list from Constitution §Technology Constraints. No routing package (single-route shell + `AuthGate` + nav-rail `IndexedStack`). (004-admin-web-shell)
- Firestore in existing project `syana-ea75a`. Reads only in Phase 6: `users/{uid}` (one-shot read for admin role), `stats/global` (stream for optional Overview placeholder smoke test). No writes initiated from this shell. (004-admin-web-shell)
- Dart (Flutter stable channel). Dart SDK constraint `^3.5.3`, unchanged from Spec 004 `pubspec.yaml`. + Allow-listed from Constitution §Technology Constraints — `firebase_core ^3.6.0`, `firebase_auth ^5.3.1`, `cloud_firestore ^5.4.4`, `cloud_functions ^5.1.3`, `firebase_app_check ^0.3.1+6`, `google_sign_in ^6.2.1`, `google_fonts ^6.2.1`. No new dependencies introduced by this spec. (005-admin-web-features)
- Firestore in existing project `syana-ea75a`. Reads: `stats/global` (stream, single doc), `jobs/*` (3 bounded streams, all `.limit(50)`), `payments/*` (one stream, `.limit(100)`), `support_chats/*` (inbox stream `.limit(50)` + unread-count stream `.limit(100)`), `support_chats/{chatId}/messages/*` (per-chat stream `.limit(50)` with `startAfterDocument` pagination on scroll), `activity_log/*` (one stream, `.limit(50)`), `users/*` (one-shot `.get()` with `.limit(100)` for available-technician lookup). Writes: zero direct writes to `jobs/*`, `payments/*`, `stats/*`, `activity_log/*`. Direct writes allowed ONLY on `support_chats/*` fields `unreadByAdmin`, `status`, `closedAt`, `lastMessageAt` and the `messages/*` subcollection create — matching the rules in `firestore.rules` lines 370–425. (005-admin-web-features)
- Dart (Flutter stable channel). Dart SDK constraint `^3.5.3`, unchanged from the existing root `pubspec.yaml`. + Existing mobile app dependencies (unchanged list): `flutter`, `google_fonts ^6.2.1`, `video_player ^2.8.6`, `location ^6.0.2`, `flutter_local_notifications ^17.1.2`, `firebase_core ^3.1.1`, `firebase_auth ^5.1.1`, `cloud_firestore ^5.0.2`, `firebase_storage ^12.1.1`, `firebase_app_check ^0.3.1`, `geolocator ^12.0.0`, `image_picker ^1.0.7`, `flutter_image_compress ^2.3.0`, `google_sign_in ^6.2.1`, `sign_in_with_apple ^6.1.0`, `crypto ^3.0.3`. **Release 1 adds**: `firebase_analytics` (stable pub.dev version matching the pinned `firebase_core ^3.1.1` family — verified at implementation time). No other dependency additions, upgrades, or removals in either release unless a deletion strictly orphans a package (FR-016). (006-mobile-admin-cleanup)
- Firestore in existing project `syana-ea75a`. **Release 1**: zero Firestore reads or writes originate from the redirect screen (FR-004). **Release 2**: mobile client emits zero writes to `stats/global`; no rule changes, no index changes, no new collections. Telemetry store is Firebase Analytics (not Firestore) for the `admin_redirect_shown` event. (006-mobile-admin-cleanup)

- Firestore Security Rules v2 (CEL); Dart / Flutter 3.41.0 for the one mobile edit + Firebase CLI (rules deploy); existing `firebase_storage` Dart SDK already in `lib/firebase_service.dart` (001-firestore-rules-hardening)

## Project Structure

```text
backend/
frontend/
tests/
```

## Commands

# Add commands for Firestore Security Rules v2 (CEL); Dart / Flutter 3.41.0 for the one mobile edit

## Code Style

Firestore Security Rules v2 (CEL); Dart / Flutter 3.41.0 for the one mobile edit: Follow standard conventions

## Recent Changes
- 006-mobile-admin-cleanup: Added Dart (Flutter stable channel). Dart SDK constraint `^3.5.3`, unchanged from the existing root `pubspec.yaml`. + Existing mobile app dependencies (unchanged list): `flutter`, `google_fonts ^6.2.1`, `video_player ^2.8.6`, `location ^6.0.2`, `flutter_local_notifications ^17.1.2`, `firebase_core ^3.1.1`, `firebase_auth ^5.1.1`, `cloud_firestore ^5.0.2`, `firebase_storage ^12.1.1`, `firebase_app_check ^0.3.1`, `geolocator ^12.0.0`, `image_picker ^1.0.7`, `flutter_image_compress ^2.3.0`, `google_sign_in ^6.2.1`, `sign_in_with_apple ^6.1.0`, `crypto ^3.0.3`. **Release 1 adds**: `firebase_analytics` (stable pub.dev version matching the pinned `firebase_core ^3.1.1` family — verified at implementation time). No other dependency additions, upgrades, or removals in either release unless a deletion strictly orphans a package (FR-016).
- 005-admin-web-features: Added Dart (Flutter stable channel). Dart SDK constraint `^3.5.3`, unchanged from Spec 004 `pubspec.yaml`. + Allow-listed from Constitution §Technology Constraints — `firebase_core ^3.6.0`, `firebase_auth ^5.3.1`, `cloud_firestore ^5.4.4`, `cloud_functions ^5.1.3`, `firebase_app_check ^0.3.1+6`, `google_sign_in ^6.2.1`, `google_fonts ^6.2.1`. No new dependencies introduced by this spec.
- 004-admin-web-shell: Added Dart (Flutter stable channel). Dart SDK constraint `^3.5.3`, matching the mobile project's `pubspec.yaml`. + `firebase_core`, `firebase_auth`, `cloud_firestore`, `cloud_functions`, `google_sign_in`, `google_fonts`, `firebase_app_check` — exact allow-list from Constitution §Technology Constraints. No routing package (single-route shell + `AuthGate` + nav-rail `IndexedStack`).


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
