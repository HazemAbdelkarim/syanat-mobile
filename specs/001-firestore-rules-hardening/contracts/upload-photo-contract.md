# Contract: `uploadPhoto` filename convention

**Feature**: `001-firestore-rules-hardening`
**File**: `lib/firebase_service.dart`
**Method**: `static Future<String> uploadPhoto(XFile file, {String? folder})`
**Current location**: line 749 (verify with grep if it has shifted)

---

## Intent

When the caller passes `folder: 'techProfiles'`, the uploaded file's name MUST begin with the caller's Firebase Auth UID followed by an underscore. For every other folder, the filename convention remains `{timestampMillis}.jpg` so that no other call site in the app breaks.

---

## Contract

- **Input**: same as today — an `XFile` and an optional `String? folder`.
- **Output**: same as today — a `Future<String>` that resolves to the download URL.
- **New behaviour**: when `folder == 'techProfiles'`, the object written to Cloud Storage MUST have the path `techProfiles/{uid}_{timestampMillis}.jpg`, where `uid` is the UID of the currently-signed-in user.
- **Fallback for `uid == null`**: if there is no signed-in user (which should never happen on this code path), use the literal string `anon` as the uid. The storage rule will then reject the upload, which is the safe failure mode.
- **All other folders**: behaviour unchanged. Filename pattern stays `{timestampMillis}.jpg`.

---

## Pre-flight check

Open `lib/firebase_service.dart` and grep (or scroll) to the `uploadPhoto` method. Confirm the current body matches the **Before** snippet below. If it does not, STOP and escalate — the file has diverged from the plan.

```bash
grep -n "uploadPhoto" lib/firebase_service.dart
```

---

## Before

```dart
static Future<String> uploadPhoto(XFile file, {String? folder}) async {
  final ref = storage.ref().child(
    '${folder ?? 'uploads'}/${DateTime.now().millisecondsSinceEpoch}.jpg',
  );
  final compressed = await compressImage(file);
  await ref
      .putData(
        Uint8List.fromList(compressed),
        SettableMetadata(contentType: 'image/jpeg'),
      )
      .timeout(const Duration(seconds: 30));
  return await ref.getDownloadURL().timeout(const Duration(seconds: 10));
}
```

## After

```dart
static Future<String> uploadPhoto(XFile file, {String? folder}) async {
  final uid = getCurrentUser()?.uid ?? 'anon';
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final fileName = folder == 'techProfiles'
      ? '${uid}_$timestamp.jpg'
      : '$timestamp.jpg';
  final ref = storage.ref().child('${folder ?? 'uploads'}/$fileName');
  final compressed = await compressImage(file);
  await ref
      .putData(
        Uint8List.fromList(compressed),
        SettableMetadata(contentType: 'image/jpeg'),
      )
      .timeout(const Duration(seconds: 30));
  return await ref.getDownloadURL().timeout(const Duration(seconds: 10));
}
```

### What changed

- Added one line at the top of the method: `final uid = getCurrentUser()?.uid ?? 'anon';`
- Added one line: `final timestamp = DateTime.now().millisecondsSinceEpoch;`
- Replaced the inline `'${folder ?? 'uploads'}/${DateTime.now().millisecondsSinceEpoch}.jpg'` path string with a computed `fileName` that branches on `folder == 'techProfiles'`.
- Updated the `storage.ref().child(...)` call to use the new `fileName` variable.

No other behaviour changes. Compression, metadata, timeouts, and download URL retrieval are byte-identical.

### Things to NOT touch

- Do not change the `timeout` values.
- Do not change `compressImage` or its arguments.
- Do not change the content type.
- Do not add logging.
- Do not refactor `folder ?? 'uploads'` into a constant.

---

## Post-edit checks

1. **Static analysis**: `flutter analyze` — must show zero new errors or warnings attributable to `firebase_service.dart`. If the file had pre-existing warnings unrelated to `uploadPhoto`, leave them alone.
2. **Grep for stale call sites**: `grep -n "uploadPhoto" lib/` should still show the same set of call sites as before the edit. No caller needs to change.
3. **Manual smoke test on emulator / device build** (before shipping the release):
    - Sign in as a technician.
    - Go to the profile photo edit flow.
    - Upload a new photo.
    - Confirm the Firebase Storage console shows a file at `techProfiles/<uid>_<big-number>.jpg`.
    - Confirm the user's profile photo URL refreshes in the app.
4. **Non-regression on other folders**: upload via any non-`techProfiles` call site (if one exists in the current flows) and confirm the path is still `{folder}/{timestamp}.jpg` with no UID prefix.

---

## Why this file is touched in Spec 001

See `plan.md` §Complexity Tracking. The edit is a prerequisite for the storage rule change (FR-008, FR-009) and cannot be deferred to Spec 006 without leaving the `techProfiles` abuse vector open for the entire migration window.
