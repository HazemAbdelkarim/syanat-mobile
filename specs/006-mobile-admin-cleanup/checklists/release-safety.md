# Release Safety Requirements Quality Checklist: Mobile Admin Cleanup

**Purpose**: Validate that the release-safety requirements in `spec.md` are complete, clear, consistent, and measurable enough to serve as an enforceable gate before Release 1 and Release 2 ship.
**Created**: 2026-04-20
**Feature**: [spec.md](../spec.md)

**Note**: This checklist is a "unit test suite for English" — it tests whether the requirements are **written well**, not whether the implementation works. Each item asks whether the specification itself is adequate. Items marked `[Gap]` flag requirements that appear to be missing; items marked `[Clarity]` flag under-quantified language; items marked `[Conflict]` flag internal contradictions.

---

## Two-Release Sequencing Requirements

- [ ] CHK001 Is the prohibition on bundling Release 1 and Release 2 into a single pull request explicit enough to be rejected at review without judgment calls? [Clarity, Spec §FR-020]
- [ ] CHK002 Are the three required artifacts per release (pull request, version-control tag, store submission) enumerated in a way that prevents any one being forgotten? [Completeness, Spec §FR-020]
- [ ] CHK003 Is the two-store-submission requirement (Google Play AND App Store) unambiguous, or could a single-store submission be interpreted as compliant? [Clarity, Spec §FR-020]
- [ ] CHK004 Is the sequencing between Release 1 "generally available" and the observation gate start explicit (e.g., the clock starts on the later-of-two-stores GA date)? [Gap, Spec §FR-020, §FR-021]
- [ ] CHK005 Are the shared branches subject to the no-force-push rule explicitly enumerated (main? release branches? feature branches?) or left implicit? [Completeness, Spec §FR-025]

---

## Observation Gate Requirements

- [ ] CHK006 Is the 7-day observation window quantified with a specific time unit and zone (UTC calendar days vs. rolling 24-hour windows from GA)? [Clarity, Spec §FR-021]
- [ ] CHK007 Are the conditions for resetting the observation clock unambiguously defined when a non-zero `admin_redirect_shown` event occurs (does the clock reset on the day of the event, or the day after)? [Clarity, Spec §FR-021]
- [ ] CHK008 Does the test-sign-in exception requirement specify where the exception is recorded, what fields are required (date, hashed UID, engineer, reason), and who approves it? [Completeness, Spec §FR-021]
- [ ] CHK009 Is the event source of truth (Firebase Analytics, not Firebase Authentication logs) pinned in a way that prevents substitution with a different source during implementation? [Consistency, Spec §FR-021, §Assumptions]
- [ ] CHK010 Does the spec define behavior when Firebase Analytics is temporarily unavailable, delayed beyond 24 hours, or reports zero events erroneously due to pipeline lag? [Edge Case, Gap]
- [ ] CHK011 Is the "hashed UID" matching rule for the exception list specified precisely enough that an implementer cannot mismatch hash formats (e.g., prefix length, casing, encoding)? [Clarity, Spec §FR-021, §FR-007]

---

## Rollback Requirements

- [ ] CHK012 Is the rollback target for Release 2 defined as a specific commit reference (not a branch name, not a tag alias, not a state description)? [Clarity, Spec §FR-022]
- [ ] CHK013 Is the revert-smoke-test success criterion quantified — does "successful" mean "build passes", "regression passes", or merely "compiles"? [Clarity, Spec §FR-022]
- [ ] CHK014 Are the platforms on which the revert-smoke-test must pass explicitly named (Android AND iOS)? [Completeness, Spec §FR-022]
- [ ] CHK015 Are requirements specified for Release 1 rollback, or is it intentionally excluded from scope with that exclusion documented? [Coverage, Gap]
- [ ] CHK016 Are the rollback decision authorities (who approves, who executes) specified, or does the spec assume it is self-serve? [Gap]

---

## Binary Size Attestation Requirements

- [ ] CHK017 Is the "same build machine and toolchain version" requirement measurable — does the spec define "same" as exact hostname, exact toolchain pin, exact Docker image, or an equivalent reproducible environment? [Clarity, Spec §FR-024]
- [ ] CHK018 Is the "primary platform" in SC-008 defined unambiguously (Android APK? iOS IPA? both must be smaller?) or open to interpretation? [Clarity, Spec §SC-008]
- [ ] CHK019 Is the positive-byte-count delta in SC-008 quantified with a minimum threshold (e.g., ≥ 10 KB), or is any positive number — even 1 byte — sufficient to pass? [Measurability, Spec §SC-008]

---

## Commit Hash & PR Record Requirements

- [ ] CHK020 Are the pre-deletion and post-deletion commit hashes required to appear in a consistent location within the Release 2 PR (e.g., a named section) or left to PR-author discretion? [Consistency, Spec §FR-023]
- [ ] CHK021 Are the commit-hash-recording requirements in FR-023 and FR-029 cross-referenced so the Release 2 PR and the SIGN_OFF.md cannot diverge? [Consistency, Spec §FR-023, §FR-029]

---

## Version-Control Safety Requirements

- [ ] CHK022 Is the prohibition on skipping version-control hooks (`--no-verify`), bypassing commit signing, and force-pushing specified with escape-hatch conditions (e.g., "only with written security-team approval"), or is it absolute? [Clarity, Spec §FR-025]
- [ ] CHK023 Does FR-025 name the specific flags and commands that are prohibited (`--no-verify`, `--no-gpg-sign`, `git push --force`) or rely on the implementer's interpretation of "skip" and "bypass"? [Clarity, Spec §FR-025]

---

## Post-Migration Monitoring Requirements

- [ ] CHK024 Is the Cloud Monitoring alert's "backend error rate" quantified with the exact metric surface (Cloud Functions errors? Firestore errors? Hosting 5xx? Combined rate?) and the data source? [Clarity, Spec §FR-026]
- [ ] CHK025 Is the "1% over a 5-minute window" threshold specified with the averaging semantics (percentage of requests? percentage of invocations? percentage of reads?) in a way that prevents ambiguity at alert-creation time? [Clarity, Spec §FR-026]
- [ ] CHK026 Does the test-fire requirement in SC-010 specify the expected outcome (specific paging channel, expected response time, acknowledgement mechanism)? [Completeness, Spec §SC-010]
- [ ] CHK027 Is the "counter document" referenced in FR-027 identified by exact Firestore path (`stats/global`), or by name only? [Clarity, Spec §FR-027]
- [ ] CHK028 Are the requirements for the 7-day zero-write observation (FR-027) specified to exclude backend-originated writes but include all client writes, with "client" defined unambiguously? [Clarity, Spec §FR-027]

---

## Sign-Off & Finalization Requirements

- [ ] CHK029 Is the SIGN_OFF.md file's location, format, and set of required signatories specified, or left to the implementer to invent? [Completeness, Spec §FR-029]
- [ ] CHK030 Is the "diverging" definition for shared-code duplication (FR-028, clarified 2026-04-20) measurable without implementer judgment calls, given that "trivial refactors" is itself a judgment term? [Clarity / Measurability, Spec §FR-028]
- [ ] CHK031 Are the file-pair comparison targets for duplication evaluation (which web-app files pair with which mobile files) enumerated in the spec, or left to implementer discovery during T054? [Coverage, Spec §FR-028]

---

## Scenario & Edge Case Coverage

- [ ] CHK032 Are requirements specified for the scenario where the observation gate fails permanently — e.g., admins keep signing in for 30+ days and never drop to zero? Is there a defined maximum wait, a path to Release 2 anyway, or a defined feature abandonment procedure? [Coverage, Edge Case, Gap]
- [ ] CHK033 Are requirements specified for the scenario where Release 1 ships but Release 2 is canceled (migration paused indefinitely)? Does admin redirect remain live forever, or is there an "unwind" path? [Coverage, Gap]
- [ ] CHK034 Are the actions during a Release 2 post-ship incident (>1% error rate triggering the FR-026 alert) specified — rollback? forward-fix? both in sequence? decision criteria for choosing? [Coverage, Gap]
- [ ] CHK035 Are requirements specified for the scenario where `admin_redirect_shown` event rate does NOT drop to zero within 48 hours of Release 2 (SC-007 violation) because a significant installed base is still on Release 1? Is this a sign-off blocker, or is residual allowed with written explanation? [Coverage, Spec §SC-007, Gap]

---

## Ambiguities & Conflicts

- [ ] CHK036 Does the spec distinguish consistently between "admin sign-in" (authentication event, measured from Firebase Auth) and "`admin_redirect_shown`" (analytics event, measured from Firebase Analytics)? Both phrases appear in gate-related text and could be conflated. [Ambiguity, Spec §US4, §FR-021, §SC-006]
- [ ] CHK037 Does US4 Acceptance Scenario 1 ("Release 1 has been live for fewer than 7 days") conflict with FR-021's event-count measurement by implying calendar-time measurement instead of event-based measurement? [Conflict, Spec §US4 AS1, §FR-021]

---

## Dependencies & Assumptions

- [ ] CHK038 Are the prerequisite specs (001–005) listed with specific production-stability thresholds rather than vague "shipped" states? For example, is "stable for at least 7 consecutive days" (§Assumptions) applied consistently or only to Spec 005? [Consistency, Spec §Dependencies, §Assumptions]
- [ ] CHK039 Is the assumption "deployed admin web URL confirmed at implementation time" backed by a named authority, document, or verification step — or is it left as implementer self-attestation? [Assumption, Spec §Assumptions]
- [ ] CHK040 Is the assumption of "two available store submission slots spaced accordingly" validated against the stated store review SLA, or left as a calendar-planning concern outside the spec? [Assumption, Spec §Assumptions]

---

## Traceability

- [ ] CHK041 Does every release-safety requirement (FR-020 through FR-029) have at least one corresponding measurable Success Criterion (SC-*), or are some requirements left without a measurable outcome? [Traceability, Spec §FR-020–§FR-029, §Success Criteria]
- [ ] CHK042 Does every Success Criterion related to release safety (SC-006, SC-008, SC-009, SC-010, SC-012) trace back to a specific Functional Requirement, so failure of an SC points to a specific FR for remediation? [Traceability, Spec §Success Criteria]

---

## Notes

- Check items off as completed: `[x]`. Add inline comments where a gap is confirmed and closed, or where a judgment call has been recorded.
- Items flagged `[Gap]` should either be closed by a spec amendment (preferred) or explicitly accepted as out-of-scope in the PR description, with a link back to the CHK ID.
- Items flagged `[Conflict]` MUST be resolved before implementation begins — a conflict discovered mid-implementation triggers a re-spec, not a judgment call.
- Items flagged `[Clarity]` can be closed either by spec amendment or by a definitive note in the Release 1 PR description that pins the interpretation for both releases (so Release 2 inherits the same reading).
