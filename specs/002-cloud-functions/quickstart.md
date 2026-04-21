# Quickstart: Admin Cloud Functions

**Feature**: `002-cloud-functions`
**Date**: 2026-04-15 (aligned with the 2026-04-15 clarification pass)

This is the runbook an engineer follows to scaffold, test, and deploy the `functions/` project end to end. It assumes the engineer has owner-level access to the `syana-ea75a` Firebase project and has the Firebase CLI installed (`firebase --version` ≥ 13.x).

---

## 1. Bootstrap `functions/` (Phase 3)

From the repo root:

```bash
# Initialize a TypeScript Cloud Functions project at the repo root.
firebase init functions
# When prompted:
#   - Language: TypeScript
#   - ESLint: No (the Flutter repo root does not ship ESLint; keep the surface small)
#   - Install deps now: Yes
#   - Overwrite: No (if prompted for package.json/index.ts)
```

Then **immediately** edit `functions/package.json`:

```jsonc
{
  "engines": { "node": "20" }   // Node 20 per R-8; not 18 (EOL)
}
```

Edit `functions/tsconfig.json` to ensure:

```jsonc
{
  "compilerOptions": {
    "strict": true,
    "target": "es2022",
    "module": "commonjs",
    "outDir": "lib",
    "esModuleInterop": true,
    "skipLibCheck": true
  }
}
```

Install test tooling:

```bash
cd functions
npm i -D jest ts-jest @types/jest firebase-functions-test
npx ts-jest config:init
```

Commit the scaffold + `.gitignore` (per FR-020: `serviceAccountKey.json`, `**/serviceAccountKey*.json`, `functions/.env`, `functions/.runtimeconfig.json`) as the first `functions/` commit. Before pushing, `git diff --cached` MUST be reviewed for accidentally-staged credential files (Principle VIII).

---

## 2. Write helpers first (`functions/src/lib/`)

Following the dependency order:

1. `functions/src/lib/verify-admin.ts` — FR-002 — reads `users/{uid}.role`, throws `HttpsError('unauthenticated'|'permission-denied')`. Note: this is called BEFORE `runTransaction`, so the admin role read is a standalone call, not part of the admin op's transaction.
2. `functions/src/lib/audit-templates.ts` — FR-003a — exports a `renderDescription(type, fields)` function with the five fixed templates in `data-model.md` §3.1.
3. `functions/src/lib/audit-log.ts` — FR-003 — exports `writeAuditLog(tx, entry)` which accepts a Firestore transaction handle and writes an `activity_log` document inside that transaction.
4. `functions/src/lib/log-safe.ts` — FR-011 / Principle XIII — exports a `safeLog(fnName, ctx)` that logs only function name + `auth.uid`, truncating any incidental reason to 200 chars.

---

## 3. Implement callables (one file per function)

Order: `assign-job.ts` first (exercises every helper), then `approve-payment.ts` (simplest), then the other three.

Each file follows the same skeleton:

```typescript
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { verifyAdmin } from '../lib/verify-admin';
import { writeAuditLog } from '../lib/audit-log';
import { renderDescription } from '../lib/audit-templates';

export const adminXxx = onCall(
  { region: 'europe-west1' },  // R-9
  async (request) => {
    try {
      await verifyAdmin(request);           // FIRST line (Principle IX)
      // validate inputs BEFORE any Firestore read (Principle X)
      // run transaction:
      //   - read preconditions from txn snapshot
      //   - assert status
      //   - tx.update(...) the job/payment
      //   - writeAuditLog(tx, { type, ... })
      // return { ok: true };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      throw new HttpsError('internal', 'Unexpected error');  // FR-010
    }
  }
);
```

Wire each callable into `functions/src/index.ts`:

```typescript
import * as admin from 'firebase-admin';
admin.initializeApp();

export { adminAssignJob }      from './admin/assign-job';
export { adminApprovePayment } from './admin/approve-payment';
export { adminRejectPayment }  from './admin/reject-payment';
export { adminResolveDispute } from './admin/resolve-dispute';
export { adminCloseJob }       from './admin/close-job';

// Spec 003 fills these in later
export * from './stats';
```

---

## 4. Write the Jest suite (`functions/test/`)

One test file per callable, plus `test/setup.ts` for emulator bootstrap + fixture seeding (admin user, non-admin user, jobs in each starting status, payments in each starting status).

Minimum scenarios per callable (mirrors FR-013 one-for-one):

| Scenario | `adminAssignJob` | `adminApprove` | `adminReject` | `adminResolve` | `adminClose` |
|---|---|---|---|---|---|
| Success | ✅ | ✅ | ✅ | ✅ (3 resolution types) | ✅ |
| Non-admin → `permission-denied` | ✅ | ✅ | ✅ | ✅ | ✅ |
| Unauthenticated → `unauthenticated` | ✅ | ✅ | ✅ | ✅ | ✅ |
| Empty/missing args → `invalid-argument` | ✅ | ✅ | ✅ (also empty `reason`) | ✅ (also bad `resolution`, empty `reason`) | ✅ (also `amountPaid < 0`, non-number) |
| Wrong status → `failed-precondition` | ✅ | ✅ | ✅ | ✅ | N/A (idempotent instead) |
| Missing technician → `not-found` | ✅ | — | — | — | — |
| Idempotent retry → success, no rewrite | — | — | — | — | ✅ (the load-bearing one) |
| Audit log assertions (type, description template, userId, timestamp, same txn) | ✅ | ✅ | ✅ | ✅ | ✅ (also: no second entry on retry) |

Every `activity_log.description` assertion MUST match the fixed template in `data-model.md` §3.1 exactly — changing the template is a breaking change for Spec 005.

---

## 5. Pre-prod gate — emulator test pass (FR-015, R-10)

```bash
cd functions
# Boot emulators, run Jest, exit with Jest's exit code.
firebase emulators:exec --only functions,firestore,auth "npm test"
# Exit code 0 → deploy allowed.
# Exit code != 0 → fix and re-run; deploy is blocked.
```

This single command IS the FR-013 matrix and the FR-015 pre-prod gate rolled into one. There is no separate hosting-preview step — hosting preview channels do not exercise Cloud Functions (research R-10).

---

## 6. Update the Firestore rule (FR-012)

Edit `firestore.rules`, find the admin assignment write branch, and expand its `affectedKeys().hasOnly([...])` from:

```text
['status', 'assignedTechnicianId', 'technicianId', 'assignedTechnicianName', 'updatedAt']
```

to:

```text
['status', 'assignedTechnicianId', 'technicianId', 'assignedTechnicianName', 'assignedBy', 'assignedAt', 'updatedAt']
```

No other rule block may be touched by this spec (FR-018). Verify in the Rules Playground that:
1. A write with only the new whitelist set is allowed.
2. A write adding `customerId` is denied.
3. A write from the current mobile client (with the old smaller field set) is still allowed — `hasOnly` permits subsets.

---

## 7. Atomic deploy (FR-014)

```bash
firebase deploy --only functions,firestore:rules
```

Splitting into two deploys is a defect per Principle IV and R-4.

Post-deploy checklist (FR-016):

1. Firebase Console → Functions → all 5 functions visible with `Active` status, zero startup errors.
2. Smoke test: invoke each of the 5 functions once with a valid payload and observe `activity_log/{autoId}` appears with the expected `type` and `description` template.
3. Confirm the first invocation region is `europe-west1` (Console → Functions → Details → Region).
4. Run `git log -p functions/` and confirm no `serviceAccountKey*.json` blob appears (SC-008).

---

## 8. Rollback plan (if smoke test fails)

1. `git revert` the deploy commit.
2. `firebase deploy --only functions,firestore:rules` again — this re-deploys the reverted state.
3. The mobile admin client continues working throughout because it never called the new functions.
4. Capture logs (`firebase functions:log`) for the failing invocation, redacting per Principle XIII before sharing.

No data migration is needed for rollback because Spec 002's new fields on `jobs/*` and `payments/*` are additive — an older client that doesn't know about them simply ignores them.
