# R3-04 - HIGH

## Problem
Notification fan-out has no durable deduplication or replay guard.

## Affected Files
- `lib/firebase_service.dart`

## Why It Matters
Once the broken customer-side notification path is fixed, repeated fan-out calls can create duplicate notification storms.

## Fix Spec
- Add a per-job idempotency strategy before sending notifications.
- Good options:
  - deterministic notification document IDs
  - a `notificationsSentAt` field on the job
  - backend transaction/lock around fan-out
- Keep batch size under Firestore limits even if technician limits increase in the future.
- Implement this together with the Cloud Function move described in A2-05.
