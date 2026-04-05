# R3-01 - CRITICAL

## Problem
Order creation is only guarded by client-side duplicate-submit logic. A direct SDK client can create jobs in a tight loop.

## Affected Files
- `lib/service_details_screen.dart`
- `lib/firebase_service.dart`

## Why It Matters
This creates a billing-bomb path: one attacker can generate large numbers of job writes, stats writes, activity logs, and notification fan-out writes.

## Fix Spec
- Move order creation behind a trusted backend path, ideally a Cloud Function.
- Enforce per-user rate limiting and deduplication in that backend path.
- Add App Check enforcement at minimum so only valid app clients can hit Firebase resources.
- If backend migration is staged, add an interim cooldown model such as:
  - recent order timestamp per user
  - one pending order per service/location window
- Treat this as P0 before public launch.
