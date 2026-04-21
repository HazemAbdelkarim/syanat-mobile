# Quickstart: Firestore Rules Hardening

**Feature**: `001-firestore-rules-hardening`
**Audience**: The engineer (human or AI) implementing this spec.
**Reading order**: Read `spec.md` → `plan.md` → this file. Then execute this file top to bottom. Do not skip steps and do not reorder them.

This is the linear execution script. Every step is independently verifiable. Check the `[ ]` box once the step is complete.

---

## Step 0 — Prep

- [ ] **0.1** Confirm you are on branch `001-firestore-rules-hardening`.
  ```bash
  git rev-parse --abbrev-ref HEAD
  ```
  Expected output: `001-firestore-rules-hardening`.
- [ ] **0.2** Confirm the working tree is clean enough. Uncommitted changes unrelated to this spec should be stashed or committed first.
  ```bash
  git status --short
  ```
- [ ] **0.3** Open the four contract files side-by-side in your editor (you'll paste from them):
    - `specs/001-firestore-rules-hardening/contracts/firestore-rules.md`
    - `specs/001-firestore-rules-hardening/contracts/storage-rules.md`
    - `specs/001-firestore-rules-hardening/contracts/upload-photo-contract.md`
    - `specs/001-firestore-rules-hardening/data-model.md`
- [ ] **0.4** Confirm the Firebase CLI is authenticated and pointing at project `syana-ea75a`.
  ```bash
  firebase projects:list
  firebase use syana-ea75a
  ```

---

## Step 1 — Edit `firestore.rules`

Follow `contracts/firestore-rules.md` precisely. It has three edits.

- [ ] **1.1** Apply **Edit 1 (Admin assignment block)** from `contracts/firestore-rules.md`. Copy-paste the "After" snippet over the "Before" snippet.
- [ ] **1.2** Apply **Edit 2 (Admin dispute resolution block)**. Pay attention to the field name `disputeResolvedAt` (not `resolvedAt`).
- [ ] **1.3** Apply **Edit 3 (Admin cancellation block)**.
- [ ] **1.4** Save `firestore.rules`.
- [ ] **1.5** Diff the file:
  ```bash
  git diff firestore.rules
  ```
  The diff MUST show exactly three `affectedKeys().hasOnly([...])` additions inside `match /jobs/{jobId}` and NOTHING ELSE. If you see changes outside those three blocks, revert the file and try again.

### Common mistakes to watch for

- Accidentally deleting a trailing `) ||` — the rule chain will become syntactically invalid. `firebase deploy --only firestore:rules` will error early if this happens, but catching it at the diff stage is faster.
- Typing `resolvedAt` instead of `disputeResolvedAt` in Edit 2.
- Forgetting one of the three edits.

---

## Step 2 — Verify `firestore.rules` in the Rules Playground

- [ ] **2.1** Open Firebase Console → Firestore → Rules → paste the unsaved rule draft (or copy the file contents into the playground tab).
- [ ] **2.2** Run every scenario in `contracts/firestore-rules.md` §Verification (A1–A4, B1–B5, C1–C4). All 13 must match expectations.
- [ ] **2.3** If any scenario fails, STOP. Re-read the relevant rule block. Do not proceed until all 13 pass.

---

## Step 3 — Edit `lib/firebase_service.dart`

Follow `contracts/upload-photo-contract.md` precisely.

- [ ] **3.1** Grep for `uploadPhoto` to confirm the current location:
  ```bash
  grep -n "uploadPhoto" lib/firebase_service.dart
  ```
- [ ] **3.2** Open `lib/firebase_service.dart`, navigate to the `uploadPhoto` method.
- [ ] **3.3** Replace the method body with the "After" snippet from `contracts/upload-photo-contract.md`.
- [ ] **3.4** Save the file.
- [ ] **3.5** Diff the file:
  ```bash
  git diff lib/firebase_service.dart
  ```
  The diff MUST be confined to the `uploadPhoto` method. If you see changes elsewhere, revert and try again.
- [ ] **3.6** Run `flutter analyze` from the repo root:
  ```bash
  flutter analyze
  ```
  Expect zero new errors or warnings attributable to `firebase_service.dart`. Pre-existing warnings elsewhere in the tree are not this spec's problem — leave them alone.

### Do NOT at this step

- Do not build or deploy any `storage.rules` change yet.
- Do not touch `admin_web/`.
- Do not touch `functions/`.

---

## Step 4 — Commit the mobile change + Firestore rules

- [ ] **4.1** Review the full diff one more time:
  ```bash
  git diff
  ```
  You should see changes in:
    - `firestore.rules` (three `affectedKeys()` additions)
    - `lib/firebase_service.dart` (one method body)
  AND NOTHING ELSE. If `storage.rules` has been modified at this point, revert it — its deploy is gated on Step 6.
- [ ] **4.2** Stage the two files explicitly (do **not** use `git add .` or `git add -A`):
  ```bash
  git add firestore.rules lib/firebase_service.dart
  ```
- [ ] **4.3** Commit with an explicit message:
  ```bash
  git commit -m "Harden admin job write rules and prep techProfiles filename convention"
  ```
- [ ] **4.4** Push the branch:
  ```bash
  git push -u origin 001-firestore-rules-hardening
  ```

---

## Step 5 — Deploy Firestore rules, ship mobile release

These two can happen in parallel but both must be complete before Step 6.

### Step 5a — Firestore rules

- [ ] **5a.1** Dry-check by viewing the current deployed rules vs the local rules:
  ```bash
  firebase deploy --only firestore:rules --dry-run
  ```
  (If Firebase CLI does not support `--dry-run` on your version, fall back to deploying to a preview cloud.firestore? There is no standard preview channel for Firestore rules — the fallback is Step 5a.2 emulator test.)
- [ ] **5a.2** Start the Firestore emulator and import rules:
  ```bash
  firebase emulators:start --only firestore
  ```
  In a second terminal, re-run the Rules Playground scenarios from Step 2 against the emulator (or the Playground UI — either works).
- [ ] **5a.3** Deploy to production:
  ```bash
  firebase deploy --only firestore:rules
  ```
- [ ] **5a.4** Within 10 minutes of the deploy, run the three SMOKE tests from `contracts/firestore-rules.md` §"Smoke test against current mobile client" using a real admin build.

### Step 5b — Mobile release

- [ ] **5b.1** Merge the branch to `main` (or your release branch — whatever the mobile release process expects).
- [ ] **5b.2** Build release artifacts:
  ```bash
  flutter build apk --release
  flutter build ios --release
  ```
- [ ] **5b.3** Ship to the stores following the existing mobile release process. The constitution does not prescribe a store release process — use whatever the team already does.
- [ ] **5b.4** Mark the release shipped and start a waiting clock. Do NOT proceed to Step 6 until either: (a) 48 hours have elapsed with no upload failures in logs, or (b) ≥ 80% of technician uploads in the last 24 hours came from the new build.

---

## Step 6 — Deploy `storage.rules` change

**GATE**: Do not begin this step until Step 5b's waiting clock is done. If you are unsure, ask. Deploying early will break technician profile uploads from every not-yet-updated device.

- [ ] **6.1** Open `storage.rules` and apply **Edit 1** from `contracts/storage-rules.md`. Copy-paste the "After" snippet over the "Before" snippet.
- [ ] **6.2** Save the file.
- [ ] **6.3** Diff:
  ```bash
  git diff storage.rules
  ```
  The diff MUST be confined to the `match /techProfiles/{fileName}` block and MUST be exactly the single `&& fileName.split('_')[0] == request.auth.uid` addition. Nothing else.
- [ ] **6.4** Run every scenario in `contracts/storage-rules.md` §Verification in the Storage Rules Playground. All 7 must match expectations.
- [ ] **6.5** Stage and commit:
  ```bash
  git add storage.rules
  git commit -m "Enforce techProfiles owner check on storage writes"
  git push
  ```
- [ ] **6.6** Deploy:
  ```bash
  firebase deploy --only storage
  ```
- [ ] **6.7** Run the SMOKE-S1 test from `contracts/storage-rules.md` §"Real device smoke test" — an end-to-end profile photo upload from a real device running the new build.

---

## Step 7 — Post-deploy monitoring (72 hours)

- [ ] **7.1** For 72 hours, watch Firestore and Storage debug logs for `PERMISSION_DENIED` events attributable to admin UIDs on `/jobs/*` or to technician UIDs on `techProfiles/*`. Target: zero.
- [ ] **7.2** If any denial appears, capture the full event (path, op, UID, resource snapshot, request snapshot) before doing anything else. Do NOT revert the rules unless the denial is blocking user-visible functionality — triage first.
- [ ] **7.3** At the 72-hour mark, cross-check against `spec.md` §Success Criteria SC-001 through SC-006. All six should evaluate to pass.

---

## Step 8 — Close the spec

- [ ] **8.1** Mark every box in this quickstart `[x]`.
- [ ] **8.2** Mark every box in `contracts/firestore-rules.md` §Verification `[x]`.
- [ ] **8.3** Mark every box in `contracts/storage-rules.md` §Verification `[x]`.
- [ ] **8.4** Update `specs/001-firestore-rules-hardening/checklists/requirements.md` with a final sign-off note in the §Notes section.
- [ ] **8.5** Notify the reviewer (this is the point the "stronger model" reviews the execution).

---

## If something goes wrong

- **Firestore deploy fails on syntax**: check you did not delete a trailing `) ||` or typo the field name. `firebase deploy` prints the exact rule line.
- **Mobile admin client starts getting `PERMISSION_DENIED` on job writes after Step 5a**: the whitelist is missing a field the client writes. Diff the admin method in `lib/firebase_service.dart` against the whitelist in `data-model.md`. If a field is missing from the whitelist, that is a Spec 001 gap — fix it in a new commit and redeploy rules. Do NOT revert the whole spec.
- **Technician profile upload fails after Step 6**: the waiting clock in Step 5b.4 was too short. Rollback `storage.rules` to the pre-edit version and redeploy:
  ```bash
  git revert <commit-hash-of-step-6.5>
  firebase deploy --only storage
  ```
  Then wait longer.
- **Anything else**: STOP. Do not improvise. Escalate to the reviewer with: the step number you were on, the exact command output, and a copy of the current `git diff`.
