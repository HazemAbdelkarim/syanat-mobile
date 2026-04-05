# R3-03 - HIGH

## Problem
Support chat send throttling is only a local `_sending` guard and does not enforce any server-side rate limit.

## Affected Files
- `lib/support_chat_screen.dart`
- `firestore.rules`

## Why It Matters
One user can flood the admin support inbox with large volumes of messages.

## Fix Spec
- Add server-side throttling for support messages.
- Pick one explicit policy and implement it consistently:
  - minimum interval between messages
  - daily quota per user
  - both
- Prefer a backend function or a server-maintained counter/timestamp model.
- Pair this with the chat message length cap.
