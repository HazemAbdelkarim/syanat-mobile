# R3-02 - HIGH

## Problem
The 2-message cap for non-technician chat users is enforced only in client logic.

## Affected Files
- `lib/chat_screen.dart`
- `firestore.rules`

## Why It Matters
Any direct SDK caller can bypass the chat cap and spam a chat indefinitely.

## Fix Spec
- Move message-count enforcement to a trusted server-side mechanism.
- If Firestore rules are used, ensure they can safely determine:
  - whether the sender is the technician
  - how many prior customer messages already exist
- Because this is awkward in rules, prefer a Cloud Function or a server-maintained counter.
- Keep the existing UI guard, but no longer rely on it for security.
