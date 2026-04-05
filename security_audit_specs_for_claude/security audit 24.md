# B4-05 - MEDIUM

## Problem
Recent activity is streamed continuously instead of fetched on demand.

## Affected Files
- `lib/firebase_service.dart`
- `lib/admin_dashboard_screen.dart`

## Why It Matters
Each new activity event re-delivers multiple documents to the dashboard and creates avoidable read churn.

## Fix Spec
- Replace the continuous stream with one-time fetch plus manual refresh, or paginate activity history.
- Keep live streaming only if there is a real operational requirement for it.
- Align this decision with the final `activity_log` hardening from A2-04.
