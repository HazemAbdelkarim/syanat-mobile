# G5-02 - HIGH

## Problem
`storage.rules` allows authenticated uploads to `payment_proofs/` without file-size or content-type restrictions.

## Affected Files
- `storage.rules`
- `lib/firebase_service.dart`

## Why It Matters
An attacker can upload oversized or unexpected files directly through the SDK, increasing storage cost and weakening upload hygiene.

## Fix Spec
- Restrict `payment_proofs/` writes by both size and MIME type.
- Baseline policy from the audit:
  - max 5 MB
  - `image/*` only
- Keep client-side compression, but treat rules as the actual control.
- Verify download and proof-review flows still accept the resulting constrained formats.
