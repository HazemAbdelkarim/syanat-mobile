# A2-08 - MEDIUM

## Problem
Any signed-in user can create notifications with arbitrary content and arbitrary target technician IDs.

## Affected Files
- `firestore.rules`
- `lib/firebase_service.dart`

## Why It Matters
This enables notification spam, forged job metadata, and targeted badge flooding.

## Fix Spec
- Tighten notification create rules with a strict schema.
- Require only known keys, `read == false` on create, and a timestamp type check.
- Longer-term fix: move notification creation fully to a backend function and remove direct client writes.
- Re-check notification readers after the schema is tightened.
