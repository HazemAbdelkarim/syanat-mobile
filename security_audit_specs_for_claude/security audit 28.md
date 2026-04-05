# G5-05 - MEDIUM

## Problem
Apple Sign-In is presented on Android even though that path is non-standard and may not be configured correctly.

## Affected Files
- `lib/login_screen.dart`

## Why It Matters
This is mainly a platform-hygiene and confusion issue, not a major exploit path.

## Fix Spec
- Gate Apple Sign-In visibility to `iOS` and any other platform where the flow is intentionally supported, such as web if configured.
- Verify the supported platform matrix before changing the button logic.
