# Contracts — Mobile Admin Cleanup

This feature introduces **zero new external contracts**.

- No new Cloud Functions callable signatures.
- No new Firestore collection shapes.
- No new Firestore Security Rule predicates.
- No new storage paths.
- No new admin web app endpoints or DTOs.
- No new mobile-app public API (the Flutter app is an app, not a library; it has no exported surface).

The only change to the mobile app's externally-observable behavior is:

1. **Release 1**: a signed-in `admin` user is shown a new static redirect screen instead of the admin dashboard. Behavior from the backend's perspective is unchanged: the same Firestore role-read occurs at the same step; no admin-facing callable is invoked from mobile anymore (it wasn't being invoked from mobile anyway — the admin dashboard on mobile was reading/writing Firestore directly, which this feature eliminates in Release 2).
2. **Release 1**: a new Firebase Analytics event named `admin_redirect_shown` is emitted. Its parameter schema is defined in `data-model.md §6`. It is consumed only by the Firebase Analytics console (Operations reads it there). There is no downstream Cloud Function trigger or consumer; it is telemetry, not an API.
3. **Release 2**: `admin` users and any user whose `role` value is not `customer` or `technician` land on a new `UnauthorizedScreen` instead of the customer home. This is a client-side routing change only; the backend is not informed of the change and does not behave differently.

This file exists so that the `/speckit.plan` Phase 1 output directory is present and deliberately documented as empty, rather than being ambiguous about whether a contract was missed.
