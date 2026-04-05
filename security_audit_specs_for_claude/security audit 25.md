# G5-03 - MEDIUM

## Problem
Raw exception details are shown directly in the UI.

## Affected Files
- `lib/service_details_screen.dart`
- `lib/support_chat_screen.dart`

## Why It Matters
Internal collection names, rule failures, and other backend details may be exposed to probing users.

## Fix Spec
- Replace raw `$e` output with user-safe generic error copy.
- Keep detailed errors in internal logging only.
- If the app has a debug mode, gate verbose exception text behind that mode only.
