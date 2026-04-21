# Contract: `storage.rules` changes

**Feature**: `001-firestore-rules-hardening`
**File**: `storage.rules` (repository root)

> **IMPORTANT — DO NOT DEPLOY THIS EDIT EARLY.** This rule change MUST only be deployed AFTER the mobile release that adopts the new `{uid}_{timestamp}.jpg` filename convention has reached production and has a safe install base. See `research.md` R-5 for the exact ordering rule. `quickstart.md` step 6 gates on this.

---

## Pre-flight check

Open `storage.rules`. Confirm the `techProfiles` block is present at roughly lines 8–13 and looks like the "Before" snippet below. If it already contains a `fileName.split(...)` clause, the edit has already been applied and you are done — stop.

---

## Edit 1 — `techProfiles/{fileName}` write rule

### Before

```javascript
match /techProfiles/{fileName} {
  allow read:  if true;
  allow write: if request.auth != null
               && request.resource.size < 5 * 1024 * 1024   // 5 MB max
               && request.resource.contentType.matches('image/.*');
}
```

### After

```javascript
match /techProfiles/{fileName} {
  allow read:  if true;
  allow write: if request.auth != null
               && request.resource.size < 5 * 1024 * 1024   // 5 MB max
               && request.resource.contentType.matches('image/.*')
               && fileName.split('_')[0] == request.auth.uid;
}
```

### What changed

Exactly one new condition, appended with `&&`. The public `allow read: if true` line MUST remain untouched — legacy filenames under the `techProfiles/` prefix must stay readable.

### Things to NOT touch

- Do **not** change the `payment_proofs` block. It is out of scope.
- Do **not** change the catch-all `match /{allPaths=**}` deny. It is out of scope.
- Do **not** attempt to reorganise the match path to something like `/techProfiles/{uid}/{fileName}`. See `research.md` R-3 for why.

---

## Verification — Storage Rules Playground scenarios

Use the Firebase Console → Storage → Rules → "Rules playground" tab. For each scenario:
- **Simulation type**: `create`
- **Location**: `techProfiles/<fileName>` (fill in per scenario)
- **Authenticated**: Yes (fill in UID per scenario)
- **Size**: something under 5 MB
- **Content type**: `image/jpeg`

### Happy path

- [ ] **S1 ALLOW**: UID `tech_A`, filename `tech_A_1712345678901.jpg`.
  **Expected**: Allow.

### Owner mismatch

- [ ] **S2 DENY**: UID `tech_A`, filename `tech_B_1712345678901.jpg`.
  **Expected**: Deny.

### Legacy filename (no UID prefix)

- [ ] **S3 DENY (writes only)**: UID `tech_A`, filename `1712345678901.jpg` (old convention). This simulates an old mobile client that has not updated.
  **Expected**: Deny. This is the blast radius of not ordering the deploy correctly — hence research R-5.

### Read parity (must still work)

- [ ] **S4 ALLOW (read)**: Simulation type `get`, location `techProfiles/1700000000000.jpg` (a legacy filename), unauthenticated.
  **Expected**: Allow (public read preserved).

### Boundary conditions (sanity)

- [ ] **S5 DENY**: UID `tech_A`, filename `tech_A_1712345678901.jpg`, size 6 MB.
  **Expected**: Deny (size check still wins).
- [ ] **S6 DENY**: UID `tech_A`, filename `tech_A_1712345678901.txt`, content type `text/plain`.
  **Expected**: Deny (content-type check still wins).
- [ ] **S7 DENY**: No auth, filename `tech_A_1712345678901.jpg`.
  **Expected**: Deny (auth check still wins).

### Real device smoke test (after deploy)

- [ ] **SMOKE-S1**: Install the shipped mobile release on a real device, sign in as a technician, change profile photo. Expect success end-to-end (upload + `getDownloadURL` returns a URL).

All 8 boxes must be checked before this contract is considered satisfied.
