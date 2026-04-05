# S1-04 - MEDIUM

## Problem
Saved location fields have no length constraints and are later copied into job documents.

## Affected Files
- `lib/service_details_screen.dart`
- any save-location write path

## Why It Matters
Oversized location payloads can be replayed into many jobs and increase read cost for staff and technicians.

## Fix Spec
- Add explicit `maxLength` limits for label, street, city, building, and notes.
- Use separate caps per field instead of one generic cap.
- Validate before saving locations and before copying them into jobs if both paths exist.
- Add server-side validation if clients can write these objects directly.
