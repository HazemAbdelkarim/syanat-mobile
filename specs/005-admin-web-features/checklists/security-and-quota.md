# Security & Quota Requirements-Quality Checklist: Spec 005 — Admin Web App Feature Screens

**Purpose**: Validate that the **requirements themselves** for security (privilege isolation, secret handling, input sanitization, error-detail leakage, XSS) and Firebase quota bounding (query limits, stream lifecycle, rate-limit / abuse surface) are complete, clear, consistent, measurable, and free of gaps before any code is written. **This is a release-gate checklist**, not a test plan.
**Created**: 2026-04-19
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md) · [tasks.md](../tasks.md)
**Depth**: Standard · **Audience**: Reviewer (PR + release gate) · **Focus**: Security + Quota (equal weight)

**How to read an item**: every item asks a question about what is (or is not) **written** in the spec/plan/contracts. Mark `[x]` if the requirement is already present at the required quality bar; leave `[ ]` and add an inline note if the requirement is ambiguous, missing, or internally conflicting. Items flagged `[Gap]` are pre-identified as missing — satisfying them usually means updating spec.md or plan.md before `/speckit.implement`.

---

## Privilege Isolation Requirement Quality

- [ ] CHK001 Is the set of "privileged admin writes" that MUST flow through a Cloud Function enumerated exhaustively, or only via examples? [Completeness, Spec §FR-021]
- [ ] CHK002 Is the allow-list of direct Firestore writes (`markSupportChatReadByAdmin`, `closeSupportChat`, `sendSupportMessage`) tied explicitly to the `firestore.rules` line ranges that authorize them? [Traceability, Spec §FR-013 + contracts/admin-firebase-service.md §`markSupportChatReadByAdmin`]
- [ ] CHK003 Is the requirement that every screen be mounted beneath `AuthGate` quantified with a grep-able invariant (e.g., "zero `Navigator.push` that bypasses `AuthGate`")? [Measurability, Spec §FR-022]
- [ ] CHK004 Is the admin-role check on sign-in documented as a single source of truth, or could two call sites drift apart? [Consistency, Spec §FR-022]
- [ ] CHK005 Are the exact six collections that MUST NOT be written to directly from the admin web app (`jobs`, `payments`, `stats`, `activity_log`, plus the two implicit ones: `users`, `service_requests`) listed as a closed set? [Completeness, Gap]
- [ ] CHK006 Is SC-003's grep phrasing tight enough that a reviewer knows exactly which regex to run, or is "direct writes" left open to interpretation? [Clarity, Spec §SC-003]
- [ ] CHK007 Is the behavior when an admin loses their role mid-session specified (does the next callable's `permission-denied` force-sign-out, and is that defined in one place)? [Coverage, Exception Flow, Spec §FR-041 and contracts/admin-cloud-functions.md §assignJob error table]
- [ ] CHK008 Is privilege isolation for the support-chat subcollection (`support_chats/{id}/messages`) explicitly scoped — i.e., the admin may create messages but may NOT create or delete parent chats from this app? [Completeness, Gap]

## Secret & Config Leak Prevention Requirement Quality

- [ ] CHK009 Is the list of artifacts forbidden from `.claude/AdminWebApp/` enumerated (service-account JSON, reCAPTCHA keys, Firebase config beyond `main.dart`) vs. left as a general warning? [Completeness, Spec §FR-025]
- [ ] CHK010 Is the re-use of Spec-004's `main.dart` Firebase config the explicit source of truth, with a forbidden-pattern statement against introducing a second one? [Clarity, Spec §FR-025]
- [ ] CHK011 Are `print` / `debugPrint` redaction requirements enumerated by exact field name (`email`, `phone`, `address`, `screenshotUrl`), or generalized and therefore interpretation-dependent? [Completeness, Spec §FR-026]
- [ ] CHK012 Is the `kDebugMode` vs release-mode distinction for logs explicit, or could a reviewer miss that a `debugPrint` is still a leak in a debug build reviewed by a non-admin? [Clarity, Spec §FR-026]
- [ ] CHK013 Is there a requirement-level statement that source-control hygiene (no credentials in `pubspec.yaml`, `firebase.json`, any `.env`) is in scope for this spec's grep gate? [Gap]
- [ ] CHK014 Are build-artifact requirements (e.g., `flutter build web --release` strips debug logs) traced to a specific SC or release gate? [Traceability, Spec §SC-009]
- [ ] CHK015 Is the requirement that App Check tokens are attached automatically (no manual handling in this spec) stated, or only assumed via Spec-004 inheritance? [Clarity, Gap — plan.md Constitution Principle XI row references it but spec.md does not]

## Input Sanitization Requirement Quality

- [ ] CHK016 Are the three free-text length caps (500 for reject-payment reason, 1000 for dispute reason, 2000 for support message) listed next to each other to make consistency auditable? [Consistency, Spec §FR-036]
- [ ] CHK017 Is "trimmed before use" defined — i.e., is trimming done on raw whitespace only, or also zero-width / RTL-override characters? [Clarity, Ambiguity, Spec §FR-036]
- [ ] CHK018 Is the requirement that caps are enforced both in the UI (maxLength) AND in the wrapper (ArgumentError) — defense-in-depth — explicit? [Completeness, Spec §FR-036 + contracts/admin-cloud-functions.md §rejectPayment]
- [ ] CHK019 Is the remaining-chars counter requirement precise about what it counts (grapheme clusters vs. Dart `String.length` UTF-16 code units)? [Ambiguity, Spec §FR-036]
- [ ] CHK020 Are numeric-input requirements (reject `NaN`, `Infinity`, negative; cap at 1,000,000) applied identically to Force-Close amount AND Dispute override amount, or are there subtle per-field differences? [Consistency, Spec §FR-038]
- [ ] CHK021 Is the doc-ID regex `^[A-Za-z0-9_-]{10,80}$` justified against the observed Firestore ID lengths in the existing collections, or picked arbitrarily? [Clarity, Traceability, Spec §FR-039]
- [ ] CHK022 Does the spec say what happens when a user-supplied reason contains characters that the Cloud Function later rejects (e.g., over the server's cap, which may be different)? [Coverage, Gap]
- [ ] CHK023 Are the three currency / money fields (Force-Close amount, dispute override amount, any payment `amountPaid` display) consistent in locale handling (decimal separator, rounding) across the spec? [Consistency, Gap]

## Exception-Detail / Error-Surface Requirement Quality

- [ ] CHK024 Is the ban on reading `FirebaseFunctionsException.details` stated uniformly in spec.md FR-023, plan.md Security Review Gate, and contracts/admin-cloud-functions.md §Error handling, with no loophole for "debug" or "admin-only" builds? [Consistency, Spec §FR-023, §SC-006]
- [ ] CHK025 Is the SC-006 grep regex (`.details`) precise enough — could it false-match legitimate Firestore field names like `.details` on user documents? [Measurability, Ambiguity, Spec §SC-006]
- [ ] CHK026 Is the required user-facing error format (`"${code}: ${message}"`) specified verbatim, or left to implementer choice? [Clarity, Spec §FR-023 + contracts/admin-cloud-functions.md §Error handling]
- [ ] CHK027 Does the spec differentiate transient errors (SnackBar) from fatal / dialog errors (inline Text), or does FR-020 leave this at implementer discretion? [Clarity, Ambiguity, Spec §FR-020 and research R-10]
- [ ] CHK028 Is there a requirement that stream errors (not just callable errors) are surfaced through the same helper, or could they route around `CallableErrorView`? [Consistency, Coverage, Gap]
- [ ] CHK029 Is the requirement that auth errors (`FirebaseAuthException`) go through the same helper as callable errors stated with the same `code: message` format? [Consistency, Spec §FR-023 + contracts/admin-cloud-functions.md §CallableErrorView.fromException]

## XSS / Markup-Injection Requirement Quality

- [ ] CHK030 Is the ban on `Html`, `RichText`, and "any markup-parsing widget" enumerated as a closed set, or open-ended ("any widget that parses markup" — how does a reviewer decide)? [Clarity, Ambiguity, Spec §FR-037]
- [ ] CHK031 Is the SC-007 grep regex (`Html\(|RichText\(`) sufficient, or does it miss alternative markup widgets (`Linkify`, `Markdown`, `FlutterHtml`, custom `TextSpan` with user-controlled strings)? [Coverage, Completeness, Spec §SC-007]
- [ ] CHK032 Does the spec require that the `labelTemplate` interpolation in `activity_icons.dart` uses `String.replaceAll` (a plain string op) rather than anything that could evaluate or parse? [Completeness, contracts/constants.md §`activity_icons.dart` Interpolation rule]
- [ ] CHK033 Is the requirement that doc-ID values are passed through `safeDocIdForUi` before interpolation stated at the callsite level (each label-render call), not just at the utility's definition? [Clarity, Traceability, Spec §FR-039]
- [ ] CHK034 Is there a requirement covering clipboard content, tooltips, or any non-`Text()` surface that can render user-controlled strings (e.g., `Tooltip.message`, `SelectableText`, `SemanticsLabel`)? [Coverage, Gap]

## Firestore Quota-Bounding Requirement Quality

- [ ] CHK035 Are all eight numeric query limits (FR-001…FR-008) centralized in one table so a reviewer can spot-check them against the contract queries? [Consistency, Spec §FR-001 through §FR-008 + contracts/admin-firebase-service.md]
- [ ] CHK036 Is the prohibition against `collectionGroup` queries and cross-collection client joins stated once in spec.md AND echoed in the contract, without exceptions? [Consistency, Spec §FR-028]
- [ ] CHK037 Is the requirement that `streamUnreadSupportCount` uses a bounded stream (not `.count()` aggregation) explained with the cost rationale, so a later implementer doesn't "optimize" it to `.count()`? [Clarity, Spec §FR-006 + research R-7]
- [ ] CHK038 Are the active-job `whereIn` status strings (`activeJobStatusStrings`) specified to match the server-side enum, and is there a checkpoint that rotates both in sync if a status is renamed? [Consistency, Spec §FR-003 + contracts/constants.md §`job_status.dart`]
- [ ] CHK039 Is pagination explicitly deferred (research R-6), AND is the forbidden-alternative (`offset`) explicitly banned for the day pagination is added (FR-031)? [Consistency, Spec §FR-031 + research R-6]
- [ ] CHK040 Is the requirement "no new composite indexes" traced to an actual enumeration of existing indexes in `firestore.indexes.json`, so a reviewer can grep that the claim holds? [Traceability, Spec §FR-032 + research R-4]
- [ ] CHK041 Is the monthly-read budget (SC-012) quantified with a number, or only stated as "within the projected envelope" without a baseline in research.md? [Measurability, Ambiguity, Spec §SC-012]

## Stream Lifecycle & Leak Prevention Requirement Quality

- [ ] CHK042 Is FR-029's invariant phrased as a grep-able rule (count of `StreamSubscription<` fields == count of `.cancel()` in `dispose()` bodies) so SC-005's audit is mechanical? [Measurability, Spec §FR-029, §SC-005]
- [ ] CHK043 Is the lifecycle of the shell-scope unread-badge stream (opened in `DashboardScreen.initState`, cancelled in `dispose`) specified with exactly one instance, preventing accidental duplication when a section re-mounts? [Clarity, Spec §FR-030 + research R-7]
- [ ] CHK044 Are per-chat message streams (Support) required to be cancelled when the user navigates away, AND is the behavior on repeated `Navigator.pop` defined? [Coverage, contracts/screen-contracts.md §Screen: Support]
- [ ] CHK045 Is there a requirement that `StreamBuilder` is the default and a `StreamSubscription<T>` field is the exception (justified only for cross-frame state like the badge count)? [Clarity, Spec §FR-029, Gap]
- [ ] CHK046 Is the behavior on hot-reload / hot-restart specified so developers do not accidentally leak streams when iterating locally? [Coverage, Gap]
- [ ] CHK047 Is the requirement that tab switches inside Jobs (Requested/Active/Completed) do NOT close+reopen streams every switch (e.g., `AutomaticKeepAliveClientMixin`) specified, or left as a performance footgun? [Gap, contracts/screen-contracts.md §Screen: Jobs]

## Callable Abuse-Surface & Rate-Limit Requirement Quality

- [ ] CHK048 Is the 500 ms post-success button lockout (FR-033) specified as an explicit `bool _justSucceeded` + `Timer` pattern rather than `Future.delayed`, AND is the `Future.delayed` anti-pattern called out as forbidden? [Consistency, Clarity, Spec §FR-033 + contracts/admin-cloud-functions.md §Forbidden patterns]
- [ ] CHK049 Is the "no automatic retry" requirement (FR-034) uniformly stated across spec.md, plan.md, and the callable contract, with no exception for "safe to retry" cases (the user has to re-click — always)? [Consistency, Spec §FR-034]
- [ ] CHK050 Is the requirement that `sendSupportMessage` respects the existing Firestore-rules throttle quantified by line-ref to `firestore.rules`, with an explicit STOP-spec clause if the throttle is missing? [Traceability, Spec §FR-035]
- [ ] CHK051 Is there a requirement that each callable wrapper enforces client-side validation identical to the server's, so the server never has to reject trivially-bad payloads (defense-in-depth)? [Completeness, Spec §FR-036 through §FR-038 + contracts/admin-cloud-functions.md]
- [ ] CHK052 Is the region-pinning of `FirebaseFunctions.instanceFor(region: 'europe-west1')` stated as "exactly one field, every call goes through it", so multiple instances (one per method) cannot accidentally drift? [Clarity, Spec §FR-009 + contracts/admin-cloud-functions.md §Shared setup]
- [ ] CHK053 Are the client-side `ArgumentError` paths (empty `jobId`, empty `reason`) specified as synchronous throws BEFORE the network call, preventing a pointless round-trip under abuse? [Completeness, contracts/admin-cloud-functions.md §assignJob, §rejectPayment, §resolveDispute, §closeJob]

## Concurrency & Stale-State Requirement Quality

- [ ] CHK054 Is the behavior on "another admin already resolved this" quantified with a specific error code (`failed-precondition`) AND a specific UI surface (SnackBar "Dispute no longer pending")? [Clarity, Spec §FR-042 + contracts/admin-cloud-functions.md §resolveDispute UI wiring]
- [ ] CHK055 Is idempotency of Force-Close specified identically in FR-040 (UI), contracts/admin-cloud-functions.md §closeJob, AND server Principle X so the three cannot drift? [Consistency, Spec §FR-040]
- [ ] CHK056 Are concurrent-admin race scenarios (two admins clicking Approve on the same payment) covered by a requirement, not only by "the stream will correct it"? [Coverage, Spec §FR-041 / §FR-042]
- [ ] CHK057 Is the requirement "no optimistic UI on callable writes" stated explicitly, not just implied by "wait for server truth within 2 s"? [Clarity, contracts/admin-cloud-functions.md §approvePayment UI wiring]

## Audit Trail & Accountability Requirement Quality

- [ ] CHK058 Is the 1:1 mapping "one privileged admin write → exactly one `activity_log` entry" specified as an invariant, with the auditing method (post-27-scenario count) stated? [Measurability, Spec §SC-011]
- [ ] CHK059 Are the server-emitted audit types (`job_assigned`, `payment_approved`, `payment_rejected`, `dispute_resolved`, `job_force_closed`, `account_created`, `job_requested`, `job_completed`, `job_cancelled`) reconciled with actual `functions/src/stats/*` emissions via a grep-step requirement? [Traceability, research R-3 + contracts/constants.md §`activity_icons.dart`]
- [ ] CHK060 Is the behavior for unknown audit types (`unknownActivityStyle`) explicitly required to render without throwing, so a new server type shipped ahead of a client update does not break the feed? [Coverage, Edge Case, contracts/constants.md §`activity_icons.dart`]
- [ ] CHK061 Is there a requirement that the acting admin's UID appears in every emitted `activity_log` entry, and that the client renders it when available? [Coverage, Gap — SC-011 mentions the UID but FR-019 does not require the UI to render it]

## Dependencies, Assumptions, Conflicts & Exclusions

- [ ] CHK062 Is the assumption "Spec 002 admin callables are deployed in `europe-west1`" listed as a pre-flight check (quickstart.md §0) AND as a validated research finding (R-1), so it cannot silently drift? [Assumption, Traceability, quickstart.md §0 + research R-1]
- [ ] CHK063 Is the assumption "Spec 003 stats triggers have fired at least once" verifiable (stats/global has all 6 fields non-null) rather than a black-box belief? [Assumption, Measurability, quickstart.md §0 check 4]
- [ ] CHK064 Is the dependency on existing composite indexes (research R-4) documented with the exact index keys, so a reviewer can cross-check `firestore.indexes.json`? [Traceability, Dependency]
- [ ] CHK065 Is there a documented conflict-resolution path if the client-side cap (e.g., 500 chars) differs from the server-side cap in the callable? [Ambiguity, Gap, Spec §FR-036]
- [ ] CHK066 Is the out-of-scope list (FR-043 mobile, FR-044 new callables, FR-045 rules) phrased with absolute "MUST NOT" language, or weak "should not" that a reviewer could override? [Clarity, Spec §FR-043, §FR-044, §FR-045]
- [ ] CHK067 Is the dependency on `flutter pub outdated` passing pre-implementation (T005, research R-8) specified with a failure criterion (known CVE published since lock), not a judgment call? [Clarity, Measurability, research R-8]
- [ ] CHK068 Does the spec document a single place to look when a new server-emitted audit type is added (i.e., "update `activity_icons.dart` + re-run SC-006 grep"), or is the update path spread across files? [Consistency, contracts/constants.md §`activity_icons.dart` + research R-3]

## Ambiguities & Conflicts to Resolve Before `/speckit.implement`

- [ ] CHK069 Does FR-009's reference to `FirebaseFunctions.instance.httpsCallable(...)` conflict with contracts/admin-cloud-functions.md §Shared setup requiring `FirebaseFunctions.instanceFor(region: 'europe-west1')`? [Conflict, Spec §FR-009 vs contracts/admin-cloud-functions.md §Shared setup]
- [ ] CHK070 Is the spec consistent on whether the UI surfaces the admin's own UID anywhere (for "acting as" confidence), or is it only captured server-side? [Ambiguity, Gap]
- [ ] CHK071 Does "zero console errors" (SC-001, SC-009) cover `console.warn` and `console.info`, or only `console.error`? [Ambiguity, Spec §SC-001 / §SC-009]
- [ ] CHK072 Is the grep-gate phrasing in SC-004 ("`.snapshots()` without `.limit(` on the preceding chain") precise enough to avoid false-positives on non-collection snapshots (e.g., `DocumentReference.snapshots()` on a single doc, which has no `.limit`)? [Ambiguity, Measurability, Spec §SC-004]
- [ ] CHK073 Are the post-MVP exclusions (fetchRecentUsers, fetchRecentActivity, initializeStatsGlobal) documented with the rationale so a future spec can reinstate them without re-deriving the logic? [Traceability, contracts/admin-firebase-service.md §Methods REMOVED]

---

## Notes

- **Mark `[x]`** only when the requirement is present at the quality bar this item asks about. **Mark `[ ]` + inline note** for anything else.
- Items flagged `[Gap]` are known missing; resolving each usually means adding a line to `spec.md` or `plan.md` BEFORE `/speckit.implement`.
- Items flagged `[Ambiguity]` / `[Conflict]` usually mean editing two places to re-align wording, not writing code.
- This checklist tests the **requirements**, not the code. Code-level grep gates (SC-004, SC-005, SC-006, SC-007 and the seven grep-gates in `tasks.md` Phase 9) are the *implementation-side* counterparts — passing them is necessary, but not sufficient. The items here must be resolved first.
- After resolution, feed the uncovered gaps back to `/speckit.plan` (if scoping changes) or directly into `/speckit.analyze` for a final consistency pass.
