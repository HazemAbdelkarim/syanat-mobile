# Syanat Project Review and Documentation

Date: 2026-03-18

## 1) Executive Summary

Syanat is an on-demand home maintenance platform ("Uber for home maintenance") built with Flutter + Firebase. It connects customers with nearby technicians in real time, supports bilingual UX (English/Arabic), and runs Firestore-backed dispatch workflows for jobs, chat, and technician operations.

Current state:
- Core architecture is understandable and mostly modular.
- Real-service integration exists (service model, repository, integration layer).
- Security rules and app behavior are not fully aligned in a few important places.
- Test coverage is minimal and currently failing.
- Static analysis reports many quality warnings (94 issues), mostly maintainability and async-context safety.

## 2) Tech Stack and Project Structure

Application stack:
- Frontend: Flutter (Dart)
- Backend: Firebase (Auth, Firestore, Storage)
- Data bootstrapping: Python scripts for CSV -> Firestore upload

Primary source tree:
- lib/: App UI and Firebase service layer
- test/: Widget tests
- flutter_projects/firestore.rules: Firestore rules file currently in nested project folder
- upload_services_to_firestore.py, setup_services.py, validate_setup.py: backend data setup utilities

Important structural note:
- There are two Flutter app trees in this workspace:
  - Root app
  - Nested duplicate under flutter_projects/
- This causes duplicated analyzer output and increases maintenance risk.

## 3) Functional Architecture

Core app flow (on-demand service dispatch model):
1. main.dart initializes Firebase through FirebaseService.initialize().
2. Splash/login/home screens route users by role and capabilities.
3. Service browsing uses:
   - models/service.dart
   - repositories/service_repository.dart
   - services_integration.dart
4. Job requests (customer -> technician) and messaging are handled in FirebaseService.
5. Technician inventory and operational data are managed in Firestore.

Data model highlights:
- Service schema uses snake_case Firestore fields:
  - category_en, category_ar
  - subcategory_en, subcategory_ar
  - service_name_en, service_name_ar

## 4) Quality Snapshot

Static analysis:
- Command: flutter analyze
- Result: 94 issues
- Pattern: mostly lint/info warnings, async BuildContext usage risks, and some unused imports/fields.

Tests:
- Command: flutter test
- Result: failing
- Existing test is still the default counter smoke test and does not match the current app UI.

## 5) Findings (Prioritized)

### Critical

1. Firestore field mismatch in service subcategory query
- Location: lib/services_integration.dart
- Issue: query uses subcategoryEn but stored schema is subcategory_en.
- Impact: subcategory filtering returns empty results or incorrect behavior when this method is used.
- Recommendation: change Firestore query field to subcategory_en.

### High

2. Chat rules are overly permissive for signed-in users
- Location: flutter_projects/firestore.rules
- Issue: chats and messages allow read/create for any authenticated user, without participant checks.
- Impact: privacy/data-leak risk (users may read unrelated chats/messages).
- Recommendation: enforce participant-based access (customerId/technicianId membership checks).

3. Inventory rules conflict with technician inventory features
- Locations:
  - flutter_projects/firestore.rules
  - lib/technician_inventory_screen.dart
  - lib/firebase_service.dart
- Issue: rules allow inventory read/write for admin only, but technician UI/service methods expect technicians to read and manage own inventory.
- Impact: permission-denied runtime failures for technician workflows.
- Recommendation: allow technicians to access only documents where technicianId == request.auth.uid.

### Medium

4. Test suite does not validate current app behavior
- Location: test/widget_test.dart
- Issue: still checks old counter app UI.
- Impact: CI signal is noisy and not meaningful; test always fails against real app.
- Recommendation: replace with smoke tests for app boot, Firebase init handling, and one screen-flow test.

5. Duplicate nested Flutter project increases operational risk
- Evidence:
  - pubspec.yaml exists at root and in nested flutter_projects/pubspec.yaml
  - duplicate lib/, platform folders, and configs
- Impact: accidental edits/deploy from wrong root, duplicated analysis noise, tooling confusion.
- Recommendation: pick one canonical root and archive/remove duplicate project tree.

### Low

6. Documentation set is extensive but partially redundant
- Many summary/guide files overlap in purpose.
- Recommendation: keep one canonical architecture doc + one setup doc + one operations runbook.

## 6) Strengths Observed

- Clear service model and repository abstraction.
- Bilingual data model and UI support integrated across service screens.
- Firebase service layer centralizes many app operations.
- Product flow already aligns with an Uber-style dispatch experience (request, assignment intent, technician interaction).
- CSV upload scripts and setup validators are practical and useful for operations.

## 7) Recommended Next Steps

Immediate (this week):
1. Fix subcategory query field mismatch in services_integration.dart.
2. Align Firestore rules with actual app permissions for chats and inventory.
3. Replace default widget test with real app smoke tests.

Short-term (next sprint):
1. Resolve high-priority analyzer warnings around async BuildContext usage.
2. Remove/merge duplicate nested project tree.
3. Consolidate docs into a smaller, maintained set.

## 8) Suggested Documentation Baseline

To keep docs maintainable, retain these as canonical docs:
- PROJECT_REVIEW_MAR_2026.md (this file): technical review + risk register
- README.md: product-level intro and run instructions
- QUICK_START.md: shortest setup path
- firestore_schema.md: source of truth for Firestore fields and relationships

## 9) Validation Commands

- flutter analyze
- flutter test
- python validate_setup.py

Expected current status:
- flutter analyze: many warnings/information issues
- flutter test: failing (default counter test mismatch)
- validate_setup.py: environment-dependent, useful for Firebase upload readiness
