# B4-02 - MEDIUM

## Problem
The admin dashboard falls back to multiple aggregation queries when `stats/global` is missing expected fields.

## Affected Files
- `lib/admin_dashboard_screen.dart`

## Why It Matters
Fresh or partially initialized projects pay a more expensive read pattern on each dashboard load.

## Fix Spec
- Ensure `stats/global` is fully initialized during setup or deploy.
- Remove the expensive slow path once initialization is reliable.
- If fallback must remain, log when it triggers so incomplete environments are visible.
