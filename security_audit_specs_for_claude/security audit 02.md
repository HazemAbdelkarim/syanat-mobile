# A2-01 - CRITICAL

## Problem
The app uses a newer multi-step job lifecycle, but `firestore.rules` still only authorizes the old status flow. The real technician and customer transitions are not covered server-side.

## Affected Files
- `firestore.rules`
- `lib/firebase_service.dart`

## Why It Matters
Core job actions can fail with permission denied in production. The workflow is not safely enforced by the server.

## Fix Spec
- Add explicit Firestore rule coverage for:
  - `active -> technician_accepted`
  - `technician_accepted -> technician_arrived`
  - `technician_arrived -> work_finished`
  - `work_finished -> awaiting_customer_approval`
  - `awaiting_customer_approval -> completed`
  - `awaiting_customer_approval -> receipt_disputed`
  - `receipt_disputed -> admin resolution state`
- Validate actor ownership on each transition:
  - assigned technician for technician steps
  - job owner for customer approval/rejection
  - admin for dispute resolution
- Keep field-level restrictions tight so each transition only changes the expected fields.
- Re-test `acceptAssignment()`, `markTechnicianArrived()`, `markWorkFinished()`, `submitReceipt()`, `approveReceipt()`, and `rejectReceipt()` against real rules.
