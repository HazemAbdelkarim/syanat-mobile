# S1-02 - MEDIUM

## Problem
Phone numbers are only checked for non-empty input before being persisted.

## Affected Files
- `lib/service_details_screen.dart`

## Why It Matters
Arbitrary strings can be stored as contact numbers, degrading data quality and confusing operators.

## Fix Spec
- Validate phone numbers with a strict Egyptian mobile regex.
- Enforce `maxLength: 11` in the UI.
- Re-validate before persistence in service-layer code if present.
- Add server-side schema validation if the phone field is written directly to Firestore by clients.
