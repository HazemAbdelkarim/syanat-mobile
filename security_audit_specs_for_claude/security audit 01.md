# G5-01 - CRITICAL

## Problem
Client-side registration can write any `role` value into `users/{uid}`. A malicious user can create their own user document with `role: 'admin'` and immediately satisfy the current `isAdmin()` rule helper.

## Affected Files
- `firestore.rules`
- `lib/role_selection_screen.dart`
- `lib/firebase_service.dart`

## Why It Matters
This is a full privilege-escalation path. A normal user can self-promote to admin.

## Fix Spec
- Lock user creation rules so client-created user documents may only use `customer` or `technician`.
- Explicitly reject `admin` at create time.
- Review update rules too, so role cannot later be changed by the same client.
- Preferred rule shape:
```text
allow create: if isSignedIn()
  && request.auth.uid == uid
  && request.resource.data.role in ['customer', 'technician'];
```
- Longer-term fix: move admin authorization to Firebase Auth custom claims instead of trusting Firestore profile data.
