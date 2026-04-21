# Syanat — Complete UI/UX Design Handoff Document

> **Purpose:** This document is a full, exhaustive audit of every screen, component, state, flow, and micro-interaction in the Syanat home-maintenance app. It is intended to be handed directly to a UI/UX designer so they can redesign or improve the product from top to bottom without needing to reverse-engineer the codebase.
>
> **Status as of audit date:** Pre-production MVP. Core flows are functional.  
> **Languages:** Fully bilingual — English (LTR) and Arabic (RTL). Every text element has both versions. RTL layout is enforced via `Directionality` widget throughout.  
> **Design Token:** Primary brand color `syanatBlue = #3C21C8` (vivid indigo/purple).

---

## Table of Contents

1. [App Architecture & Role System](#1-app-architecture--role-system)
2. [Splash Screen](#2-splash-screen)
3. [Authentication — Login Screen](#3-authentication--login-screen)
4. [Role Selection Screen](#4-role-selection-screen)
5. [Customer Signup Flow](#5-customer-signup-flow)
6. [Technician Signup Flow](#6-technician-signup-flow)
7. [Customer Home Screen](#7-customer-home-screen)
8. [Service Details Screen](#8-service-details-screen)
9. [Order Request Sheet (Bottom Sheet)](#9-order-request-sheet-bottom-sheet)
10. [Orders Screen (Customer)](#10-orders-screen-customer)
11. [Receipt Approval Sheet (Customer)](#11-receipt-approval-sheet-customer)
12. [More/Account Screen (Customer)](#12-moreaccount-screen-customer)
13. [Personal Info Screen](#13-personal-info-screen)
14. [Account Settings Screen](#14-account-settings-screen)
15. [Saved Locations Screen](#15-saved-locations-screen)
16. [Support Chat Screen (Customer)](#16-support-chat-screen-customer)
17. [FAQ Screen](#17-faq-screen)
18. [Technician Home Screen](#18-technician-home-screen)
19. [Technician Active Job Screen](#19-technician-active-job-screen)
20. [Technician Receipt Screen](#20-technician-receipt-screen)
21. [Technician Profile Screen](#21-technician-profile-screen)
22. [Technician Notifications Sheet](#22-technician-notifications-sheet)
23. [Settings Screen (Technician)](#23-settings-screen-technician)
24. [Chat Screen (Shared)](#24-chat-screen-shared)
25. [Admin Dashboard Screen](#25-admin-dashboard-screen)
26. [Admin Support Chat Screen](#26-admin-support-chat-screen)
27. [Global Components & Shared UI Patterns](#27-global-components--shared-ui-patterns)
28. [Complete Order Lifecycle & Status Map](#28-complete-order-lifecycle--status-map)
29. [Identified Gaps, Inconsistencies & Missing Features](#29-identified-gaps-inconsistencies--missing-features)

---

## 1. App Architecture & Role System

### Roles
| Role | Entry Point After Login | Description |
|------|------------------------|-------------|
| `customer` | `UserHomeScreen` | Books home-maintenance services |
| `technician` | `TechHomeScreen` | Accepts and fulfils jobs |
| `admin` | `AdminDashboardScreen` | Manages the entire platform |

### Global State
- **Locale:** Managed by `AppLocale` — an `InheritedNotifier<ValueNotifier<Locale>>`. Any screen can read or write it. The language switch is instant app-wide with no reload.
- **Auth:** Firebase Authentication (email/password, Google, Apple).
- **Data:** Cloud Firestore with real-time `StreamBuilder`s throughout.
- **No global design system file** (e.g., no `theme.dart`). Colors and text styles are repeated inline in each file. This is a key design-system gap.

---

## 2. Splash Screen

**File:** `splash_screen.dart`

### Layout
- Full-screen, centered column
- App logo/name displayed with a **fade-in + scale animation** on mount
- Background: Solid `syanatBlue` (`#3C21C8`)
- No text other than the logo/brand mark

### Logic (invisible to user but affects navigation)
After the animation completes (~1.5s):
1. Check if Firebase user is logged in.
2. If **not logged in** → navigate to `LoginScreen`.
3. If **logged in**, fetch Firestore profile:
   - Profile missing or incomplete → navigate to `RoleSelectionScreen` (re-onboard)
   - Role = `customer`, profile complete → `UserHomeScreen`
   - Role = `technician`, profile complete → `TechHomeScreen`
   - Role = `admin` → `AdminDashboardScreen`

### States
| State | UI |
|-------|----|
| Loading/animating | Animated logo, no user action possible |
| Error fetching profile | Currently **no error UI** shown — a gap |

### Designer Notes
- The animation is a simple Flutter `FadeTransition` + `ScaleTransition`. There is no Lottie or complex animation.
- The background is a flat solid color. Consider a gradient or subtle pattern.
- No loading indicator after animation ends while profile is being fetched — add a subtle spinner.

---

## 3. Authentication — Login Screen

**File:** `login_screen.dart`

### Layout
- `SingleChildScrollView` to handle keyboard overflow
- Top section: App logo + "Welcome back" heading
- Form section: Email field, Password field
- CTAs: "Login" button (primary), "Forgot Password?" (text link)
- Divider: "OR"
- Social login: Google button, Apple button (conditional — shown only on iOS)
- Bottom link: "Don't have an account? Sign up"

### Form Fields
| Field | Keyboard | Validation |
|-------|----------|------------|
| Email | Email type, no autocorrect | Required, basic `contains('@')` check |
| Password | Obscured, normal text | Required, min 6 characters |

Password field has a **show/hide toggle** icon button.

### CTAs
- **Login Button:** Full-width, `syanatBlue` fill, white text. Shows `CircularProgressIndicator` inside button while request is in-flight. Disabled during loading.
- **Forgot Password:** Opens `showDialog` with a single email field. On submit, calls `sendPasswordResetEmail`. Success/error shown via `SnackBar`.
- **Google Sign-In:** White card button with Google logo asset + "Sign in with Google" text.
- **Apple Sign-In:** Same style as Google. Only rendered on iOS. Uses `sign_in_with_apple` package.
- **Sign Up Link:** `TextButton`, navigates to `RoleSelectionScreen`.

### States
| State | UI |
|-------|----|
| Idle | Normal form |
| Loading | Button shows spinner, all inputs + buttons disabled |
| Error (wrong credentials) | Red `SnackBar` with Firebase error message (raw, not user-friendly — **gap**) |
| Error (network) | Same red `SnackBar` |
| Success | Navigates based on role (see Splash logic) |

### Error Handling Gap
Firebase error messages (e.g., `[firebase_auth/wrong-password]`) are shown raw to the user. These need to be mapped to human-friendly strings.

---

## 4. Role Selection Screen

**File:** `role_selection_screen.dart`

### Layout
- Full-screen, scrollable
- Top: App logo + "Join Syanat" heading + subtitle
- Two large role cards (Customer / Technician) in a vertical column
- Each card: Icon, Title, Subtitle description, Radio-style selection indicator
- Tapping selects the role and highlights the card
- Bottom: "Continue" button (full-width, `syanatBlue`, disabled until a role is selected)

### Interaction
- Selecting a card deselects the other (single-select)
- "Continue" navigates to `CustomerSignupFlow` or `TechnicianSignupFlow`
- "Already have an account? Login" link at the bottom

### States
| State | UI |
|-------|----|
| No selection | Both cards neutral, "Continue" button grayed/disabled |
| Customer selected | Customer card highlighted with blue border, dot filled |
| Technician selected | Technician card highlighted, dot filled |

---

## 5. Customer Signup Flow

**File:** `customer_signup_flow.dart`

### Multi-Step Structure
A `PageView` (not a `Stepper`). Progress shown via **step dots indicator** at the top. 3 pages total.

#### Step 1 — Personal Information
| Field | Type | Validation |
|-------|------|------------|
| Full Name | Text | Required |
| Email | Email | Required, uniqueness checked via Firebase |
| Phone Number | Phone | Required, digits only |
| Password | Obscured | Required, min 6 chars |
| Confirm Password | Obscured | Must match password |

"Next" button triggers validation. Inline error text appears below failing fields.

#### Step 2 — Location (Optional in some builds)
- "Detect my location" button using `geolocator`
- Shows current city/district if detected
- Alternatively, user can manually enter city/area
- Skippable ("Skip" text button at bottom right)

#### Step 3 — Review & Confirm
- Summary of entered data (name, email, phone)
- "Create Account" button (full-width, `syanatBlue`)
- Shows terms and conditions notice (text only, no checkbox — **legal gap**)
- On success: creates Firebase Auth user + Firestore `users` doc → navigates to `UserHomeScreen`

### States
| State | UI |
|-------|----|
| Entering data | Normal form |
| Validation error | Red text below failing field |
| Loading (on submit) | Button shows spinner, form locked |
| Firebase error (duplicate email) | Raw Firebase error in SnackBar (**gap**) |
| Success | Navigate to `UserHomeScreen` |

---

## 6. Technician Signup Flow

**File:** `technician_signup_flow.dart`

### Multi-Step Structure
Similar `PageView` with step dots. 4 pages.

#### Step 1 — Personal Information
Same fields as Customer (Name, Email, Phone, Password, Confirm).

#### Step 2 — Professional Details
| Field | Type | Notes |
|-------|------|-------|
| Specialty (Service Type) | Multi-select chips | 10 service categories with both EN/AR labels |
| Years of Experience | Number field | Optional |
| Bio / Description | Multi-line text | Optional |

Specialty chips are a `Wrap` of tappable `FilterChip`s. At least one must be selected to proceed.

#### Step 3 — Profile Photo & ID Upload
| Element | Required? |
|---------|-----------|
| Profile Photo | Required |
| National ID Front | Required |
| National ID Back | Required |

Each picker is a tappable card with a dashed border. Before selection: placeholder icon + "Tap to upload". After selection: thumbnail preview.

#### Step 4 — Location
- "Detect my location" button (geolocator)
- Stores `GeoPoint` in Firestore
- Required to proceed (**no fallback if permission is denied — gap**)

#### Final Submit
- Creates Firebase Auth user
- Uploads images to Firebase Storage
- Creates Firestore `users` doc with `role: technician`, `status: pending_verification`
- Navigates to a "pending approval" message screen

### States
| State | UI |
|-------|----|
| Image not picked | Dashed placeholder card |
| Image picked | Thumbnail preview in card |
| Location denied | No fallback — **gap** |
| Submit loading | Full-screen overlay spinner |
| Submit error | SnackBar with raw error |
| Submit success | Navigate to pending screen |

---

## 7. Customer Home Screen

**File:** `user_home_screen.dart`

### Overall Structure
Bottom navigation bar with 3 tabs:
1. **Home** (service catalog)
2. **Orders** (`OrdersScreen`)
3. **Account** (`MoreScreen`)

### Tab 1: Home

#### Header Section
- `syanatBlue` background banner
- Greeting text ("Good morning, [Name]") + Language toggle button
- Current address/location chip (tappable to change location)

#### Location Selection
- Tapping the chip opens a bottom sheet (list of saved addresses + "Add new location")

#### Service Catalog Grid
A `GridView` of 10 service cards (2 columns). Each card:
- Icon (Material icon, white, on `syanatBlue` background circle)
- Service name (localized)
- Tapping navigates to `ServiceDetailsScreen`

| Key | EN Label | AR Label |
|-----|----------|----------|
| `ac` | Air Conditioning | تكييف |
| `plumbing` | Plumbing | سباكة |
| `electricity` | Electrical | كهرباء |
| `security_intercom` | Security & Intercom | أنظمة أمن وإنتركم |
| `large_appliances` | Large Appliances | أجهزة منزلية كبيرة |
| `small_appliances` | Small Appliances | أجهزة منزلية صغيرة |
| `carpentry` | Carpentry | نجارة |
| `pest_control` | Pest Control | مكافحة حشرات |
| `aluminum` | Aluminum | ألوميتال |
| `finishing` | Finishing | تشطيبات |

---

## 8. Service Details Screen

**File:** `lib/service_details_screen.dart`

### Header
- `syanatBlue` background, full-width
- Back arrow (direction per locale) + Centered service name + Language toggle

### Body (scrollable)

#### Quick Order Card (`GlassCard`)
- Title: "Quick Order" / "طلب سريع"
- Subtitle explaining on-site diagnosis
- **CTA:** "Quick Order — 200 EGP" / "طلب سريع — ٢٠٠ جنيه" (full-width blue button with flash icon)
- Button shows spinner when `_sheetOpen` (loading); otherwise opens `_OrderRequestSheet`

#### Service Types (Subcategory Filter Chips)
- Rendered as a `Wrap` of `FilterChip`s
- First chip auto-selected on load
- "Other / Others" always sorted last
- Filtering updates the services list below in real-time

#### Available Services List
Each service is a tappable card:
- Icon in `syanatBlue`-tinted container
- Service name + optional price (green text)
- Trailing arrow icon
- Tapping opens `_OrderRequestSheet` with that service pre-filled

### States
| State | UI |
|-------|----|
| Loading | `CircularProgressIndicator` centered |
| Error | Red container with error text |
| No services | "No services available" text |
| Sheet already open | All tappable items disabled |

---

## 9. Order Request Sheet (Bottom Sheet)

**Component:** `_OrderRequestSheet` inside `service_details_screen.dart`

### Presentation
`showModalBottomSheet` with `isScrollControlled: true` and a 400ms slide-up animation.

### Form Fields

#### Urgency Toggle
Two tappable segments: "Urgent" (default) | "Scheduled"

#### Scheduled Time Picker
Shown only when "Scheduled" selected. Native date picker → time picker. Selected value shown as formatted string.

#### Description
Multi-line `TextField`. Pre-filled with "Quick inspection request" for quick orders.

#### Phone Number
Pre-filled from user profile. Editable.

#### Location Selector
- Radio-style cards for each saved location
- "+ Add New Location" → `AlertDialog` with 5 fields (Label, Street, City, Building, Notes)

### CTA
"Request Service" / "طلب الخدمة" — full-width blue button that shows a spinner while submitting.

### Validation
- At least one location required
- Phone must be filled
- For scheduled: time must be picked
- Inline `_inlineError` string shown in red below the form

### Post-Submit
- Success: sheet closes, green SnackBar "Order placed successfully"
- Error: red SnackBar with raw Firebase error
- Duplicate-submit guard (`_submitted` flag)

---

## 10. Orders Screen (Customer)

**File:** `orders_screen.dart`

### AppBar
- `syanatBlue`, no back button
- Title: "My Orders" / "طلباتي"
- 3 tabs: Ongoing / Recent / Cancelled (white indicator, 4px weight)

### Tab 1: Ongoing
Statuses included: `requested`, `active`, `technician_accepted`, `technician_arrived`, `work_finished`, `awaiting_customer_approval`, `receipt_disputed`, plus legacy statuses.

**Pending Receipt Banner (top of list, conditional):**
- Purple-tinted card with left blue border (4px)
- Icon + "Receipt Ready for Review" text + total + technician name
- Tapping opens `_ReceiptApprovalSheet`

### Job Card Structure
White card (20px radius, soft shadow):
- **Top strip:** Service icon + name + truncated job ID | Status badge (colored pill with icon)
- **Divider** (1px)
- **Body:** Description (2 lines max) + Price (green or "Price TBD") + Date
- **Timeline** (Ongoing only): horizontal progress steps
- **Cancel strip** (cancelable statuses only): "Cancel Order" red TextButton

### Cancel Dialog
AlertDialog: "Cancel Order?" → "Keep It" | "Cancel Order" (red)

### Status Badge Colors
| Status | Color |
|--------|-------|
| requested / active | Amber `#F59E0B` |
| technician_accepted | Blue `#3B82F6` |
| technician_arrived | Darker Blue `#2563EB` |
| work_finished | Purple `#8B5CF6` |
| awaiting_customer_approval | Amber |
| receipt_disputed | Red `#EF4444` |
| completed | Green `#10B981` |
| cancelled | Red `#EF4444` |

### Empty / Error / Not-Logged-In States
Each has a centered icon + message appropriate to the context.

---

## 11. Receipt Approval Sheet (Customer)

**Component:** `_ReceiptApprovalSheet` in `orders_screen.dart`

### Presentation
Full-height `DraggableScrollableSheet` via `showModalBottomSheet`.

### Content
- Handle pill + "Review Receipt" title
- Services list (name + price per row)
- Parts list (if any)
- Subtotals + Grand Total section
- Notes (if any)

### CTAs
1. **Approve** (full-width green) → `FirebaseService.approveReceipt` → status: `completed`
2. **Dispute** (full-width red outline) → `FirebaseService.disputeReceipt` → status: `receipt_disputed`

Both show spinners while in-flight.

---

## 12. More/Account Screen (Customer)

**File:** `more_screen.dart`

### AppBar
- `syanatBlue`, no back button. Title: "Account" / "الحساب"

### Settings List (ListView)
Each item is a `ListTile` with icon in blue-tinted container, bold title, and chevron trailing.

| Item | Destination |
|------|-------------|
| Personal information | `PersonalInfoScreen` |
| Account settings | `AccountSettingsScreen` |
| Saved locations | `SavedLocationsScreen` |
| Need help? | `SupportChatScreen` |
| FAQ | `FaqScreen` |
| Language | Toggles locale inline (no navigation) |

**Logout:** Small red `TextButton.icon` at bottom. Signs out → navigates to `LoginScreen`.

---

## 13. Personal Info Screen

**File:** `personal_info_screen.dart`

### Content
- Circular avatar (100px, tappable to change photo)
- Editable fields: Full Name, Phone
- Email shown read-only (grayed)
- "Save" button → full-width blue

---

## 14. Account Settings Screen

**File:** `account_settings_screen.dart`

### Content
- Change Password section (3 fields + button)
- Delete Account section (confirmation dialog)
- Notification preference toggles (may be non-functional — **gap**)

---

## 15. Saved Locations Screen

**File:** `saved_locations_screen.dart`

### Content
- `ListView` of location cards (label + address + edit/delete buttons)
- "+ Add Location" button opens an `AlertDialog` with 5 fields (Label, Street, City, Building, Notes)

### Empty State
Map-pin icon + "No saved locations yet" + prompt button.

---

## 16. Support Chat Screen (Customer)

**File:** `support_chat_screen.dart`

### Layout
- Chat bubble list + message input + send button
- Creates/retrieves `support_chats` document in Firestore
- Customer: right-aligned blue bubbles; Admin: left-aligned gray bubbles

---

## 17. FAQ Screen

**File:** `faq_screen.dart`

### Content
- `ExpansionTile` list of ~10 bilingual Q&A pairs
- Topics: booking, payment, cancellation, technician verification, etc.

---

## 18. Technician Home Screen

**File:** `tech_home_screen.dart`

### Auto-Redirect Logic
If active job exists with a "locked" status (`active`, `technician_accepted`, `technician_arrived`, `work_finished`), the entire screen is replaced by `TechnicianActiveJobScreen`. The technician cannot navigate away.

### Layout
No bottom nav bar. Single screen with top header.

**Header (syanatBlue):**
- Left: "Welcome Technician" + availability toggle (tappable inline row)
- Right: Notification bell (with red count badge), Profile icon, Settings icon, Language toggle

**Availability Toggle:**
- Green filled dot + "Available" OR gray outline dot + "Unavailable"
- Tapping calls `FirebaseService.updateAvailability(uid, newVal)`

### Stats Row (3 GlassCards)
| Card | Value Source |
|------|-------------|
| Active Jobs | Count of active-status jobs |
| Earnings Today | Sum of completed job prices (all-time — **misleading label**) |
| Rating | "★ X.XX" or "—" |

### Passive-Wait Banner (conditional)
When job status is `awaiting_customer_approval` or `receipt_disputed`:
- Blue or red tinted card with icon + status message
- Tapping navigates to `TechnicianActiveJobScreen`

### Jobs List
`ListView` of all assigned jobs (last 50). Each is a `GlassCard` + `ListTile`:
- Customer name, description, status text, price
- Trailing: Chat button (blue) + "Open" button (amber, legacy migration) + status badge

### States
| State | UI |
|-------|----|
| Loading | `CircularProgressIndicator` centered |
| No jobs | "No jobs yet" text (not localized — **gap**) |

---

## 19. Technician Active Job Screen

**File:** `technician_active_job_screen.dart`

### Navigation Lock
`PopScope(canPop: false)` during locked statuses. Back arrow hidden.

### Address Card
White card at top showing `locationAddress` from job. Falls back to "Address unavailable".

### Step Cards (1–3)
Each step is an `AnimatedContainer` (300ms) with 3 states:
- **Pending:** white bg, gray border, gray number
- **Active:** light purple bg, blue border, blue glow shadow, active action widget
- **Done:** light green bg, green border, checkmark, "Done" badge

| Step | Trigger Status | Action Widget |
|------|---------------|---------------|
| 1. Accept Assignment | `active` | Slide-to-confirm bar |
| 2. Arrived at Location | `technician_accepted` | Slide-to-confirm bar |
| 3. Work Finished | `technician_arrived` | Slide-to-confirm bar |

### Slide-to-Confirm Bar
64px tall rounded track with draggable white thumb. Supports RTL. Auto-resets if released before the end. Fires action when dragged to 100%.

### Post-Step States
- `work_finished`: "Fill Receipt Now" button card → navigates to `TechnicianReceiptScreen`
- `awaiting_customer_approval`: spinner + "Waiting for customer to review" card
- `receipt_disputed`: red-bordered card + gavel icon + admin review message

---

## 20. Technician Receipt Screen

**File:** `technician_receipt_screen.dart`

### Navigation Lock
`PopScope(canPop: false)` — no back button.

### Content (scrollable)
- **Services section:** Dynamic rows (title field + price field + remove button). Min 1 row. "+ Add Service" button.
- **Parts section:** Same as services but optional. Empty-state message shown.
- **Totals card:** Services subtotal, Parts subtotal, Grand Total (auto-calculated, live-updating)
- **Notes:** Optional multi-line field

### Bottom Bar (fixed)
Total amount + "Submit Receipt to Customer" button (full-width, 52px, blue).

### Validation
At least one service with a non-empty title. Error: red SnackBar.

### Post-Submit
Calls `FirebaseService.submitReceipt` → pops to root → green SnackBar.

---

## 21. Technician Profile Screen

**File:** `technician_profile_screen.dart`

### Content
- Large circular avatar (tappable to re-upload)
- Editable fields: Name, Phone, Bio
- Specialty chips (same multi-select as signup)
- Rating display (stars + numeric, read-only)
- Rating history list (per completed job)
- ID image thumbnails + re-upload option
- "Save Changes" button

---

## 22. Technician Notifications Sheet

**Component:** `_TechNotificationsSheet` in `tech_home_screen.dart`

### Presentation
`DraggableScrollableSheet` (initial 75%, min 40%, max 95%). White background, top rounded corners, handle pill.

### Content
`StreamBuilder` on `FirebaseService.streamTechnicianNotifications(uid)`. Each item: icon + title + body + timestamp + blue unread dot.

### States
Loading: spinner. Empty: "No notifications yet". Populated: `ListView`.

**Gap:** No "Mark all as read" button visible.

---

## 23. Settings Screen (Technician)

**File:** `settings_screen.dart`

### Content
- Language toggle
- Notification preference toggles (may be non-functional — **gap**)
- Privacy Policy link (external URL)
- Terms of Service link (external URL)
- App Version display
- Logout button (red)

---

## 24. Chat Screen (Shared)

**File:** `chat_screen.dart`

### Layout
- AppBar: other party's name + back
- `ListView` of chat bubbles (auto-scrolls to bottom)
- Bottom input: `TextField` + send `IconButton`

### Bubbles
- Own: right-aligned, `syanatBlue` bubble, white text
- Other: left-aligned, gray bubble, dark text
- Timestamp below each bubble

### States
Loading spinner. Empty: "No messages yet. Say hello!". Sending: button briefly disabled.

---

## 25. Admin Dashboard Screen

**File:** `admin_dashboard_screen.dart`

### AppBar
- `syanatBlue`, Title: "Dashboard" / "لوحة التحكم"
- Actions: Refresh button + overflow menu (Export CSV, Manage Users, Manage Jobs, Payouts — all "Coming soon" **gaps** — and Logout)
- 4-tab `TabBar` in AppBar bottom (Overview / Users / Jobs / Support)
- Support tab icon shows red badge with unread support count (live stream)

### Loading State
Full-screen `CircularProgressIndicator` while stats fetch.

### Stats Fetching Strategy
1. Fast path: single read from `stats/global` (Cloud-Function-maintained)
2. Slow path fallback: 10 parallel `count()` aggregation queries

### Tab 1: Overview
**KPI Cards (2-column grid):**
| KPI | Icon | Color |
|-----|------|-------|
| Total Users | `people` | Blue |
| Total Payouts | `monetization_on` | Green |
| Jobs Requested | `pending_actions` | Orange |
| Completed Jobs | `check_circle` | Teal |
| Cancelled Orders | `cancel` | Red |
| Cancellation % | `percent` | Deep Orange |

**Revenue Chart:** Placeholder — "Chart coming soon" — **unimplemented**.

**Pull-to-refresh:** `RefreshIndicator` on entire tab. Shows "Dashboard refreshed!" SnackBar.

### Tab 2: Users
- Horizontal progress breaking down Customers vs. Technicians %
- Stat cards: Customers count (blue) | Technicians count (green)
- Recent Users stream: latest 3 signups as `ListTile`s (avatar, name, role, join date)

### Tab 3: Jobs
Nested 3-tab bar: Requested / Active / Completed

Each sub-tab is a `StreamBuilder`:
- **Requested:** Live stream of `status = requested`. Tapping opens assign-technician sheet.
- **Active:** Live stream of all active statuses. Tapping opens detail/force-cancel sheet.
- **Completed:** Live stream of `status = completed`.

**Assign Technician Detail Sheet:**
- Job summary info
- List of available technicians for that service category
- Each technician: name, rating, photo, "Assign" button
- `FirebaseService.assignTechnician(jobId, techId)` → status: `active` + notification sent

**Active Job Detail Sheet:**
- Job summary
- Current status
- Force Cancel button (red)
- Resolve Dispute button (if disputed)

### Tab 4: Support
`StreamBuilder` on `support_chats`. Cards show: customer name, last message preview, timestamp, unread badge. Tapping → `AdminSupportChatScreen`.

---

## 26. Admin Support Chat Screen

**File:** `admin_support_chat_screen.dart`

### Layout
Same bubble UI as Chat Screen. Admin messages on right. Customer messages on left.

"Close Ticket" action in AppBar → marks `support_chats/{id}.status = closed`.

---

## 27. Global Components & Shared UI Patterns

### `GlassCard` (`glass_card.dart`)
Reusable card: white 12% opacity fill, 16px radius, soft shadow, subtle border. Used in Technician Home stat cards, Service Details.

### `GradientBackground` (`gradient_background.dart`)
`Container` with `LinearGradient` from `syanatBlue` to lighter shade. Used on some auth screens.

### Language Toggle Pattern
All screens use: `AppLocale.of(context).value = otherLocale;`
Single `InheritedNotifier` at app root. No reload needed.

### Directionality
Every screen wraps content in `Directionality(textDirection: isEn ? TextDirection.ltr : TextDirection.rtl)`.

### SnackBar Convention
- Success: `backgroundColor: Colors.green`
- Error: `backgroundColor: Colors.red`
- **Gap:** No shared SnackBar component — each screen implements its own.

---

## 28. Complete Order Lifecycle & Status Map

```
[Customer Books] ──────────────────────── status: requested
        ↓
[Admin Assigns Technician] ─────────────── status: active
        ↓
[Technician Slides to Accept] ──────────── status: technician_accepted
        ↓
[Technician Slides to Confirm Arrival] ─── status: technician_arrived
        ↓
[Technician Slides to Confirm Work Done] ── status: work_finished
        ↓
[Technician Submits Receipt] ───────────── status: awaiting_customer_approval
        ↓
    ┌──────────────────────────────────────────┐
    │          Customer Reviews Receipt         │
    ├──────────────────────────────────────────┤
    │ Approve ──→ status: completed             │
    │ Dispute ──→ status: receipt_disputed      │
    │              ↓                            │
    │         Admin Resolves ──→ completed      │
    └──────────────────────────────────────────┘

At any point before technician_accepted:
[Customer or Admin Cancels] ─── status: cancelled
```

**Legacy Status Mappings (backward compat):**
| Old Status | Maps To |
|------------|---------|
| `accepted` | `technician_accepted` |
| `en_route` | `technician_arrived` |
| `in_progress` / `inprogress` | `work_finished` |
| `payment_pending` | `awaiting_customer_approval` |

---

## 29. Identified Gaps, Inconsistencies & Missing Features

### Critical UX Gaps

| # | Gap | Screen | Severity |
|---|-----|--------|----------|
| 1 | No error UI on Splash if profile fetch fails | Splash | High |
| 2 | Raw Firebase error codes shown to users (e.g., `[firebase_auth/wrong-password]`) | Login, Signup | High |
| 3 | No fallback if location permission is denied during technician signup | Tech Signup Step 4 | High |
| 4 | No re-upload/fix flow if ID image upload fails during technician signup | Tech Signup Step 3 | High |
| 5 | No terms & conditions checkbox on signup forms (legal risk) | Both Signups | High |
| 6 | No rating/review flow for customers after job completion | Customer Orders | High |
| 7 | Customer has no way to chat with the assigned technician from the Orders screen | Customer Orders | High |

### Medium UX Gaps

| # | Gap | Screen | Severity |
|---|-----|--------|----------|
| 8 | "Earnings Today" stat is actually total lifetime earnings, not filtered by day | Tech Home | Medium |
| 9 | "Active Jobs" and "No jobs yet" labels are hardcoded in English, not localized | Tech Home | Medium |
| 10 | No visual confirmation animation when availability toggle is tapped | Tech Home | Medium |
| 11 | Admin "Export CSV", "Manage Users", "Manage Jobs", "Payouts" menu items are non-functional stubs | Admin Dashboard | Medium |
| 12 | Revenue chart in Admin Overview is a placeholder ("coming soon") | Admin Dashboard | Medium |
| 13 | No push notification permission prompt — app silently fails to notify | Global | Medium |
| 14 | No offline fallback or skeleton state for service catalog loading | Service Details | Medium |
| 15 | Technician notifications sheet has no "Mark all as read" button | Notifications Sheet | Medium |
| 16 | Order cards in the Orders screen have no tap-to-expand detail view | Customer Orders | Medium |

### Design Inconsistencies

| # | Issue | Affected Screens |
|---|-------|-----------------|
| 17 | No centralized theme/design-system — colors, radii, and text styles duplicated in every file | All |
| 18 | `syanatBlue` defined as a local `const` in 8+ different files | All |
| 19 | Card corner radius varies: 12px, 14px, 16px, 20px used inconsistently | All |
| 20 | No brand typeface — uses OS system font. No Google Fonts import. | All |
| 21 | Language toggle button position varies (top-left vs top-right) across screens | Multiple |
| 22 | Customer home greeting does not reflect time-of-day ("Good morning/evening") | Customer Home |
| 23 | Bottom nav uses Material 2 `BottomNavigationBar` — consider Material 3 `NavigationBar` | Customer Home |
| 24 | Status strings in the Tech Home job list are shown raw (e.g., "technician_accepted") not localized | Tech Home |

### Missing Screens (inferred from user flows)

| # | Missing Feature | Expected Location |
|---|----------------|-------------------|
| 25 | Technician Earnings / Payout History screen | Technician section |
| 26 | Customer job detail / live tracking screen (drill-down from order card) | Customer Orders |
| 27 | Order confirmation screen (between placing order and seeing it in the list) | Customer flow |
| 28 | Technician availability calendar for scheduled jobs | Technician section |
| 29 | Admin user detail screen (view/edit individual user profile) | Admin Dashboard |
| 30 | Admin technician approval/rejection workflow with feedback message to the technician | Admin Dashboard |
| 31 | Push notification deep-link handling (tapping a notification opens the correct screen) | Global |
| 32 | First-time onboarding/tutorial for new users | Post-signup |
| 33 | Map view showing technician en-route (customer-facing) | Customer Orders |

---

*Document generated from full codebase audit of all 32 source files in `lib/`. Accurate as of audit date.*
