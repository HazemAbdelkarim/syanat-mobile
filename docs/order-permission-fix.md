# Order-submit permissions fix

## Root cause (confirmed via Firebase MCP against `syana-ea75a`, 2026-04-21)

The "Missing or insufficient permissions" error on order submit was caused
by **stale deployed Firestore rules combined with a newer client that now
writes phones in E.164 format** (`+201…`). Live inspection via the
Firebase MCP tools produced three decisive facts:

1. **Deployed `phoneValid` is legacy-only.** The live ruleset's helper
   regex is `^01[0125][0-9]{8}$` — it accepts the 11-digit local form
   (`01012345678`) and rejects every E.164 value. Source: the rules
   returned by `firebase_get_security_rules` against the live project.
2. **Every active customer now has an E.164 phone.** Sampled users via
   `firestore_list_documents` / `firestore_get_document`:
   - `arjMg3ddfAUxYGB05hxNzzrfJ6m2` → `+201023645696` (reporting user)
   - `RhbeB6zgB6Wbp3JM3h0DsqHwbxg2` → `+201009986828`
   - `2Z6FDr3bAXYWz6RruEP0ukbm8GJ2` → `+201100228687`
3. **No Cloud Functions are deployed.** `functions_list_functions`
   returned empty. The Spec-003 event-driven stats pipeline
   (`onJobCreated`, `onJobStatusChanged`, `onUserCreated`) is entirely
   non-functional in production, so `stats/global` is not being
   maintained authoritatively and `lastOrderAt` is never stamped
   server-side — the entire 60s cooldown currently rides on the client
   batch alone.

Put together: the order batch merges the user doc (client calls `set
merge:true` on `users/{uid}` to bump `lastOrderAt`), the merge pulls the
existing `+201…` phone into `request.resource.data`, and the stale
`phoneValid(request.resource.data)` predicate on `users/update` rejects
the entire batch with `permission-denied`. The secondary contributors —
the old `getAfter(...)` cooldown predicate on `jobs/create`, and the
client mapping `permission-denied` to either the misleading
"wait 60s / check phone" banner or the raw Firestore string — still
mattered for UX but were not the trigger.

The local `firestore.rules` in this repo already contains the corrected
predicates and validates cleanly against the emulator schema
(`firebase_validate_security_rules` → "OK: No errors detected.").
**The fix is not live until the rules and functions are actually
deployed.**

## What changed

**`firestore.rules`**

- `jobs/create`: dropped `getAfter(...)` entirely. Cooldown is now enforced
  by reading the caller's **prior** `users/{uid}.lastOrderAt` (`get`, not
  `getAfter`). The create succeeds when no prior order exists, when
  `lastOrderAt` is null, or when more than 60s have elapsed.
- `users/update`: `phoneValid(...)` is now evaluated **only** when the
  `phone` field is in the update's affectedKeys. Unrelated writes (like the
  `lastOrderAt` bump) no longer touch phone validation. `role` equality
  check uses `.get('role','')` for legacy-doc resilience.
- Added an access-model comment block at the top of the rules file.

**`functions/src/stats/on-job-created.ts`**

- In addition to incrementing `stats/global.jobsRequested`, the trigger now
  authoritatively stamps `users/{customerId}.lastOrderAt` via the Admin
  SDK. This closes the cooldown-bypass gap for any malicious client that
  skips its own batch companion write. Idempotent with the client bump.

**`lib/firebase_service.dart`**

- The order batch uses `set(..., merge: true)` on the user doc instead of
  `update(...)`, so a missing user document (never expected, but possible
  from legacy auth states) no longer manifests as `permission-denied`.
- Pre-flight validation raises dedicated exception types:
  `MissingUserProfileException`, `StoredPhoneInvalidException`,
  `OrderCooldownException`. Each carries enough context for an actionable
  UI message.
- Debug logging (gated by `kDebugMode`) prints the outgoing payload and
  the raw server error on failure.

**`lib/service_details_screen.dart`**

- `_friendlyErrorMessage` branches on each dedicated exception type first,
  falling back to generic but non-leaky messages. `permission-denied`
  **never** surfaces the raw Firestore string to customers — it maps to
  "We couldn't place your order right now. Please try again in a moment,
  or contact support if the issue continues." with the full error logged
  for diagnostics.
- `FirebaseAuthException` and `permission-denied` with an
  `unauthenticated` tail map to a re-auth prompt.

## How to grant a user the admin role

Rules use `users/{uid}.role == 'admin'` — no Firebase custom claims are
required.

From the Firebase Console:

1. Open Firestore → `users` → the target user's document (by uid).
2. Set `role: "admin"` (string). No other fields change.

From a Cloud Function / Admin SDK script:

```ts
await admin.firestore().doc(`users/${uid}`).set(
  { role: 'admin' },
  { merge: true },
);
```

Admin reads and writes on all collections kick in on the next rule
evaluation — no sign-out required.

## Deploy checklist

MCP cannot deploy. These must be run from a shell that has the Firebase
CLI on PATH and is authenticated to `syana-ea75a`.

1. **Enable billing on `syana-ea75a`** (Firebase Console → Upgrade to
   Blaze). 2nd-gen Cloud Functions refuse to deploy on the Spark plan.
2. `firebase deploy --only firestore:rules`
3. `firebase deploy --only firestore:indexes` (no new indexes, but safe
   to re-apply)
4. `firebase deploy --only functions` — first deploy will provision
   `onUserCreated`, `onJobCreated`, `onJobStatusChanged`, and the
   admin-callable functions. MCP confirmed none of these currently
   exist in production.

Order matters only loosely: the new rules are forgiving when
`lastOrderAt` is absent on the user doc, so deploying rules before
functions does not break new customers. But until the `onJobCreated`
trigger is live, the 60s cooldown is enforced only by the client-side
`lastOrderAt` bump, which is bypassable — so ship functions as soon as
billing is on.

## How the fix was verified

- `firebase_get_environment` → active project `syana-ea75a`.
- `firebase_get_security_rules` → returned the stale ruleset with
  legacy-only `phoneValid`.
- `firebase_validate_security_rules` against the local `firestore.rules`
  → "OK: No errors detected."
- `functions_list_functions` → empty list (no deployed functions).
- `firestore_list_documents` on `users` → confirmed E.164 phones on
  three sampled active customers.
- `firestore_get_document` on `stats/global` → counters present but not
  being updated by any trigger (values drift as orders happen).
