# B4-06 - LOW

## Problem
`getCancelledJobsCount()` appears to be dead code now that the dashboard reads the value from `stats/global`.

## Affected Files
- `lib/firebase_service.dart`

## Why It Matters
Unused query helpers are easy to call accidentally later and reintroduce unnecessary reads.

## Fix Spec
- Remove the method if it is no longer used.
- If removal is deferred, mark it deprecated and point callers to `stats/global`.
