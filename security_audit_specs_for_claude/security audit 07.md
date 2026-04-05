# A2-05 - HIGH

## Problem
The customer-side flow queries the `users` collection for technicians, but current rules only allow reading your own user document or admin reads.

## Affected Files
- `firestore.rules`
- `lib/firebase_service.dart`

## Why It Matters
Technician notification fan-out silently fails today. If fixed naively by loosening reads, it could expose technician PII to customers.

## Fix Spec
- Do not relax `users` collection read access for customers.
- Move technician lookup and notification fan-out to a trusted backend path, ideally a Cloud Function triggered on job creation.
- Return only the minimum data needed for notification delivery.
- Remove or surface the current silent `catch (_) {}` failure so this path is observable.
