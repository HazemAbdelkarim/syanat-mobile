# A2-02 - CRITICAL

## Problem
`services/{serviceId}` currently allows writes from any signed-in user.

## Affected Files
- `firestore.rules`
- any client flow that calls `ensureServiceExists`

## Why It Matters
Any authenticated user can overwrite, delete, or forge the services catalog and manipulate `techCount`.

## Fix Spec
- Change `services` writes from `isSignedIn()` to admin-only access.
- Remove direct client ownership of service creation and catalog mutation.
- Move `ensureServiceExists` behavior to a Cloud Function or another trusted admin-only path.
- After tightening rules, verify technician onboarding still works without client-side catalog writes.
