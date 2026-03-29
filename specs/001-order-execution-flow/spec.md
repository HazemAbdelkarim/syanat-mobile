# Feature Specification: Order Execution Flow + Urgent Order Fix

**Feature Branch**: `001-order-execution-flow`
**Created**: 2026-03-28
**Status**: Draft

---

## User Scenarios & Testing

### User Story 1 — Urgent Order No Longer Freezes (Priority: P1)

A customer taps "Urgent Order" on a service page. The button immediately disables and shows a loading indicator. All other UI on the page — including the Schedule button and any navigation — is locked until the submission either succeeds or fails. If it fails, an error message is shown and the UI unlocks so the customer can retry. The order never submits twice regardless of how long the user waits.

**Why this priority**: This is a live bug. Customers are currently experiencing a broken flow with no feedback and no way to recover except force-quitting the app.

**Independent Test**: Open any service page, tap Urgent Order, verify the Schedule button and back navigation are unresponsive during submission. Verify that a success or error result always unlocks the UI within a reasonable time.

**Acceptance Scenarios**:

1. **Given** a customer is on the service details page, **When** they tap Urgent Order, **Then** the button becomes disabled and shows a spinner immediately.
2. **Given** an urgent order submission is in progress, **When** the customer taps the Schedule button or any other action, **Then** nothing happens — all actions are blocked.
3. **Given** the order submission fails (network error, validation error), **When** the error is returned, **Then** the UI unlocks, an error message is shown, and the customer can retry.
4. **Given** the order submission succeeds, **When** the confirmation is received, **Then** the UI shows success and navigates appropriately.

---

### User Story 2 — Admin Assigns Order to Technician (Priority: P2)

An admin sees incoming orders on the dashboard. For each pending order, the admin selects an available technician from a list and assigns the order. The assignment is instant. The order status changes from `pending` to `assigned`. The technician is notified (or sees the change on their next dashboard refresh). The admin cannot assign to a technician who is already on an active job.

**Why this priority**: This is the gateway that starts the entire job execution chain. Nothing downstream works without this step.

**Independent Test**: Create a test order, open admin dashboard, assign it to an available technician. Verify order status becomes `assigned` in Firestore and the technician's dashboard reflects the new job.

**Acceptance Scenarios**:

1. **Given** a pending order exists, **When** the admin opens the order and selects an available technician and confirms, **Then** the order status becomes `assigned` and the technician is linked to the order.
2. **Given** a technician already has an active job (`assigned`, `technician_en_route`, or `in_progress` status), **When** the admin tries to assign them another order, **Then** they do not appear in the available technicians list.
3. **Given** an assignment is made, **When** the technician opens their dashboard, **Then** they see the active job view instead of the normal dashboard.

---

### User Story 3 — Technician Active Job View (Priority: P3)

Once assigned, the technician's dashboard is replaced by an active job screen. This screen shows only the customer's service address and the type of service needed. No customer name, phone number, or any other personal information is visible. The technician has a single prominent slide-to-confirm bar labelled "Slide to confirm arrival".

**Why this priority**: This is the first thing the technician interacts with after assignment. Security is critical here — customer PII must not leak.

**Independent Test**: Assign a job to a technician. Log in as that technician. Verify the dashboard shows the address and service type only, with no name, phone, or email visible anywhere on screen.

**Acceptance Scenarios**:

1. **Given** a technician has an assigned job, **When** they open the app, **Then** they see the active job screen with only the service address and service type.
2. **Given** the active job screen is shown, **Then** no customer name, phone number, or email appears anywhere on the screen or in any network response visible to the technician's device.
3. **Given** the technician is on the active job screen, **When** they slide the arrival bar to 100%, **Then** the order status changes to `technician_en_route` and the bar is replaced by a "Slide to mark job complete" bar.

---

### User Story 4 — Job Completion Slide (Priority: P4)

After marking arrival, the technician performs the job. When finished, they slide a second bar labelled "Slide to mark job complete". The order status changes to `in_progress` briefly then immediately to `payment_pending`. The technician is taken to the payment entry screen.

**Why this priority**: This closes the job execution loop and triggers the payment confirmation step.

**Independent Test**: With a job in `technician_en_route` status, slide the completion bar. Verify status changes to `payment_pending` and the payment screen appears.

**Acceptance Scenarios**:

1. **Given** the technician has confirmed arrival, **When** they slide the "job complete" bar to 100%, **Then** the order status moves to `payment_pending` and the payment screen is shown.
2. **Given** the completion bar is not slid to 100%, **When** the technician releases it, **Then** the bar snaps back and no status change occurs.

---

### User Story 5 — Payment Confirmation (Priority: P5)

The technician enters the amount the customer paid them. The customer simultaneously sees a payment confirmation screen on their side with a prominent disclaimer warning them not to accept any payment manipulation and to confirm only the exact amount they actually paid. Both parties confirm. Once both have confirmed, the order status moves to `completed`, the technician's dashboard returns to normal, and the customer sees a completion screen.

**Why this priority**: This is the company's financial audit trail. The double-confirmation ensures the company always has the customer-side record of what was actually paid.

**Independent Test**: With a job in `payment_pending` status, enter a payment amount as technician. Verify the customer sees the same amount with the disclaimer. Confirm from both sides. Verify order status is `completed` and technician dashboard is back to normal.

**Acceptance Scenarios**:

1. **Given** the order is in `payment_pending` status, **When** the technician enters a valid payment amount and submits, **Then** the customer's app shows a payment confirmation screen with the amount and a red/bold disclaimer.
2. **Given** the customer sees the payment confirmation screen, **When** they tap Confirm, **Then** the order status becomes `completed`.
3. **Given** the order is `completed`, **When** the technician's app updates, **Then** their dashboard returns to normal and they can accept new jobs.
4. **Given** a technician attempts to enter a negative, zero, or implausibly large payment amount, **When** they submit, **Then** the input is rejected with an error message before any Firestore write occurs.
5. **Given** the customer receives the payment confirmation, **Then** the disclaimer text is visually prominent (bold, red or warning color) and explicitly states they must not confirm an amount different from what they actually paid.

---

### Edge Cases

- What happens if the technician closes the app mid-job? The active job screen must reappear on next open if the order is still in an active status.
- What happens if the customer closes the app before confirming payment? The payment confirmation screen must reappear on next open if order is in `payment_pending`.
- What happens if the technician tries to navigate away from the active job screen? Navigation back is blocked — the active job screen is the only destination until the job is complete.
- What happens if two admins try to assign the same order simultaneously? A Firestore transaction must ensure the order can only be assigned once.
- What happens if an urgent order submission times out on the server? A timeout of 15 seconds must be enforced client-side, after which the UI unlocks and an error is shown.

---

## Requirements

### Functional Requirements

- **FR-001**: System MUST disable all interactive UI elements immediately when an order submission begins and re-enable them only on success or failure.
- **FR-002**: System MUST enforce a 15-second client-side timeout on order submissions; if exceeded, the user sees an error and can retry.
- **FR-003**: Admin MUST be able to assign a pending order to an available technician from the order detail view.
- **FR-004**: System MUST prevent assigning a technician who already has a job in `assigned`, `technician_en_route`, or `in_progress` status.
- **FR-005**: System MUST use a Firestore transaction when assigning an order to prevent double-assignment.
- **FR-006**: Technician's dashboard MUST automatically show the active job view when they have a job in `assigned`, `technician_en_route`, `in_progress`, or `payment_pending` status.
- **FR-007**: The active job view MUST display only: service type, customer address. It MUST NOT display customer name, phone, or email.
- **FR-008**: Firestore security rules MUST enforce that technicians cannot read any customer profile fields beyond what is embedded in the order document.
- **FR-009**: The order document sent to the technician MUST contain only: `serviceKey`, `serviceCategory`, `address`, `description`, `status`, `assignedTechnicianId`. No customer UID, name, phone, or email.
- **FR-010**: Arrival and job-completion actions MUST be implemented as slide-to-confirm bars that require the user to drag to 100% before the action fires.
- **FR-011**: Releasing the slide bar before 100% MUST snap the bar back with no action taken.
- **FR-012**: The technician payment entry MUST validate: amount is a positive number, has at most 2 decimal places, and does not exceed 50,000 EGP.
- **FR-013**: The customer payment confirmation screen MUST display the entered amount prominently and MUST include a bold, visually distinct disclaimer warning against confirming a manipulated amount.
- **FR-014**: Order status MUST only move forward through the defined state machine — no skipping, no reverting — enforced in both client code and Firestore rules.
- **FR-015**: Once an order is `completed`, the technician's dashboard MUST return to its normal multi-job state.

### Key Entities

- **Order**: Service type, address, description, status, assigned technician ID, submitted price (set by technician), customer-confirmed price (set by customer), timestamps for each status transition.
- **Technician Active Job View**: Read-only projection of an order containing only address, service type, and current status. No customer PII.
- **Payment Record**: Amount submitted by technician, confirmation timestamp from customer, stored on the order document.

---

## Success Criteria

### Measurable Outcomes

- **SC-001**: Urgent order submission no longer hangs indefinitely — a result (success or error) is always delivered within 15 seconds.
- **SC-002**: Zero customer PII fields (name, phone, email) are readable by a technician's authenticated session in Firestore.
- **SC-003**: An order can travel from `pending` to `completed` through the full execution chain without any manual Firestore edits.
- **SC-004**: The payment confirmation disclaimer is visible without scrolling on all standard phone screen sizes.
- **SC-005**: Double-assignment is impossible — concurrent admin attempts to assign the same order result in exactly one successful assignment.

---

## Assumptions

- The existing order document in Firestore already contains a `status` field and an `address` field derived from the customer's saved location.
- Technicians already have a dashboard screen (`technician_dashboard_screen.dart` or equivalent) that this feature will modify.
- Push notifications for technician assignment are out of scope for this feature — the technician will see the job on next app open or stream refresh.
- The admin dashboard already lists orders; this feature adds an assign action to each order, not a new orders list.
- Payment is always in EGP (Egyptian Pounds).
- The company does not process payments through the app — the technician collects cash and this feature only records what was collected.
