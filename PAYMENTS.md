# Payments — data model, rules, and admin surfaces

Last updated: 2026-04-21

The admin payments tab is a live, filterable view over the `payments/*`
collection. Every admin action (approve / reject / refund / note) flows
through a Firebase Cloud Function callable — the Admin SDK bypasses
Firestore rules, so the client never writes status fields directly.

## Storage shapes

### `payments/{paymentId}`

| Field                  | Type        | Written by     | Notes                                                                 |
|------------------------|-------------|----------------|-----------------------------------------------------------------------|
| `status`               | string      | mobile / CF    | Lowercase: `pending`, `approved`, `rejected`, `refunded`. Legacy uppercase `PENDING` / `CONFIRMED` / `REJECTED` docs still parse via `paymentStatusFromString`. |
| `amount`               | number      | mobile         | Legacy numeric total (non-itemized payments).                         |
| `currency`             | string      | mobile         | Defaults to `'EGP'` when absent.                                      |
| `createdAt`            | Timestamp   | mobile         | Client write time.                                                    |
| `approvedAt`           | Timestamp   | `adminApprovePayment` | Stamped on approve.                                            |
| `rejectedAt`           | Timestamp   | `adminRejectPayment`  | Stamped on reject.                                             |
| `refundedAt`           | Timestamp   | `adminRefundPayment`  | Stamped on refund.                                             |
| `userId`               | string      | mobile         | Customer UID. Must equal `auth.uid` on create (rule).                 |
| `technicianId`         | string      | mobile         | UID of the assigned technician — unlocks per-technician read rule.    |
| `jobId`                | string      | mobile         | Owning job document id.                                               |
| `serviceKey`           | string      | mobile         | Service category key (e.g. `plumber`, `electrician`).                 |
| `method`               | string      | mobile         | `cash`, `card`, `wallet`, … — parsed via `paymentMethodFromString`.   |
| `externalReference`    | string      | mobile         | Gateway txn id, when applicable.                                      |
| `customerSnapshot`     | map         | mobile         | `{uid, name, phone}` — denormalized so the list renders without fanout. |
| `technicianSnapshot`   | map         | mobile         | `{uid, name, phone}` — same pattern for the assigned technician.      |
| `receiptSnapshot`      | map         | mobile         | `{items: [{label, qty, unit, amount}], total, currency}`.             |
| `screenshotUrl`        | string      | mobile         | Only field the customer may update post-create.                       |
| `reviewedBy`           | string      | CF             | Admin UID of the last reviewer.                                       |
| `reviewedAt`           | Timestamp   | CF             | Last review timestamp (shared across approve/reject/refund).          |
| `rejectionReason`      | string      | `adminRejectPayment`  | Required on reject.                                            |
| `refundReason`         | string      | `adminRefundPayment`  | Required on refund.                                            |
| `internalNote`         | string      | `adminAddPaymentNote` | Latest admin note (historical notes live in `paymentEvents/*`). |
| `internalNoteBy`       | string      | `adminAddPaymentNote` | Admin UID who wrote `internalNote`.                             |
| `internalNoteAt`       | Timestamp   | `adminAddPaymentNote` | When the note landed.                                           |

### `payments/{paymentId}/paymentEvents/{eventId}`

Append-only audit log, mirroring `jobs/*/orderEvents/*`. One entry per
admin action — the admin detail view sorts ascending by `at` and renders
a timeline.

| Field       | Type        | Notes                                                             |
|-------------|-------------|-------------------------------------------------------------------|
| `type`      | string      | `created` / `approved` / `rejected` / `refunded` / `note_added`.  |
| `at`        | Timestamp   | Server timestamp.                                                 |
| `actorUid`  | string      | Admin UID for admin-initiated events.                             |
| `actorRole` | string      | `admin` (currently the only writer).                              |
| `note`      | string?     | Rejection/refund reason, or the note text for `note_added`.       |
| `status`    | string?     | Target status (`approved`/`rejected`/`refunded`).                 |

## Security rules (excerpt)

- `payments/{paymentId}`:
  - Read: admins, owning customer, assigned technician (`technicianId == auth.uid`).
  - Create: `request.resource.data.userId == auth.uid`.
  - Update: admin; or owning customer limited to `affectedKeys() == ['screenshotUrl']`.
  - Delete: admin only.
- `payments/{paymentId}/paymentEvents/{eventId}`:
  - Read: admin, owning customer, assigned technician.
  - Create: admin (production writes come from the Admin SDK, which
    bypasses rules; this clause keeps the door closed for direct client
    writes).
  - Update/Delete: never.

## Indexes

- `payments (userId ASC, createdAt DESC)` — "my payments" for customer dashboards.
- `payments (status ASC, createdAt DESC)` — filter-chip streams in admin.
- `payments (technicianId ASC, createdAt DESC)` — technician-scoped reads.

## Cloud Functions

All callables live in `europe-west1` and require `verifyAdmin(request)`:

| Callable                | Precondition         | Effects                                                           |
|-------------------------|----------------------|-------------------------------------------------------------------|
| `adminApprovePayment`   | status == `pending`  | → `approved`; stamps `approvedAt`, `reviewedBy`, `reviewedAt`; appends `paymentEvents{type:approved}`; `activity_log:payment_approved`. |
| `adminRejectPayment`    | status == `pending`  | → `rejected`; requires `reason`; appends `paymentEvents{type:rejected, note:reason}`; `activity_log:payment_rejected`. |
| `adminRefundPayment`    | status == `approved` (or legacy `confirmed`) | → `refunded`; requires `reason`; appends `paymentEvents{type:refunded, note:reason}`; `activity_log:payment_refunded`. Does **not** reverse `stats/global.totalEarnings` — add a dedicated trigger if/when refund accounting is needed. |
| `adminAddPaymentNote`   | payment exists       | Sets `internalNote`; appends `paymentEvents{type:note_added, note}`; `activity_log:payment_note_added`. |

## Admin UI

`lib/payments/payments_screen.dart`:

- Filter chips: All / Pending / Approved / Rejected / Refunded.
- Date range: All / Today / This week / This month (client-side filter).
- Search: name / phone / jobId / paymentId / userId.
- Summary strip: pending amount, approved today, total this month — all
  computed from the streamed window (no extra reads).
- Rich row: amount (bold) · customer · service · technician · method chip
  · job ref (`#6char`) · status pill · relative timestamp.
- Tapping a row pushes `PaymentDetailScreen`.

`lib/payments/payment_detail_screen.dart`:

- Header: amount, method, created-at, external ref, status pill.
- Customer, technician, linked job blocks (click-to-call on phones).
- Itemized receipt block rendered from `receiptSnapshot.items[]`.
- Live audit log streamed from `paymentEvents/*`.
- Action row: Approve / Reject (pending only); Refund (approved only);
  Add internal note (any status).

## Acceptance criteria (reconciliation)

The user's 13 acceptance criteria collapse into five checkpoints:

1. List renders readable rows, not bare 20-char IDs. ✔
2. Filter chips, date range, search, summary strip. ✔
3. Detail view with customer/technician/job/receipt/events. ✔
4. Admin actions (approve/reject/refund/note) with required reasons. ✔
5. Security rules + indexes in place. ✔

Open follow-ups (deferred):

- Mobile-side writes for `customerSnapshot`, `technicianSnapshot`,
  `receiptSnapshot` — legacy docs render with blanks until the customer
  app emits them. Rendering is defensive (no nulls crash the UI).
- Refund accounting on `stats/global.totalEarnings`: introduce an
  `onPaymentStatusChanged` trigger when this becomes a reporting need.
- Deep link to `jobs/{id}` detail + Maps preview in the linked-job block.
