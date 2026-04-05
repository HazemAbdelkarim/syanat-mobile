# A2-04 - HIGH

## Problem
`activity_log` accepts any string in the `type` field.

## Affected Files
- `firestore.rules`
- all code paths that create `activity_log` documents

## Why It Matters
A malicious user can forge audit events and poison operational history.

## Fix Spec
- Replace free-form `type` acceptance with an explicit whitelist.
- Audit all current producers of `activity_log` and enumerate the valid event types they actually emit.
- Reject unknown types in rules.
- Consider tightening `description` shape and maximum length at the same time.
