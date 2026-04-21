# Web App Migration

## Purpose

This document defines the migration plan for moving the admin dashboard out of the mobile Flutter app and into a separate web app so the shipped mobile apps are smaller, cleaner, and easier to secure.

This is a planning and migration blueprint document only. It does not implement any code.

## Current State In This Repo

The current app is a single Flutter project that contains:

- Customer mobile flows
- Technician mobile flows
- Admin dashboard UI (~2,300 lines in a single screen file)
- Admin support chat UI
- Shared Firebase service logic for all roles (~1,750 lines, all static methods)

The main admin entry points currently visible in the repo are:

- `lib/login_screen.dart` — role-based routing, sends `role == 'admin'` users to `AdminDashboardScreen`
- `lib/admin_dashboard_screen.dart` — the monolithic admin dashboard (4 tabs: Overview, Users, Jobs, Support)
- `lib/admin_support_chat_screen.dart` — admin-side support conversation view
- `lib/firebase_service.dart` — all Firebase interaction for every role, including admin

### Complete Admin Method Inventory In `FirebaseService`

These are all methods currently used exclusively or primarily by admin flows:

| Method | Type | Action |
|--------|------|--------|
| `assignJob(...)` | Write | Assigns technician to requested job (status: requested -> active) |
| `adminCloseJob(...)` | Write | Force-closes a job with amount paid |
| `adminResolveDispute(...)` | Write | Resolves receipt dispute (reopen/complete/cancel) |
| `updatePaymentStatus(...)` | Write | Sets payment to CONFIRMED or REJECTED |
| `closeSupportChat(...)` | Write | Marks a support chat as closed |
| `markSupportChatReadByAdmin(...)` | Write | Clears unread flag when admin opens chat |
| `initializeStatsGlobal()` | Write | Seeds stats/global document from live counts |
| `streamActiveJobsAdmin()` | Read | Streams jobs in active statuses for admin view |
| `streamAllPayments()` | Read | Streams all payment documents |
| `streamAllSupportChats()` | Read | Streams all support chat threads |
| `streamUnreadSupportCount()` | Read | Streams count of unread support chats |
| `fetchRecentUsers(...)` | Read | Fetches latest user signups |
| `fetchRecentActivity(...)` | Read | Fetches recent activity log entries |
| `getAvailableTechnicianIdsByService(...)` | Read | Lists available technicians for assignment |

### Current Firestore Rules Assessment

The Firestore rules are already well-structured with:

- An `isAdmin()` helper function that reads the caller's user document for `role == 'admin'`
- Tight field-level and status-transition constraints on jobs (each status transition is individually gated)
- Admin-only gates on payment status changes, dispute resolution, job deletion, and service catalog mutations
- Append-only activity log with schema enforcement
- Stats collection bounded writes (non-admin users can only change counters by +/-1 per write)

**Known gaps in current rules:**

- Admin write operations (dispute resolution, job cancellation from any status) allow any field changes — no `affectedKeys()` restriction on admin transitions
- Stats collection is writable by any authenticated user (bounded by +/-1), but a malicious user could still drift counters over time. The codebase itself has a TODO: "migrate to Cloud Function event-driven counters"
- Storage rules for `techProfiles/` allow any authenticated user to write any filename (no owner check on the filename path)
- The `isAdmin()` function costs one Firestore document read per rule evaluation, which adds latency and cost at scale

### Current Storage Rules

- `techProfiles/{fileName}` — public read, any authenticated write (5MB, image only)
- `payment_proofs/{fileName}` — authenticated read, any authenticated write (5MB, image only)
- Default deny for everything else

## Why This Migration Makes Sense

Moving admin to a web app gives these benefits:

- Smaller mobile binary because admin screens, admin-only widgets, and admin-only routes are no longer bundled into the customer/technician app
- Cleaner architecture because admin code stops sharing UI structure with mobile flows
- Better security posture because admin behavior can be isolated and tightened
- Easier admin iteration because dashboard changes can be shipped to web without republishing mobile apps
- Better product fit because dashboards, moderation, payment review, and operations tools belong more naturally on web

## Main Problem To Solve

The current coupling is not only in UI. The real coupling is:

- Role-based routing in the login flow (`login_screen.dart` line 49 directly imports and navigates to `AdminDashboardScreen`)
- Admin-only methods mixed into the shared `FirebaseService` (14+ admin methods among 60+ total)
- Admin screens directly depending on mobile app code structure (importing `firebase_service.dart`, `splash_screen.dart`)
- All privileged admin actions executed as direct client-to-Firestore writes, relying entirely on Firestore rules for enforcement

If only the admin screens are removed without changing the service boundaries, the codebase remains entangled and the migration will be incomplete.

## Migration Goal

Target end state:

- Mobile app contains only customer and technician flows
- Admin experience lives in a separate Flutter web app
- Admin-only methods are isolated from the mobile codebase
- The highest-risk admin actions (payment approval, dispute resolution, job force-close) are executed through Cloud Functions, not direct client writes
- Mobile login no longer opens admin screens
- Stats counters are updated by Cloud Function triggers, not client-side increments

## Non-Goals

These are not required for the first migration:

- Rewriting all existing UI from scratch
- Moving customer or technician flows to web
- Introducing a completely different backend
- Building a multi-tenant architecture
- Changing the existing Firebase project
- Extracting a shared Dart package (defer until the admin web app stabilizes)

## Technology Decision: Flutter Web For Admin Dashboard

### Why Flutter Web Is Acceptable Here

- The team already knows Flutter and Dart — no ramp-up cost
- Admin UI can reuse existing data models and Firestore query patterns
- Firebase packages work on web with the same API surface
- The admin dashboard is internal-use, not public-facing — Flutter web's SEO limitations and initial load time are irrelevant
- Admin users will be on desktop browsers with good connections

### Known Trade-offs To Accept

- Flutter web produces a large initial JS bundle (~2-4 MB). Acceptable for an internal tool, but set expectations.
- Flutter web text rendering uses CanvasKit by default, which adds ~1.5 MB. Use `--web-renderer html` for the admin app to reduce this if text-heavy dashboards feel slow.
- Responsive layout must be built from scratch — mobile widget layouts will not look right on desktop without rework. Do not plan to "copy-paste" mobile widgets.
- Browser dev tools are less useful for debugging Flutter web than native Flutter — use `flutter run -d chrome --web-renderer html` during development.

### When To Reconsider

If the admin dashboard later needs: public-facing pages, complex data tables with sorting/filtering/export, or integration with third-party JS widgets — consider migrating the admin web to a standard web framework (React, Next.js) at that point. Do not over-engineer this decision now.

## Recommended Target Architecture

### Practical First Step For This Repo

```text
current repo root/
  lib/                    mobile app stays here
  admin_web/              new separate Flutter web project
    lib/
    web/
    pubspec.yaml
```

This avoids restructuring the existing mobile project. The admin web app gets its own `pubspec.yaml` with only web-compatible dependencies.

### Future Evolution (Not Required For MVP)

If shared Dart code grows beyond copy-pasting a few model classes, restructure to:

```text
apps/
  mobile_app/
  admin_web/
packages/
  shared_core/
    lib/
      models/
      repositories/
```

**Decision point:** Do not move to this structure until at least 3 model files or 2 repository files are being duplicated between mobile and admin web. Premature extraction creates maintenance overhead for a small team.

## Recommended Product Boundary

### Keep In Mobile App

- Customer authentication and onboarding
- Technician authentication and onboarding
- Ordering flow
- Service browsing
- Active jobs for customers and technicians
- User support chat (customer side)
- Technician job workflow (accept, arrive, finish, submit receipt)
- Customer receipt approval/rejection
- Notifications for non-admin users
- In-job chat between customer and technician

### Move To Admin Web App

- Dashboard statistics (Overview tab)
- User overview and recent signups (Users tab)
- Job monitoring: requested, active, completed (Jobs tab with 3 sub-tabs)
- Job assignment (assigning technician to requested job)
- Job force-close
- Payment review and approval/rejection
- Dispute resolution (3-button panel: reopen/complete/cancel)
- Support inbox and admin chat responses (Support tab)
- Unread support count badge
- Recent activity feed
- Stats initialization utility

## Current Files To Treat As Admin Scope

Files to move entirely:

- `lib/admin_dashboard_screen.dart` — all 2,290 lines
- `lib/admin_support_chat_screen.dart`

Files with admin coupling to refactor:

- `lib/login_screen.dart` — remove admin route (lines 6, 49-50)
- `lib/firebase_service.dart` — extract admin methods listed in inventory above

Files to review during migration:

- `firestore.rules` — verify admin write gates are tight enough for web-only admin
- `storage.rules` — no admin-specific changes needed currently
- `firebase.json` — add hosting configuration for admin web app

## Migration Strategy

Use a phased migration. Do not try to move everything in one large cut.

**Critical sequencing principle:** Security hardening for privileged write actions must happen before or during feature migration, not after. The current plan moves the UI first and hardens later — this creates a window where a new web client executes sensitive actions (payment approval, dispute resolution) with no backend enforcement beyond Firestore rules. Since these actions involve money and trust, backend enforcement should be built as each feature is migrated.

### Phase 0: Discovery, Security Audit, And Design

**Duration estimate:** 1-2 days

**Deliverables:**

- Admin feature inventory (table format, see Detailed Blueprint section 2)
- Security classification of every admin write action
- Cloud Functions decision for each privileged write
- Web app scope for MVP
- Firebase Hosting configuration plan

**Tasks:**

1. Review `lib/admin_dashboard_screen.dart` and map each tab/section to its data sources and write actions.
2. Review `lib/admin_support_chat_screen.dart`.
3. Review admin role routing in `lib/login_screen.dart`.
4. Tag all admin-only methods in `lib/firebase_service.dart` (use the inventory table above as starting point).
5. Review Firestore rules — confirm that every admin write path has an `isAdmin()` gate. (Current assessment: they do, but admin transitions lack `affectedKeys()` restrictions.)
6. **Decide:** Which admin actions will move to Cloud Functions vs remain as direct client writes. Use the risk classification in the Security Blueprint section below.
7. **Decide:** Whether to use Firebase Custom Claims for admin role instead of Firestore document reads. (Recommendation: yes — see Authentication section below.)

**Exit criteria:** A completed data access map table and a signed-off list of which actions get Cloud Functions.

### Phase 1: Backend Hardening (Cloud Functions + Auth)

**Duration estimate:** 2-3 days

**Why this comes before UI work:** Building Cloud Functions first means the admin web app calls secure endpoints from day one. If you build UI first, you ship insecure direct writes and then retrofit — which means rewriting call sites twice.

**Deliverables:**

- Cloud Functions for high-risk admin actions
- Firebase Custom Claims setup for admin role (if decided in Phase 0)
- Updated Firestore rules if needed
- Stats counter migration to event-driven Cloud Functions

**Tasks:**

1. **Set up Cloud Functions project** in the repo (`functions/` directory with TypeScript).
2. **Implement callable Cloud Functions** for these high-risk actions:
   - `adminApprovePayment` / `adminRejectPayment` — validates admin claim, updates payment status, logs audit trail
   - `adminResolveDispute` — validates admin claim, enforces valid resolution types, logs audit trail
   - `adminCloseJob` — validates admin claim, enforces idempotency, logs audit trail
   - `adminAssignJob` — validates admin claim, validates technician exists and is available
3. **Implement event-driven Cloud Functions** for stats:
   - `onUserCreate` — increment totalUsers, customers/technicians counter
   - `onJobStatusChange` — update jobsRequested/jobsOngoing/jobsCompleted/jobsCancelled counters
   - `onPaymentConfirmed` — update totalEarnings
   - This replaces the current client-side stats writes that the codebase itself flags as needing migration
4. **Set up Firebase Custom Claims** (if decided):
   - Create an admin Cloud Function or Firebase Admin SDK script to set `{ admin: true }` custom claim on admin user accounts
   - Update Firestore rules to use `request.auth.token.admin == true` instead of the document-read `isAdmin()` helper
   - This eliminates one Firestore read per rule evaluation and prevents admin role from being spoofed via direct document writes
5. **Tighten Firestore rules** for admin transitions:
   - Add `affectedKeys()` restrictions to admin dispute resolution writes
   - Add `affectedKeys()` restrictions to admin job cancellation writes
   - Lock down stats writes to admin-only (or remove non-admin write access entirely once event-driven functions handle counters)
6. **Deploy and test** Cloud Functions in staging/emulator before proceeding.

**Exit criteria:** All high-risk admin actions can be called via Cloud Functions. Stats are updated by event triggers. Functions pass integration tests in the Firebase emulator.

### Phase 2: Create Admin Web App Shell

**Duration estimate:** 1-2 days

**Deliverables:**

- New Flutter web app scaffold at `admin_web/`
- Firebase initialization for web
- Admin login gate
- Basic dashboard layout shell
- Firebase Hosting configuration

**Tasks:**

1. Create `admin_web/` Flutter project: `flutter create --platforms web admin_web`
2. Add `firebase.json` hosting configuration:
   ```json
   {
     "hosting": {
       "site": "syanat-admin",
       "public": "admin_web/build/web",
       "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
       "rewrites": [{ "source": "**", "destination": "/index.html" }]
     }
   }
   ```
3. Initialize Firebase in the web app (same Firebase project, web app registration in Firebase Console).
4. **Register the web app for App Check** if App Check is active. Web uses reCAPTCHA Enterprise provider, not the mobile providers.
5. Add admin auth gate:
   - Sign in (email/password or Google — Apple Sign-In is not practical for a web-only admin tool)
   - If using Custom Claims: check `idTokenResult.claims['admin'] == true`
   - If using Firestore role: fetch profile, confirm `role == admin`
   - Deny access with a clear message otherwise
   - Do not expose any admin routes or data before the gate passes
6. Build the navigation shell:
   - Responsive sidebar (not tabs — tabs are a mobile pattern, sidebar is standard for web dashboards)
   - Sections: Overview, Jobs, Payments, Support, Activity
   - Placeholder content in each section

**Exit criteria:** Admin can log in on the web app, see the navigation shell, and be denied access if not admin role. Firebase Hosting serves the app.

### Phase 3: Migrate Admin Features One By One

**Duration estimate:** 5-8 days

**Deliverables:**

- Working web dashboard features with equivalent behavior
- Each feature calling Cloud Functions for writes (not direct Firestore writes)

**Recommended migration order:**

1. **Dashboard stats** (read-only, lowest risk, immediate visual confirmation)
2. **Support inbox + unread count** (read + simple write: mark read, close chat, send message)
3. **Active jobs monitoring** (read-only list with detail views)
4. **Job assignment** (write: assigns technician to requested job — calls Cloud Function)
5. **Payment review and approval/rejection** (write: calls Cloud Function)
6. **Dispute handling** (write: calls Cloud Function)
7. **Recent users + recent activity** (read-only, can be deferred past MVP)
8. **Job force-close** (write: calls Cloud Function, rare operation)

**Per-feature migration checklist:**

For each feature migrated:

- [ ] Web UI renders the same data as mobile admin
- [ ] Write actions call the Cloud Function (not direct Firestore)
- [ ] Firestore streams/queries work correctly on web
- [ ] Edge cases handled (empty states, loading states, error states)
- [ ] Tested with real data in staging

**Important implementation notes:**

- Do not copy-paste mobile widget code. Mobile uses `TabController`, `BottomSheet`, mobile-sized cards. Web should use sidebar navigation, full-width tables, dialog modals.
- Firestore `snapshots()` streams work identically on web. No changes needed to query logic.
- For the requested/active/completed jobs sub-views: use a segmented control or top tabs within the Jobs section, not the mobile `TabBarView` pattern.
- Support chat: the admin support chat screen is a real-time messaging UI. This works fine on Flutter web — no special handling needed.

### Phase 4: Remove Admin From Mobile App

**Duration estimate:** 1 day

**Prerequisite:** Admin team has used the web app for at least 1 week in production without blockers.

**Deliverables:**

- No admin dashboard bundled into mobile app
- Mobile login no longer routes into admin screens
- Mobile binary size reduced

**Tasks:**

1. Remove admin route from `lib/login_screen.dart`:
   - Remove `import 'admin_dashboard_screen.dart';` (line 6)
   - Replace the `if (role == 'admin')` block (lines 49-50) with a message: "Admin access is available at [web URL]. This app is for customers and technicians."
2. Remove `lib/admin_dashboard_screen.dart` from the mobile project.
3. Remove `lib/admin_support_chat_screen.dart` from the mobile project.
4. Remove admin-only methods from `lib/firebase_service.dart` in the mobile project. (These methods are now only called by Cloud Functions or the admin web app.) Specifically remove: `adminCloseJob`, `adminResolveDispute`, `updatePaymentStatus`, `streamActiveJobsAdmin`, `streamAllPayments`, `streamAllSupportChats`, `streamUnreadSupportCount`, `fetchRecentUsers`, `fetchRecentActivity`, `initializeStatsGlobal`, `closeSupportChat`, `markSupportChatReadByAdmin`, `getAvailableTechnicianIdsByService`.
5. Remove dead imports and verify the mobile app builds and runs cleanly.
6. Run full regression test on customer and technician flows.

**Exit criteria:** Mobile app builds without admin code. Customer and technician flows work identically to before. App binary is measurably smaller.

### Phase 5: Post-Migration Cleanup And Monitoring

**Duration estimate:** Ongoing

**Tasks:**

1. Monitor Cloud Functions logs for errors or unexpected behavior.
2. Monitor Firestore usage — confirm that removing the Firestore-read-based `isAdmin()` (if migrated to Custom Claims) reduced read costs.
3. If admin web app and mobile app share more than 3 model classes via copy-paste, consider extracting `packages/shared_core/`.
4. Review whether `assignJob` should require admin Custom Claim in Firestore rules (currently it only checks `isAdmin()` via document read).
5. Consider adding rate limiting to Cloud Functions to prevent abuse.
6. Archive or delete any admin-only assets from the mobile project.

## Detailed Blueprint

### 1. Inventory The Existing Admin Dashboard

The admin dashboard (`lib/admin_dashboard_screen.dart`) contains these functional blocks:

| Block | Tab | Lines (approx) | Read/Write |
|-------|-----|-----------------|------------|
| KPI stat cards (totalUsers, revenue, jobs, chats) | Overview | 302-400 | Read: stats/global |
| User breakdown card (customers vs technicians) | Users | 462-550 | Read: stats/global |
| Recent users list | Users | 553-645 | Read: users collection (limit 3) |
| Requested jobs list | Jobs | 684-715 | Read: jobs where status == 'requested' |
| Active jobs list | Jobs | 716-747 | Read: jobs where status in active statuses |
| Completed jobs list | Jobs | 748-774 | Read: jobs where status == 'completed' |
| Job detail sheet (requested) | Jobs (sheet) | 1562-1864 | Read: job doc + technicians. Write: assignJob |
| Job detail sheet (active) | Jobs (sheet) | 1895-2290 | Read: job doc + receipt. Write: adminCloseJob, adminResolveDispute |
| Support inbox with unread badge | Support | 1303-1400 | Read: support_chats. Write: markSupportChatReadByAdmin, closeSupportChat |
| Recent activity feed | Overview | 1402-1560 | Read: activity_log (limit 10) |
| Refresh behavior | All | 76-110 | Re-fetches all stats |

### 2. Create A Data Access Map

For each admin feature, capture:

```text
Feature | Method | Reads | Writes | Risk Level | Cloud Function? | MVP?
--------|--------|-------|--------|------------|-----------------|-----
Job assignment | assignJob | jobs/{id}, users, tech_availability | jobs/{id} | Medium | Yes | Yes
Payment approval | updatePaymentStatus | payments/{id} | payments/{id} | High (money) | Yes | Yes
Dispute resolution | adminResolveDispute | jobs/{id} | jobs/{id}, stats/global | High (money+trust) | Yes | Yes
Job force-close | adminCloseJob | jobs/{id} | jobs/{id}, stats/global | High (irreversible) | Yes | No (Phase 2)
Support mark read | markSupportChatReadByAdmin | — | support_chats/{id} | Low | No | Yes
Support close | closeSupportChat | — | support_chats/{id} | Low | No | Yes
Support send message | sendSupportMessage | — | support_chats/{id}/messages | Low | No | Yes
Dashboard stats | (reads stats/global) | stats/global | — | None (read-only) | N/A | Yes
Active jobs stream | streamActiveJobsAdmin | jobs collection | — | None (read-only) | N/A | Yes
All payments stream | streamAllPayments | payments collection | — | None (read-only) | N/A | Yes
Recent users | fetchRecentUsers | users collection | — | None (read-only) | N/A | No (Phase 2)
Recent activity | fetchRecentActivity | activity_log | — | None (read-only) | N/A | No (Phase 2)
Stats initialization | initializeStatsGlobal | users, jobs | stats/global | Medium | Yes (one-time) | No
```

### 3. Define Admin-Only Service Boundaries

The migration requires splitting `FirebaseService` into logical groups. This does not require creating Dart packages — just logical separation within each app.

**For the mobile app** (after migration): Remove all methods from the admin inventory table above. The remaining methods serve customer and technician flows only.

**For the admin web app**: Copy only the methods needed from `FirebaseService` into the admin web project. For write operations, replace direct Firestore calls with Cloud Function calls using `FirebaseFunctions.instance.httpsCallable('functionName')`.

**Shared models** that will be needed in both apps (copy, don't extract yet):

- User profile shape (fields: name, email, phone, role, createdAt, etc.)
- Job document shape (fields: status, customerId, assignedTechnicianId, receipt, etc.)
- Support chat shape (fields: userId, unreadByAdmin, lastMessageAt, etc.)
- Payment document shape (fields: userId, amount, status, screenshotUrl, etc.)

### 4. Design Admin Authentication For Web

**Recommended approach: Firebase Custom Claims**

Current state: Admin role is stored as `role: 'admin'` in the Firestore `users/{uid}` document. The `isAdmin()` Firestore rule helper reads this document on every rule evaluation.

**Problems with the current approach for web:**

- Every Firestore rule evaluation that calls `isAdmin()` costs one additional document read
- The admin role is stored in a document the admin user can technically read — if Firestore rules had a bug, role escalation would be possible
- Custom Claims are embedded in the ID token and evaluated locally by Firestore rules with zero read cost

**Migration path:**

1. Set custom claims on admin accounts via Firebase Admin SDK: `admin.auth().setCustomUserClaims(uid, { admin: true })`
2. Update Firestore rules `isAdmin()` helper:
   ```
   function isAdmin() {
     return request.auth != null && request.auth.token.admin == true;
   }
   ```
3. Admin web app checks claims after sign-in: `idTokenResult.claims['admin'] == true`
4. Keep the `role` field in the user document for display purposes but stop relying on it for authorization

**Decision item:** This is a recommended improvement but not strictly required. If the team wants to defer this, the existing Firestore document-read approach works — it's just slower and more expensive per rule evaluation.

**Auth flow for admin web app:**

1. User signs in with Google (or email/password).
2. App retrieves ID token result and checks for admin claim (or reads user doc if claims not implemented).
3. If admin: render dashboard. If not: show "Access denied" and sign out.
4. On token refresh failure or session expiry: redirect to login.

### 5. Review Firestore Rule Gaps

**Already secure (no changes needed):**

- Job creation (customer-only, with rate limiting)
- Job status transitions (each transition individually gated by role and allowed field changes)
- Payment creation (owner-only)
- Payment screenshot update (owner-only, restricted to screenshotUrl field)
- Support chat creation (owner-only)
- Support message creation (participant-only, with throttling and message count caps)
- Notification creation (schema-enforced, append-only)
- Activity log (append-only, schema-enforced, admin-only reads)

**Needs tightening:**

- **Admin dispute resolution** (line 197-200 in firestore.rules): Admin can change status from `receipt_disputed` to `awaiting_customer_approval`, `completed`, or `cancelled` but there is no `affectedKeys()` restriction — admin could write arbitrary fields. Add field restrictions.
- **Admin job cancellation** (line 203-208): Same issue — admin can cancel from any non-terminal status with no field restrictions.
- **Admin job assignment** (line 135-141): Checks status transition and requires `assignedTechnicianId` but doesn't restrict which other fields admin can change.
- **Stats writes** (line 399-429): Any authenticated user can modify stats counters by +/-1. Once Cloud Function event triggers handle stats, lock this to admin-only or remove client write access entirely.

### 6. Cloud Functions Design

**Callable functions to implement:**

```typescript
// functions/src/admin.ts

// All admin callable functions should:
// 1. Verify auth context exists
// 2. Verify admin custom claim (or read user doc for role)
// 3. Validate input parameters
// 4. Execute the Firestore write in a transaction
// 5. Write an audit log entry
// 6. Return a structured result

exports.adminAssignJob = functions.https.onCall(async (data, context) => {
  // Verify admin, validate jobId + technicianId
  // Transaction: read job (must be 'requested'), write status='active' + assignedTechnicianId
  // Log to activity_log
});

exports.adminApprovePayment = functions.https.onCall(async (data, context) => {
  // Verify admin, validate paymentId
  // Update payment status to CONFIRMED
  // Log to activity_log with audit fields
});

exports.adminRejectPayment = functions.https.onCall(async (data, context) => {
  // Verify admin, validate paymentId + reason
  // Update payment status to REJECTED
  // Log to activity_log with audit fields
});

exports.adminResolveDispute = functions.https.onCall(async (data, context) => {
  // Verify admin, validate jobId + resolution (reopen/complete/cancel)
  // Transaction: read job (must be 'receipt_disputed'), apply resolution
  // Update stats if completing or cancelling
  // Log to activity_log with audit fields
});

exports.adminCloseJob = functions.https.onCall(async (data, context) => {
  // Verify admin, validate jobId + amountPaid
  // Idempotency: check adminClosedAt not already set
  // Transaction: update job, update stats
  // Log to activity_log with audit fields
});
```

**Event-driven functions for stats:**

```typescript
// functions/src/stats.ts

exports.onUserCreated = functions.firestore
  .document('users/{uid}')
  .onCreate(async (snap) => {
    // Increment totalUsers and customers/technicians counter in stats/global
  });

exports.onJobStatusChanged = functions.firestore
  .document('jobs/{jobId}')
  .onUpdate(async (change) => {
    // Decrement old status counter, increment new status counter
    // If completed: add to totalEarnings
  });
```

### 7. Build The Admin Web MVP

**MVP scope (first production release):**

- Admin login with role/claim verification
- Overview dashboard with KPI cards (totalUsers, revenue, jobs breakdown, active chats)
- Jobs section with requested/active/completed sub-views
- Job assignment from requested job detail (calls Cloud Function)
- Payment review list with approve/reject (calls Cloud Function)
- Dispute queue with resolve actions (calls Cloud Function)
- Support inbox with unread badge, mark-read, close, and send message

**Deferred to post-MVP:**

- Recent users list
- Recent activity feed
- Job force-close (rare admin action)
- Advanced filtering, search, or sorting
- Bulk actions
- Service catalog management
- Stats initialization utility
- Export or reporting features

### 8. Remove Admin Routing From Mobile

Current behavior:
- `lib/login_screen.dart` line 49: `if (role == 'admin')` navigates to `AdminDashboardScreen`

Target behavior after migration:
- If role is `admin`, show a dialog or screen stating: "Admin access has moved to the web dashboard at [URL]."
- Optionally include a button to copy or open the URL
- Do not render any admin functionality in the mobile app

### 9. Remove Admin Code From Mobile Build

Once cutover is complete and the web app is stable, remove from the mobile project:

- `lib/admin_dashboard_screen.dart` (delete file)
- `lib/admin_support_chat_screen.dart` (delete file)
- All admin method bodies from `lib/firebase_service.dart` (14 methods listed in inventory)
- Admin import in `lib/login_screen.dart`
- Any admin-only assets if they exist

**Do not remove until:** The web app has been in production use for at least 1 week without critical issues.

## Proposed Folder Blueprint

### Admin Web App Structure

```text
admin_web/
  lib/
    main.dart
    app.dart
    auth/
      login_screen.dart
      auth_gate.dart
    dashboard/
      dashboard_screen.dart
      widgets/
        kpi_card.dart
        stats_overview.dart
    jobs/
      jobs_screen.dart
      job_detail_screen.dart
      widgets/
        job_list_tile.dart
        assign_dialog.dart
    payments/
      payments_screen.dart
      widgets/
        payment_review_tile.dart
    disputes/
      disputes_screen.dart
    support/
      support_inbox_screen.dart
      support_chat_screen.dart
    services/
      admin_firebase_service.dart
      admin_cloud_functions.dart
    models/
      job.dart
      payment.dart
      user_profile.dart
      support_chat.dart
  web/
    index.html
    favicon.png
  pubspec.yaml
  firebase.json
```

### Admin Web Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^3.1.1
  firebase_auth: ^5.1.1
  cloud_firestore: ^5.0.2
  cloud_functions: ^5.0.0    # For calling admin Cloud Functions
  firebase_app_check: ^0.3.1  # If App Check is active
  google_sign_in: ^6.2.1      # For Google auth on web
  google_fonts: ^6.2.1
```

**Do not include:** `image_picker`, `flutter_image_compress`, `location`, `geolocator`, `video_player`, `flutter_local_notifications`, `sign_in_with_apple`, `workmanager`. These are mobile-only or unnecessary for admin.

## Security Blueprint

### Minimum Security Standard

The admin web app must not rely only on hidden routes or role checks in widgets.

Required controls:

1. **Authentication gate** — admin role verified before any route renders
2. **Custom Claims or Firestore role check** — enforced at the auth layer, not just UI
3. **Cloud Functions for privileged writes** — payment approval, dispute resolution, job force-close
4. **Firestore rules** — continue to enforce admin-only reads/writes as defense-in-depth
5. **Audit trail** — every privileged write logs who did what, when, and why
6. **App Check** — register web app with reCAPTCHA Enterprise provider if App Check is active on mobile

### Risk Classification For Admin Actions

| Action | Risk | Reason | Enforcement |
|--------|------|--------|-------------|
| Approve/reject payment | High | Involves money | Cloud Function required |
| Resolve dispute | High | Involves money + trust | Cloud Function required |
| Force-close job | High | Irreversible status change | Cloud Function required |
| Assign technician | Medium | Affects job flow | Cloud Function recommended |
| Cancel job (admin) | Medium | Irreversible for active jobs | Cloud Function recommended |
| Close support chat | Low | Operational convenience | Direct Firestore write OK |
| Mark support read | Low | UI state only | Direct Firestore write OK |
| Send support message | Low | Communication only | Direct Firestore write OK |
| Read any data | None | Read-only | Firestore rules sufficient |

### Audit Fields To Standardize

For admin-sensitive operations, every Cloud Function should write:

- `actedBy` — admin UID
- `actedAt` — server timestamp
- `actionType` — e.g., `payment_approved`, `dispute_resolved_complete`
- `previousStatus` — status before the action
- `newStatus` — status after the action
- `reason` — free-text reason (required for dispute resolution and payment rejection)

Store these as fields on the affected document AND as a separate entry in `activity_log`.

## Deployment Blueprint

### Environment Strategy

- **Development:** Firebase Emulator Suite (Firestore, Auth, Functions, Hosting emulators). Test Cloud Functions locally before deploying.
- **Staging:** Use the same Firebase project with a staging hosting site (`syanat-admin-staging`) if the team wants, or simply test on the emulator. A separate Firebase project for staging is ideal but not required for a small team.
- **Production:** Firebase Hosting on the primary project, deployed via `firebase deploy --only hosting:syanat-admin`.

### Firebase Hosting Configuration

Add to `firebase.json`:

```json
{
  "hosting": {
    "site": "syanat-admin",
    "public": "admin_web/build/web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [{ "source": "**", "destination": "/index.html" }]
  }
}
```

The rewrite rule ensures Flutter web's client-side routing works for all paths.

### Build And Release

```bash
# Build
cd admin_web
flutter build web --web-renderer html --release

# Deploy
cd ..
firebase deploy --only hosting:syanat-admin

# Deploy Cloud Functions
firebase deploy --only functions
```

Set up a simple CI script (GitHub Actions) that builds and deploys on push to a `deploy/admin-web` branch or on manual trigger.

### Domain

Use a subdomain like `admin.syanat.com` pointed at Firebase Hosting, or use the default Firebase Hosting URL (`syanat-admin.web.app`) for internal use.

## Testing Blueprint

### Before Migration

Capture current behavior as a manual test script:

- [ ] Admin login routes to dashboard
- [ ] Dashboard shows correct KPI numbers (cross-check with Firestore Console)
- [ ] Support unread count matches actual unread chats
- [ ] Active jobs list shows all non-terminal jobs
- [ ] Requested jobs list allows technician assignment
- [ ] Payment review shows all payments, approve/reject works
- [ ] Dispute resolution shows disputed jobs, all 3 resolution types work
- [ ] Recent users shows latest signups
- [ ] Recent activity shows latest events

### During Migration (Per Feature)

For each migrated feature:

- [ ] Web admin sees the same data as mobile admin did
- [ ] Write actions produce the same Firestore document changes
- [ ] Cloud Function audit logs are written correctly
- [ ] Real-time streams update without page refresh
- [ ] Error handling: what happens when Cloud Function fails? (show error toast, don't silently fail)
- [ ] Loading states: show spinners or skeletons, don't show stale data

### Before Cutover

- [ ] Admin login on web works with production credentials
- [ ] All MVP features functional on web
- [ ] Cloud Functions deployed and tested in production
- [ ] Customer and technician flows on mobile are unaffected (regression test)
- [ ] Firestore rules deployed with any tightening changes
- [ ] App Check configured for web (if applicable)
- [ ] No console errors in browser dev tools during normal admin workflow
- [ ] Test with slow network: does the app degrade gracefully?

## Cutover Plan

1. Deploy Cloud Functions to production.
2. Deploy admin web app to Firebase Hosting.
3. Verify admin login and all MVP features work in production.
4. Invite 1-2 admins to use the web app alongside mobile for 3-5 days (parallel run).
5. Gather feedback, fix blockers.
6. Switch all admins to web-only.
7. Deploy mobile update that removes admin route and shows web redirect message.
8. After 1 week of stable web-only operation: deploy mobile update that removes admin code entirely.

**Important:** Steps 7 and 8 are separate mobile releases. Step 7 is low-risk (just changes routing). Step 8 removes code and should only happen after confirming no regressions.

## Rollback Plan

### If Cloud Functions Fail

Cloud Functions and direct Firestore writes can coexist. If a Cloud Function has a bug:
1. Fix and redeploy the function.
2. If urgent: temporarily revert Firestore rules to allow direct admin writes for the affected action.
3. The mobile admin path still works until it is removed.

### If Web App Has Critical Bugs

1. Do not remove admin code from mobile until the web app is proven stable.
2. If web release fails operationally, admins continue using the mobile app.
3. The mobile admin code remains in git history even after removal — it can be restored by reverting the removal commit.

### Schema Compatibility

All Firestore schema changes during migration must be backward-compatible:
- New fields added by Cloud Functions should have defaults or be optional
- No existing field semantics should change
- Both old (mobile) and new (web) admin paths should be able to read/write the same documents during the parallel run period

## Risks

### Risk 1: Service Layer Stays Coupled

If `FirebaseService` remains a single giant class, both apps will keep dragging each other's assumptions.

**Mitigation:** Do not try to share a Dart package between mobile and admin web in the first phase. Instead, copy the needed methods into the admin web app and delete them from the mobile app. A shared package can be extracted later if duplication becomes a maintenance problem.

### Risk 2: UI Migration Happens Before Security Review

Moving the admin UI to web without hardening backend enforcement preserves dangerous direct writes in a nicer interface.

**Mitigation:** Phase 1 (Backend Hardening) comes before Phase 3 (Feature Migration). Every privileged write action uses a Cloud Function from day one in the web app.

### Risk 3: Mobile Still Bundles Admin-Adjacent Code

If admin code is only hidden and not removed, app size benefits will be limited and dead code accumulates.

**Mitigation:** Phase 4 removes admin code from the mobile project. Do not skip this phase.

### Risk 4: Stats Counters Are Unreliable

The current stats/global document is written by clients with +/-1 bounds. Over time, counters can drift due to bugs, race conditions, or malicious manipulation.

**Mitigation:** Phase 1 introduces event-driven Cloud Functions that maintain stats from the source of truth (actual documents), eliminating client-side counter manipulation entirely.

### Risk 5: App Check Not Configured For Web

If App Check is active on mobile but not configured for the web app, all web requests will be rejected.

**Mitigation:** Register the web app in Firebase Console and configure reCAPTCHA Enterprise provider before deploying the web app.

### Risk 6: Admin Custom Claims Migration Breaks Existing Flow

If Firestore rules are updated to use Custom Claims but the admin user's token hasn't been refreshed, admin access breaks until re-authentication.

**Mitigation:** During migration, support both claim-based and document-based admin checks in Firestore rules temporarily:
```
function isAdmin() {
  return request.auth != null
    && (request.auth.token.admin == true
        || get(/databases/$(database)/documents/users/$(request.auth.uid))
             .data.get('role', '') == 'admin');
}
```
Remove the document-read fallback after all admin users have re-authenticated.

## Recommended MVP Definition

For the first production-ready admin web app, the minimum useful scope:

- Login with admin access check
- Dashboard overview cards (KPIs from stats/global)
- Jobs section: requested, active, completed lists with detail views
- Job assignment (Cloud Function)
- Payment moderation list with approve/reject (Cloud Function)
- Dispute queue with resolve actions (Cloud Function)
- Support inbox with unread badge, mark-read, close, send message

Everything else follows after the core operational loop is stable.

## Decision Log

Track these decisions explicitly before implementation begins:

| Decision | Options | Recommendation | Status |
|----------|---------|----------------|--------|
| Admin role enforcement | Custom Claims vs Firestore doc read | Custom Claims (faster, cheaper, more secure) | Decide in Phase 0 |
| Privileged writes | Direct Firestore vs Cloud Functions | Cloud Functions for High/Medium risk actions | Decide in Phase 0 |
| Stats management | Client writes vs event-driven Functions | Event-driven Functions | Decide in Phase 0 |
| Repo structure | Subfolder vs monorepo | Subfolder (`admin_web/`) first | Default |
| Shared code extraction | Now vs later | Later, only if 3+ files duplicated | Default |
| Admin web framework | Flutter web vs React/Next.js | Flutter web (team expertise, internal tool) | Default |
| Hosting | Firebase Hosting vs other | Firebase Hosting (same project) | Default |
| App Check for web | Enable vs skip | Enable if App Check is active on mobile | Check current state |

## Immediate Next Steps

If implementation starts, the first sequence should be:

1. **Complete the data access map** using the table template in section 2 above. Fill in any missing methods.
2. **Decide on Custom Claims vs Firestore role check** — this affects Firestore rules, Cloud Functions, and the web auth gate.
3. **Set up Cloud Functions project** (`firebase init functions` in repo root).
4. **Implement the 3-4 high-risk callable functions** (payment, dispute, job close, assignment).
5. **Implement event-driven stats functions** (replace client-side counter writes).
6. **Create the admin web Flutter app shell** (`flutter create --platforms web admin_web`).
7. **Build admin login gate** (Custom Claims or Firestore role check).
8. **Migrate dashboard stats** as the first feature (read-only, lowest risk).
9. **Migrate remaining MVP features** in the order specified in Phase 3.
10. **Parallel run** with 1-2 admins for 3-5 days before cutting over.
