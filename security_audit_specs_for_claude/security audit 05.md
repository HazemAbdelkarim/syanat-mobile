# A2-03 - HIGH

## Problem
`stats/global` can be written by any authenticated user as long as the keys are allowed. The rule does not validate the values.

## Affected Files
- `firestore.rules`
- admin stats flows that read `stats/global`

## Why It Matters
Any signed-in user can forge KPIs such as earnings and completed jobs.

## Fix Spec
- Restrict `stats/global` writes to admin-only or backend-only code.
- Prefer a Cloud Function that updates counters from trusted business events.
- Do not trust client absolute values for counters.
- If client writes remain temporarily, reduce scope hard and plan migration away from this model immediately.
