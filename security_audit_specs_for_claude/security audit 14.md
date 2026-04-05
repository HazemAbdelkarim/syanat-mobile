# S1-03 - MEDIUM

## Problem
Order descriptions are length-limited only by the UI, while service-layer writes accept the raw string.

## Affected Files
- `lib/service_details_screen.dart`
- `lib/firebase_service.dart`
- `firestore.rules`

## Why It Matters
Direct SDK callers can bypass the UI and persist oversized descriptions.

## Fix Spec
- Add server-side length validation for `description`.
- Suggested upper bound from the audit: 500 characters.
- Keep the UI limit, but make rule validation authoritative.
- Verify all order creation paths write the same field name and schema.
