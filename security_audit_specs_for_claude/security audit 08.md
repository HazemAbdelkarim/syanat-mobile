# S1-01 - HIGH

## Problem
Chat message writes have no server-side length cap. UI constraints do not protect against direct Firebase SDK writes.

## Affected Files
- `lib/chat_screen.dart`
- `lib/support_chat_screen.dart`
- `firestore.rules`

## Why It Matters
An attacker can write oversized messages, driving read cost, risking Firestore document size failures, and polluting admin-visible content.

## Fix Spec
- Add Firestore rule validation that `text` is a string and is capped to a sane size.
- Suggested cap from the audit: 2000 characters.
- Mirror the same cap in UI fields for consistency, but treat rules as authoritative.
- Apply the same rule strategy to both user chat and support chat collections.
