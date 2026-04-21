# Admin Web Migration — Implementation Plan

> **Last updated:** 2026-04-13 (post-audit revision)
>
> All `[FILL]` placeholders have been resolved from a full codebase audit.
> Dead tasks (Custom Claims) have been removed. Field names, method signatures,
> and collection names match the actual codebase.

---

## Resolved Blueprint — Source of Truth

### Collections & Field Names

| Collection | Document Path | Key Fields |
|-----------|--------------|------------|
| users | `users/{uid}` | `role`: `'customer'`\|`'technician'`\|`'admin'`, `username`, `email`, `phone`, `createdAt`, `updatedAt`, `city`, `service`, `language`, `rating`, `ratingCount`, `earnings`, `available`, `featured`, `photoUrl`, `location` (GeoPoint), `activeLocationId`, `lastOrderAt` |
| jobs | `jobs/{jobId}` | `status`: `'requested'`\|`'active'`\|`'technician_accepted'`\|`'technician_arrived'`\|`'work_finished'`\|`'awaiting_customer_approval'`\|`'receipt_disputed'`\|`'completed'`\|`'cancelled'`, `customerId`, `customerName`, `assignedTechnicianId`, `technicianId`, `assignedTechnicianName`, `serviceKey`, `serviceCategory`, `description`, `urgencyType`, `locationAddress`, `locationLabel`, `amountPaid`, `price`, `receipt` (map), `createdAt`, `updatedAt`, `adminClosedAt`, `disputeResolvedAt`, `receiptRejected`, `receiptRejectedAt`, `receiptSubmittedAt`, `customerApprovedAt`, `technicianAcceptedAt`, `technicianArrivedAt`, `workFinishedAt`, `notificationsSentAt`, `hiddenForCustomer`, `cancelledBy`, `cancelledAt` |
| payments | `payments/{paymentId}` | `userId`, `status`: `'PENDING'`\|`'CONFIRMED'`\|`'REJECTED'`, `screenshotUrl`, `orderId`, `createdAt` |
| support_chats | `support_chats/{chatId}` | `userId`, `userName`, `status`: `'open'`\|`'closed'`, `unreadByAdmin`, `userMessageCount`, `lastUserMessageAt`, `lastMessageAt`, `closedAt`, `createdAt`. **Subcollection:** `messages/{messageId}` → `senderId`, `text`, `createdAt` |
| stats | `stats/global` | `totalUsers`, `customers`, `technicians`, `totalEarnings`, `jobsRequested`, `jobsOngoing`, `jobsCompleted`, `jobsCancelled`, `activeChats` |
| activity_log | `activity_log/{docId}` | `type`: `'account_created'`\|`'job_requested'`\|`'job_cancelled'`\|`'job_completed'`\|`'receipt_rejected'`\|`'dispute_resolved'`, `description`, `createdAt`, `jobId`?, `userId`?, `role`? |
| tech_availability | `tech_availability/{uid}` | `serviceKey`, `available` |
| notifications | `notifications/{notifId}` | `technicianId`, `jobId`, `serviceKey`, `serviceCategory`, `customerName`, `locationAddress`, `urgencyType`, `read`, `createdAt` |
| chats | `chats/{chatId}` | `customerId`, `technicianId`, `customerMessageCount`. **Subcollection:** `messages/{messageId}` → `senderId`, `text`, `createdAt` |

### Architectural Decisions (Finalized)

| ID | Topic | Decision | Rationale |
|----|-------|----------|-----------|
| D1 | Admin role check | **Firestore doc read (keep current)** | Current `isAdmin()` works. Small admin team = negligible read cost. Eliminates 3 tasks (claim script, dual-mode rules, cleanup). Additive change later if needed. |
| D2 | Payment approve/reject | **Cloud Function** | Current `updatePaymentStatus` is a bare status write with no `reviewedBy`, `reviewedAt`, or `rejectionReason`. CF adds accountability. |
| D3 | Dispute resolution | **Cloud Function** | Current method doesn't record admin UID or reason. CF adds `resolvedBy` and `resolutionNote`. |
| D4 | Job force-close | **Cloud Function** | Adds `adminClosedBy` field. Status remains `'completed'` (not `'force_closed'`) for backward compat. |
| D5 | Job assignment | **Cloud Function** | CF can look up `technicianName` server-side. Adds `assignedBy` and `assignedAt` fields. |
| D6 | Stats counters | **Event-driven CF** | 5 client-side locations write stats today. Moving to CF eliminates all. Tasks 5-1 + 5-2 must deploy atomically. |
| D7 | Framework | **Flutter Web** | Team knows Flutter. Internal tool doesn't need SSR/SEO. |
| D8 | Repo structure | **`admin_web/` subfolder** | Temporary co-location during migration. |
| D9 | Shared code | **Extract later** | No shared code exists yet. Evaluate at migration end. |
| D10 | App Check on web | **Enable** | Mobile already activates App Check. Requires real reCAPTCHA Enterprise key (current key is placeholder `YOUR_RECAPTCHA_V3_SITE_KEY`). |
| D11 | Hosting site name | **`syanat-admin`** | Standard convention. |
| D12 | Domain | **Firebase default initially** | Custom subdomain after stable. |

### Method Mapping (Mobile → Web Service Layer)

| Mobile Method (firebase_service.dart) | Line | Web Equivalent | Transport |
|---------------------------------------|------|----------------|-----------|
| `assignJob({jobId, technicianId, technicianName})` | 1048 | `AdminCloudFunctions.assignJob(jobId, technicianId)` | CF (name looked up server-side) |
| `adminCloseJob({jobId, amountPaid}) → Future<bool>` | 1109 | `AdminCloudFunctions.closeJob(jobId, amountPaid)` | CF |
| `adminResolveDispute({jobId, resolution, overrideAmount?})` | 1596 | `AdminCloudFunctions.resolveDispute(jobId, resolution, reason, overrideAmount?)` | CF (adds reason) |
| `updatePaymentStatus(paymentId, status)` | 912 | `AdminCloudFunctions.approvePayment(paymentId)` / `.rejectPayment(paymentId, reason)` | CF (split into two; adds reviewedBy/At/reason) |
| `closeSupportChat(chatId)` | 704 | `AdminFirebaseService.closeSupportChat(chatId)` | Direct Firestore |
| `markSupportChatReadByAdmin(chatId)` | 712 | `AdminFirebaseService.markSupportChatReadByAdmin(chatId)` | Direct Firestore |
| `sendSupportMessage({chatId, senderId, text, setUnreadForAdmin})` | 672 | `AdminFirebaseService.sendSupportMessage({chatId, text})` | Direct Firestore |
| `initializeStatsGlobal()` | 1711 | `AdminFirebaseService.initializeStatsGlobal()` | Direct Firestore (admin utility) |
| `streamActiveJobsAdmin()` | 1169 | `AdminFirebaseService.streamActiveJobsAdmin()` | Direct Firestore read |
| `streamJobsByStatus(status)` | 1154 | `AdminFirebaseService.streamJobsByStatus(status)` | Direct Firestore read |
| `streamAllPayments()` | 920 | `AdminFirebaseService.streamAllPayments()` | Direct Firestore read |
| `streamSupportChats()` | 647 | `AdminFirebaseService.streamSupportChats()` | Direct Firestore read |
| `streamUnreadSupportCount()` | 661 | `AdminFirebaseService.streamUnreadSupportCount()` | Direct Firestore read |
| `fetchRecentUsers({limit})` | 1318 | `AdminFirebaseService.fetchRecentUsers({limit})` | Direct Firestore read |
| `fetchRecentActivity({limit})` | 1690 | `AdminFirebaseService.fetchRecentActivity({limit})` | Direct Firestore read |
| `getAvailableTechnicianIdsByService(serviceKey)` | 1198 | `AdminFirebaseService.getAvailableTechnicianIdsByService(serviceKey)` | Direct Firestore read |

> **Note:** The mobile codebase uses `streamSupportChats()` (line 647), NOT `streamAllSupportChats()`. The web layer must use the same name.

### Firebase Web Config (from firebase_service.dart lines 33–42)

```
projectId: syana-ea75a
apiKey: AIzaSyBDZlSoKBy_MWYeCUc27PVxBH7KYAfKfZ0
authDomain: syana-ea75a.firebaseapp.com
databaseURL: https://syana-ea75a-default-rtdb.firebaseio.com
storageBucket: syana-ea75a.appspot.com
messagingSenderId: 850445794682
appId: 1:850445794682:web:0a05be4e3e0ccb1d5caac3
measurementId: G-KYNSN89SZS
```

### Current isAdmin() Implementation (firestore.rules lines 17–21)

```javascript
function isAdmin() {
  return isSignedIn()
    && get(/databases/$(database)/documents/users/$(request.auth.uid))
         .data.get('role', '') == 'admin';
}
```

This remains unchanged for the entire migration (D1 = Firestore doc read).

### Login Screen Admin Routing (login_screen.dart)

- Admin import: line 6 (`import 'admin_dashboard_screen.dart';`)
- Role check: lines 46–57 (`_routeByRole` method — `if (role == 'admin') dest = const AdminDashboardScreen()`)
- The `_routeByRole` method is called from `_login()` (line 94) and `_handleSocialSignIn()` (line 126)

### Admin Dashboard Screen Tabs (admin_dashboard_screen.dart)

| Tab | Lines | FirebaseService Methods Called | R/W |
|-----|-------|-------------------------------|-----|
| Overview | 302–403 | `fetchRecentUsers(limit:3)`, `fetchRecentActivity(limit:10)`, reads `stats/global` doc directly | R |
| Users | 405–459 | Uses state vars loaded in `_loadAllStats()` from `stats/global` | R |
| Jobs (Requested) | 684–711 | `streamJobsByStatus('requested')` | R |
| Jobs (Active) | 716–744 | `streamActiveJobsAdmin()` | R |
| Jobs (Completed) | 748–771 | `streamJobsByStatus('completed')` | R |
| Jobs (Assign) | 1092–1102 | `getAvailableTechnicianIdsByService(serviceKey)`, `assignJob(...)` | R+W |
| Jobs (Close) | 1104–1113 | `adminCloseJob(...)` | W |
| Support | 1303–1400 | `streamSupportChats()`, navigates to `AdminSupportChatScreen` | R |
| Support badge | 59–63 | `streamUnreadSupportCount()` | R |

### Admin Support Chat Screen (admin_support_chat_screen.dart)

| Action | Lines | FirebaseService Methods Called | R/W |
|--------|-------|-------------------------------|-----|
| Open chat | 30 | `markSupportChatReadByAdmin(chatId)` | W |
| Send message | 49–53 | `sendSupportMessage(chatId, senderId, text, setUnreadForAdmin:false)` | W |
| End conversation | 100 | `closeSupportChat(chatId)` | W |
| Message stream | 215–220 | Direct Firestore query on `support_chats/{chatId}/messages` | R |

### App Check Status

- Active in mobile: Yes (`firebase_service.dart` line 58–64)
- Provider: Play Integrity (Android), App Attest (iOS), ReCaptcha V3 (web)
- Web reCAPTCHA key: **PLACEHOLDER** (`YOUR_RECAPTCHA_V3_SITE_KEY`) — must be replaced with real key before web deployment
- `firebase_app_check` in pubspec.yaml: Yes (line 41)

### Client-Side Stats Writers (all must be removed in Phase 5)

| Method | Line | Stats Fields Written | Called By |
|--------|------|---------------------|-----------|
| `createUser()` | 348–358 | `totalUsers` +1, `customers` or `technicians` +1 | Customer/technician signup |
| `assignJob()` | 1074–1079 | `jobsRequested` -1, `jobsOngoing` +1 | Admin (mobile) |
| `adminCloseJob()` | 1131–1136 | `totalEarnings` +amount, `jobsCompleted` +1, `jobsOngoing` -1 | Admin (mobile) |
| `adminResolveDispute()` (complete) | 1636–1641 | `totalEarnings` +amount, `jobsCompleted` +1, `jobsOngoing` -1 | Admin (mobile) |
| `adminResolveDispute()` (cancel) | 1649–1653 | `jobsCancelled` +1, `jobsOngoing` -1 | Admin (mobile) |
| `addEarnings()` | 785–789 | `totalEarnings` +amount | Technician flows |

### Storage Rules — Tech Profile Upload Convention

- Current upload method: `uploadPhoto()` at line 749–761
- Filename pattern: `{folder}/{timestampMillis}.jpg` — **no UID in filename**
- For tech profiles: path is `techProfiles/{timestampMillis}.jpg`
- Storage rules (`storage.rules` lines 8–12): any authenticated user can write — no owner check
- **Blocker:** The plan's proposed `fileName.split('_')[0]` owner check won't work. The upload method must be changed to include UID before the storage rule can enforce ownership.

### Firestore Rules — Admin Write Paths (current state)

| Path | Rule Location | Has isAdmin() gate? | Has affectedKeys()? | Fields currently written by mobile client |
|------|--------------|---------------------|---------------------|------------------------------------------|
| Job assignment (requested → active) | Lines 134–140 | Yes | **No** | `status`, `assignedTechnicianId`, `technicianId`, `assignedTechnicianName`, `updatedAt` |
| Job cancellation (admin, any → cancelled) | Lines 203–209 | Yes | **No** | `status` (only field guaranteed) |
| Dispute resolution (receipt_disputed → *) | Lines 197–201 | Yes | **No** | `status`, `receiptRejected`, `disputeResolvedAt`, `updatedAt`, `amountPaid`?, `price`?, `adminClosedAt`? |
| Payment status update | Lines 325–329 | Yes | **No** (admin path is unrestricted) | `status` (bare write only) |
| Stats writes | Lines 419–438 | No (bounded ±1) | N/A | All counter fields |

### activity_log Rules (already exist — firestore.rules lines 444–465)

- Admin-only reads
- Any signed-in user can create with whitelisted schema and type enum
- Events are immutable (update/delete: `if false`)
- Cloud Functions use Admin SDK and bypass these rules entirely

---

## Phase 1: Audit & Decisions (COMPLETE)

### Task 1-1: Codebase Audit — COMPLETE

All field names, method signatures, line numbers, collection names, and rule implementations are documented in the Resolved Blueprint section above.

### Task 1-2: Sign-Off Decisions — COMPLETE

All 12 decisions recorded in the Architectural Decisions table above.

### Task 1-3: Folder & Structure Plan

* **Objective:** Document the full target folder structure and approved package list.
* **Terminal Commands:** None.
* **File Operations:** This section of the blueprint serves as the reference.
* **Implementation Details:**
    * Target folder tree:
      ```
      /                          ← existing mobile Flutter project (unchanged except Phase 8)
      ├── admin_web/             ← new Flutter web project
      │   ├── lib/
      │   ├── web/
      │   ├── pubspec.yaml
      │   └── analysis_options.yaml
      ├── functions/             ← Cloud Functions (TypeScript)
      │   ├── src/
      │   │   ├── index.ts
      │   │   ├── admin.ts
      │   │   ├── stats.ts
      │   │   └── shared/
      │   │       ├── verify-admin.ts
      │   │       └── audit-log.ts
      │   ├── package.json
      │   └── tsconfig.json
      ├── firestore.rules        ← shared (root-level)
      ├── storage.rules          ← shared (root-level)
      └── firebase.json          ← shared (root-level, gains hosting + functions blocks)
      ```
    * `admin_web/pubspec.yaml` allowed packages: `firebase_core`, `firebase_auth`, `cloud_firestore`, `cloud_functions`, `google_sign_in`, `google_fonts`, `firebase_app_check`.
    * Explicitly forbidden mobile-only packages: `image_picker`, `flutter_image_compress`, `location`, `geolocator`, `video_player`, `flutter_local_notifications`, `sign_in_with_apple`, `workmanager`, `flutter_native_splash`.
    * Target `firebase.json`:
      ```json
      {
        "firestore": {
          "database": "(default)",
          "location": "nam5",
          "rules": "firestore.rules",
          "indexes": "firestore.indexes.json"
        },
        "storage": {
          "rules": "storage.rules"
        },
        "hosting": {
          "site": "syanat-admin",
          "public": "admin_web/build/web",
          "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
          "rewrites": [{ "source": "**", "destination": "/index.html" }]
        },
        "functions": {
          "source": "functions",
          "runtime": "nodejs18"
        }
      }
      ```
    * **Flutter tooling isolation:** Never run `flutter analyze` or `flutter build` at the repo root expecting it to affect `admin_web/`. Always `cd admin_web` first. The two projects must never share `.dart_tool/` or `.flutter-plugins`.

---

## Phase 2: Firestore Rules Hardening

### Task 2-1: Add `affectedKeys()` Restrictions to Admin Write Paths

* **Objective:** Add field-level restrictions to admin write paths that currently allow arbitrary field changes.
* **Terminal Commands:** `firebase deploy --only firestore:rules`
* **File Operations:** Modify `firestore.rules` — exactly 3 rule blocks inside the jobs match.
* **Implementation Details:**
    * **IMPORTANT:** These restrictions must match the fields the CURRENT mobile client writes. They will be updated again in Phase 4 when Cloud Functions replace the mobile client writes.
    * Block A — Admin job assignment (lines 134–140). Add restriction:
      ```javascript
      && request.resource.data.diff(resource.data)
           .affectedKeys().hasOnly(['status', 'assignedTechnicianId', 'technicianId', 'assignedTechnicianName', 'updatedAt'])
      ```
    * Block B — Admin dispute resolution (lines 197–201). Add restriction:
      ```javascript
      && request.resource.data.diff(resource.data)
           .affectedKeys().hasOnly(['status', 'receiptRejected', 'disputeResolvedAt', 'updatedAt', 'amountPaid', 'price', 'adminClosedAt'])
      ```
    * Block C — Admin job cancellation (lines 203–209). Add restriction:
      ```javascript
      && request.resource.data.diff(resource.data)
           .affectedKeys().hasOnly(['status', 'cancelledBy', 'cancelledAt', 'updatedAt'])
      ```
    * Deploy and test in Firebase Console Rules Playground:
      * Admin writing only allowed fields → ALLOW
      * Admin writing an extra field → DENY
    * **Do NOT touch the stats write rules in this phase.** Stats rules remain unchanged until Phase 5.

### Task 2-2: Fix Storage Rule — Tech Profile Owner Check

* **Objective:** Add an owner check to the `techProfiles` storage rule. Requires changing the upload filename convention first.
* **Terminal Commands:** `firebase deploy --only storage` (after mobile code change ships)
* **File Operations:** Modify `storage.rules` — `techProfiles` write rule. Modify `lib/firebase_service.dart` — `uploadPhoto()` method.
* **Implementation Details:**
    * **Step 1 — Change upload filename convention.** In `firebase_service.dart` line 750–751, when `folder == 'techProfiles'`, change the filename from `{timestamp}.jpg` to `{uid}_{timestamp}.jpg`:
      ```dart
      final uid = getCurrentUser()?.uid ?? 'anon';
      final fileName = folder == 'techProfiles'
          ? '${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg'
          : '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = storage.ref().child('${folder ?? 'uploads'}/$fileName');
      ```
    * **Step 2 — Ship the mobile update.** The new filename convention must be live before the storage rule is deployed, otherwise existing upload flows will be rejected.
    * **Step 3 — Update `storage.rules`** `techProfiles` write rule:
      ```javascript
      match /techProfiles/{fileName} {
        allow read:  if true;
        allow write: if request.auth != null
                     && request.resource.size < 5 * 1024 * 1024
                     && request.resource.contentType.matches('image/.*')
                     && fileName.split('_')[0] == request.auth.uid;
      }
      ```
    * Existing files with old naming (`{timestamp}.jpg`) remain readable (read rule is public). They just can't be overwritten by non-owners (which was already the case since the filename won't match the UID pattern).
    * Test: upload with matching UID → ALLOW; upload with mismatched UID → DENY.

---

## Phase 3: Cloud Functions Scaffold

### Task 3-1: Cloud Functions Project & Shared Utilities

* **Objective:** Initialize the Cloud Functions project, configure TypeScript, and create the shared `verifyAdmin` and `audit-log` helpers that every write function depends on.
* **Terminal Commands:**
    ```bash
    firebase init functions  # select TypeScript, existing project, don't overwrite
    cd functions && npm run build
    ```
* **File Operations:** Create `functions/src/index.ts`, `functions/src/admin.ts` (stubs), `functions/src/stats.ts` (stubs), `functions/src/shared/verify-admin.ts`, `functions/src/shared/audit-log.ts`, `functions/package.json`, `functions/tsconfig.json`. Modify `firebase.json` — add functions block.
* **Implementation Details:**
    * Set `tsconfig.json` to strict mode with `module: commonjs`, `target: es2017`, `strict: true`.
    * Create `verify-admin.ts`: does an async Firestore read of `users/{uid}` and checks `role == 'admin'` (matching D1 decision). Throws `HttpsError('unauthenticated')` if no auth, `HttpsError('permission-denied')` if not admin.
    * Create `audit-log.ts` with `AuditEntry` interface, `buildAuditEntry()` function (uses `FieldValue.serverTimestamp()` for `createdAt`), and `writeAuditLog()` function that writes to `activity_log` collection. Fields must match the activity_log schema: `type`, `description`, `createdAt`, `jobId`?, `userId`?, `role`?.
    * `index.ts` calls `admin.initializeApp()` exactly once and re-exports from `./admin` and `./stats`.
    * `admin.ts` and `stats.ts` contain null stubs for the 5 callable and 2 event-driven functions respectively.
    * Add functions block to `firebase.json`:
      ```json
      "functions": { "source": "functions", "runtime": "nodejs18" }
      ```
    * `npm run build` must produce zero TypeScript errors.
    * Add `serviceAccountKey.json` and `**/serviceAccountKey*.json` to `.gitignore`.

---

## Phase 4: Cloud Functions — Write Functions

### Task 4-1: Implement `adminAssignJob`

* **Objective:** Replace the `adminAssignJob` stub with the real implementation.
* **Terminal Commands:** `cd functions && npm run build`
* **File Operations:** Modify `functions/src/admin.ts` — replace `adminAssignJob` stub only.
* **Implementation Details:**
    * `verifyAdmin(context)` is the first line.
    * Validate `jobId` and `technicianId` from `data` — both must be non-empty strings.
    * Look up technician name from `users/{technicianId}` document (server-side — web client doesn't need to pass it).
    * Inside a transaction: read the job document, verify `status == 'requested'`, then update:
      ```
      assignedTechnicianId: technicianId
      technicianId: technicianId          // kept for existing stream queries
      assignedTechnicianName: <looked up>
      status: 'active'
      assignedBy: context.auth.uid        // NEW — admin UID
      assignedAt: FieldValue.serverTimestamp()  // NEW
      updatedAt: FieldValue.serverTimestamp()
      ```
    * Write an audit log entry via `writeAuditLog()` with `type: 'job_assigned'`.
    * Status check must be inside the transaction.

### Task 4-1b: Update Firestore Rules for CF Assignment Fields

* **Objective:** Update the job assignment `affectedKeys()` restriction to include the new fields written by the CF.
* **Terminal Commands:** `firebase deploy --only firestore:rules`
* **File Operations:** Modify `firestore.rules` — admin assignment block only.
* **Implementation Details:**
    * Update Block A to:
      ```javascript
      && request.resource.data.diff(resource.data)
           .affectedKeys().hasOnly(['status', 'assignedTechnicianId', 'technicianId', 'assignedTechnicianName', 'assignedBy', 'assignedAt', 'updatedAt'])
      ```
    * **Note:** Cloud Functions use the Admin SDK and bypass Firestore rules entirely. This rule update is for the transition period where the mobile admin client might still be active. Once Task 8-1 ships, this rule only applies to direct admin Firestore writes (which shouldn't happen but acts as defense-in-depth).

### Task 4-2: Implement `adminApprovePayment` & `adminRejectPayment`

* **Objective:** Replace both payment stubs with implementations.
* **Terminal Commands:** `cd functions && npm run build`
* **File Operations:** Modify `functions/src/admin.ts`.
* **Implementation Details:**
    * Both functions: `verifyAdmin(context)` first, validate `paymentId` as non-empty string.
    * `adminApprovePayment`: inside transaction, read payment, verify `status == 'PENDING'`, update:
      ```
      status: 'CONFIRMED'
      reviewedBy: context.auth.uid       // NEW field
      reviewedAt: FieldValue.serverTimestamp()  // NEW field
      ```
    * `adminRejectPayment`: additionally validate `reason` as non-empty trimmed string. Update:
      ```
      status: 'REJECTED'
      reviewedBy: context.auth.uid       // NEW field
      reviewedAt: FieldValue.serverTimestamp()  // NEW field
      rejectionReason: reason            // NEW field
      ```
    * Write audit log for both.
    * A rejection without a reason must never reach Firestore — enforced at input validation.

### Task 4-3: Implement `adminResolveDispute`

* **Objective:** Replace the stub with an implementation supporting 3 resolution types.
* **Terminal Commands:** `cd functions && npm run build`
* **File Operations:** Modify `functions/src/admin.ts`.
* **Implementation Details:**
    * Define `VALID_RESOLUTIONS = ['reopen', 'complete', 'cancel'] as const`.
    * Validate `jobId`, `resolution` (must be in the valid set), `reason` (required for all 3 types), and `overrideAmount` (optional number, only used for `complete`).
    * Map each resolution to its target status:
      * `reopen` → `'awaiting_customer_approval'`
      * `complete` → `'completed'`
      * `cancel` → `'cancelled'`
    * Inside transaction: verify `status == 'receipt_disputed'`, then update job. **Use existing field name `disputeResolvedAt`** (not `resolvedAt`). Add new fields:
      ```
      status: <target>
      disputeResolvedAt: FieldValue.serverTimestamp()  // EXISTING field name
      resolvedBy: context.auth.uid                     // NEW field
      resolutionNote: reason                           // NEW field
      receiptRejected: false                           // for 'reopen' only
      updatedAt: FieldValue.serverTimestamp()
      ```
    * For `complete`: also set `amountPaid`, `price`, `adminClosedAt`.
    * Stats counter updates are NOT done here — they're handled by the event-driven `onJobStatusChanged` in Phase 5.
    * Write audit log with resolution type and reason.

### Task 4-4: Implement `adminCloseJob`

* **Objective:** Replace the stub with an idempotent force-close implementation.
* **Terminal Commands:** `cd functions && npm run build`
* **File Operations:** Modify `functions/src/admin.ts`.
* **Implementation Details:**
    * Validate `jobId` as non-empty string and `amountPaid` as a non-negative number (`0` is valid).
    * Inside transaction: read job, check if `adminClosedAt` field is already non-null. If so, return success without re-writing (idempotency guard).
    * If not already closed: update with:
      ```
      status: 'completed'              // NOT 'force_closed' — must match existing stream queries
      amountPaid: amountPaid
      price: amountPaid
      adminClosedAt: FieldValue.serverTimestamp()
      adminClosedBy: context.auth.uid  // NEW field
      updatedAt: FieldValue.serverTimestamp()
      ```
    * Stats counter updates are NOT done here — handled by Phase 5 event-driven function.
    * Write audit log entry.

### Task 4-5: Deploy All Functions & Full Emulator Verification

* **Objective:** Run a complete emulator test pass and deploy to production.
* **Terminal Commands:**
    ```bash
    firebase emulators:start --only functions,firestore,auth
    firebase deploy --only functions
    ```
* **File Operations:** No code changes — deploy only.
* **Implementation Details:**
    * Complete a test matrix covering:
      * Valid admin calls (success) — all 5 functions
      * Non-admin calls (permission-denied) — all 5 functions
      * Wrong status preconditions (failed-precondition)
      * Missing/invalid arguments (invalid-argument)
      * Non-existent documents (not-found)
      * Idempotency (second close call returns success without re-write)
      * Rejection without reason (invalid-argument)
    * All tests must pass before deploying.
    * **Preview deploy first:** `firebase hosting:channel:deploy preview-phase4` to validate without touching production.
    * After production deploy, verify all 5 functions appear in Firebase Console with no errors.

---

## Phase 5: Event-Driven Stats Functions

### Task 5-1: Implement Stats Functions

* **Objective:** Replace both stubs in `stats.ts` with event-driven implementations.
* **Terminal Commands:** `cd functions && npm run build`
* **File Operations:** Modify `functions/src/stats.ts` only.
* **Implementation Details:**
    * `onUserCreated`: Firestore `onCreate` trigger on `users/{uid}`. Increments `totalUsers` always; conditionally increments `customers` or `technicians` based on `role` field.
    * `onJobStatusChanged`: Firestore `onUpdate` trigger on `jobs/{jobId}`. If `status` unchanged, return (no-op). Uses a `statusToField` map:
      ```typescript
      const statusToField: Record<string, string> = {
        'requested': 'jobsRequested',
        'active': 'jobsOngoing',
        'technician_accepted': 'jobsOngoing',
        'technician_arrived': 'jobsOngoing',
        'work_finished': 'jobsOngoing',
        'awaiting_customer_approval': 'jobsOngoing',
        'receipt_disputed': 'jobsOngoing',
        'completed': 'jobsCompleted',
        'cancelled': 'jobsCancelled',
      };
      ```
    * Decrements the previous status counter and increments the new status counter.
    * On completion (`completed`): also increments `totalEarnings` by `amountPaid` if it's a positive number.
    * Ensure `stats/global` document exists before deploying — call `initializeStatsGlobal()` if needed.
    * **Do NOT deploy this task alone** — it must deploy together with Task 5-2.

### Task 5-2: Lock Client Stats Writes & Deploy Atomically

* **Objective:** Remove all client-side stats writes and lock the stats collection to CF-only writes. Deploy in a single atomic command.
* **Terminal Commands:** `firebase deploy --only functions,firestore:rules` (SINGLE command)
* **File Operations:** Modify `firestore.rules` — stats write rule. Modify mobile `lib/firebase_service.dart` — remove stats writes from 6 locations.
* **Implementation Details:**
    * **Step 1 — Remove client-side stats writes from mobile code:**
      * `createUser()` lines 348–358: remove the `stats/global` set call and the surrounding try/catch.
      * `assignJob()` lines 1074–1079: remove the `stats/global` set call.
      * `adminCloseJob()` lines 1131–1136: remove the `stats/global` set call.
      * `adminResolveDispute()` lines 1636–1641 (complete branch): remove the `statsRef` set inside the transaction.
      * `adminResolveDispute()` lines 1649–1653 (cancel branch): remove the `statsRef` set inside the transaction.
      * `addEarnings()` lines 785–789: remove the `stats/global` set call. **This is critical — it's called from technician flows, not admin.**
    * **Step 2 — Lock stats rules:**
      ```javascript
      match /stats/{docId} {
        allow read: if request.auth != null;
        allow write: if false; // All updates via Cloud Function triggers only
      }
      ```
    * **Step 3 — Deploy atomically:**
      ```bash
      firebase deploy --only functions,firestore:rules
      ```
      Never two separate deploys — avoids double-counting window.
    * **Verification within 60 seconds:** create a test user → `stats/global` `totalUsers` increments; update a job status → correct counter updates; attempt direct client write to `stats/global` → DENY in Rules Playground.

---

## Phase 6: Admin Web App Shell

### Task 6-0: Create `admin_web/` Flutter Web Project

* **Objective:** Scaffold the `admin_web/` Flutter web project inside the repo.
* **Terminal Commands:**
    ```bash
    flutter create --platforms web admin_web
    ```
* **File Operations:** Creates `admin_web/` directory with Flutter web scaffold.
* **Implementation Details:**
    * Run from the repo root.
    * Verify `admin_web/web/` directory exists after creation.
    * Verify `admin_web/pubspec.yaml` exists and has `flutter` SDK dependency.
    * **Commit the raw scaffold immediately** before making any modifications. This gives a clean revert point.
    * Do NOT run `flutter pub get` at the repo root — it's for the mobile project only. Always `cd admin_web && flutter pub get`.

### Task 6-1: Firebase Config & Placeholder Deploy

* **Objective:** Configure Firebase in `admin_web/`, replace dependencies with the approved list, and deploy a placeholder to confirm the hosting pipeline works.
* **Terminal Commands:**
    ```bash
    cd admin_web && flutter pub get
    flutter build web --web-renderer html --release
    cd .. && firebase hosting:channel:deploy preview-shell  # preview first
    firebase deploy --only hosting:syanat-admin              # then production
    ```
* **File Operations:** Replace `admin_web/pubspec.yaml` dependencies. Create/modify `admin_web/lib/main.dart`. Modify root `firebase.json` — add hosting block.
* **Implementation Details:**
    * Replace `pubspec.yaml` dependencies with approved list (see Task 1-3). No forbidden mobile-only packages.
    * In `main.dart`:
      ```dart
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(options: const FirebaseOptions(
        apiKey: 'AIzaSyBDZlSoKBy_MWYeCUc27PVxBH7KYAfKfZ0',
        authDomain: 'syana-ea75a.firebaseapp.com',
        projectId: 'syana-ea75a',
        storageBucket: 'syana-ea75a.appspot.com',
        messagingSenderId: '850445794682',
        appId: '1:850445794682:web:0a05be4e3e0ccb1d5caac3',
        measurementId: 'G-KYNSN89SZS',
      ));
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider('<REAL_RECAPTCHA_KEY>'),  // must be real
      );
      runApp(const AdminApp());
      ```
    * **Before this task:** register the web app with reCAPTCHA Enterprise in Firebase Console and obtain a real site key.
    * Add hosting block to root `firebase.json` (see Task 1-3 target).
    * Always use `--web-renderer html` on every build.
    * Preview channel deploy first → verify no errors → then production deploy.
    * Verify the deployed URL shows the placeholder with zero browser console errors.

### Task 6-1b: CI Setup

* **Objective:** Set up GitHub Actions to validate `admin_web/` on every PR.
* **Terminal Commands:** None (create workflow file).
* **File Operations:** Create `.github/workflows/admin-web.yml`.
* **Implementation Details:**
    * Trigger: on PRs that touch `admin_web/**`.
    * Steps: checkout, setup Flutter, `cd admin_web && flutter pub get`, `flutter analyze`, `flutter build web --web-renderer html --release`.
    * This catches broken imports, type errors, and build failures before merge.

### Task 6-2: Auth Gate

* **Objective:** Build the authentication gate that guards the admin web app.
* **Terminal Commands:** `cd admin_web && flutter build web --web-renderer html --release`
* **File Operations:** Create `admin_web/lib/auth/login_screen.dart`, `admin_web/lib/auth/auth_gate.dart`. Modify `admin_web/lib/main.dart`.
* **Implementation Details:**
    * `LoginScreen`: email/password sign-in and Google sign-in. Error display, loading state. Constrained to 400px max width.
    * `AuthGate`: wraps the admin app. Uses `StreamBuilder<User?>` on `authStateChanges()`. If no user → `LoginScreen`. If user exists → `_AdminCheck`.
    * `_AdminCheck`: in `initState`, reads `users/{uid}` document and checks `role == 'admin'` (matching D1 = Firestore doc read). If not admin, calls `FirebaseAuth.instance.signOut()` immediately, then shows "Access denied" message.
    * Sign out must happen before the denied screen renders — a non-admin with an active session can query Firestore from the browser console.
    * The `authStateChanges()` stream also handles session expiry — if the token can't refresh, the stream emits null and the user is redirected to login.

### Task 6-3: Navigation Shell

* **Objective:** Build the sidebar navigation with 6 sections.
* **Terminal Commands:** `cd admin_web && flutter build web --web-renderer html --release`
* **File Operations:** Create `admin_web/lib/dashboard/dashboard_screen.dart`. Modify `main.dart`.
* **Implementation Details:**
    * Define `AdminSection` enum: `overview`, `jobs`, `payments`, `disputes`, `support`, `activity`.
    * `DashboardScreen`: `NavigationRail` on left, `Expanded` content area on right, `VerticalDivider` separator.
    * Each destination: icon + label. Click switches content to placeholder text.
    * No overflow on 1280px+ window.

### Task 6-4: Service Layer Stubs

* **Objective:** Create service files with all method signatures stubbed.
* **Terminal Commands:** `cd admin_web && flutter build web --web-renderer html --release`
* **File Operations:** Create `admin_web/lib/services/admin_firebase_service.dart`, `admin_web/lib/services/admin_cloud_functions.dart`.
* **Implementation Details:**
    * `AdminFirebaseService` stubs (all throw `UnimplementedError` except `streamStats`):
      * `streamStats()` — implemented: streams `stats/global` document snapshots
      * `streamActiveJobsAdmin()`
      * `streamJobsByStatus(String status)` — **not in original plan, needed for Requested/Completed tabs**
      * `streamAllPayments()`
      * `streamSupportChats()` — **correct name (not `streamAllSupportChats`)**
      * `streamUnreadSupportCount()`
      * `markSupportChatReadByAdmin(String chatId)`
      * `closeSupportChat(String chatId)`
      * `sendSupportMessage({required String chatId, required String text})`
      * `fetchRecentUsers({int limit})`
      * `fetchRecentActivity({int limit})`
      * `getAvailableTechnicianIdsByService(String serviceKey)`
      * `initializeStatsGlobal()`
    * `AdminCloudFunctions` stubs:
      * `assignJob(String jobId, String technicianId)`
      * `approvePayment(String paymentId)`
      * `rejectPayment(String paymentId, String reason)`
      * `resolveDispute(String jobId, String resolution, String reason, {double? overrideAmount})`
      * `closeJob(String jobId, double amountPaid)`
    * Must compile without errors.

---

## Phase 7: Admin Web App Feature Screens

### Task 7-1: Overview Screen (Dashboard Stats)

* **Objective:** Implement the Overview section with KPI cards streaming from `stats/global`.
* **Terminal Commands:** `cd admin_web && flutter build web --web-renderer html --release`
* **File Operations:** Create `admin_web/lib/dashboard/widgets/kpi_card.dart`, `admin_web/lib/dashboard/overview_screen.dart`. Modify `DashboardScreen`.
* **Implementation Details:**
    * `KpiCard`: stateless widget — icon, large value text, label inside a `Card`.
    * `OverviewScreen`: `StreamBuilder` on `AdminFirebaseService().streamStats()`. Maps actual field names to KPI cards:
      * `totalUsers` → Total Users
      * `totalEarnings` → Total Payouts (format as `{value} EGP`)
      * `jobsRequested` → Jobs Requested
      * `jobsCompleted` → Completed Jobs
      * `jobsCancelled` → Cancelled Orders
      * `jobsOngoing` → Active Jobs
    * Handle loading, error, and empty states (if `stats/global` doesn't exist).
    * Cards must update in real time.

### Task 7-2: Jobs Screen (List + Assignment)

* **Objective:** Build the jobs screen with 3 sub-views and job assignment via CF.
* **Terminal Commands:** `cd admin_web && flutter build web --web-renderer html --release`
* **File Operations:** Implement `AdminFirebaseService.streamActiveJobsAdmin()`, `AdminFirebaseService.streamJobsByStatus()`, `AdminCloudFunctions.assignJob()`. Create jobs screen files. Modify `DashboardScreen`.
* **Implementation Details:**
    * `streamJobsByStatus(status)`: queries `jobs` collection with `where('status', isEqualTo: status)`, ordered by `createdAt` desc, limit 50.
    * `streamActiveJobsAdmin()`: queries `jobs` with `whereIn` for `['active', 'technician_accepted', 'technician_arrived', 'work_finished', 'awaiting_customer_approval', 'receipt_disputed']`.
    * `assignJob()`: calls `httpsCallable('adminAssignJob')` with `{jobId, technicianId}`.
    * Jobs screen: top `TabBar` with 3 sub-views:
      * Requested: uses `streamJobsByStatus('requested')`, each row has "Assign" button
      * Active: uses `streamActiveJobsAdmin()`, read-only list
      * Completed: uses `streamJobsByStatus('completed')`, read-only list
    * `AssignDialog`: fetches available technicians via `getAvailableTechnicianIdsByService(serviceKey)`, shows dropdown, confirm calls `assignJob()`.
    * Cancel `StreamSubscription` in `dispose()`.

### Task 7-3: Payments Screen (Review + Approve/Reject)

* **Objective:** Build payments list with approve and reject actions via CF.
* **Terminal Commands:** `cd admin_web && flutter build web --web-renderer html --release`
* **File Operations:** Implement payment stubs. Create payments screen. Modify `DashboardScreen`.
* **Implementation Details:**
    * `streamAllPayments()`: queries `payments` ordered by `createdAt` desc, limit 100.
    * `approvePayment()`: calls `httpsCallable('adminApprovePayment')` with `{paymentId}`.
    * `rejectPayment()`: calls `httpsCallable('adminRejectPayment')` with `{paymentId, reason}`.
    * Status badges: `PENDING` (orange), `CONFIRMED` (green), `REJECTED` (red).
    * Approve/Reject buttons visible only for `PENDING`.
    * Reject requires reason — confirm button disabled until `reason.trim().isNotEmpty`.
    * Both actions show loading state and error on failure.

### Task 7-4: Support Screen (Inbox + Chat + Unread Count)

* **Objective:** Build support inbox, real-time chat, and unread badge.
* **Terminal Commands:** `cd admin_web && flutter build web --web-renderer html --release`
* **File Operations:** Implement all support stubs. Create support screen files. Modify `DashboardScreen`.
* **Implementation Details:**
    * `streamSupportChats()`: queries `support_chats` ordered by `lastMessageAt` desc, limit 50.
    * `streamUnreadSupportCount()`: queries `support_chats` where `unreadByAdmin == true` and `status == 'open'`, maps to `.size`.
    * `markSupportChatReadByAdmin(chatId)`: updates `unreadByAdmin` to `false`.
    * `closeSupportChat(chatId)`: updates `status` to `'closed'` and `closedAt` to server timestamp.
    * `sendSupportMessage({chatId, text})`: adds to `messages` subcollection with `senderId: currentUser.uid`, `text`, `createdAt: serverTimestamp`. Updates parent doc `lastMessageAt`.
    * Inbox: list of chats, unread highlighted. Tap → `markSupportChatReadByAdmin` → open chat.
    * Chat: real-time message list, text input, "Close chat" button with confirmation.
    * Sidebar unread badge: `StreamBuilder<int>` on `streamUnreadSupportCount()`, red badge when > 0.

### Task 7-5: Disputes Screen

* **Objective:** Build disputed jobs list with 3-option resolve panel via CF.
* **Terminal Commands:** `cd admin_web && flutter build web --web-renderer html --release`
* **File Operations:** Implement `AdminCloudFunctions.resolveDispute()`. Create disputes screen. Modify `DashboardScreen`.
* **Implementation Details:**
    * `resolveDispute()`: calls `httpsCallable('adminResolveDispute')` with `{jobId, resolution, reason, overrideAmount?}`.
    * Disputes screen: uses `streamJobsByStatus('receipt_disputed')` (or filters from active jobs stream).
    * For each job: show summary, required reason text field, optional override amount (for `complete` only), and 3 buttons (Reopen / Complete / Cancel).
    * All buttons disabled until `reason.trim().isNotEmpty`.
    * Resolution strings from hardcoded constants, never from button labels.
    * Job disappears from list after resolution.

### Task 7-6: Activity Screen & Job Force-Close

* **Objective:** Build activity feed and add force-close on active jobs.
* **Terminal Commands:** `cd admin_web && flutter build web --web-renderer html --release`
* **File Operations:** Implement `AdminCloudFunctions.closeJob()`. Create activity screen. Modify jobs screen. Modify `DashboardScreen`.
* **Implementation Details:**
    * `closeJob()`: calls `httpsCallable('adminCloseJob')` with `{jobId, amountPaid}`.
    * Activity screen: streams last 50 from `activity_log` ordered by `createdAt` desc. Displays: type icon, description, timestamp. Type mapping:
      * `account_created` → person_add icon (blue)
      * `job_requested` → pending_actions icon (orange)
      * `job_completed` → check_circle icon (green)
      * `job_cancelled` → cancel icon (red)
      * `receipt_rejected` → warning icon (amber)
      * `dispute_resolved` → gavel icon (purple)
    * Force-close in jobs screen: "Force close" button on active job detail. Confirmation dialog names specific job ID. Amount input (non-negative, required). Calls `closeJob()`.
    * Idempotency: force-closing already-closed job returns success.

### Task 7-7: End-to-End Verification

* **Objective:** Complete a full manual test pass before mobile cleanup.
* **Terminal Commands:** None.
* **File Operations:** None.
* **Implementation Details:**
    * **Preview channel deploy first:** `firebase hosting:channel:deploy preview-e2e`
    * Execute all tests:
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
    * All 27 tests must pass before Phase 8.

---

## Phase 8: Mobile Cleanup

### Task 8-1: Mobile Release 1 — Admin Routing Redirect

* **Objective:** Remove the admin route from mobile login and replace with a redirect screen.
* **Terminal Commands:** `flutter analyze`
* **File Operations:** Modify `lib/login_screen.dart`. Create `lib/admin_redirect_screen.dart`.
* **Implementation Details:**
    * **Wait gate:** Notify all admins and confirm they are operational on the web app.
    * In `login_screen.dart`:
      * Remove import at line 6: `import 'admin_dashboard_screen.dart';`
      * Add: `import 'admin_redirect_screen.dart';`
      * In `_routeByRole` method (lines 46–57), replace `dest = const AdminDashboardScreen()` with `dest = const AdminRedirectScreen()`.
    * Create `AdminRedirectScreen`: stateless widget showing icon, "Admin access has moved to the web dashboard." text, the deployed web URL, and a "Copy URL" button.
    * The web URL must be the actual deployed URL from D12 — NOT a placeholder.
    * `admin_dashboard_screen.dart` and `admin_support_chat_screen.dart` files still exist. Only routing changes.
    * `flutter analyze` → zero errors.
    * Regression test: customer flow, technician flow, admin redirect all pass.
    * Ship Release 1. Start observation period.
    * **Observation gate:** 7 days with zero admin-role logins on mobile (verifiable from auth logs). Not just calendar time.

### Task 8-2: Mobile Release 2 — Admin Code Removal

* **Objective:** Delete admin screen files and remove admin-only methods from `firebase_service.dart`.
* **Terminal Commands:**
    ```bash
    git rm lib/admin_dashboard_screen.dart
    git rm lib/admin_support_chat_screen.dart
    flutter analyze
    flutter build apk --release
    flutter build ios --release
    ```
* **File Operations:** Delete 2 screen files. Modify `firebase_service.dart` — remove admin-only methods. Modify `login_screen.dart` — remove redirect.
* **Implementation Details:**
    * **Wait gate:** Observation period passed (Task 8-1).
    * Record pre-deletion commit hash.
    * Delete screen files first (surfaces compile errors).
    * Remove these admin-only methods from `firebase_service.dart`:
      * `assignJob` (line 1048)
      * `adminCloseJob` (line 1109)
      * `adminResolveDispute` (line 1596)
      * `updatePaymentStatus` (line 912)
      * `closeSupportChat` (line 704)
      * `markSupportChatReadByAdmin` (line 712)
      * `initializeStatsGlobal` (line 1711)
      * `streamActiveJobsAdmin` (line 1169)
      * `streamJobsByStatus` (line 1154)
      * `streamAllPayments` (line 920)
      * `streamSupportChats` (line 647)
      * `streamUnreadSupportCount` (line 661)
      * `fetchRecentUsers` (line 1318)
      * `fetchRecentActivity` (line 1690)
      * `getAvailableTechnicianIdsByService` (line 1198)
    * For each method: use IDE Find Usages to confirm zero non-admin callers before removing.
    * Remove `import 'admin_redirect_screen.dart';` and the `if (role == 'admin')` block from `login_screen.dart`.
    * Also delete `lib/admin_redirect_screen.dart`.
    * `flutter analyze` → zero errors.
    * Build both platforms. Record binary size reduction.
    * Ship Release 2.

### Task 8-3: Post-Migration Finalization

* **Objective:** Set up monitoring and close the migration.
* **Terminal Commands:** None (monitoring setup via Firebase Console).
* **File Operations:** None.
* **Implementation Details:**
    * Set up Cloud Monitoring alert: function error rate > 1% over 5 minutes → alert.
    * Confirm `stats/global` receives zero client writes in Firestore usage dashboard.
    * Check shared code threshold: if 3+ model files are duplicated and diverging between mobile and `admin_web`, extract `packages/shared_core/`. Otherwise defer.
    * Ensure CI pipeline (from Task 6-1b) covers admin web build and deploy.
    * Complete migration sign-off checklist:
      * [ ] All admin-only methods removed from mobile
      * [ ] Binary size reduction documented
      * [ ] All Cloud Functions error-free for 2 weeks
      * [ ] All admins operational on web
      * [ ] Zero client stats writes in Firestore dashboard
      * [ ] Commit hashes recorded (pre-deletion, post-deletion)

---

## Risk Register

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|-----------|--------|------------|
| 1 | **Stats double-counting** during Phase 5 deploy if rules + functions aren't atomic | HIGH | HIGH | Single `firebase deploy --only functions,firestore:rules` command. Test in emulator first. Remove ALL client stats writes from mobile simultaneously. |
| 2 | **`addEarnings()` stats writes missed** in Phase 5 | MEDIUM | HIGH | Listed explicitly in Task 5-2 as one of 6 removal sites. Grep for ALL `stats/global` writes before deploying. |
| 3 | **`affectedKeys()` rules reject mobile client writes** if field lists mismatch | HIGH | HIGH | Phase 2 rules match current mobile fields. Phase 4 updates rules for CF fields. Two-phase rule update. |
| 4 | **Flutter tooling cross-contamination** between root and `admin_web/` | MEDIUM | MEDIUM | Never run flutter commands at root for web. Always `cd admin_web`. Separate terminal sessions. |
| 5 | **Storage owner check impossible** with current filename convention | HIGH | MEDIUM | Task 2-2 changes upload to `{uid}_{timestamp}.jpg` before deploying rule. |
| 6 | **Admin session stale on web** — token expires mid-dashboard | MEDIUM | MEDIUM | Auth gate uses `authStateChanges()` stream. Null emission → redirect to login. |
| 7 | **Mobile admin still calls direct Firestore writes** after CFs deployed | MEDIUM | MEDIUM | CFs use Admin SDK (bypasses rules). Mobile client writes and CF writes can coexist during transition. Task 8-1 redirect eliminates mobile admin access. |
| 8 | **App Check placeholder key** blocks web deployment | HIGH | MEDIUM | Must register real reCAPTCHA Enterprise key in Firebase Console before Task 6-1. Listed as prerequisite. |
