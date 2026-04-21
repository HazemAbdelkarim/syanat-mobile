# Phase 1 Data Model — Admin Web Shell (Spec 004)

**Date**: 2026-04-18
**Scope**: Dart-side types (classes, enums, widgets) introduced by this spec. The Firestore schema is unchanged — this spec reads existing collections (`users/{uid}`, `stats/global`) and declares service-layer stubs for Phase 7 to implement.

---

## 1. `AdminFirebaseService`

**File**: `.claude/AdminWebApp/lib/services/admin_firebase_service.dart`

**Shape**:

```dart
class AdminFirebaseService {
  AdminFirebaseService();

  /// IMPLEMENTED in Phase 6 — used by the Overview placeholder smoke test.
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamStats() {
    return FirebaseFirestore.instance
        .doc('stats/global')
        .snapshots();
  }

  // ---- All methods below are Phase 7 stubs. Each throws UnimplementedError. ----

  Stream<QuerySnapshot<Map<String, dynamic>>> streamActiveJobsAdmin() {
    throw UnimplementedError(
      'AdminFirebaseService.streamActiveJobsAdmin not implemented (Phase 7)',
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamJobsByStatus(String status) {
    throw UnimplementedError(
      'AdminFirebaseService.streamJobsByStatus not implemented (Phase 7)',
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamAllPayments() {
    throw UnimplementedError(
      'AdminFirebaseService.streamAllPayments not implemented (Phase 7)',
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamSupportChats() {
    throw UnimplementedError(
      'AdminFirebaseService.streamSupportChats not implemented (Phase 7)',
    );
  }

  Stream<int> streamUnreadSupportCount() {
    throw UnimplementedError(
      'AdminFirebaseService.streamUnreadSupportCount not implemented (Phase 7)',
    );
  }

  Future<void> markSupportChatReadByAdmin(String chatId) {
    throw UnimplementedError(
      'AdminFirebaseService.markSupportChatReadByAdmin not implemented (Phase 7)',
    );
  }

  Future<void> closeSupportChat(String chatId) {
    throw UnimplementedError(
      'AdminFirebaseService.closeSupportChat not implemented (Phase 7)',
    );
  }

  Future<void> sendSupportMessage({required String chatId, required String text}) {
    throw UnimplementedError(
      'AdminFirebaseService.sendSupportMessage not implemented (Phase 7)',
    );
  }

  Future<List<Map<String, dynamic>>> fetchRecentUsers({int limit = 10}) {
    throw UnimplementedError(
      'AdminFirebaseService.fetchRecentUsers not implemented (Phase 7)',
    );
  }

  Future<List<Map<String, dynamic>>> fetchRecentActivity({int limit = 50}) {
    throw UnimplementedError(
      'AdminFirebaseService.fetchRecentActivity not implemented (Phase 7)',
    );
  }

  Future<List<String>> getAvailableTechnicianIdsByService(String serviceKey) {
    throw UnimplementedError(
      'AdminFirebaseService.getAvailableTechnicianIdsByService not implemented (Phase 7)',
    );
  }

  Future<void> initializeStatsGlobal() {
    throw UnimplementedError(
      'AdminFirebaseService.initializeStatsGlobal not implemented (Phase 7)',
    );
  }
}
```

**Invariants**:
- The class has exactly 13 methods (1 implemented + 12 stubs).
- `UnimplementedError` messages follow the exact template `'AdminFirebaseService.<methodName> not implemented (Phase 7)'`.
- `streamStats()` MUST read `stats/global` (exact path) using `FirebaseFirestore.instance.doc(...).snapshots()`.
- No mutable state in the class (no fields other than dependencies injected via constructor — and Phase 6 has none).
- Spelling: `streamSupportChats` (not `streamAllSupportChats` — spec FR-026 and Migration Plan agree on this shorter name).

---

## 2. `AdminCloudFunctions`

**File**: `.claude/AdminWebApp/lib/services/admin_cloud_functions.dart`

**Shape**:

```dart
class AdminCloudFunctions {
  AdminCloudFunctions();

  Future<void> assignJob(String jobId, String technicianId) {
    throw UnimplementedError(
      'AdminCloudFunctions.assignJob not implemented (Phase 7)',
    );
  }

  Future<void> approvePayment(String paymentId) {
    throw UnimplementedError(
      'AdminCloudFunctions.approvePayment not implemented (Phase 7)',
    );
  }

  Future<void> rejectPayment(String paymentId, String reason) {
    throw UnimplementedError(
      'AdminCloudFunctions.rejectPayment not implemented (Phase 7)',
    );
  }

  Future<void> resolveDispute(
    String jobId,
    String resolution,
    String reason, {
    double? overrideAmount,
  }) {
    throw UnimplementedError(
      'AdminCloudFunctions.resolveDispute not implemented (Phase 7)',
    );
  }

  Future<void> closeJob(String jobId, double amountPaid) {
    throw UnimplementedError(
      'AdminCloudFunctions.closeJob not implemented (Phase 7)',
    );
  }
}
```

**Invariants**:
- Exactly 5 methods, all throwing `UnimplementedError`.
- Method names and parameter lists mirror the deployed callable signatures from Spec 002 (`adminAssignJob`, `adminApprovePayment`, `adminRejectPayment`, `adminResolveDispute`, `adminCloseJob`) minus the `admin` prefix — this keeps the web class ergonomic while unambiguously mapping to the backend.
- `resolveDispute` takes the three positional strings `(jobId, resolution, reason)` and an optional named `overrideAmount` — the parameter ordering is load-bearing because Phase 7 feature code will call this with positional args.

---

## 3. `AdminSection` enum

**File**: `.claude/AdminWebApp/lib/dashboard/dashboard_screen.dart` (declared at file scope, not inside `DashboardScreen`).

**Shape**:

```dart
enum AdminSection {
  overview,
  jobs,
  payments,
  disputes,
  support,
  activity,
}
```

**Invariants**:
- Exactly 6 values in exactly this order (FR-022).
- Order matters because `NavigationRail.destinations[i]` maps to `AdminSection.values[i]`.
- No additional fields — this is a plain enum (Dart 3 enhanced enums are allowed but not needed in Phase 6).

---

## 4. `AuthGate` widget

**File**: `.claude/AdminWebApp/lib/auth/auth_gate.dart`

**Shape** (high-level contract):

```dart
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }
        final user = snap.data;
        if (user == null) return const LoginScreen();
        return _AdminCheck(user: user);
      },
    );
  }
}

class _AdminCheck extends StatefulWidget {
  final User user;
  const _AdminCheck({required this.user});
  @override
  State<_AdminCheck> createState() => _AdminCheckState();
}

class _AdminCheckState extends State<_AdminCheck> {
  // initState: one-shot read of users/{uid}
  // If !exists || role != 'admin': await FirebaseAuth.signOut() BEFORE setState showing denied screen.
  // While loading: CircularProgressIndicator.
  // On pass: DashboardScreen.
}
```

**Invariants**:
- `StreamBuilder<User?>` on `authStateChanges()` — not `userChanges()` and not `idTokenChanges()`.
- Admin check is a **one-shot** `.get()` against `users/{uid}`, NOT a stream (a stream would keep the user's own-doc subscription open indefinitely; a one-shot is enough because the gate re-runs on every `authStateChanges()` emission).
- `FirebaseAuth.instance.signOut()` MUST be awaited BEFORE `setState` transitions to the denied-screen UI.
- `_AdminCheck` MUST re-run its check on every mount (achieved by making it a `StatefulWidget` keyed by `user.uid` — if the `User` instance changes, a new `_AdminCheck` is built).

---

## 5. `LoginScreen` widget

**File**: `.claude/AdminWebApp/lib/auth/login_screen.dart`

**Shape** (contract, not full implementation):

```dart
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _submitting = false;
  String? _errorMessage;

  Future<void> _submitEmailPassword() async { /* ... */ }
  Future<void> _submitGoogle() async { /* ... */ }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: /* email + password + two buttons + error area */,
        ),
      ),
    );
  }
}
```

**Invariants**:
- Form width constrained to `maxWidth: 400` (FR-014).
- Submit button disabled + shows `CircularProgressIndicator` while `_submitting == true` (FR-015).
- Google sign-in uses `google_sign_in` → `FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(...))` (FR-016).
- Error text surface shows `FirebaseAuthException.message` ONLY (FR-020, Principle XIII) — no stack traces, no network error dumps.
- `dispose()` MUST dispose both `TextEditingController`s.

---

## 6. `DashboardScreen` widget

**File**: `.claude/AdminWebApp/lib/dashboard/dashboard_screen.dart`

**Shape** (contract):

```dart
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0; // AdminSection.overview

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.dashboard),        label: Text('Overview')),
              NavigationRailDestination(icon: Icon(Icons.work_outline),     label: Text('Jobs')),
              NavigationRailDestination(icon: Icon(Icons.payments_outlined), label: Text('Payments')),
              NavigationRailDestination(icon: Icon(Icons.gavel),            label: Text('Disputes')),
              NavigationRailDestination(icon: Icon(Icons.support_agent),    label: Text('Support')),
              NavigationRailDestination(icon: Icon(Icons.history),          label: Text('Activity')),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                _OverviewPlaceholder(),
                _SectionPlaceholder('Jobs'),
                _SectionPlaceholder('Payments'),
                _SectionPlaceholder('Disputes'),
                _SectionPlaceholder('Support'),
                _SectionPlaceholder('Activity'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

**Invariants**:
- Six destinations in the exact order specified by `AdminSection.values` (FR-021, FR-022, FR-023).
- `IndexedStack` is required (not a conditional build) so that clicking the same destination twice is a no-op rebuild (spec Edge Case).
- Icon assignment per FR-023: Overview → `Icons.dashboard`, Jobs → `Icons.work_outline`, Payments → `Icons.payments_outlined`, Disputes → `Icons.gavel`, Support → `Icons.support_agent`, Activity → `Icons.history`.
- At 1280×800, no overflow (SC-008, FR-025) — achieved by `Expanded` on the content area and `labelType: NavigationRailLabelType.all` which keeps the rail narrow enough.

---

## 7. `main.dart` bootstrap contract

**File**: `.claude/AdminWebApp/lib/main.dart`

**Shape** (contract):

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyBDZlSoKBy_MWYeCUc27PVxBH7KYAfKfZ0',
      appId: '1:850445794682:web:0a05be4e3e0ccb1d5caac3',
      messagingSenderId: '850445794682',
      projectId: 'syana-ea75a',
      authDomain: 'syana-ea75a.firebaseapp.com',
      storageBucket: 'syana-ea75a.appspot.com',
      measurementId: 'G-KYNSN89SZS',
    ),
  );
  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider('<REAL_SITE_KEY>'), // see FR-007 — no placeholder
  );
  runApp(const _AdminApp());
}

class _AdminApp extends StatelessWidget {
  const _AdminApp();
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.light(useMaterial3: true), // Phase 6 pin; Phase 7 may refine colors
        home: const AuthGate(),
      );
}
```

**Invariants**:
- Firebase init MUST `await` before `FirebaseAppCheck.instance.activate(...)`.
- App Check activation MUST NOT be wrapped in `try { ... } catch (_) {}` — failure MUST propagate as an uncaught error so a placeholder key is visibly broken (spec Edge Case).
- Firebase config values come verbatim from `WOOHOO/Migration_Implementation_Plan.md` and `lib/firebase_service.dart` (FR-006).

---

## 8. Data-flow summary

```text
                   ┌────────────────┐
                   │  main.dart     │
                   │  (FB + Check)  │
                   └────────┬───────┘
                            │ runApp
                   ┌────────▼───────┐
                   │  _AdminApp     │
                   │  MaterialApp   │
                   └────────┬───────┘
                            │ home:
                   ┌────────▼───────┐
                   │   AuthGate     │────authStateChanges()───► FirebaseAuth
                   └────┬──────┬────┘
            User==null  │      │ User!=null
                   ┌────▼──┐  ┌▼──────────┐
                   │ Login │  │ _AdminCheck│──doc read─► users/{uid}
                   │Screen │  └──┬──────┬──┘
                   └───────┘     │      │
                     ok:role==   │      │ fail: signOut() → Denied screen
                   admin        │
                          ┌─────▼─────┐
                          │ Dashboard │─(optional)─► streamStats() → stats/global
                          │  Screen   │
                          └───────────┘
```

**Reads**:
- `users/{currentUser.uid}` — ONE-SHOT read per `_AdminCheck` mount.
- `stats/global` — STREAM, only when Overview placeholder chooses to use `streamStats()` (optional per R10).

**Writes**: NONE. Phase 6 ships zero admin write paths; every callable wrapper is an `UnimplementedError` stub.

---

## 9. Entity lifecycle

| Entity | Created at | Disposed at |
|--------|-----------|-------------|
| `AdminFirebaseService` instance | First use in a widget's `build()` or `initState()` | Never (no mutable state to clean up; Flutter GC handles it) |
| `AdminCloudFunctions` instance | First use | Never |
| `StreamSubscription` on `stats/global` | `StreamBuilder` creation (if Overview wires the smoke test) | Widget dispose via `StreamBuilder` internals |
| Firebase `User?` stream | `StreamBuilder<User?>` in `AuthGate` | Widget dispose via `StreamBuilder` internals |
| `TextEditingController` (email/password) | `_LoginScreenState` initState | `_LoginScreenState.dispose()` (MANDATORY) |
