# B4-01 - HIGH

## Problem
Unread technician notification count is computed by streaming up to 100 full notification documents and counting them client-side.

## Affected Files
- `lib/firebase_service.dart`
- `lib/tech_home_screen.dart`

## Why It Matters
The badge counter uses expensive reads for a value that should be aggregated.

## Fix Spec
- Replace document-stream counting with a cheaper count strategy.
- Options:
  - poll a Firestore `count()` aggregation
  - maintain an unread counter field server-side
- If real-time badge updates are needed, a maintained counter is the cleanest design.
- Re-check permissions and indexes after changing the query strategy.
