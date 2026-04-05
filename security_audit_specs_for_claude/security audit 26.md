# G5-04 - MEDIUM

## Problem
`isAdmin()` performs a Firestore document read during rule evaluation.

## Affected Files
- `firestore.rules`

## Why It Matters
Admin activity pays extra rule-evaluation reads repeatedly, especially on dashboard-heavy workloads.

## Fix Spec
- Move admin identity from Firestore profile reads to Firebase Auth custom claims.
- Update `isAdmin()` to check `request.auth.token.role == 'admin'` or equivalent claim shape.
- Plan a migration path so existing admins receive the claim before rules are switched over.
