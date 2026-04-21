<!--
Sync Impact Report
- Version change: 1.0 → 1.1.0
- Bump rationale: MINOR — added six new principles (VIII–XIII) and a new
  "Security Review Gate" governance clause covering secrets hygiene, least
  privilege, input validation, audit trail, defense-in-depth, and safe
  error reporting. No existing principle was removed or redefined in a
  backward-incompatible way; existing I–VII are preserved verbatim.
- Modified principles:
    - I. Migration Plan Is the Source of Truth (unchanged)
    - II. Workspace Boundary (unchanged)
    - III. No Guessing — Read First (unchanged)
    - IV. Deploy Safety (unchanged)
    - V. Backward Compatibility During Migration (unchanged)
    - VI. Flutter Tooling Isolation (unchanged)
    - VII. No Premature Abstraction (unchanged)
- Added sections:
    - VIII. Secrets & Credential Hygiene (NEW)
    - IX. Least Privilege & Explicit Authorization (NEW)
    - X. Input Validation & Transactional Integrity (NEW)
    - XI. Audit Trail & Accountability (NEW)
    - XII. Defense in Depth (NEW)
    - XIII. Safe Error Reporting & Logging (NEW)
    - Governance → Security Review Gate (NEW sub-section)
- Removed sections: none
- Templates requiring updates:
    - ✅ .specify/templates/spec-template.md — no change required; spec-level
      security requirements are expressed through functional requirements.
    - ✅ .specify/templates/plan-template.md — no structural change; the
      existing "Constitution Check" gate automatically picks up the new
      principles. Plans for Specs 002+ MUST enumerate compliance with
      Principles VIII–XIII explicitly in their Constitution Check block.
    - ✅ .specify/templates/tasks-template.md — no change required; security
      tasks are already expressible under existing task categories.
- Follow-up TODOs:
    - None. Ratification date unchanged; all placeholders resolved.
-->

# Syanat Admin Web Migration — Constitution

## Core Principles

### I. Migration Plan Is the Source of Truth

The file `WOOHOO/Migration_Implementation_Plan.md` contains every resolved field name, method signature, collection path, and architectural decision. Every spec, plan, and task MUST reference it — never guess a field name or status value. If the migration plan and the codebase disagree, read the codebase and update the migration plan before proceeding.

### II. Workspace Boundary

All admin web code lives inside `admin_web/`. All Cloud Functions code lives inside `functions/`. No admin web files may be created outside `admin_web/`. No Cloud Function files may be created outside `functions/`. The root `lib/` directory is the mobile app — touch it only in Spec 006 (Mobile Cleanup).

### III. No Guessing — Read First

Before writing any code that references a Firestore field name, collection name, method signature, or status value: read the actual source file and confirm the name. The migration plan's Resolved Blueprint section has line numbers — use them. If a line number has shifted, grep for the method name.

### IV. Deploy Safety

- Never run `firebase deploy` without first showing the diff of what will be deployed.
- Every production deploy must be preceded by a Firebase preview channel deploy (`firebase hosting:channel:deploy preview-<name>`) or emulator test.
- Firestore rules and Cloud Functions that must go live together are deployed in a single `firebase deploy --only X,Y` command — never separately.
- Never deploy storage rules before the mobile app ships the corresponding upload convention change.

### V. Backward Compatibility During Migration

The mobile app is live in production. Any change to Firestore rules or Cloud Functions must not break existing mobile client behavior. Specifically:
- Job status values must not change (e.g., `adminCloseJob` uses `'completed'`, not `'force_closed'`).
- `affectedKeys()` restrictions must include all fields the current mobile client writes, not just fields the future CF will write.
- Stats rules remain open to non-admin writes until Phase 5 deploys the event-driven CFs atomically.

### VI. Flutter Tooling Isolation

- Mobile: `flutter analyze` / `flutter build` from repo root.
- Web: `cd admin_web && flutter analyze` / `flutter build web --web-renderer html --release`.
- These two projects must never share `.dart_tool/` or `.flutter-plugins`.
- Never run `flutter pub get` at the repo root expecting it to affect `admin_web/`.

### VII. No Premature Abstraction

Do not create shared packages, monorepo tooling, or extracted models until Spec 006 evaluates whether 3+ model files have diverged. Start simple. The `admin_web/` extraction to its own repo happens after migration, not during.

### VIII. Secrets & Credential Hygiene (NON‑NEGOTIABLE)

Private credentials MUST NEVER be committed to git, logged at runtime, or embedded in client code.

- `.gitignore` MUST exclude: `serviceAccountKey.json`, `**/serviceAccountKey*.json`, `.env`, `.env.*`, `functions/.env`, `functions/.runtimeconfig.json`, `*.key`, `*.pem`, `*.p8`, `*.p12`, `*.jks`, `google-services.json.local`, `GoogleService-Info.plist.local`, and any `.flaskenv` / `.npmrc` containing tokens. Before any commit that touches `functions/`, `admin_web/`, or `firebase.json`, `git diff --cached` MUST be reviewed for accidental inclusion.
- Firebase **public web config** (`apiKey`, `authDomain`, `projectId`, `storageBucket`, `messagingSenderId`, `appId`, `measurementId`) is public by design and MAY appear in client code, but every such embed MUST be paired with active App Check on that surface (Principle XII). A public config without App Check is treated as a leaked secret.
- The reCAPTCHA Enterprise site key used by App Check on web MUST be a real, project-scoped key. Shipping, committing, or previewing the literal placeholder `YOUR_RECAPTCHA_V3_SITE_KEY` to any deployed channel (including preview) is forbidden.
- Firebase Admin SDK service account keys MUST only be used in the Cloud Functions runtime (which auto-injects credentials) or locally in a developer environment where the key file is gitignored. They MUST NEVER be bundled into `admin_web/`, `lib/`, or any file shipped to clients.
- Cloud Function source code MUST NOT read `context.auth.token` and write it, `request.headers`, or any portion of the Firebase ID token into Firestore, Storage, or logs.
- Any CI workflow that needs a deploy credential MUST source it from GitHub Actions Secrets (or the equivalent masked store), never from a file in the repo.
- When any of the above is violated, the leaked credential MUST be rotated before the next deploy — removing the file from HEAD is insufficient.

**Rationale:** A single accidental `git add .` that pulls in a service account key grants full project admin to anyone who can read the repo, including past states. Public web config is not a secret but loses its harmlessness the instant App Check is disabled on that surface.

### IX. Least Privilege & Explicit Authorization (NON‑NEGOTIABLE)

Every write path and every privileged read MUST be gated by an explicit authorization check, and that check MUST be as narrow as the operation allows.

- **Firestore rules**: every admin-gated write MUST call `isAdmin()` AND restrict the diff via `request.resource.data.diff(resource.data).affectedKeys().hasOnly([...])`. A rule that gates on `isAdmin()` alone — with no field whitelist — is considered a defect and MUST be fixed before the spec it belongs to can ship.
- **Cloud Functions**: every callable that performs a write MUST call `verifyAdmin(context)` as its first executable line, before any argument parsing or Firestore read. A `verifyAdmin` that is called after a Firestore read is a defect.
- **Web auth gate**: when a signed-in user fails the `role == 'admin'` check on the admin web app, the code MUST call `FirebaseAuth.instance.signOut()` **before** rendering the denied screen. A "denied" UI rendered while the Firebase session is still alive is a defect, because the user can open a browser console and query Firestore directly.
- **Data exposure controls**: admin reads of unbounded collections (`users`, `jobs`, `payments`, `activity_log`, `support_chats`) MUST be paginated or limited to ≤ 100 documents per query. There is no "fetch all users" endpoint or query anywhere in `admin_web/` or `functions/`.
- **Firestore admin role check** remains a Firestore document read against `users/{uid}.role == 'admin'` (decision D1). Custom Claims are out of scope and MUST NOT be introduced without a constitution amendment.
- **Storage writes** MUST include an owner check. The `techProfiles` write rule MUST enforce `fileName.split('_')[0] == request.auth.uid` in addition to size and content-type checks. A storage path that allows `request.auth != null` without an owner or role constraint is a defect.

**Rationale:** Without field-level `affectedKeys()`, a compromised admin account — or a single buggy client release — can silently rewrite unrelated fields (customer identity, price, timestamps). Without pre-authorization in callables, an attacker can side-effect the database simply by reaching the input-validation code path.

### X. Input Validation & Transactional Integrity (NON‑NEGOTIABLE)

Cloud Functions MUST validate every input and MUST perform state transitions inside Firestore transactions.

- Every string input MUST be validated as non-empty after `.trim()`. Every numeric input MUST be validated for type and range (e.g., `amountPaid` must be a finite, non-negative number; `0` is valid).
- Enumerated inputs MUST be validated against a locally-defined `as const` array. Examples: `resolution ∈ {'reopen', 'complete', 'cancel'}`; `status ∈ { ... }`.
- A rejection without a reason MUST never reach Firestore. `adminRejectPayment` and `adminResolveDispute` both require a trimmed non-empty `reason` at the input-validation layer.
- State-changing writes MUST occur inside a `db.runTransaction(...)` block where the precondition (e.g., `status == 'requested'`) is checked against the transaction-read snapshot, not against a pre-transaction read. Checking a status outside the transaction and then writing inside it is a TOCTOU defect.
- Writes MUST be idempotent where the operation is naturally retryable. `adminCloseJob` MUST check `adminClosedAt` inside the transaction and return success without re-writing if the job is already closed. A second identical call MUST NOT double-update counters or re-charge.
- `context.auth.uid` is trusted (it comes from the verified Firebase ID token). All other fields sourced from `data.*` are untrusted and MUST pass validation before use — including lookups such as `technicianId`, where the function MUST still confirm the referenced document exists before writing.
- HTTP error mapping MUST use Firebase `HttpsError` codes precisely: `unauthenticated`, `permission-denied`, `invalid-argument`, `failed-precondition`, `not-found`, `already-exists`, `aborted`. Throwing a generic `Error` from a callable is a defect.

**Rationale:** The single biggest class of Firebase backend bugs is "client sent bad input, function wrote bad data." Input validation plus transactional preconditions eliminates the majority of it without extra infrastructure.

### XI. Audit Trail & Accountability (NON‑NEGOTIABLE)

Every privileged write MUST leave a durable, server-set audit record.

- Every admin write MUST record an actor field using `context.auth.uid` and a server-set timestamp using `FieldValue.serverTimestamp()`. Concretely:
    - `adminAssignJob` → `assignedBy`, `assignedAt`
    - `adminApprovePayment` / `adminRejectPayment` → `reviewedBy`, `reviewedAt` (and `rejectionReason` for rejects)
    - `adminResolveDispute` → `resolvedBy`, `resolutionNote`, `disputeResolvedAt`
    - `adminCloseJob` → `adminClosedBy`, `adminClosedAt`
- Every state-changing Cloud Function MUST additionally write an entry to `activity_log` via the shared `writeAuditLog()` helper, using an allowed `type` enum value. The entry is written inside the same transaction where practical; when transactional writes are not possible, the audit write MUST still complete before the function returns success.
- `activity_log` entries are immutable. The Firestore rule MUST enforce `allow update, delete: if false` for every `activity_log` document. Any rule that allows client-side update of `activity_log` is a defect.
- Audit fields MUST NOT be accepted from the client. `assignedBy`, `reviewedBy`, `resolvedBy`, `adminClosedBy`, and all `*At` timestamps MUST be derived server-side. A callable that copies `data.assignedBy` into Firestore is a defect.
- Timestamps MUST use `FieldValue.serverTimestamp()`, not `Date.now()` or `new Date()`. Client-side clocks are untrusted.

**Rationale:** Without per-action accountability, a dispute over "who force-closed this job at that amount" becomes unanswerable. The audit trail is also the forensic surface for detecting compromised admin accounts.

### XII. Defense in Depth (NON‑NEGOTIABLE)

No single control is trusted. Every privileged action MUST pass through at least two independent layers.

- **App Check** MUST be active on every Firebase surface that ships: mobile (Play Integrity / App Attest) and web (reCAPTCHA Enterprise v3). Firebase App Check enforcement MUST be **enabled** (not monitor-only) for Firestore, Storage, and Cloud Functions before Spec 005 is considered complete.
- **Firestore rules remain the first line of defense even after Cloud Functions take over.** Cloud Functions using the Admin SDK bypass rules, but direct-client writes do not. Rules MUST NOT be relaxed "because the CF handles it." When a CF takes ownership of a write path, the corresponding client-direct path in the rules MUST be closed (`allow write: if false`) rather than left wide open.
- **Stats collection** (`stats/global`) MUST transition to `allow write: if false` in Phase 5 in the same deploy that publishes the event-driven CFs (atomic deploy per Principle IV).
- **CF inputs are validated even though rules would also catch invalid writes.** Rule enforcement is not a substitute for input validation (Principle X); they enforce different threat models.
- **Web app sign-in** MUST rely on `authStateChanges()` and MUST re-verify admin role on every mount of the dashboard shell, not only at login. Token refresh failures MUST force a redirect to the login screen.
- **Firestore indexes** that power admin queries MUST be explicit in `firestore.indexes.json`. Implicit/auto-generated indexes from console-driven queries are forbidden because they make deploys non-reproducible.
- **Dependency hygiene**: `cd functions && npm audit --production` MUST report zero high/critical vulnerabilities before any `firebase deploy --only functions`. `cd admin_web && flutter pub outdated` is reviewed at each spec's plan phase; known-vulnerable packages MUST be upgraded before deploy.

**Rationale:** Every Firebase breach post-mortem traces back to "rule relaxed because the function handles it" or "App Check was monitor-only so the attacker called the function directly." Two independent controls on every path is the only cheap defense.

### XIII. Safe Error Reporting & Logging (NON‑NEGOTIABLE)

Errors surfaced to clients MUST NOT leak internal state, and server logs MUST NOT contain secrets or personal data.

- Cloud Functions MUST catch non-`HttpsError` exceptions at the top level and re-throw them as `HttpsError('internal', 'Unexpected error')`. Raw stack traces, Firestore error messages, or Node exception strings MUST NEVER reach the client.
- Logs MUST NOT include: Firebase ID tokens, OAuth refresh tokens, reCAPTCHA tokens, `context.auth.token.*` values, user passwords, customer phone numbers beyond the last 4 digits, full document contents of `users/*`, or `screenshotUrl` values from `payments/*`.
- `console.log(data)` where `data` is the full callable payload is forbidden for callables that touch `payments`, `users`, or `support_chats/{chatId}/messages`. Log the field names that are present, not the values.
- Error messages shown in the admin web UI on a failed CF call MUST use the `HttpsError.message` field only. They MUST NOT display raw network/fetch errors or JSON blobs from the failed response body.
- `firebase functions:log` output, Cloud Logging exports, and any screenshot pasted into a bug report MUST be reviewed for the forbidden fields above before being shared outside the team. Redact before sharing.
- Crashlytics / analytics events on mobile MUST NOT include PII beyond the signed-in UID, and even the UID is only included when strictly required for debugging.

**Rationale:** Many Firebase leaks are not exfiltration from Firestore at all — they are log exports, support tickets, and bug-report screenshots containing tokens. Treat the logging surface as if it is public.

## Technology Constraints

**Admin Web App (`admin_web/`):**
- Framework: Flutter Web
- Allowed packages: `firebase_core`, `firebase_auth`, `cloud_firestore`, `cloud_functions`, `google_sign_in`, `google_fonts`, `firebase_app_check`
- Forbidden packages: `image_picker`, `flutter_image_compress`, `location`, `geolocator`, `video_player`, `flutter_local_notifications`, `sign_in_with_apple`, `workmanager`, `flutter_native_splash`
- Build command: always `--web-renderer html`

**Cloud Functions (`functions/`):**
- Language: TypeScript (strict mode)
- Runtime: Node.js 18
- Admin role verification: Firestore doc read (`users/{uid}.role == 'admin'`), NOT Custom Claims
- Shared helpers: `verify-admin.ts` and `audit-log.ts` MUST be imported by every write function; re-implementing either inline is forbidden.

**Firebase Project:**
- Project ID: `syana-ea75a`
- Hosting site name: `syanat-admin`
- Firestore rules: root `firestore.rules`
- Storage rules: root `storage.rules`
- Config: root `firebase.json`

## Spec Sequence (Migration Phases → SpecKit Features)

| Spec | Feature | Migration Phases | Prerequisite |
|------|---------|-----------------|--------------|
| 001 | Firestore Rules Hardening | Phase 2 | None |
| 002 | Cloud Functions | Phase 3 + 4 | Spec 001 deployed |
| 003 | Event-Driven Stats | Phase 5 | Spec 002 deployed |
| 004 | Admin Web Shell | Phase 6 | None (can parallel with 001–003) |
| 005 | Admin Web Features | Phase 7 | Spec 002 + 003 + 004 deployed |
| 006 | Mobile Cleanup | Phase 8 | Spec 005 verified |

## Governance

- This constitution supersedes any default SpecKit template assumptions.
- Every spec's plan.md MUST include a "Constitution Check" section confirming compliance with Principles I through XIII. Plans that do not enumerate Principles VIII–XIII explicitly will be rejected.
- If a spec needs to violate a principle (e.g., touching root `lib/` before Spec 006), the violation MUST be documented with rationale in the plan.md before implementation begins. Violations of Principles VIII–XIII additionally require a written security-review note attached to the plan.

### Amendment Procedure

- Amendments are proposed by opening a PR that modifies this file along with a bumped version line and a populated Sync Impact Report at the top of the file.
- Amendments that add, remove, or redefine a principle MUST cite the migration-plan section or spec that motivated the change.
- Amendments affecting Principles VIII–XIII MUST be reviewed by an engineer with Firebase project owner access before merge.

### Versioning Policy

- Semantic versioning, three parts (`MAJOR.MINOR.PATCH`).
- MAJOR: a principle is removed, a principle is redefined in a backward-incompatible way, or a governance gate is weakened.
- MINOR: a new principle is added, or an existing principle is materially expanded.
- PATCH: wording clarifications, typo fixes, rationale edits that do not change the rule.
- The version line at the bottom of this file MUST match the version in the Sync Impact Report.

### Security Review Gate

Every plan.md in Specs 002 through 006 MUST attach a Security Review Gate table with one row per principle VIII–XIII, each row stating: the specific control the spec implements, the file path where that control lives, and how the control will be verified (rule playground scenario, emulator test, code review checklist, etc.). A plan that leaves any row blank cannot enter implementation.

Security-relevant defects discovered after deploy (missing `affectedKeys()`, missing `verifyAdmin`, missing owner check, credential in git history, log leak) MUST be tracked as a dedicated follow-up spec or hotfix and MUST NOT be silently patched into an unrelated spec.

### Compliance Review

- At the end of each spec, the team runs the spec's plan-level Security Review Gate as a checklist on the actually-deployed artifacts.
- At the end of the migration (Spec 006 sign-off), the entire constitution is reviewed against production. Any principle that cannot be evidenced on a live surface triggers an immediate remediation spec before the migration is considered closed.

**Version**: 1.1.0 | **Ratified**: 2026-04-13 | **Last Amended**: 2026-04-13
