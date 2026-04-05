# B4-03 - MEDIUM

## Problem
`streamActiveJobsAdmin()` uses a `whereIn` list at the Firestore boundary with 11 status values.

## Affected Files
- `lib/firebase_service.dart`

## Why It Matters
The query is fragile, depends on too many legacy statuses, and is at or beyond the safe Firestore `whereIn` limit noted in the audit.

## Fix Spec
- Run a data migration to normalize legacy job statuses.
- Remove obsolete aliases from the active-jobs query after migration.
- Keep the final `whereIn` set small and aligned to the canonical workflow only.
