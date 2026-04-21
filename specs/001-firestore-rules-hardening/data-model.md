# Data Model: Firestore Rules Hardening

**Feature**: `001-firestore-rules-hardening`
**Date**: 2026-04-13

This is not a data-schema change. The collections, documents, and field types are already defined and already populated in production. This file catalogues the **field whitelists** each restricted rule block must enforce, so the implementer can cross-check the rule diffs in `contracts/firestore-rules.md` against a single source of truth.

---

## Entity: `jobs/{jobId}`

Only the three admin-gated update branches are in scope. Customer / technician state-machine branches are already hardened and MUST NOT be touched by this spec.

### Branch A — Admin assigns technician (`requested` → `active`)

| Field | Required? | Intent |
|---|---|---|
| `status` | Yes | Transitions from `'requested'` to `'active'`. |
| `assignedTechnicianId` | Yes | The technician's UID. Must be a non-empty string. |
| `technicianId` | Yes | Duplicate of `assignedTechnicianId`. Kept for backward compatibility with existing stream queries that filter on `technicianId`. |
| `assignedTechnicianName` | Yes | Human-readable technician name. Written by the current mobile client from a pre-fetched user doc. (Spec 002 will move this lookup server-side.) |
| `updatedAt` | Yes | Server timestamp bump. |

**Whitelist**: `['status', 'assignedTechnicianId', 'technicianId', 'assignedTechnicianName', 'updatedAt']`
**Precondition**: `resource.data.status == 'requested' && request.resource.data.status == 'active'` (already enforced in existing rule).
**Authorization**: `isAdmin()` (already enforced).

### Branch B — Admin resolves dispute (`receipt_disputed` → `awaiting_customer_approval` | `completed` | `cancelled`)

| Field | Required? | Intent |
|---|---|---|
| `status` | Yes | One of `'awaiting_customer_approval'` (reopen), `'completed'` (complete), `'cancelled'` (cancel). |
| `receiptRejected` | Optional | Set to `false` on reopen to clear the rejection flag. |
| `disputeResolvedAt` | Yes (on complete/cancel) | Server timestamp. Note: the existing field is `disputeResolvedAt`, not `resolvedAt`. |
| `updatedAt` | Yes | Server timestamp bump. |
| `amountPaid` | Optional | Only written when resolution is `complete` and admin overrides the charge. |
| `price` | Optional | Mirrors `amountPaid` on complete. |
| `adminClosedAt` | Optional | Only written on complete to mark that admin force-closed the dispute to `completed`. |

**Whitelist**: `['status', 'receiptRejected', 'disputeResolvedAt', 'updatedAt', 'amountPaid', 'price', 'adminClosedAt']`
**Precondition**: `resource.data.status == 'receipt_disputed' && request.resource.data.status in ['awaiting_customer_approval', 'completed', 'cancelled']` (already enforced).
**Authorization**: `isAdmin()` (already enforced).

### Branch C — Admin cancels job (any non-terminal → `cancelled`)

| Field | Required? | Intent |
|---|---|---|
| `status` | Yes | Transitions to `'cancelled'`. |
| `cancelledBy` | Optional | Admin UID recorded for forward compatibility with Spec 002 Cloud Functions. The current mobile client does not write this field; `hasOnly` permits its absence. |
| `cancelledAt` | Optional | Same as above — forward-compat. |
| `updatedAt` | Optional | Server timestamp bump. The current mobile client does not consistently set this on the admin cancel path, so it is optional. |

**Whitelist**: `['status', 'cancelledBy', 'cancelledAt', 'updatedAt']`
**Precondition**: `!(resource.data.status in ['completed', 'cancelled']) && request.resource.data.status == 'cancelled'` (already enforced).
**Authorization**: `isAdmin()` (already enforced).

---

## Entity: Storage object `techProfiles/{fileName}`

Not a Firestore entity. Listed here because the field whitelist style still applies: the filename is parsed as a structured identifier.

| Segment | Position | Content | Source |
|---|---|---|---|
| `uid` | `fileName.split('_')[0]` | Owner's Firebase Auth UID. | `request.auth.uid` at upload time. |
| `timestamp` | `fileName.split('_')[1]` (before `.jpg`) | `DateTime.now().millisecondsSinceEpoch`. Used only for uniqueness. | Client clock — not trusted for anything other than collision avoidance. |

**Invariant**: `fileName.split('_')[0] == request.auth.uid`.
**Constraints already in rule** (must not be weakened): size `< 5 MiB`, content type matches `image/.*`, `request.auth != null`.

---

## Entity: Admin user (`users/{uid}`)

No fields on `users/{uid}` are written by this spec. The existing `isAdmin()` helper — which performs a single `get(...)` of `users/{uid}` and checks `role == 'admin'` — is the only read this spec relies on, and it is already in place. Listed here only so the implementer does not inadvertently touch the `users/{uid}` rule block looking for "where admin is defined."

---

## State transitions (out of scope but good to know)

This spec does not add or remove any job-status transitions. It only constrains which fields an already-permitted admin transition may change. The complete state machine is documented in `WOOHOO/Migration_Implementation_Plan.md` §"Resolved Blueprint — Collections & Field Names" under the `jobs` row.

## Non-goals (explicitly)

- Stats collection (`stats/global`) — no rule change in this spec.
- Payments collection — no rule change in this spec.
- Activity log — no rule change in this spec.
- Any new collection — none.
- Any new field on any document — none (beyond the forward-compat whitelist slots in Branch C, which are slots, not writes).
