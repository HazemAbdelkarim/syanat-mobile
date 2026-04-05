# G5-07 - LOW

## Problem
Offline persistence can continue showing cached data after a user’s role or authorization should no longer allow access.

## Affected Files
- app-wide Firebase auth/session handling

## Why It Matters
Demoted or blocked users may briefly retain stale cached visibility until auth state is fully refreshed.

## Fix Spec
- Ensure role/security-sensitive account changes trigger token refresh or revocation.
- Use Firebase Admin SDK session revocation where appropriate.
- Review whether any especially sensitive screens should avoid relying on stale cached reads.
