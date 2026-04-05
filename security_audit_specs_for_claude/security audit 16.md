# A2-06 - MEDIUM

## Problem
Cancellation rules still reference the legacy `accepted` status, while the app uses `active`.

## Affected Files
- `firestore.rules`
- `lib/orders_screen.dart`

## Why It Matters
Users can see a cancel path in the UI that fails at the Firestore rule layer for `active` jobs.

## Fix Spec
- Update cancellation rules to match current status names.
- At minimum allow the intended customer cancellation states:
  - `requested`
  - `active`
- Re-test the cancel button on both statuses with real Firebase rules enabled.
