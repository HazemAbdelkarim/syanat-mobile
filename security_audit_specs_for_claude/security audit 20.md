# R3-05 - MEDIUM

## Problem
Account creation relies mostly on Firebase Auth defaults and still causes Firestore side effects on each signup.

## Affected Files
- `lib/role_selection_screen.dart`
- `lib/firebase_service.dart`

## Why It Matters
Automated signup abuse can still amplify Firestore writes through stats and activity-log updates.

## Fix Spec
- Enable App Check for Authentication-related flows and Firebase resources used during signup.
- Review whether `stats/global` and `activity_log` writes should happen directly from the client during registration.
- Consider moving post-signup side effects to a backend trigger on user creation.
