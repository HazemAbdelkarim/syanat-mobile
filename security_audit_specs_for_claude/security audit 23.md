# B4-04 - MEDIUM

## Problem
Recent users in the admin area are loaded as a live stream and stay subscribed for the lifetime of the tab.

## Affected Files
- `lib/admin_dashboard_screen.dart`

## Why It Matters
Every new registration re-delivers recent user documents to every admin client, even if manual refresh would be enough.

## Fix Spec
- Replace the live stream with a one-time fetch where possible.
- If a stream must remain, ensure its subscription is disposed correctly.
- Prefer explicit refresh actions for admin-only inspection widgets.
