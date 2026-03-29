# Tasks: Order Execution Flow + Urgent Order Fix

**Spec**: `specs/001-order-execution-flow/spec.md`
**Plan**: `specs/001-order-execution-flow/plan.md`
**Read both fully before starting any task.**

---

## Phase 1: Bug Fix — Urgent Order Hang + UI Lock (P1 — do this first)

**Goal**: Urgent order submission no longer hangs forever; all UI is locked during any sheet loading or submission.

- [X] T001 [US1] `lib/service_details_screen.dart` — Add `bool _sheetOpen = false` to `_ServiceDetailsScreenState`. Wrap `_showQuickOrderSheet()` with `_sheetOpen` guard: set true before `Future.wait`, false in `finally`. Add `.timeout(const Duration(seconds: 15))` to the `Future.wait` call. Show SnackBar on TimeoutException or any other error.
- [X] T002 [US1] `lib/service_details_screen.dart` — Apply same `_sheetOpen` guard to `_showOrderRequestSheet()` (the schedule flow). Both flows share the same lock — only one sheet can open at a time.
- [X] T003 [US1] `lib/service_details_screen.dart` — In the screen `build()`: set Quick Order button `onPressed: _sheetOpen ? null : _showQuickOrderSheet`. Set Schedule button `onPressed: _sheetOpen ? null : () => _showOrderRequestSheet(service)`. Show a small `SizedBox(width:16, height:16, child: CircularProgressIndicator(strokeWidth:2, color:syanatBlue))` inside the Quick Order button when `_sheetOpen` is true.
- [X] T004 [US1] `lib/service_details_screen.dart` — In `_OrderRequestSheet._submit()`: add `.timeout(const Duration(seconds: 15))` to the `FirebaseService.createOrderRequest(...)` call. Convert bare `catch` to `try/catch/finally`. In `finally`: `if (mounted) setState(() { _submitting = false; })`. In `catch`: reset `_submitted = false` to allow retry. Remove `_submitted = false` from anywhere else.

**Checkpoint**: Build and run. Tap Urgent Order — button shows spinner, Schedule button is disabled. Wait 15s with no network — error SnackBar appears, UI unlocks, retry works.

---

## Phase 2: Firebase — New Methods (P2)

**Goal**: All Firestore operations for the new status flow are in `firebase_service.dart`.

- [X] T005 [P] [US3] `lib/firebase_service.dart` — Add `markArrived(String jobId, String technicianId)`: transaction that asserts `status == 'accepted'` and `assignedTechnicianId == technicianId`, then updates `status: 'en_route'`, `arrivedAt: FieldValue.serverTimestamp()`, `updatedAt: FieldValue.serverTimestamp()`.
- [X] T006 [P] [US4] `lib/firebase_service.dart` — Add `markJobComplete(String jobId, String technicianId)`: transaction that asserts `status == 'en_route'` and `assignedTechnicianId == technicianId`, then updates `status: 'payment_pending'`, `jobCompletedAt: FieldValue.serverTimestamp()`, `updatedAt: FieldValue.serverTimestamp()`.
- [X] T007 [P] [US5] `lib/firebase_service.dart` — Add `submitTechnicianPayment(String jobId, String technicianId, double amount)`: validate amount (> 0, ≤ 50000, round to 2dp). Transaction asserts `status == 'payment_pending'`, `assignedTechnicianId == technicianId`, `technicianPaymentAmount == null`. Updates `technicianPaymentAmount: amount`, `technicianPaymentSubmittedAt: FieldValue.serverTimestamp()`, `updatedAt: FieldValue.serverTimestamp()`. Status stays `payment_pending`.
- [X] T008 [P] [US5] `lib/firebase_service.dart` — Add `confirmCustomerPayment(String jobId, String customerId)`: transaction asserts `status == 'payment_pending'`, `customerId == request.auth.uid equivalent`, `technicianPaymentAmount != null`. Updates `status: 'completed'`, `amountPaid: technicianPaymentAmount`, `price: technicianPaymentAmount`, `customerConfirmedAt: FieldValue.serverTimestamp()`, `updatedAt`. After transaction: increment `stats/global` (`totalEarnings`, `jobsCompleted +1`, `jobsOngoing -1`). Append activity_log entry `type: 'job_completed'`.
- [X] T009 [P] [US3] `lib/firebase_service.dart` — Add `streamTechnicianActiveJob(String technicianId)` returning `Stream<Map<String, dynamic>?>`. Query: `jobs.where('assignedTechnicianId', isEqualTo: technicianId).where('status', whereIn: ['accepted', 'en_route', 'payment_pending']).limit(1)`. Map to first doc with `id` injected, or null.
- [X] T010 [P] [US5] `lib/firebase_service.dart` — Add `streamCustomerActivePayment(String customerId)` returning `Stream<Map<String, dynamic>?>`. Query: `jobs.where('customerId', isEqualTo: customerId).where('status', isEqualTo: 'payment_pending').limit(1)`. Map to first doc with `id` injected, or null.
- [X] T011 [US2] `lib/firebase_service.dart` — In `createOrderRequest()`: remove `'phoneNumber': phoneNumber` from the data map written to Firestore. The phone number must not be stored on the job document (PII protection). Do NOT remove the `phoneNumber` parameter from the method signature — it may be used by other callers for other purposes. Simply do not write it to Firestore.

**Checkpoint**: No compile errors. New methods exist and are callable.

---

## Phase 3: Firestore Rules (P2 — parallel with Phase 2)

**Goal**: Status transitions enforced server-side; technician cannot read customer PII.

- [X] T012 [US2,US3,US4,US5] `firestore.rules` — Add/replace the `jobs` collection rules to enforce the exact status transition table from the plan. Include all five allowed transitions: admin assigns, tech marks arrived, tech marks complete, tech submits payment, customer confirms. Include cancellation rule. See plan.md Phase 3 for the exact rule structure.
- [X] T013 [US3] `firestore.rules` — Ensure the `users` collection rule blocks a technician from reading any user document other than their own: `allow read: if request.auth.uid == userId || isAdmin(request.auth.uid)`. Technicians must not be able to call `getProfile(customerId)`.

**Checkpoint**: Deploy rules (`firebase deploy --only firestore:rules`). Manually verify in Firebase console simulator that a technician UID cannot read another user's document.

---

## Phase 4: Technician Active Job Screen (P3)

**Goal**: When technician has an active job, they see only address + service type + slide bar.

- [X] T014 [US3] `lib/technician_active_job_screen.dart` — Create file. `TechnicianActiveJobScreen` stateful widget. Constructor: `({required Map<String, dynamic> job, required String technicianId})`. Wrap root in `Directionality`. AppBar with `syanatBlue`, show service category (EN/AR). Do NOT render any field named `customerName`, `phoneNumber`, `customerId`, or `customerEmail` anywhere.
- [X] T015 [US3] `lib/technician_active_job_screen.dart` — Implement the address card: white container with `borderRadius 14`, shadow `Color(0x0F000000) blurRadius 8 offset (0,3)`, icon `Icons.location_on` in `Color(0x143C21C8)` background, display `job['locationAddress']` text.
- [X] T016 [US3] `lib/technician_active_job_screen.dart` — Implement private `_SlideToConfirmBar` stateful widget. Track drag percentage with `onHorizontalDragUpdate`. Fire `onConfirmed` only at 100%. Snap back with `AnimationController(300ms, Curves.easeOut)` on release below 100%. Disable after confirmed. Height 64dp, radius 32dp, thumb 56dp.
- [X] T017 [US3,US4] `lib/technician_active_job_screen.dart` — Status-conditional body: `status == 'accepted'` → address card + arrival slide bar; `status == 'en_route'` → address card + completion slide bar; `status == 'payment_pending'` → waiting-for-customer card with spinner. Each action (markArrived, markJobComplete) has `_loading` state, try/catch/finally, mounted check.
- [X] T018 [US4] `lib/technician_active_job_screen.dart` — On `markJobComplete` success: `Navigator.push(context, MaterialPageRoute(builder: (_) => TechnicianPaymentScreen(jobId: job['id'], technicianId: technicianId)))`.

**Checkpoint**: Screen renders with a mock job map. Slide bar snaps back correctly on partial drag.

---

## Phase 5: Technician Payment Screen (P5)

**Goal**: Technician enters the amount paid and submits it.

- [X] T019 [US5] `lib/technician_payment_screen.dart` — Create file. `TechnicianPaymentScreen` stateful widget. Constructor: `({required String jobId, required String technicianId})`. AppBar "Payment Entry" / "إدخال المدفوعات". Single `_fieldCard`-style amount input, `TextInputType.numberWithOptions(decimal: true)`.
- [X] T020 [US5] `lib/technician_payment_screen.dart` — Submit button with full loading state (try/catch/finally, mounted check). Validate: `double.tryParse` must succeed, result must be > 0 and ≤ 50000. On invalid: show SnackBar, do NOT call Firebase. On success: `Navigator.pop(context)`.

**Checkpoint**: Enter 0 → error. Enter 60000 → error. Enter 500 → calls `submitTechnicianPayment`, returns to active job screen.

---

## Phase 6: Customer Payment Confirmation (P5)

**Goal**: Customer sees amount + prominent disclaimer; confirms to close the order.

- [X] T021 [US5] `lib/orders_screen.dart` — Subscribe to `FirebaseService.streamCustomerActivePayment(uid)`. Store result in `_pendingPayment` state variable. Cancel subscription in `dispose()`.
- [X] T022 [US5] `lib/orders_screen.dart` — When `_pendingPayment != null`, render a payment confirmation banner at the TOP of the orders list (before the ListView/existing content). Banner background: `Color(0xFFFFF8E1)`, left border: orange `Color(0xFFFF9800)` width 4. Show amount in large bold text.
- [X] T023 [US5] `lib/orders_screen.dart` — Inside the banner: render the disclaimer text in bold red (`Colors.red.shade700`, fontSize 13, fontWeight bold). EN: "Only confirm the exact amount you paid. Do not confirm if the amount was changed. This protects your rights and ensures accurate service records." AR: "قم بالتأكيد فقط إذا كان هذا هو المبلغ الذي دفعته بالضبط. لا تقبل أي تعديل على المبلغ. هذا يحمي حقوقك ويضمن دقة سجلات الخدمة."
- [X] T024 [US5] `lib/orders_screen.dart` — Two buttons in the banner: "Confirm" (ElevatedButton, green) calls `FirebaseService.confirmCustomerPayment(jobId, uid)` with loading state; "Report Issue" (OutlinedButton, red) navigates to `SupportChatScreen`. Full try/catch/finally on confirm.

**Checkpoint**: With an order in `payment_pending` + `technicianPaymentAmount` set, banner appears at top. Disclaimer is clearly visible. Confirm calls Firebase and banner disappears.

---

## Phase 7: Admin Assign Flow (P2)

**Goal**: Admin can assign a pending order to an available technician from the dashboard.

- [X] T025 [US2] `lib/admin_dashboard_screen.dart` — Find the widget that renders a single `requested`-status order card. Add an "Assign Technician" / "تعيين فني" button to it (ElevatedButton or TextButton with syanatBlue color).
- [X] T026 [US2] `lib/admin_dashboard_screen.dart` — On tap: open `showModalBottomSheet`. Inside sheet: fetch `users` where `role == 'technician'` and `isAvailable == true` (single query, `.limit(50)`). Filter out technicians already in active jobs by cross-referencing the `_jobs` data already loaded in the dashboard state. Show a `ListView` of available technicians (name only — no phone/email).
- [X] T027 [US2] `lib/admin_dashboard_screen.dart` — On technician selection: call existing `FirebaseService.assignJob(jobId, technicianId, technicianName)`. Show loading state. On success: close sheet, show SnackBar. try/catch/finally with mounted check.

**Checkpoint**: Open admin dashboard, find a pending order, tap Assign, select a technician, verify order moves to `accepted` in Firestore.

---

## Phase 8: Technician Dashboard — Active Job Detection (P3)

**Goal**: Tech home screen automatically shows the active job view when an active job exists.

- [X] T028 [US3] `lib/tech_home_screen.dart` — Add `Map<String, dynamic>? _activeJob` state variable and `StreamSubscription? _activeJobSub`.
- [X] T029 [US3] `lib/tech_home_screen.dart` — In `initState()`: subscribe to `FirebaseService.streamTechnicianActiveJob(uid)`. In the listener: `setState(() => _activeJob = job)`. Store subscription in `_activeJobSub`. Cancel in `dispose()`.
- [X] T030 [US3] `lib/tech_home_screen.dart` — In `build()`: if `_activeJob != null`, return `TechnicianActiveJobScreen(job: _activeJob!, technicianId: uid)` directly (replace the entire scaffold, not just a part of it). Import `technician_active_job_screen.dart`.

**Checkpoint**: Assign a job to a technician in Firestore. Open tech app — active job screen appears. Complete the job flow through to `completed` — tech app returns to normal dashboard.

---

## Dependencies & Execution Order

- Phase 1 has no dependencies — start immediately, it is the live bug fix
- Phase 2 and Phase 3 can run in parallel (Firebase methods + Firestore rules)
- Phase 4 depends on T005, T006 (Firebase methods for markArrived, markJobComplete)
- Phase 5 depends on T007
- Phase 6 depends on T008, T010
- Phase 7 depends on existing `assignJob()` — no new Firebase methods needed
- Phase 8 depends on T009 and Phase 4 being complete

---

## Final Security Checklist (run before submitting)

- [X] Grep `technician_active_job_screen.dart` for `customerName`, `phoneNumber`, `customerEmail` — must return zero matches
- [X] Grep `technician_payment_screen.dart` for same — must return zero matches
- [X] `createOrderRequest` in `firebase_service.dart` does NOT write `phoneNumber` to the job document
- [ ] All new `async` methods have `try/catch/finally` and `mounted` checks
- [X] `_sheetOpen` guard is in place in `service_details_screen.dart`
- [X] `.timeout(Duration(seconds:15))` is on the `createOrderRequest` call in `_submit()`
- [ ] Firestore rules deployed and tested

