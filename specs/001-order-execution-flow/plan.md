# Implementation Plan: Order Execution Flow + Urgent Order Fix

**Branch**: `001-order-execution-flow` | **Date**: 2026-03-28 | **Spec**: `specs/001-order-execution-flow/spec.md`

---

## Summary

Fix a live bug where urgent order submission hangs with no timeout and no UI lock. Then implement the full order execution chain: admin assigns → technician active job view (location only, zero customer PII) → arrival slide → completion slide → dual-sided payment confirmation.

---

## Technical Context

**Language/Version**: Dart / Flutter 3.x
**Primary Dependencies**: cloud_firestore, firebase_auth (all already in pubspec.yaml — add NO new packages)
**Storage**: Firestore — `jobs` collection, `users` collection, `stats/global` doc
**Testing**: None required
**Target Platform**: Android + iOS (existing app)
**Project Type**: Mobile app — existing codebase, smallest-scope changes only
**Performance Goals**: Zero extra unbounded streams; all new streams have `.limit()`
**Constraints**: No new packages. No renames of existing files. No refactors outside direct task scope.

---

## Constitution Check

- [x] All strings have `en` and `ar` variants
- [x] UI uses `syanatBlue`, `borderRadius 14`, matching shadow
- [x] All async actions use `try/catch/finally` + `mounted` check
- [x] All new Firestore writes use `FieldValue.serverTimestamp()` for timestamps
- [x] Technician receives ZERO customer PII — enforced in both Dart and Firestore rules
- [x] Payment input validated client-side before any Firestore write
- [x] Status transitions enforced in Firestore rules, not just client code
- [x] No new packages

---

## Existing Code to Understand Before Starting

Read these files fully before writing any code:

| File | Why |
|------|-----|
| `lib/service_details_screen.dart` | Contains `_showQuickOrderSheet()`, `_OrderRequestSheet._submit()`, and `_submitting` flag — this is where the urgent bug lives |
| `lib/firebase_service.dart` | Contains `assignJob()` (line ~990), `createOrderRequest()` (line ~932), `adminCloseJob()` (line ~1014), `notifyAvailableTechnicians()` (line ~1113) |
| `lib/tech_home_screen.dart` | Existing technician dashboard — will be modified to detect active job and redirect |
| `lib/admin_dashboard_screen.dart` | Existing admin dashboard — assign button added here |
| `lib/orders_screen.dart` | Customer orders list — payment confirmation trigger added here |
| `firestore.rules` | Must be updated to enforce new statuses and block technician PII access |

---

## Current Order Status Chain (Existing)

```
requested → accepted → (in_progress) → completed | cancelled
```

`requested` = customer placed order
`accepted` = admin assigned a technician
`in_progress` = used in admin stream queries (may not be set today)
`completed` = job closed

---

## New Order Status Chain (After This Feature)

```
requested → accepted → en_route → payment_pending → completed | cancelled
```

Two new statuses added: `en_route`, `payment_pending`.
`in_progress` is no longer written going forward but existing rows with it are harmless.
`accepted` stays as the assignment status (do NOT rename it — existing queries depend on it).

Transition rules (enforced in BOTH Firestore rules AND client):
- `requested` → `accepted`: admin only
- `accepted` → `en_route`: assigned technician only
- `en_route` → `payment_pending`: assigned technician only
- `payment_pending` → `completed`: customer only (the one who placed the order)
- Any status → `cancelled`: admin or customer, only if status is `requested` or `accepted`

---

## Project Structure

```
lib/
├── service_details_screen.dart     ← MODIFIED (urgent order bug fix)
├── firebase_service.dart           ← MODIFIED (new methods)
├── tech_home_screen.dart           ← MODIFIED (active job detection + redirect)
├── admin_dashboard_screen.dart     ← MODIFIED (assign button)
├── orders_screen.dart              ← MODIFIED (payment confirmation trigger)
├── technician_active_job_screen.dart  ← NEW
└── technician_payment_screen.dart     ← NEW
firestore.rules                     ← MODIFIED (new status rules + PII block)
```

---

## Phase 1: Bug Fix — Urgent Order Hang + UI Lock

### Root Cause

`_showQuickOrderSheet()` in `service_details_screen.dart` calls `Future.wait([getProfile, getSavedLocations])` with NO timeout and NO screen-level loading flag. If Firestore hangs, the button appears frozen with no feedback and no recovery path.

Additionally, `_OrderRequestSheet._submit()` is missing a `finally` block — if the `!mounted` guard on line 827 fires, `_submitting` never resets to `false`.

A second sheet (`_showOrderRequestSheet`) can be opened while the first is loading because there is no screen-level `_submitting` guard.

### Fix in `lib/service_details_screen.dart`

**In `_ServiceDetailsScreenState`:**

1. Add `bool _sheetOpen = false;` at the top of the state class.

2. Rewrite `_showQuickOrderSheet()`:
   ```dart
   Future<void> _showQuickOrderSheet() async {
     if (_sheetOpen) return;  // block re-entry
     setState(() => _sheetOpen = true);
     try {
       final user = FirebaseService.getCurrentUser();
       if (user == null) return;
       final results = await Future.wait([
         FirebaseService.getProfile(user.uid),
         FirebaseService.getSavedLocations(user.uid),
       ]).timeout(const Duration(seconds: 15));
       if (!mounted) return;
       // ... rest of sheet opening unchanged ...
     } catch (e) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(isEn ? 'Error: $e' : 'خطأ: $e')),
         );
       }
     } finally {
       if (mounted) setState(() => _sheetOpen = false);
     }
   }
   ```

3. Do the same for `_showOrderRequestSheet()` (the Schedule flow): wrap with the same `_sheetOpen` guard so both flows share the same lock.

4. Disable ALL buttons that open sheets when `_sheetOpen` is true:
   - Quick Order button: `onPressed: _sheetOpen ? null : _showQuickOrderSheet`
   - Schedule button: `onPressed: _sheetOpen ? null : () => _showOrderRequestSheet(service)`
   - Show a `CircularProgressIndicator` in place of button content when `_sheetOpen` is true

**In `_OrderRequestSheet._submit()`:**

5. Add `.timeout(const Duration(seconds: 15))` to the `createOrderRequest()` call.

6. Replace the bare `catch` block with `try/catch/finally`:
   ```dart
   } finally {
     if (mounted) setState(() { _submitting = false; });
   }
   ```
   Remove `_submitted = false` from catch — the duplicate-submit guard (`_submitted`) should only reset if the user explicitly closes and reopens the sheet, not on retry within the same session. Keep `_submitted = true` after first attempt.

   Actually: after a FAILED submission (error), allow retry by resetting both. Keep the guard active only during in-flight submission. So:
   ```dart
   setState(() { _submitting = true; _submitted = true; });
   try {
     // ... submit ...
   } catch (e) {
     if (mounted) {
       setState(() { _submitted = false; }); // allow retry
       ScaffoldMessenger...
     }
   } finally {
     if (mounted) setState(() { _submitting = false; });
   }
   ```

---

## Phase 2: Firebase Methods — New Status Transitions

### In `lib/firebase_service.dart`, add these methods:

**`markArrived(String jobId, String technicianId)`**
- Run a Firestore transaction
- Read the job document
- Assert `status == 'accepted'` AND `assignedTechnicianId == technicianId`, else throw
- Update: `status: 'en_route'`, `arrivedAt: FieldValue.serverTimestamp()`, `updatedAt: FieldValue.serverTimestamp()`

**`markJobComplete(String jobId, String technicianId)`**
- Run a Firestore transaction
- Read the job document
- Assert `status == 'en_route'` AND `assignedTechnicianId == technicianId`, else throw
- Update: `status: 'payment_pending'`, `jobCompletedAt: FieldValue.serverTimestamp()`, `updatedAt: FieldValue.serverTimestamp()`

**`submitTechnicianPayment(String jobId, String technicianId, double amount)`**
- Validate `amount`: must be > 0, must be ≤ 50000, round to 2 decimal places using `(amount * 100).round() / 100`
- If invalid, throw `ArgumentError('Invalid payment amount')`
- Run a Firestore transaction
- Read the job document
- Assert `status == 'payment_pending'` AND `assignedTechnicianId == technicianId` AND `technicianPaymentAmount == null` (idempotency), else throw
- Update: `technicianPaymentAmount: amount`, `technicianPaymentSubmittedAt: FieldValue.serverTimestamp()`, `updatedAt: FieldValue.serverTimestamp()`
- Note: status stays `payment_pending` — customer still needs to confirm

**`confirmCustomerPayment(String jobId, String customerId)`**
- Run a Firestore transaction
- Read the job document
- Assert `status == 'payment_pending'` AND `customerId == customerId field in doc` AND `technicianPaymentAmount != null`, else throw
- Update: `status: 'completed'`, `amountPaid: data['technicianPaymentAmount']`, `price: data['technicianPaymentAmount']`, `customerConfirmedAt: FieldValue.serverTimestamp()`, `updatedAt: FieldValue.serverTimestamp()`
- After transaction: `FieldValue.increment` on `stats/global`: `totalEarnings += amountPaid`, `jobsCompleted += 1`, `jobsOngoing += -1`
- Append to `activity_log`: type `'job_completed'`, description `'Job closed — X EGP'`

**`streamTechnicianActiveJob(String technicianId)`** — returns `Stream<Map<String, dynamic>?>`
- Query: `jobs.where('assignedTechnicianId', isEqualTo: technicianId).where('status', whereIn: ['accepted', 'en_route', 'payment_pending']).limit(1)`
- Map snapshots: return first document data with `id` field injected, or `null` if empty
- This is the ONLY stream the technician active job screen subscribes to

**`streamCustomerActivePayment(String customerId)`** — returns `Stream<Map<String, dynamic>?>`
- Query: `jobs.where('customerId', isEqualTo: customerId).where('status', isEqualTo: 'payment_pending').limit(1)`
- Map snapshots: return first document data with `id` injected, or `null`

---

## Phase 3: Firestore Rules Update

In `firestore.rules`, add/update these rules:

```
// jobs collection
match /jobs/{jobId} {
  // Customer can read their own jobs (all fields except nothing is hidden at doc level —
  // customer PII is NOT in the job doc fields that technicians access)
  allow read: if request.auth != null && (
    resource.data.customerId == request.auth.uid ||   // customer
    resource.data.assignedTechnicianId == request.auth.uid ||  // assigned tech
    isAdmin(request.auth.uid)  // admin
  );

  // Customer can create
  allow create: if request.auth != null && request.resource.data.customerId == request.auth.uid;

  // Status transition enforcement
  allow update: if request.auth != null && (
    // Admin can assign (requested → accepted)
    (isAdmin(request.auth.uid) &&
     resource.data.status == 'requested' &&
     request.resource.data.status == 'accepted') ||

    // Technician can mark arrived (accepted → en_route)
    (resource.data.assignedTechnicianId == request.auth.uid &&
     resource.data.status == 'accepted' &&
     request.resource.data.status == 'en_route') ||

    // Technician can mark complete (en_route → payment_pending)
    (resource.data.assignedTechnicianId == request.auth.uid &&
     resource.data.status == 'en_route' &&
     request.resource.data.status == 'payment_pending') ||

    // Technician submits payment amount (stays payment_pending)
    (resource.data.assignedTechnicianId == request.auth.uid &&
     resource.data.status == 'payment_pending' &&
     request.resource.data.status == 'payment_pending') ||

    // Customer confirms payment (payment_pending → completed)
    (resource.data.customerId == request.auth.uid &&
     resource.data.status == 'payment_pending' &&
     request.resource.data.status == 'completed') ||

    // Admin or customer cancels (requested or accepted only)
    ((isAdmin(request.auth.uid) || resource.data.customerId == request.auth.uid) &&
     (resource.data.status == 'requested' || resource.data.status == 'accepted') &&
     request.resource.data.status == 'cancelled')
  );
}
```

**CRITICAL — PII Protection**: The job document sent to the technician MUST NOT contain `customerPhone` or `customerEmail`. Verify `createOrderRequest()` does NOT store these fields in the job document. Looking at the existing code (line ~946-969): the job document stores `customerId`, `customerName`, `phoneNumber`, `locationAddress`. The `phoneNumber` field is customer PII that the technician can currently read.

**Fix required**: Remove `phoneNumber` from the job document that is readable by the technician. Two options:
- Option A (Recommended): Remove `phoneNumber` from the job document entirely. Customers already have it on their profile. Technicians don't need it.
- Option B: Keep it in Firestore but block it via rules using field masks (complex, not supported in Firestore rules).

**Use Option A**: Remove `'phoneNumber': phoneNumber` from `createOrderRequest()` data map. The phone number is only needed for admin and customer, both of whom can get it from the user profile.

---

## Phase 4: Admin Assign Flow

### In `lib/admin_dashboard_screen.dart`

Find where individual pending orders are rendered (the `requested` status list). For each order card, add an "Assign Technician" button.

When tapped:
1. Show a `showModalBottomSheet` with a list of available technicians
2. Available = `users` where `role == 'technician'` AND `isAvailable == true` AND NOT currently in `assignedTechnicianId` of any job with status in `['accepted', 'en_route', 'payment_pending']`
3. Fetch this list with a single Firestore query: `users.where('role', isEqualTo: 'technician').where('isAvailable', isEqualTo: true).limit(50)` — then filter out occupied ones client-side using the `streamJobsByStatus` data already loaded on the dashboard
4. User selects a technician → call `FirebaseService.assignJob(jobId, technicianId, technicianName)` (existing method — no changes needed)
5. Show success SnackBar, close sheet

The technician list item shows: technician name and specialty only. No phone, no email.

---

## Phase 5: Technician Active Job Screen

### New file: `lib/technician_active_job_screen.dart`

This screen is shown INSTEAD of `TechHomeScreen` content when the technician has an active job.

**Constructor**: `TechnicianActiveJobScreen({required Map<String, dynamic> job})`

The `job` map contains fields from the Firestore job document. It will have: `id`, `serviceKey`, `serviceCategory`, `locationAddress`, `status`, `assignedTechnicianId`, `technicianPaymentAmount` (nullable).

**What to display** (based on `job['status']`):

When `status == 'accepted'`:
- AppBar: service category name (EN or AR based on locale)
- Body: address card (icon + `locationAddress` text). Nothing else.
- Bottom: `SlideToConfirmBar` widget (see below) with label "Slide to confirm arrival" / "اسحب لتأكيد الوصول"
- On slide complete: call `FirebaseService.markArrived(job['id'], currentTechId)` — show loading, handle error

When `status == 'en_route'`:
- Same address card
- `SlideToConfirmBar` with label "Slide to mark job complete" / "اسحب لإتمام العمل"
- On slide complete: call `FirebaseService.markJobComplete(job['id'], currentTechId)` — on success, push `TechnicianPaymentScreen`

When `status == 'payment_pending'` AND `job['technicianPaymentAmount'] != null`:
- Show "Waiting for customer to confirm payment of X EGP" / "في انتظار تأكيد العميل للدفع"
- No action buttons — just a status card with a spinner

**`SlideToConfirmBar` widget** (private to this file):

```dart
class _SlideToConfirmBar extends StatefulWidget {
  final String label;
  final VoidCallback onConfirmed;
  // ...
}
```

Implementation:
- A `GestureDetector` wrapping a `Stack`
- Background track: rounded container, syanatBlue at 20% opacity
- Draggable thumb: white rounded container with an arrow icon
- Track user drag with `onHorizontalDragUpdate` — compute percentage as `dragX / maxWidth`
- Only fire `onConfirmed` when percentage reaches 1.0 (100%)
- On release below 100%: animate thumb back to start with `AnimationController` (300ms ease-out)
- Once confirmed: disable further interaction (`_confirmed = true`)
- Show a checkmark icon in place of arrow when confirmed
- Height: 64dp. Corner radius: 32dp. Thumb size: 56dp square.

**IMPORTANT**: Do not import or display `customerName`, `customerId`, `phoneNumber` anywhere in this screen.

---

## Phase 6: Technician Payment Screen

### New file: `lib/technician_payment_screen.dart`

**Constructor**: `TechnicianPaymentScreen({required String jobId, required String technicianId})`

Content:
- AppBar: "Payment Entry" / "إدخال المدفوعات"
- A single `_fieldCard`-style input for "Amount paid (EGP)" / "المبلغ المدفوع (جنيه)"
- Keyboard type: `TextInputType.numberWithOptions(decimal: true)`
- A submit button: "Submit" / "إرسال"
- Loading state: disable button + show spinner while submitting
- On submit:
  - Parse amount: `double.tryParse(controller.text.trim())`
  - If null or ≤ 0 or > 50000: show SnackBar error, return
  - Call `FirebaseService.submitTechnicianPayment(jobId, technicianId, amount)`
  - On success: `Navigator.pop(context)` — tech returns to `TechnicianActiveJobScreen` which will show "waiting for customer" state

---

## Phase 7: Customer Payment Confirmation

### In `lib/orders_screen.dart`

The customer's orders list already streams their orders. When an order has `status == 'payment_pending'` AND `technicianPaymentAmount != null`:

1. Render a visually prominent banner/card at the TOP of the orders list (above all other orders):
   - Background: amber/warning yellow (`Color(0xFFFFF8E1)`) with an orange left border
   - Bold text: "Payment Confirmation Required" / "مطلوب تأكيد الدفع"
   - Amount shown in large text: `technicianPaymentAmount` EGP
   - The disclaimer (must be visually distinct — bold, red text, 13sp minimum):
     > **"Only confirm the exact amount you paid. Do not confirm if the amount was changed. This protects your rights and ensures accurate service records."**
     > Arabic: **"قم بالتأكيد فقط إذا كان هذا هو المبلغ الذي دفعته بالضبط. لا تقبل أي تعديل على المبلغ. هذا يحمي حقوقك ويضمن دقة سجلات الخدمة."**
   - Two buttons: "Confirm" (green) / "Report Issue" (outlined red — opens support chat for now, uses existing `SupportChatScreen`)
   - On Confirm: call `FirebaseService.confirmCustomerPayment(jobId, customerId)` with loading state and error handling

2. The banner dismisses once `status == 'completed'` (the stream updates automatically).

---

## Phase 8: Technician Dashboard — Active Job Detection

### In `lib/tech_home_screen.dart`

In `initState` (or in the stream subscription), after loading jobs, check if any job has status in `['accepted', 'en_route', 'payment_pending']` and `assignedTechnicianId == currentUserId`.

Use the new `FirebaseService.streamTechnicianActiveJob(uid)` stream.

In `build()`, wrap the entire scaffold body with:

```dart
if (_activeJob != null) {
  return TechnicianActiveJobScreen(job: _activeJob!);
}
// ... existing dashboard UI
```

`_activeJob` is a `Map<String, dynamic>?` state variable updated by the stream subscription.

Cancel the stream subscription in `dispose()`.

---

## Data Schema Additions

Add these fields to the `jobs` document (all nullable, set as jobs progress):

| Field | Type | Set by |
|-------|------|--------|
| `arrivedAt` | Timestamp | Technician (`markArrived`) |
| `jobCompletedAt` | Timestamp | Technician (`markJobComplete`) |
| `technicianPaymentAmount` | double | Technician (`submitTechnicianPayment`) |
| `technicianPaymentSubmittedAt` | Timestamp | Technician (`submitTechnicianPayment`) |
| `customerConfirmedAt` | Timestamp | Customer (`confirmCustomerPayment`) |

**Remove from `createOrderRequest` data map**: `'phoneNumber': phoneNumber` (PII protection — technician can read the job doc).

---

## Security Checklist

- [ ] Job document does NOT contain `phoneNumber`, `customerEmail` fields
- [ ] Technician active job screen: grep for any text rendering of `customerName` or `phoneNumber` — must be zero occurrences
- [ ] Firestore rules block technician from reading `users/{customerId}` document
- [ ] Payment amount is validated both client-side (Dart) and is a positive finite double before any write
- [ ] All status transitions are in Firestore rules — not just `if` statements in Dart
- [ ] `_sheetOpen` guard prevents concurrent sheet opens in service details screen
- [ ] `.timeout(Duration(seconds: 15))` on `createOrderRequest` call
- [ ] `try/catch/finally` on all new async methods with `mounted` checks

---

## Notes for Codex

- Do not rename any existing Firestore field names — `assignedTechnicianId`, `technicianId`, `customerName` etc. are used by existing screens.
- The `phoneNumber` removal from `createOrderRequest` is the ONLY schema removal. All other fields stay.
- The `SlideToConfirmBar` widget lives in `technician_active_job_screen.dart` as a private widget — do not create a separate file for it.
- All new screens follow the existing pattern: `Directionality` wrapper, `syanatBlue` AppBar, white background.
- Do not add the `TechnicianActiveJobScreen` to `main.dart` routes — it is pushed programmatically from `TechHomeScreen`.
- The `_fieldCard` widget in `account_settings_screen.dart` is the visual pattern reference for input cards.
