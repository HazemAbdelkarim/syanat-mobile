# A2-07 - MEDIUM

## Problem
Users can update their own `support_chats` document too broadly.

## Affected Files
- `firestore.rules`

## Why It Matters
A user may be able to mutate fields that should be admin-controlled, such as ticket status or future sensitive metadata.

## Fix Spec
- Restrict user updates to a narrow allowed field set only.
- Keep admin unrestricted where necessary.
- Use `diff(...).affectedKeys().hasOnly([...])` style checks for user edits.
- Review existing support chat schema before finalizing the allowed field list.
