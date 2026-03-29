# Spec 002 — Auth & Signup Redesign + Order Freeze Bug Fix

**Version:** 1.0
**Date:** 2026-03-29
**Target agent:** Codex
**Status:** Ready for implementation

---

## 1. Feature Overview

This spec covers seven related changes to the Syanat Flutter + Firebase app:

| # | Feature | Files primarily affected |
|---|---------|--------------------------|
| F1 | Login page — social sign-in UI redesign | `lib/login_screen.dart` |
| F2 | Login page — Create Account button redesign | `lib/login_screen.dart` |
| F3 | Role-selection popup/modal (new screen or dialog) | new file `lib/role_selection_screen.dart` |
| F4 | Customer multi-step signup flow | new file `lib/customer_signup_flow.dart` |
| F5 | Technician multi-step signup flow | new file `lib/technician_signup_flow.dart` |
| F6 | In-app inline error handling across all auth/signup screens | all above files |
| F7 | Normal order freeze / loading-state bug fix | `lib/service_details_screen.dart` |

The existing `lib/create_account_screen.dart` is fully **replaced** by F3 + F4 + F5. The old file is deleted once the new flows are wired up and verified correct.

---

## 2. Goals

- Make the login page visually lighter and more premium by repositioning social sign-in as the primary entry path.
- Ensure new Google/Apple accounts go through a polished, non-bypassable role-selection and data-collection flow before being considered "onboarded".
- Replace the current monolithic create-account form with two separate, step-by-step premium flows (customer and technician).
- Add a selfie capture step to the technician flow (gallery or camera).
- Replace all snackbar-only validation with inline, context-aware in-app errors.
- Fix the order submission screen freezing in a loading state after the order is already successfully created in Firestore.

---

## 3. Non-Goals

- Do not redesign `UserHomeScreen`, `TechHomeScreen`, or `AdminDashboardScreen`.
- Do not change any Firebase Security Rules (`firestore.rules`).
- Do not change `firestore.indexes.json`.
- Do not add new Firestore collections or change existing document schemas beyond what is already in the codebase.
- Do not add new Flutter packages unless `image_picker` (already in project) is insufficient for the selfie step — the project already includes `image_picker`, `geolocator`, `firebase_storage`, `flutter_image_compress`. Use those.
- Do not add phone-number OTP verification — the existing phone field + Egyptian format validation is sufficient.
- Do not change `firebase_service.dart` logic for `createUser`, `createTechnician`, `isProfileComplete`, `signInWithGoogle`, or `signInWithApple`. Reuse them as-is.
- Do not add analytics events or FCM push changes.
- Do not change the `_OrderRequestSheet` business logic, Firestore writes, or timeout values — only fix the loading-state reset bug.
- Do not create README files, doc files, or test files.

---

## 4. Existing Constraints to Preserve

### 4.1 Design system
The app uses a strict visual system. Every new widget must follow it exactly:

| Token | Value |
|-------|-------|
| Primary blue | `Color(0xFF3C21C8)` — referred to as `syanatBlue` |
| Background (screens) | `Color(0xFFF7F7FB)` or `syanatBlue` full-bleed for auth screens |
| Card background | `Colors.white` |
| Card border radius | 14–24 dp (login card: 24, create-account card: 30, sub-cards: 14) |
| Card shadow | `BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 3))` |
| Button height (primary) | 52 dp |
| Button border radius | 14 dp |
| Field background | `Colors.grey.shade100` with `Colors.grey.shade300` border, radius 15 |
| Field prefix icon color | `Colors.black54` |
| Text — heading | `fontSize: 26–32, fontWeight: FontWeight.bold, color: Colors.black` |
| Text — label | `fontSize: 13, color: Colors.black54` |
| Social button style | `OutlinedButton` with `Colors.grey.shade300` border, white bg, radius 14 |
| Divider style | `Divider(color: Colors.grey.shade300)` with label in grey.shade500 |
| Progress indicator color | `syanatBlue` |
| `Directionality` | Always wrap in `Directionality` using `isEn ? TextDirection.ltr : TextDirection.rtl` |

### 4.2 Localization
- Language is stored in `AppLocale.of(context).value` (a `ValueNotifier<Locale>`).
- All screens must check `Localizations.localeOf(context).languageCode == 'en'` for `isEn`.
- Every user-visible string needs both English and Arabic.
- Default language is English.
- Language toggle button (`Icons.language, color: Colors.white`) must appear in the top bar of every auth screen.

### 4.3 Architecture
- `FirebaseService` is the single point of all Firebase access. Do not call `FirebaseFirestore.instance` or `FirebaseAuth.instance` directly from UI screens — route through `FirebaseService`.
- Routing is `Navigator.pushReplacement` for post-auth transitions; `Navigator.push` for forward navigation within a flow; `Navigator.pop` for back.
- State management: `StatefulWidget` + `setState` only. No providers, blocs, or streams in new UI.

### 4.4 Security
- `isProfileComplete` (phone + role + username all non-empty) is the gate. A user is never routed to the home screen if their profile is incomplete.
- `_routeByRole` in `LoginScreen` handles final routing by role. Do not duplicate this logic.

### 4.5 Firebase cost
- No new real-time listeners during signup or auth.
- No polling loops.
- One profile read (`getProfile`) after sign-in to determine routing — this already exists in `_handleSocialSignIn`. Do not add a second read.
- Firestore writes during signup must remain idempotent (the existing `createUser` transaction already handles this — do not bypass it).

---

## 5. Functional Requirements

### F1 — Social sign-in box redesign (Login page)

**Current state:** Google and Apple are rendered as full-width `OutlinedButton` rows stacked vertically below a divider, below the Create Account button.

**Required new state:**
- Remove the existing full-width Google button and full-width Apple button.
- Add a **divider row** ("or sign in with" / "أو سجّل الدخول عبر") **above the email/password block** — placed between the page title and the email field.
  - Actually — re-read the layout goal: the social buttons are **compact square/rounded boxes** side by side, placed **above** the email/password section (right below the "Login" heading).
  - This puts social sign-in first in visual hierarchy.
- Replace them with **two compact icon boxes** displayed in a `Row` with equal width, side by side, centered:
  - Left box: Google — shows the branded "G" icon (reuse existing `_googleIcon()` helper, scaled to 28 dp)
  - Right box: Apple — shows `Icons.apple` (size 28, color `Colors.black87`)
  - Apple box: show only when `showApple` is true (the existing `!kIsWeb && (Platform.isIOS || Platform.isMacOS)` logic). When `showApple` is false, the Google box is shown alone, centered, without the Apple slot.
- Each box:
  - Height: 56 dp
  - Width: fills its half of the row (use `Expanded`)
  - Background: `Colors.white`
  - Border: `Border.all(color: Colors.grey.shade300, width: 1.5)`
  - Border radius: `BorderRadius.circular(16)`
  - Shadow: same card shadow as above
  - Icon centered inside
  - Tap behavior: same `_handleSocialSignIn(FirebaseService.signInWithGoogle)` / `_handleSocialSignIn(FirebaseService.signInWithApple)` calls — no change to logic
  - Loading state: when `_socialLoading` is true, replace icon with a `SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: syanatBlue))`
  - Both boxes disable tap when `_socialLoading || _loading`

**Layout order inside the white auth card (top to bottom):**
1. "Login" / "تسجيل الدخول" heading
2. Horizontal divider row: `— or sign in with —` / `— أو سجّل الدخول عبر —`
3. Social icon boxes row (Google + Apple)
4. Spacer `SizedBox(height: 20)`
5. Email field
6. Password field
7. Login button (full width, syanatBlue, existing style)
8. "Create Account" link (see F2 below)

### F2 — Create Account button redesign

**Current state:** Full-width `OutlinedButton` with `height: 48`, blue border, below the Login button.

**Required new state:**
- Remove the current full-width Create Account button.
- Add a compact text-link style button at the **bottom of the card**, below the Login button and below the social boxes section.
- Style:
  - `TextButton` (no outline, no fill)
  - Label: `"Don't have an account? Create one"` / `"ليس لديك حساب؟ أنشئ واحداً"`
  - Font: `fontSize: 14, fontWeight: FontWeight.w600, color: syanatBlue`
  - No minimum size constraints — let it size to content
  - Centered
- Tap behavior: navigates to the role-selection screen (F3) — NOT directly to `CreateAccountScreen`
  - Use `Navigator.push(context, MaterialPageRoute(builder: (_) => const RoleSelectionScreen()))`

### F3 — Role selection screen

**Trigger points (all three must work):**
1. User taps "Create Account" link on login page (F2)
2. `_handleSocialSignIn` returns a new/incomplete user (currently routes to `CreateAccountScreen`) — instead route to `RoleSelectionScreen`, passing `prefillUid`, `prefillEmail`, `prefillName`
3. *(No change to existing-user social sign-in: complete profiles still route via `_routeByRole` as now)*

**New file:** `lib/role_selection_screen.dart`

**Constructor:**
```
RoleSelectionScreen({
  String? prefillUid,
  String prefillEmail = '',
  String prefillName = '',
})
```

**UX behavior:**
- Full screen (not a dialog or bottom sheet — this is a navigation destination).
- Background: `syanatBlue` full-bleed (matching the existing auth screen background).
- Top bar: back arrow (white) on the left, language toggle (white) on the right.
- Centered white card (same card style as other auth screens, `BorderRadius.circular(24)`, padding 28).
- Card content:
  - Heading: `"Who are you?"` / `"من أنت؟"` — `fontSize: 26, fontWeight: FontWeight.bold`
  - Subheading: `"Choose your account type to get started"` / `"اختر نوع حسابك للبدء"` — `fontSize: 14, color: Colors.black54`
  - `SizedBox(height: 32)`
  - Two vertical choice cards (full width, stacked), each:
    - Height: 80 dp
    - Background: `Colors.white`
    - Border: `Border.all(color: Colors.grey.shade200)` when not selected
    - Border: `Border.all(color: syanatBlue, width: 2)` when selected (use `_selected` state variable)
    - Border radius: `BorderRadius.circular(16)`
    - Shadow: standard card shadow
    - Left side: icon in a rounded container with `syanatBlue.withOpacity(0.1)` bg
      - Customer card: `Icons.person` icon
      - Technician card: `Icons.build` icon
    - Right side: title + subtitle
      - Customer: title `"Customer"` / `"عميل"`, subtitle `"Book services at home"` / `"احجز خدمات في المنزل"`
      - Technician: title `"Potential Technician"` / `"فني محتمل"`, subtitle `"Join our network of professionals"` / `"انضم إلى شبكة المحترفين"`
    - Tap: sets `_selectedRole` state variable to `'customer'` or `'technician'`
  - `SizedBox(height: 28)`
  - "Continue" / "متابعة" button — full width, height 52, syanatBlue style (existing ElevatedButton style from the codebase)
    - Disabled (grey) when `_selectedRole == null`
    - On tap: navigates to the appropriate flow based on `_selectedRole`:
      - `'customer'` → `CustomerSignupFlow(prefillUid: ..., prefillEmail: ..., prefillName: ...)`
      - `'technician'` → `TechnicianSignupFlow(prefillUid: ..., prefillEmail: ..., prefillName: ...)`
      - Use `Navigator.push` (not `pushReplacement`) so the user can go back to change their role

**State:** `String? _selectedRole = null;`

### F4 — Customer multi-step signup flow

**New file:** `lib/customer_signup_flow.dart`

**Constructor:**
```
CustomerSignupFlow({
  String? prefillUid,
  String prefillEmail = '',
  String prefillName = '',
})
```

**Before writing any step, Codex must read `lib/create_account_screen.dart` and `lib/firebase_service.dart` (specifically `createUser` and `isProfileComplete`) to identify every field required for a valid customer profile.** Based on current codebase the required customer fields are: `username`, `phone`, `city`, `email` (skip for social mode), `password` (skip for social mode), `role = 'customer'`. Use exactly these fields — do not add or remove.

**Step layout:**
- 2 fields per step, then a "Next" button.
- Final step shows "Create Account" / "إنشاء الحساب" button instead of "Next".
- Progress indicator at the top: a `LinearProgressIndicator` (color: syanatBlue, background: `syanatBlue.withOpacity(0.15)`) showing `currentStep / totalSteps` progress. Updates as user moves forward.
- Step counter text: `"Step X of Y"` / `"الخطوة X من Y"` — small, grey, centered below the progress bar.

**Steps for non-social mode (prefillUid == null):**

| Step | Field 1 | Field 2 |
|------|---------|---------|
| 1 | Full Name (`username`) | Phone Number (`phone`) |
| 2 | City (`city`) | Email (`email`) |
| 3 | Password (`password`) | *(Confirm Password — validated locally, not stored)* |

**Steps for social mode (prefillUid != null):**

| Step | Field 1 | Field 2 |
|------|---------|---------|
| 1 | Full Name (`username`, pre-filled from `prefillName`) | Phone Number (`phone`) |
| 2 | City (`city`) | *(step is complete with just city — Next is active after city is entered)* |

For the social 2-field constraint: Step 2 has only one required field (city). The second slot on Step 2 displays a read-only pre-filled email chip/tag, styled as a disabled field (grey background, padlock icon), not an editable TextField. This satisfies the "2 items per screen" visual layout without asking for redundant data.

**Screen structure:**
- Background: `syanatBlue`
- Top bar: back arrow (pops to role selection), language toggle, step counter
- Centered white card filling most of the screen
- Inside card: step heading, 2 field widgets, Next/Submit button
- Each field uses the existing `_buildModernTextField` styling (grey bg, radius 15, prefix icon)

**Validation per step (must block "Next" if invalid):**
- Step 1 — username: non-empty, trimmed, min 2 chars, max 60 chars, no leading/trailing spaces after trim. Phone: matches `^\+201[0125]\d{8}$` — show inline error if invalid.
- Step 2 (non-social) — city: non-empty, trimmed, min 2 chars. Email: valid email format using `RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')`.
- Step 2 (social) — city: non-empty, trimmed, min 2 chars.
- Step 3 (non-social only) — password: min 8 chars. Confirm password: must equal password.

**Error display (inline — NOT snackbars):**
- Each field gets a `String? _fieldError` variable.
- On "Next" tap, validate. If invalid, set `_fieldError` and show a red error container **below the field** inside the card:
  ```
  Container(
    margin: EdgeInsets.only(top: 6),
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Color(0xFFFFEBEB),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.red.shade300),
    ),
    child: Row(children: [
      Icon(Icons.error_outline, color: Colors.red, size: 16),
      SizedBox(width: 8),
      Expanded(child: Text(errorMessage, style: TextStyle(color: Colors.red.shade800, fontSize: 13))),
    ]),
  )
  ```
- The field border also turns red when its error is set: `Border.all(color: Colors.red.shade400)` — toggle via state.
- Clear the error when the user starts typing in that field.

**Submission (final step):**
- Same `_isLoading` guard as existing code.
- Calls `FirebaseService.createUser(...)` or creates Firebase Auth account then calls `createUser` — exact same logic as current `_signup()` in `CreateAccountScreen`, just split across steps.
- On success: `Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserHomeScreen()))`.
- On error: show an error container at the top of the card (above all fields), same red style, with the Firebase error message. Do NOT show a snackbar for submission errors.

**Progress preservation:**
- All controller values must survive step transitions within the same `State`. Use one `StatefulWidget` with a `_currentStep` int and `PageView` or manual widget-swap (prefer `AnimatedSwitcher` with a slide transition — `SlideTransition` using the existing `AnimationController` pattern from the codebase).
- Do NOT push a new route for each step — stay in the same screen.

### F5 — Technician multi-step signup flow

**New file:** `lib/technician_signup_flow.dart`

**Constructor:**
```
TechnicianSignupFlow({
  String? prefillUid,
  String prefillEmail = '',
  String prefillName = '',
})
```

**Before writing steps, Codex must read `lib/create_account_screen.dart` and `lib/firebase_service.dart` (`createTechnician`) to identify every required technician field.** Current required fields: `username`, `phone`, `city`, `service` (selected from `technicianServices` list), `email` (skip social), `password` (skip social), `photoUrl` (selfie, optional but recommended — upload to `techProfiles` folder). Location (`GeoPoint`) is fetched via `_getLocation()` at submission time. Preserve all of this.

**Copy the `technicianServices` list and `arabicToServiceKey` map verbatim from `create_account_screen.dart`** — do not re-invent.

**Steps for non-social mode:**

| Step | Field 1 | Field 2 |
|------|---------|---------|
| 1 | Full Name (`username`) | Phone Number (`phone`) |
| 2 | City (`city`) | Email (`email`) |
| 3 | Password (`password`) | Confirm Password |
| 4 | Service specialty (`service` dropdown) | *(single item: service dropdown takes full width of the step; second slot shows helper text: "Your specialty determines which jobs you receive" / "تخصصك يحدد الوظائف التي تصلك")* |
| 5 | Selfie / profile photo | *(step is complete after photo is selected or skipped)* |

**Steps for social mode:**

| Step | Field 1 | Field 2 |
|------|---------|---------|
| 1 | Full Name (pre-filled) | Phone |
| 2 | City | Read-only email chip |
| 3 | Service specialty | Helper text |
| 4 | Selfie / profile photo | *(skip button available)* |

**Selfie step (final step in both modes):**
- Screen heading: `"Add a Profile Photo"` / `"أضف صورة شخصية"`
- Subheading: `"Help customers recognize you. You can add a photo now or skip."` / `"ساعد العملاء على التعرف عليك. يمكنك إضافة صورة الآن أو التخطي."`
- Large centered `CircleAvatar` (radius 60), showing preview if photo selected, else a grey placeholder with `Icons.person` icon.
- Two buttons below the avatar, side by side:
  - "Camera" / "الكاميرا" — `Icons.camera_alt` — calls `ImagePicker().pickImage(source: ImageSource.camera)`
  - "Gallery" / "المعرض" — `Icons.photo_library` — calls `ImagePicker().pickImage(source: ImageSource.gallery)`
  - Both styled as outlined buttons with syanatBlue border, syanatBlue icon and text
- "Skip" / "تخطي" as a `TextButton` below both buttons — grey text — skips photo (sets `_profileImage = null`)
- "Submit" / "إرسال" button — full width, syanatBlue — active even if photo is skipped
- Photo is uploaded via `FirebaseService.uploadPhoto(_profileImage!, folder: 'techProfiles')` — same as existing code — only if `_profileImage != null`
- Validation: no field validation on this step. Photo is always optional.

**Submission:**
- Calls `_getLocation()` first if not already called (same pattern as existing `_signup()`)
- Then calls `FirebaseService.createTechnician(...)` — same parameters as current code
- Then updates location GeoPoint if available — same as current code
- On success: `Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TechHomeScreen()))`
- On error: red inline error container at top of the final step card, same style as F4

**Pending/review state:**
- After the technician account is created, the app routes to `TechHomeScreen` as before. The existing `TechHomeScreen` already handles any `pending` / `available: false` display logic — do not change it.

**Validation per step:**
- Steps 1–3: same rules as F4 (username, phone regex, city min 2 chars, email regex, password min 8, confirm match)
- Step 4 (service): dropdown must have a non-null value selected before Next is active. Inline error: "Please select your service specialty" / "يرجى اختيار تخصصك"

**Inline error display:** identical pattern to F4.

### F6 — Inline error handling (applies to all new auth/signup screens)

This requirement applies to F3, F4, F5 and to the existing `LoginScreen`.

**For `LoginScreen`:**
- The existing `_login()` error uses `ScaffoldMessenger.showSnackBar`. Change it to show an inline error container **inside the white card, above the Login button**.
- Use the same red container pattern defined in F4.
- Store error in a `String? _loginError` state variable. Clear it when the user starts typing in either field.
- Do NOT show a snackbar for login errors anymore.
- Keep the snackbar for `_handleSocialSignIn` errors — those are acceptable since social sign-in returns to the same screen automatically.

**Rules for all new signup screens:**
- Every field-level validation error must appear inline, immediately below the relevant field, using the red container pattern.
- Every submission-level error (Firebase error, network error) must appear in a red container at the top of the active step's card content — not as a snackbar.
- Snackbars are only acceptable for transient success confirmations (e.g., "Order submitted!") — not for errors in auth/signup flows.
- Fields with errors get a red border. Fields without errors get the standard `Colors.grey.shade300` border.
- Errors clear on user input (via `onChanged` handler on the `TextEditingController`).
- RTL layout of error icons and text must be correct in Arabic: the icon leads (left side in LTR, right side in RTL), text follows.

### F7 — Order freeze / loading-state bug fix

**File:** `lib/service_details_screen.dart` — class `_OrderRequestSheetState`

**Observed symptom:** After tapping Submit in `_OrderRequestSheet`, the UI shows a loading state (spinner replaces the Submit button, or button is disabled). The Firestore write completes successfully (the order appears in the admin dashboard), but the sheet never closes and the spinner never stops. The user sees a frozen/hung screen.

**Root cause to investigate and fix:**

Codex must read the full `_submit()` method (lines ~838–927) before writing any fix. The method currently:
1. Sets `_submitting = true` and `_submitted = true`
2. Calls `FirebaseService.createOrderRequest(...)` with a `.timeout(const Duration(seconds: 15))`
3. Calls `FirebaseService.notifyAvailableTechnicians(...)` as fire-and-forget
4. On success: calls `Navigator.pop(context)` then shows a `SnackBar`
5. On error: resets `_submitted = false`
6. In `finally`: sets `_submitting = false`

**Likely causes (Codex must verify each against the code before picking a fix):**

- **Cause A:** `Navigator.pop(context)` is called on the sheet's `BuildContext` (`context`) after the sheet is already dismissed or before the widget is fully mounted, causing the `finally` block to never execute or the snackbar context to be stale.
- **Cause B:** The `notifyAvailableTechnicians` call (fire-and-forget, unawaited) throws synchronously before the `Navigator.pop`, preventing the pop from being reached. The `unawaited` call should be inside a `try/catch` or after the pop.
- **Cause C:** The `mounted` check at line `if (!mounted) return;` (after the await) exits the function before `Navigator.pop`, and the `finally` block sets `_submitting = false` but the sheet is never closed — leaving the user on a frozen sheet with a re-enabled button.
- **Cause D:** The `DraggableScrollableSheet` captures the context, and `Navigator.pop(context)` in this case closes the wrong route.

**Required fix approach:**
1. Codex must trace the exact control flow and confirm which cause applies.
2. The fix must ensure:
   - After a successful `createOrderRequest`, the sheet always closes (`Navigator.pop`)
   - `_submitting` is always reset to `false` in `finally`
   - The snackbar fires on the **parent** `BuildContext` (the `ServiceDetailsScreen`), not the sheet's context — because after `Navigator.pop` the sheet's context is disposed
   - The fire-and-forget `notifyAvailableTechnicians` call is wrapped so that any synchronous exception it throws cannot block the pop
3. The fix must NOT:
   - Add new network calls or retries
   - Change `createOrderRequest` logic
   - Add polling or stream listeners
   - Create duplicate job documents

**Specific implementation pattern to use:**
```dart
// After await createOrderRequest(...) succeeds:
// 1. Fire-and-forget the notification (safe, exceptions swallowed)
try {
  FirebaseService.notifyAvailableTechnicians(...);
} catch (_) {}

// 2. Pop the sheet FIRST
if (mounted) Navigator.pop(context);

// 3. Show the snackbar using the OUTER context passed in as a parameter,
//    OR use a callback/result pattern from the showModalBottomSheet call.
//    Do NOT call ScaffoldMessenger.of(context) after Navigator.pop on the sheet's own context.
```

The cleanest fix: change `_OrderRequestSheet` to return a result (a boolean or a success message string) via `Navigator.pop(context, resultValue)`, and have the `showModalBottomSheet` caller (in `_showOrderRequestSheet` / `_showQuickOrderSheet`) handle the snackbar on its own context after the sheet returns. This is a safe, pattern-consistent approach.

---

## 6. UX / UI Requirements

### 6.1 Premium feel checklist
Every new screen and widget must satisfy:
- [ ] Rounded corners everywhere — no hard rectangles
- [ ] Subtle shadows on all cards and interactive containers
- [ ] Smooth transitions between steps (use `AnimatedSwitcher` with `FadeTransition` or `SlideTransition` — 300ms duration)
- [ ] Loading states replace interactive elements (not layered on top) — spinner replaces button label
- [ ] Disabled states visually distinct (grey tint, reduced opacity 0.5)
- [ ] Field focus state: when a field is focused, its border becomes `Colors.blue.shade300` (or `syanatBlue.withOpacity(0.6)`) — use `FocusNode` listeners or `TextField`'s own focus handling
- [ ] Error state: field border turns red, error container fades in below
- [ ] Icons in fields use the `syanatBlue.withOpacity(0.1)` background rounded container for visual weight (matching the existing `technician_active_job_screen.dart` and `technician_payment_screen.dart` field card style)
- [ ] All touch targets minimum 48×48 dp
- [ ] Keyboard behavior: `TextInputAction.next` on all fields except the last in a step (use `TextInputAction.done` on last field)
- [ ] `ScrollView` wrapping content in all steps to avoid overflow on small devices

### 6.2 Step transition animation
Inside the multi-step flows (F4, F5), when the user taps "Next":
- The current step content slides out to the left (LTR) / right (RTL)
- The new step content slides in from the right (LTR) / left (RTL)
- Duration: 300ms, `Curves.easeInOut`
- Use `AnimatedSwitcher` with a custom `transitionBuilder` using `SlideTransition` + `FadeTransition`

### 6.3 Role selection card interaction
In `RoleSelectionScreen`:
- When a card is tapped, it immediately highlights (border changes, slight scale animation `0.97` using `AnimatedContainer` or `GestureDetector` + `Transform.scale`)
- The Continue button becomes active (transitions from grey to syanatBlue over 200ms using `AnimatedContainer`)

### 6.4 Social box loading state
When `_socialLoading` is true on the login page:
- Both social boxes become disabled (opacity 0.5)
- The tapped box shows a spinner instead of its icon
- Track which box was tapped with a `String? _socialLoadingProvider` variable (`'google'` or `'apple'`) to show the spinner only in the correct box

---

## 7. Localization Requirements

Every new string must have both English and Arabic. The complete list:

### RoleSelectionScreen
| Key | English | Arabic |
|-----|---------|--------|
| heading | Who are you? | من أنت؟ |
| subheading | Choose your account type to get started | اختر نوع حسابك للبدء |
| customer_title | Customer | عميل |
| customer_subtitle | Book services at home | احجز خدمات في المنزل |
| technician_title | Potential Technician | فني محتمل |
| technician_subtitle | Join our network of professionals | انضم إلى شبكة المحترفين |
| continue_btn | Continue | متابعة |

### CustomerSignupFlow
| Key | English | Arabic |
|-----|---------|--------|
| screen_title | Create Your Account | إنشاء حسابك |
| step_counter | Step %d of %d | الخطوة %d من %d |
| field_name | Full Name | الاسم الكامل |
| field_phone | Phone Number | رقم الهاتف |
| field_city | City | المدينة |
| field_email | Email | البريد الإلكتروني |
| field_password | Password | كلمة المرور |
| field_confirm | Confirm Password | تأكيد كلمة المرور |
| next_btn | Next | التالي |
| submit_btn | Create Account | إنشاء الحساب |
| err_name_empty | Please enter your full name | يرجى إدخال اسمك الكامل |
| err_name_short | Name must be at least 2 characters | يجب أن يكون الاسم حرفين على الأقل |
| err_phone_invalid | Invalid phone. Use format: +201XXXXXXXXX | رقم الهاتف غير صحيح. استخدم: +201XXXXXXXXX |
| err_city_empty | Please enter your city | يرجى إدخال مدينتك |
| err_email_invalid | Please enter a valid email address | يرجى إدخال بريد إلكتروني صحيح |
| err_password_short | Password must be at least 8 characters | يجب أن تكون كلمة المرور 8 أحرف على الأقل |
| err_password_mismatch | Passwords do not match | كلمتا المرور غير متطابقتين |

### TechnicianSignupFlow
All the same strings as CustomerSignupFlow, plus:
| Key | English | Arabic |
|-----|---------|--------|
| screen_title | Join as a Technician | انضم كفني |
| field_service | Service Specialty | التخصص |
| service_hint | Select your specialty | اختر تخصصك |
| service_helper | Your specialty determines which jobs you receive | تخصصك يحدد الوظائف التي تصلك |
| selfie_heading | Add a Profile Photo | أضف صورة شخصية |
| selfie_subheading | Help customers recognize you | ساعد العملاء على التعرف عليك |
| btn_camera | Camera | الكاميرا |
| btn_gallery | Gallery | المعرض |
| btn_skip | Skip | تخطي |
| btn_submit | Submit Application | إرسال الطلب |
| err_service_empty | Please select your service specialty | يرجى اختيار تخصصك |

### LoginScreen additions
| Key | English | Arabic |
|-----|---------|--------|
| social_divider | or sign in with | أو سجّل الدخول عبر |
| create_account_link | Don't have an account? Create one | ليس لديك حساب؟ أنشئ واحداً |
| err_login_failed | Login failed. Check your email and password. | فشل تسجيل الدخول. تحقق من البريد وكلمة المرور. |

---

## 8. Validation and Sanitization Requirements

All input must be sanitized before use. Apply these rules at the field level — on the "Next"/"Submit" tap, before any Firebase call.

| Field | Sanitization | Validation rule | Error shown when |
|-------|-------------|-----------------|-----------------|
| username | `.trim()` | non-empty, 2–60 chars | empty or too short/long |
| phone | `.trim()` | matches `^\+201[0125]\d{8}$` | pattern mismatch |
| city | `.trim()` | non-empty, 2–80 chars | empty or too short |
| email | `.trim().toLowerCase()` | matches `^[^@\s]+@[^@\s]+\.[^@\s]+$` | pattern mismatch |
| password | no trim (intentional) | min 8 chars | length < 8 |
| confirm password | no trim | must equal `password` exactly | mismatch |
| service | — | non-null DropdownMenuItem selected | null |
| description (order) | `.trim()` | non-empty | empty |
| phone (order) | `.trim()` | non-empty (existing rule) | empty |

**Additional sanitization rules:**
- All string fields stored to Firestore must be `.trim()`-ed before the `createUser`/`createTechnician` call.
- Email must be `.toLowerCase()` before being passed to `createUserWithEmailAndPassword` and to `createUser`.
- Passwords are never stored — only passed to Firebase Auth, never written to Firestore.
- Photo: no validation required — photo upload failures must be caught and surfaced as a non-blocking warning (the account can still be created without a photo). If photo upload fails, set `photoUrl = ''` and proceed.

---

## 9. Firebase / Auth / Data Requirements

### 9.1 Social sign-in routing change
In `LoginScreen._handleSocialSignIn`, change the `else` branch (incomplete profile) from:
```dart
Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (_) => CreateAccountScreen(
      prefillUid: user.uid,
      prefillEmail: user.email ?? '',
      prefillName: user.displayName ?? '',
    ),
  ),
);
```
to:
```dart
Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (_) => RoleSelectionScreen(
      prefillUid: user.uid,
      prefillEmail: user.email ?? '',
      prefillName: user.displayName ?? '',
    ),
  ),
);
```

### 9.2 Profile completeness gate
`FirebaseService.isProfileComplete` (phone + role + username) remains unchanged as the routing gate. After signup through any new flow, the user must have all three fields written before being routed to a home screen.

### 9.3 Idempotency
The `createUser` and `createTechnician` methods already handle idempotency (transaction checks doc existence). New flows must call these methods exactly as the existing `_signup()` method does — no direct `firestore.collection('users').doc(uid).set(...)` calls from UI code.

### 9.4 Photo upload
- Reuse `FirebaseService.uploadPhoto(xfile, folder: 'techProfiles')` unchanged.
- Wrap in `try/catch` — if it fails, log the error (print in debug) and continue with `photoUrl = ''`.
- Do not block account creation on photo upload failure.

### 9.5 Location fetch
- Reuse `FirebaseService`-adjacent `_getLocation()` pattern (Geolocator, same as current code) — move the location-fetch helper into `TechnicianSignupFlow` verbatim.
- Call it just before submission, same as existing code.

### 9.6 No new Firestore collections
Do not create any new collections. The new flows write to the same `users` collection via the existing service methods.

### 9.7 Firebase setup steps required by the developer (YOU must do these)

**Codex cannot perform these steps. The developer must complete them manually.**

1. **Google Sign-In for Android:**
   - In the Firebase Console → Project Settings → Your Apps → Android app → download the latest `google-services.json`.
   - Ensure the SHA-1 and SHA-256 fingerprints for your debug and release keystores are added in Project Settings → Your Apps → Android.
   - In Firebase Console → Authentication → Sign-in method → Google: must be Enabled with a valid support email set.

2. **Google Sign-In for iOS:**
   - In Firebase Console → Project Settings → Your Apps → iOS app → download the latest `GoogleService-Info.plist`.
   - In Xcode: add `REVERSED_CLIENT_ID` from `GoogleService-Info.plist` as a URL scheme in `Info.plist` under `CFBundleURLTypes`.
   - In Firebase Console → Authentication → Sign-in method → Google: must be Enabled.

3. **Apple Sign-In (iOS/macOS only):**
   - In Apple Developer Console: enable "Sign in with Apple" capability for the App ID.
   - In Xcode: add "Sign in with Apple" entitlement.
   - In Firebase Console → Authentication → Sign-in method → Apple: must be Enabled. Configure the Apple Service ID, team ID, key ID, and private key if using web flows (not required for pure-native iOS but must be enabled).

4. **Firebase Storage rules for `techProfiles/`:**
   - The existing `storage.rules` must allow authenticated users to write to `techProfiles/{filename}` (used by `FirebaseService.uploadPhoto`). Verify your Storage rules include something like:
     ```
     match /techProfiles/{file} {
       allow read: if true;
       allow write: if request.auth != null;
     }
     ```
   - If this rule is not present, selfie uploads will fail silently (the app handles this gracefully with `photoUrl = ''`, but photos will not be stored).

5. **App Check:**
   - The project already initializes App Check in `FirebaseService.initialize()`. Ensure that:
     - For Android: Play Integrity API is enabled in the Google Play Console for your app.
     - For iOS: App Attest is enabled in the Apple Developer Console.
     - For debug builds: the debug token printed in the console must be registered in Firebase Console → App Check → Apps → Manage debug tokens.
   - Without correct App Check configuration, all Firebase calls from the app will be blocked in production.

6. **`image_picker` permissions:**
   - Android: add the following to `AndroidManifest.xml` if not already present:
     ```xml
     <uses-permission android:name="android.permission.CAMERA"/>
     <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
     ```
   - iOS: add to `ios/Runner/Info.plist` if not already present:
     ```xml
     <key>NSCameraUsageDescription</key>
     <string>We need camera access to take your profile photo.</string>
     <key>NSPhotoLibraryUsageDescription</key>
     <string>We need photo library access to choose your profile photo.</string>
     ```

---

## 10. Security Requirements

- All new screens must require a signed-in Firebase Auth session to write to Firestore. The existing Firestore rules enforce this server-side. No client-side bypass is acceptable.
- The role field written to Firestore must come from the `RoleSelectionScreen` UI choice — it must not be inferred from any external source or URL parameter.
- A role of `'admin'` must never be a selectable option in the role selection screen. Only `'customer'` and `'technician'` are valid choices.
- Email must be lowercased before passing to Firebase Auth to avoid case-sensitivity issues with duplicate accounts.
- Passwords are never logged, printed, or stored anywhere except passed directly to `FirebaseAuth.instance.createUserWithEmailAndPassword`.
- Photo file paths are never stored in Firestore. Only the download URL returned by `uploadPhoto` is stored.
- The `prefillUid` passed through the flow from social sign-in must be the UID returned by `FirebaseAuth` — it must not be modifiable by the user.

---

## 11. Performance / Cost Requirements

- Zero new real-time listeners during any part of the signup or auth flow.
- Maximum one Firestore read per auth attempt: the existing `getProfile` call in `_handleSocialSignIn`. Do not add a second read.
- No Firestore reads during step transitions in the multi-step forms.
- Photo upload: already uses `flutter_image_compress` via `FirebaseService.uploadPhoto` — do not add a second compression step.
- `_getLocation()` for technicians: called once just before submission, not on every step transition.
- `RoleSelectionScreen` has no Firestore reads.
- The social icon boxes on the login page do not trigger any network requests until tapped.

---

## 12. Order Flow Bug Fix Requirements

**File:** `lib/service_details_screen.dart`

### 12.1 Investigation steps (Codex must perform these before writing any fix)

1. Read the full `_submit()` method body (currently around lines 838–927).
2. Read the `_showOrderRequestSheet()` and `_showQuickOrderSheet()` callers to understand how the sheet is opened and what happens after it closes.
3. Confirm whether `Navigator.pop(context)` in `_submit()` uses the sheet's own `BuildContext` — which becomes invalid immediately after pop.
4. Confirm the exact line order of: `Navigator.pop` → snackbar → `finally` block.
5. Identify whether `notifyAvailableTechnicians` can throw synchronously before the pop.

### 12.2 Required outcome of the fix

After the fix:

- `createOrderRequest` succeeds → sheet closes immediately → loading spinner stops → user returns to `ServiceDetailsScreen` → success message appears.
- `createOrderRequest` throws/times out → sheet stays open → error shown inline inside the sheet → loading spinner stops → user can retry.
- `notifyAvailableTechnicians` failure has zero effect on the above outcomes — it is always fire-and-forget and its exceptions are always silently swallowed.
- `_submitting` is always `false` after the operation completes (success or failure) — guaranteed by the `finally` block.
- `_submitted` is reset to `false` only on failure (to allow retry) — on success the sheet is gone so it doesn't matter.

### 12.3 Snackbar context fix

The success snackbar must be shown using the `ServiceDetailsScreen`'s context, not the sheet's context. The recommended pattern:

Option A (preferred): `Navigator.pop(context, 'success_message_string')` from inside the sheet, and the caller (`_showOrderRequestSheet` / `_showQuickOrderSheet`) checks the result:
```dart
final result = await showModalBottomSheet<String?>(...);
if (result != null && mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(result), backgroundColor: Colors.green, duration: Duration(seconds: 4)),
  );
}
```

Option B: pass a `VoidCallback onSuccess` parameter to the sheet and call it before pop. Both are acceptable — choose whichever is cleaner given the existing code structure.

### 12.4 Do-not-change boundaries for this bug fix

- Do not change `FirebaseService.createOrderRequest` or `FirebaseService.notifyAvailableTechnicians`.
- Do not change the timeout value (`const Duration(seconds: 15)`).
- Do not change any validation logic in `_submit()`.
- Do not change the duplicate-submit guard (`_submitted` boolean).
- Do not change the sheet's appearance or layout.
- Only change the control flow after the successful `createOrderRequest` call and the snackbar delivery mechanism.

---

## 13. Acceptance Criteria

### F1 — Social sign-in boxes
- [ ] Login page shows Google and Apple icon boxes side by side (or Google alone when Apple is unavailable)
- [ ] Boxes are compact, visual hierarchy places social sign-in above email/password
- [ ] Tapping Google box triggers Google sign-in (existing logic unchanged)
- [ ] Tapping Apple box triggers Apple sign-in on iOS/macOS (existing logic unchanged)
- [ ] Loading spinner appears inside the tapped box only while `_socialLoading` is true
- [ ] Both boxes are disabled while loading

### F2 — Create Account link
- [ ] Full-width Create Account button is removed
- [ ] A compact text link "Don't have an account? Create one" appears at the bottom of the card
- [ ] Tapping the link navigates to `RoleSelectionScreen` (not `CreateAccountScreen`)

### F3 — Role selection
- [ ] `RoleSelectionScreen` appears when Create Account is tapped
- [ ] `RoleSelectionScreen` appears when a new Google/Apple account is detected (incomplete profile)
- [ ] Customer and Technician options are clearly visible with icons and descriptions
- [ ] Selecting a role highlights the card and enables the Continue button
- [ ] Continue navigates to the correct signup flow
- [ ] Works in Arabic and English
- [ ] `'admin'` is never an option

### F4 — Customer signup flow
- [ ] Multi-step form: 2 fields per step, progress bar visible
- [ ] Next button validates current step before advancing
- [ ] Inline errors appear below fields, not as snackbars
- [ ] Field borders turn red on error
- [ ] Errors clear when user starts typing
- [ ] Social mode skips email/password steps
- [ ] Submission calls `FirebaseService.createUser` (or creates Auth then calls `createUser`)
- [ ] On success, routes to `UserHomeScreen`
- [ ] Step transitions are animated

### F5 — Technician signup flow
- [ ] Multi-step form with service selection and selfie step
- [ ] Camera and gallery options both work on device
- [ ] Skip button works on photo step
- [ ] Selfie uploaded to `techProfiles` folder if provided
- [ ] Location fetched at submission
- [ ] On success, routes to `TechHomeScreen`
- [ ] Service specialty chosen from existing `technicianServices` list
- [ ] `arabicToServiceKey` mapping used for Firestore writes

### F6 — Inline errors
- [ ] No snackbars for field validation errors in any signup or auth flow
- [ ] Login error appears inside the card
- [ ] Submission errors appear inside the card at the top
- [ ] RTL error layout correct in Arabic

### F7 — Order freeze bug
- [ ] After successful order submission, the sheet closes immediately
- [ ] Loading spinner stops after success or failure
- [ ] Success message appears on the `ServiceDetailsScreen` background (not on the dismissed sheet context)
- [ ] On error, the sheet stays open with an inline error, loading stops, and the user can retry
- [ ] No duplicate orders created
- [ ] `notifyAvailableTechnicians` failure does not prevent sheet closure

---

## 14. Edge Cases

### Auth flow
- **Google sign-in: existing complete profile** — routes to home screen normally. No change.
- **Google sign-in: existing incomplete profile** — routes to `RoleSelectionScreen`. This case already existed but now routes to the new screen.
- **Google sign-in: user cancels** — `signInWithGoogle` returns `null`, `_handleSocialSignIn` returns early. No screen change.
- **Social sign-in while `_loading` is true** — disabled by `if (_loading || _socialLoading) return;` guard. Preserved.
- **Create Account tapped while `_socialLoading` is true** — the Create Account link should also be disabled when `_socialLoading` is true (add `_socialLoading ? null : () => Navigator.push(...)` as the `onPressed`).

### Multi-step flows
- **Back navigation from step 2 back to step 1** — field values must be preserved. Since all controllers live in one `State`, this is automatic.
- **Back navigation from `CustomerSignupFlow` to `RoleSelectionScreen`** — role selection resets. This is correct behavior.
- **Social mode + empty prefillName** — Full Name field starts empty. User must fill it in. No crash.
- **Photo upload timeout** — wrap `uploadPhoto` in `.timeout(const Duration(seconds: 20))`. If it times out, catch it, set `photoUrl = ''`, and continue with account creation. Show a non-blocking warning: "Photo could not be uploaded. You can update it later." / "تعذّر رفع الصورة. يمكنك تحديثها لاحقاً." — displayed as a yellow/amber warning container (not red).
- **Permission denied for camera/gallery** — `ImagePicker` throws a `PlatformException`. Catch it and show an inline warning inside the selfie step: "Camera access denied. Please allow it in settings." / "تم رفض الوصول إلى الكاميرا. يرجى السماح به في الإعدادات."
- **Password confirm mismatch** — inline error, both password fields get red borders.
- **City with only spaces** — `.trim()` results in empty string → triggers validation error.

### Order bug fix
- **Sheet closed by swipe-down before submission completes** — `mounted` check prevents setState crashes. The `finally` block still runs.
- **Timeout during `createOrderRequest`** — caught as a `TimeoutException`, which is a subtype of `Exception`, caught by the generic `catch (e)` block. Sheet stays open, inline error shown.
- **Double tap on Submit** — blocked by `if (_submitted || _submitting) return;` guard. Preserved.

---

## 15. Implementation Notes for Codex

### Reading order before writing any code
1. Read `lib/login_screen.dart` fully — understand all state variables, helpers, and layout structure.
2. Read `lib/create_account_screen.dart` fully — understand all fields, validation logic, `arabicToServiceKey`, `technicianServices`, and `_signup()` method.
3. Read `lib/firebase_service.dart` lines 60–360 — understand `isProfileComplete`, `createUser`, `createTechnician`, `uploadPhoto`, `signInWithGoogle`, `signInWithApple`.
4. Read `lib/service_details_screen.dart` lines 560–927 — understand `_OrderRequestSheet`, `_submit()`, and the sheet caller methods.
5. Read `lib/main.dart` — understand `AppLocale` and how language switching works.

### File creation checklist
- [ ] Create `lib/role_selection_screen.dart`
- [ ] Create `lib/customer_signup_flow.dart`
- [ ] Create `lib/technician_signup_flow.dart`
- [ ] Modify `lib/login_screen.dart` (F1, F2, F6, F3 routing)
- [ ] Modify `lib/service_details_screen.dart` (F7 only)
- [ ] Delete `lib/create_account_screen.dart` after confirming no other file imports it (search entire lib/ for `create_account_screen` imports before deleting)

### Import checklist for new files
Every new file needs:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // if needed for photo preview
import 'dart:io' show File; // for FileImage preview on mobile
import 'firebase_service.dart';
import 'main.dart' show AppLocale;
import 'user_home_screen.dart'; // CustomerSignupFlow
import 'tech_home_screen.dart'; // TechnicianSignupFlow
import 'package:geolocator/geolocator.dart'; // TechnicianSignupFlow
import 'package:image_picker/image_picker.dart'; // TechnicianSignupFlow
import 'package:cloud_firestore/cloud_firestore.dart'; // for GeoPoint in TechnicianSignupFlow
```

### Avoiding common mistakes
- Do NOT import `create_account_screen.dart` from any new file.
- Do NOT call `FirebaseFirestore.instance` directly from any new UI file.
- Do NOT call `FirebaseAuth.instance` directly from any new UI file except via `FirebaseService.auth`.
- Do NOT define `const Color syanatBlue = Color(0xFF3C21C8)` in multiple files with the same constant name — move it to a shared location or define it at the top of each file that needs it (current codebase pattern is per-file definition, follow that).
- Do NOT use `Theme.of(context)` for the primary color — always use the hardcoded `syanatBlue` constant, as the existing codebase does.
- Do NOT add `const` to widgets that reference non-const state variables.
- Always check `if (!mounted) return;` after every `await` before calling `setState` or any context-dependent method.
- Always use `if (mounted) setState(...)` inside `finally` blocks.

### Animation approach
For step transitions, use this pattern (simpler than `PageView`, consistent with the codebase's `AnimationController` usage):
```dart
late int _currentStep;
late bool _forward; // direction of last navigation

// In build: use AnimatedSwitcher wrapping the current step's content widget
// with a custom transitionBuilder that uses SlideTransition in the correct direction
```

Do not use `PageView` — it adds unnecessary scroll physics and complicates the step logic.

### `_buildModernTextField` and `_buildModernDropdown` equivalents
Do not copy-paste these as-is from `create_account_screen.dart`. Build equivalent stateless helper methods in each new file that additionally accept an optional `String? errorText` parameter, so the field can render in error state when `errorText != null`.

The field widget must:
1. Set its container border to red when `errorText != null`
2. Render the red error container below itself when `errorText != null`
3. Be a self-contained widget that includes both the field and its error display

### Code style
- Follow the existing pattern: no trailing commas on function calls that span a single line, trailing commas on multi-line widget builds.
- Use `final isEn = Localizations.localeOf(context).languageCode == 'en';` at the top of every `build` method.
- Use `String _t(bool isEn, String en, String ar) => isEn ? en : ar;` as a helper inside state classes.
- All `async` methods that modify UI state must have a `_loading` bool guard and a `finally` block that resets it.

---

## 16. Files / Areas Likely Impacted

| File | Change type | Notes |
|------|-------------|-------|
| `lib/login_screen.dart` | Modified | Social boxes, Create Account link, inline error, routing to `RoleSelectionScreen` |
| `lib/create_account_screen.dart` | Deleted | Replaced by new flows. Delete only after new flows are wired and tested. |
| `lib/role_selection_screen.dart` | Created | New — role picker |
| `lib/customer_signup_flow.dart` | Created | New — customer multi-step form |
| `lib/technician_signup_flow.dart` | Created | New — technician multi-step form with selfie |
| `lib/service_details_screen.dart` | Modified | Bug fix in `_submit()` and sheet-caller snackbar context only |
| `lib/firebase_service.dart` | Not changed | Read only |
| `lib/main.dart` | Not changed | Read only |
| `lib/user_home_screen.dart` | Not changed | Read only |
| `lib/tech_home_screen.dart` | Not changed | Read only |
| `lib/admin_dashboard_screen.dart` | Not changed | — |
| `firestore.rules` | Not changed | — |
| `firestore.indexes.json` | Not changed | — |
| `pubspec.yaml` | Not changed (unless `image_picker` is somehow missing) | Verify first |

---

## 17. Explicit Do-Not-Change Boundaries

The following must not be touched under any circumstances:

- `FirebaseService.isProfileComplete` — profile completeness logic
- `FirebaseService.createUser` — user creation transaction
- `FirebaseService.createTechnician` — technician creation and service-catalogue update
- `FirebaseService.signInWithGoogle` — Google sign-in implementation
- `FirebaseService.signInWithApple` — Apple sign-in implementation
- `FirebaseService.createOrderRequest` — order submission
- `FirebaseService.notifyAvailableTechnicians` — notification logic
- `firestore.rules` — security rules
- `firestore.indexes.json` — index definitions
- `lib/user_home_screen.dart`
- `lib/tech_home_screen.dart`
- `lib/admin_dashboard_screen.dart`
- `lib/orders_screen.dart`
- `lib/payment_screen.dart`
- `lib/chat_screen.dart`
- `lib/support_chat_screen.dart`
- `lib/admin_support_chat_screen.dart`
- `lib/settings_screen.dart`
- `lib/more_screen.dart`
- `lib/splash_screen.dart`
- All files not listed in Section 16 "Files Likely Impacted"
