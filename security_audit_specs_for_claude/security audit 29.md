# G5-06 - LOW

## Problem
Admin logout routes directly to `LoginScreen` instead of returning through `SplashScreen`.

## Affected Files
- `lib/admin_dashboard_screen.dart`

## Why It Matters
This is a consistency issue and only matters if session cleanup logic is expected in the splash flow.

## Fix Spec
- Route logout through the canonical app entry flow if that is where auth-state cleanup is centralized.
- If `SplashScreen` is intentionally bypassed, document that decision and confirm no cleanup is missing.
