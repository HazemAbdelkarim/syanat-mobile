# Contract: UI shells (`AuthGate`, `LoginScreen`, `DashboardScreen`)

**Files**:
- `.claude/AdminWebApp/lib/auth/auth_gate.dart`
- `.claude/AdminWebApp/lib/auth/login_screen.dart`
- `.claude/AdminWebApp/lib/dashboard/dashboard_screen.dart`

## 1. `AuthGate`

**Exports**: `class AuthGate extends StatelessWidget`.

**Builds** a `StreamBuilder<User?>` over `FirebaseAuth.instance.authStateChanges()`.

**Emission-by-emission behavior**:

| Snapshot state | Rendered widget |
|----------------|-----------------|
| `connectionState == waiting` | Centered `CircularProgressIndicator` (Scaffold with loader). |
| `data == null` | `const LoginScreen()`. |
| `data != null` | `_AdminCheck(user: data!)` — internal widget (private) that performs the role check. |

**`_AdminCheck` responsibilities**:

1. In `initState`, kick off `FirebaseFirestore.instance.doc('users/${widget.user.uid}').get()`.
2. While the `Future` is pending, render a centered `CircularProgressIndicator`.
3. When the Future completes:
   - **Doc exists AND `data['role'] == 'admin'`** → render `const DashboardScreen()`.
   - **Otherwise** → `await FirebaseAuth.instance.signOut()`, THEN `setState` to render a denied screen showing text "Access denied" and a "Try again" button that returns to `LoginScreen` (triggered by the `authStateChanges()` emission that `signOut()` causes).
4. Any exception during the role check MUST be treated as "deny" (fail-closed) — `signOut()` and show the denied screen.
5. Widget key: `ValueKey(widget.user.uid)` so changing users mounts a fresh `_AdminCheck`.

**Invariants (enforced by code review)**:

- `signOut()` call site MUST precede the `setState` that renders the denied screen. (Principle IX verbatim.)
- The role check MUST be a `.get()`, NOT a `.snapshots()`. A stream subscription outlives the widget and wastes reads.
- No `context.auth` equivalent is used here — we're on the client; we read the user's OWN doc as themselves.

---

## 2. `LoginScreen`

**Exports**: `class LoginScreen extends StatefulWidget`.

**Visual contract**:

- `Scaffold` with a centered form.
- Form wrapped in `ConstrainedBox(constraints: BoxConstraints(maxWidth: 400))`.
- Vertical order of elements:
  1. Heading text (e.g., "Syanat Admin").
  2. Email `TextFormField`.
  3. Password `TextFormField(obscureText: true)`.
  4. Inline error `Text` (only rendered when `_errorMessage != null`; red color).
  5. "Sign in" `ElevatedButton`.
  6. Divider or spacer.
  7. "Sign in with Google" `OutlinedButton` (or similar).

**State contract**:

```dart
bool _submitting = false;
String? _errorMessage;
final _emailCtrl = TextEditingController();
final _passwordCtrl = TextEditingController();
```

**Behavior contract**:

| Action | Button state | On success | On failure |
|--------|--------------|------------|------------|
| Tap "Sign in" (email+password) | Disabled + `CircularProgressIndicator` while in flight. | `authStateChanges()` fires, `AuthGate` takes over. | `setState(() { _errorMessage = e.message; _submitting = false; })` — no navigation. |
| Tap "Sign in with Google" | Same pattern. | Same. | Same — surface `e.message`, do not crash. |

**Error surface**: ONLY `FirebaseAuthException.message` string. No `toString()`, no stack trace, no JSON dump. Principle XIII.

**Disposal**: `_emailCtrl.dispose()` and `_passwordCtrl.dispose()` in `dispose()`. Mandatory.

---

## 3. `DashboardScreen`

**Exports**: `enum AdminSection { overview, jobs, payments, disputes, support, activity }` AND `class DashboardScreen extends StatefulWidget`.

**Visual contract**:

```text
┌──────────────────────────────────────────────────┐
│  Scaffold                                         │
│  ┌─────────┬──────┬──────────────────────────┐   │
│  │NavRail  │ V    │  IndexedStack              │   │
│  │(6 dest) │ Div  │  (active placeholder)      │   │
│  │         │ t=1  │                            │   │
│  └─────────┴──────┴──────────────────────────┘   │
└──────────────────────────────────────────────────┘
```

**`NavigationRail` configuration**:

- `labelType: NavigationRailLabelType.all` (always show labels).
- `selectedIndex: _selectedIndex` (owned by `_DashboardScreenState`).
- `onDestinationSelected: (i) => setState(() => _selectedIndex = i)`.
- `destinations` — EXACTLY six, in this order:

| Index | `AdminSection` | Icon | Label |
|-------|----------------|------|-------|
| 0 | `overview` | `Icons.dashboard` | "Overview" |
| 1 | `jobs` | `Icons.work_outline` | "Jobs" |
| 2 | `payments` | `Icons.payments_outlined` | "Payments" |
| 3 | `disputes` | `Icons.gavel` | "Disputes" |
| 4 | `support` | `Icons.support_agent` | "Support" |
| 5 | `activity` | `Icons.history` | "Activity" |

**Content area**:

- `Expanded(child: IndexedStack(index: _selectedIndex, children: [...6 placeholder widgets...]))`.
- Placeholder widgets are `const` to avoid rebuild cost and may be simple private widgets that render `Center(child: Text('<SectionName> — coming soon'))`.
- The Overview placeholder MAY optionally wrap its text in a `StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>` over `AdminFirebaseService().streamStats()` as a smoke test (not required — see research.md R10).

**Overflow contract (SC-008, FR-025)**:

- At a 1280×800 viewport, no horizontal scrolling and no yellow-and-black overflow stripes in debug mode.
- If an overflow ever appears, the fix is `labelType: NavigationRailLabelType.selected` (narrower rail) — not introducing a horizontal scroll.

---

## 4. Smoke tests (developer-facing, not CI — CI is `analyze + build`)

Operator checklist after the first preview-channel deploy:

1. **Unauthed entry**: Incognito window → open preview URL → expect `LoginScreen`.
2. **Bad creds**: Submit wrong password → inline red text shows; no navigation; `FirebaseAuth.instance.currentUser` still `null`.
3. **Admin sign-in**: Submit admin creds → `DashboardScreen` appears within 30 s.
4. **Non-admin sign-in**: Submit customer creds → "Access denied" screen, AND `FirebaseAuth.instance.currentUser` returns `null` immediately after (checked in browser devtools console).
5. **Nav switching**: Click each of six destinations → content placeholder swaps; no console errors; no layout overflow at 1280×800.
6. **Refresh while signed in**: F5 on dashboard → auth persists, dashboard re-renders (selected index may reset to 0 — that's allowed per US3 AS5).
7. **Token revocation**: Disable the admin account in Firebase Console → within ~1 minute, `authStateChanges()` emits `null`, `LoginScreen` reappears.

All seven MUST pass before Task 6-1 is marked done.
