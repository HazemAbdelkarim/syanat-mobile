import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb, kDebugMode;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
// XFile comes via `flutter_image_compress` (which re-exports `cross_file`).
// `image_picker` is imported by callers that actually need the picker itself.
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

import 'job_status.dart' show calculateCancellationPenalty, canStartTrip;

/// Thrown when the caller needs to wait before retrying an order.
/// [remainingSeconds] is the rounded-up number of seconds left on the
/// server-side 60-second cooldown window.
class OrderCooldownException implements Exception {
  final int remainingSeconds;
  OrderCooldownException(this.remainingSeconds);
  @override
  String toString() =>
      'OrderCooldownException(remaining=${remainingSeconds}s)';
}

/// Thrown when the phone on the caller's stored user profile fails the
/// server-side phoneValid() rule. The UX should prompt the user to update
/// their profile phone before re-submitting.
class StoredPhoneInvalidException implements Exception {
  final String storedPhone;
  StoredPhoneInvalidException(this.storedPhone);
  @override
  String toString() =>
      'StoredPhoneInvalidException(phone=$storedPhone)';
}

/// Thrown when the caller has no users/{uid} profile document. The UX should
/// redirect to profile creation / login.
class MissingUserProfileException implements Exception {
  @override
  String toString() => 'MissingUserProfileException';
}

/// Thrown by image-upload paths when the compressed payload still exceeds
/// the 5 MB Firebase Storage rule cap on `payment_proofs/*`. Callers should
/// surface a "pick a smaller photo" message — this is unusually large media,
/// not a network or permission failure.
class ImageTooLargeException implements Exception {
  final int sizeBytes;
  ImageTooLargeException(this.sizeBytes);
  @override
  String toString() => 'ImageTooLargeException(size=$sizeBytes)';
}

/// Thrown on the web path when `package:image` cannot decode the raw bytes.
/// Indicates a corrupt or unusual file slipped past the picker; callers
/// should surface a "try a different photo" message.
class ImageDecodeException implements Exception {
  @override
  String toString() => 'ImageDecodeException';
}

/// Thrown by `deleteAccount` when the caller has one or more jobs in a
/// non-terminal status. Account deletion is blocked until those jobs are
/// completed or cancelled. [activeCount] is how many active jobs were found.
class AccountHasActiveJobsException implements Exception {
  final int activeCount;
  AccountHasActiveJobsException(this.activeCount);
  @override
  String toString() => 'AccountHasActiveJobsException(active=$activeCount)';
}

/// Thrown by `deleteAccount` when Firebase Auth refuses the final
/// `user.delete()` because the user's last sign-in is too old. The UI should
/// sign the user out, prompt them to sign in again, and let them retry.
class RequiresRecentLoginException implements Exception {
  @override
  String toString() => 'RequiresRecentLoginException';
}

class FirebaseService {
  static FirebaseAuth auth = FirebaseAuth.instance;
  static FirebaseFirestore firestore = FirebaseFirestore.instance;
  static FirebaseStorage storage = FirebaseStorage.instance;

  /// One-shot, in-memory message displayed by `LoginScreen` after the user is
  /// force-signed-out by `AuthGate` for having an incomplete profile. Cleared
  /// by `LoginScreen` once shown. Process-scoped — never persisted.
  static String? pendingAuthSnackEn;
  static String? pendingAuthSnackAr;

  /// Set to `true` while `OnboardingFlow._submitAndShowSuccess` is mid-flight,
  /// i.e. between `createUserWithEmailAndPassword` (which makes the user
  /// "signed in" from Firebase Auth's perspective) and the `createUser`
  /// Firestore write that lands the `users/{uid}` profile document.
  ///
  /// AuthGate honors this flag: while true, it suppresses the
  /// "profile incomplete → force sign-out + LoginScreen snackbar" path
  /// (case 7) and stays on Splash. Without this guard, AuthGate would race
  /// the in-flight Firestore write and sign the user out partway through
  /// legitimate onboarding.
  ///
  /// MUST be reset in a `finally` block so a thrown exception can never
  /// leave the flag stuck `true`, which would mask future profile-incomplete
  /// detections for the rest of the process lifetime.
  static bool signupInProgress = false;

  /// Egyptian mobile accepted formats:
  ///   * E.164:              `+201XXXXXXXXX`  (13 chars)
  ///   * Legacy local-only:  `01XXXXXXXXX`    (11 chars) — kept for data
  ///                         written before E.164 canonicalization.
  /// Valid carrier prefixes after `+20`/`0` are 10, 11, 12, 15.
  static final _egyptianMobileRegex =
      RegExp(r'^(\+201|01)[0125]\d{8}$');

  /// Returns true when [phone] is a valid Egyptian mobile number in either
  /// the canonical E.164 form (`+201XXXXXXXXX`) or the legacy local form
  /// (`01XXXXXXXXX`).
  static bool isValidEgyptianMobile(String phone) =>
      _egyptianMobileRegex.hasMatch(phone.trim());

  /// Accepts any Egyptian-mobile shape (`1XXXXXXXXX`, `01XXXXXXXXX`,
  /// `+201XXXXXXXXX`, with incidental whitespace/dashes) and returns the
  /// canonical E.164 form. Returns an empty string when the input cannot be
  /// normalized to a valid 10-digit local carrier prefix.
  static String _canonicalizeEgyptianPhone(String raw) {
    final String digits = raw.replaceAll(RegExp(r'\D'), '');
    String local = digits;
    if (local.startsWith('20') && local.length > 10) {
      local = local.substring(2);
    }
    if (local.length == 11 && local.startsWith('0')) {
      local = local.substring(1);
    }
    if (local.length != 10) return '';
    if (!RegExp(r'^1[0125]\d{8}$').hasMatch(local)) return '';
    return '+20$local';
  }

  // ----------------------
  // INITIALIZE FIREBASE
  // ----------------------
  static Future<void> initialize() async {
    if (kIsWeb) {
      const firebaseOptions = FirebaseOptions(
        apiKey: "AIzaSyBDZlSoKBy_MWYeCUc27PVxBH7KYAfKfZ0",
        authDomain: "syana-ea75a.firebaseapp.com",
        databaseURL: "https://syana-ea75a-default-rtdb.firebaseio.com",
        projectId: "syana-ea75a",
        storageBucket: "syana-ea75a.appspot.com",
        messagingSenderId: "850445794682",
        appId: "1:850445794682:web:0a05be4e3e0ccb1d5caac3",
        measurementId: "G-KYNSN89SZS",
      );
      await Firebase.initializeApp(options: firebaseOptions);
    } else {
      await Firebase.initializeApp();
      // Configure Firestore offline persistence for mobile.
      // Must be set before any Firestore operation is issued.
      firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }

    // App Check — blocks unauthorized clients from reaching Firebase APIs.
    //
    // Web: a hardcoded placeholder reCAPTCHA key previously here caused
    // recaptcha/api2/clr to 400 on every web load; the resulting AppCheck
    // failure surfaced as `currentUser == null` past the 8-second auth-ready
    // guard in tech_home_screen.dart. We now read the key from a build-time
    // dart-define and skip web activation entirely when no key is provided.
    //   Build with App Check enabled:
    //     flutter build web --dart-define=RECAPTCHA_V3_SITE_KEY=<key>
    //   Get the key from: https://www.google.com/recaptcha/admin
    // Mobile builds always activate (debug providers in debug mode, attestation
    // providers otherwise) and do not depend on the dart-define.
    //
    // App Check enforcement in the Firebase Console is currently MONITORING.
    // Before flipping to ENFORCING for the web app, deploy a build that
    // passes a real RECAPTCHA_V3_SITE_KEY and verify zero AppCheck errors in
    // DevTools Console.
    const recaptchaSiteKey =
        String.fromEnvironment('RECAPTCHA_V3_SITE_KEY', defaultValue: '');
    if (kIsWeb) {
      if (recaptchaSiteKey.isNotEmpty) {
        await FirebaseAppCheck.instance.activate(
          webProvider: ReCaptchaV3Provider(recaptchaSiteKey),
        );
      }
    } else {
      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider:
            kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
      );
    }
  }

  // ----------------------
  // USER MANAGEMENT
  // ----------------------
  static User? getCurrentUser() => auth.currentUser;

  static Future<Map<String, dynamic>?> getProfile(String uid) async {
    final doc = await firestore.collection('users').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  /// Updates a technician's editable profile fields (username, phone, email,
  /// and optionally photoUrl). Only the caller's own UID is written — the UID
  /// must come from [getCurrentUser], never from UI input.
  static Future<void> updateTechnicianProfile({
    required String uid,
    required String username,
    required String phone,
    required String email,
    String? photoUrl,
  }) async {
    if (!isValidEgyptianMobile(phone)) {
      throw ArgumentError('Invalid Egyptian mobile number');
    }
    final Map<String, dynamic> updates = {
      'username': username.trim(),
      'phone': phone.trim(),
      'email': email.trim().toLowerCase(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (photoUrl != null && photoUrl.isNotEmpty) {
      updates['photoUrl'] = photoUrl;
    }
    await firestore.collection('users').doc(uid).update(updates);
  }

  /// Returns true when the Firestore profile has all fields required to use the app.
  /// A Firebase Auth account alone is NOT considered complete — phone, role, and
  /// username are required by the onboarding flow before the user is admitted.
  static bool isProfileComplete(Map<String, dynamic>? profile) {
    if (profile == null) return false;
    final phone = (profile['phone'] as String? ?? '').trim();
    final role = (profile['role'] as String? ?? '').trim();
    final username = (profile['username'] as String? ?? '').trim();
    return phone.isNotEmpty && role.isNotEmpty && username.isNotEmpty;
  }

  // ----------------------
  // SOCIAL SIGN-IN
  // ----------------------

  /// Signs in with Google. Returns null if the user cancelled.
  static Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null; // user cancelled
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return auth.signInWithCredential(credential);
  }

  /// Signs in with Apple. Returns null if the user cancelled.
  /// Uses a cryptographic nonce to prevent replay attacks.
  static Future<UserCredential?> signInWithApple() async {
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );
      return auth.signInWithCredential(oauthCredential);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
  }

  // Generates a cryptographically secure random nonce string for Apple Sign-In.
  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
        length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  // Returns the SHA-256 hash of the input string.
  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Updates specific fields on the user profile document.
  static Future<void> updateProfile(String uid, Map<String, dynamic> fields) async {
    await firestore.collection('users').doc(uid).update(fields);
  }

  /// Permanently deletes the signed-in customer's account, removing or
  /// anonymizing all client-reachable data:
  ///   1. Verify no active (non-terminal) jobs — throws
  ///      [AccountHasActiveJobsException] if any are found.
  ///   2. Anonymize completed/cancelled/disputed jobs (replace [customerName]
  ///      with `[Deleted user]`, clear [phoneNumber], stamp [customerDeleted]).
  ///   3. Delete fan-out notifications carrying this customer's PII to
  ///      technicians (`notifications` where `customerId == uid`).
  ///   4. Hard-delete the saved-locations subcollection.
  ///   5. Hard-delete the `users/{uid}` document.
  ///   6. Delete the Firebase Auth user. If Auth requires a recent sign-in,
  ///      throws [RequiresRecentLoginException]; the UI signs the user out so
  ///      they can re-authenticate and retry.
  ///
  /// Steps 1–5 are idempotent — a retry after a step-6 failure re-runs cleanly
  /// (anonymized jobs stay anonymized, notifications already deleted are a
  /// no-op, locations are already gone, deleting a missing user doc is a
  /// Firestore no-op).
  ///
  /// Steps 2, 3, and 5 require Firestore Security Rules updates. Without
  /// them the customer write fails with permission-denied. The rule
  /// branches landed in the same Spec W3 commit; the deploy still has to
  /// happen separately via `firebase deploy --only firestore:rules`.
  static Future<void> deleteAccount() async {
    final user = auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user to delete');
    }
    final uid = user.uid;

    // Terminal job statuses safe to leave behind (anonymized).
    const terminal = ['completed', 'cancelled', 'receipt_disputed'];

    // (1) Block deletion when any non-terminal job exists for this customer.
    final activeJobsSnap = await firestore
        .collection('jobs')
        .where('customerId', isEqualTo: uid)
        .where('status', whereNotIn: terminal)
        .get();
    if (activeJobsSnap.docs.isNotEmpty) {
      throw AccountHasActiveJobsException(activeJobsSnap.docs.length);
    }

    // (2) Anonymize the user's terminal jobs in batches of <=450 writes.
    final allJobsSnap = await firestore
        .collection('jobs')
        .where('customerId', isEqualTo: uid)
        .get();
    WriteBatch jobsBatch = firestore.batch();
    int jobsBatched = 0;
    for (final doc in allJobsSnap.docs) {
      jobsBatch.update(doc.reference, {
        'customerName': '[Deleted user]',
        'phoneNumber': '',
        'customerDeleted': true,
        'customerDeletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      jobsBatched++;
      if (jobsBatched >= 450) {
        await jobsBatch.commit();
        jobsBatch = firestore.batch();
        jobsBatched = 0;
      }
    }
    if (jobsBatched > 0) await jobsBatch.commit();

    // (3) Delete fan-out notifications. The `notifications` collection
    // mirrors customerName / locationAddress to every available
    // technician at order time. Scrubbing them removes residual PII.
    // Notifications written before `customerId` was added to the schema
    // will not match this query and remain admin-only-deletable — that is
    // the intended legacy behavior.
    final notifsSnap = await firestore
        .collection('notifications')
        .where('customerId', isEqualTo: uid)
        .get();
    WriteBatch notifBatch = firestore.batch();
    int notifBatched = 0;
    for (final doc in notifsSnap.docs) {
      notifBatch.delete(doc.reference);
      notifBatched++;
      if (notifBatched >= 450) {
        await notifBatch.commit();
        notifBatch = firestore.batch();
        notifBatched = 0;
      }
    }
    if (notifBatched > 0) await notifBatch.commit();

    // (4) Delete saved-locations subcollection (owner has delete rights).
    final locsSnap = await firestore
        .collection('users')
        .doc(uid)
        .collection('locations')
        .get();
    WriteBatch locsBatch = firestore.batch();
    int locsBatched = 0;
    for (final doc in locsSnap.docs) {
      locsBatch.delete(doc.reference);
      locsBatched++;
      if (locsBatched >= 450) {
        await locsBatch.commit();
        locsBatch = firestore.batch();
        locsBatched = 0;
      }
    }
    if (locsBatched > 0) await locsBatch.commit();

    // (5) Delete the user profile document. If the doc is already absent
    // (idempotent retry after a step-6 failure), Firestore treats this as
    // a no-op success.
    await firestore.collection('users').doc(uid).delete();

    // (6) Delete the Firebase Auth user — must come last because subsequent
    // Firestore writes would no longer carry this user's auth context.
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw RequiresRecentLoginException();
      }
      rethrow;
    }

    // TODO(BLAZE): Apple Sign-In token revocation requires a Cloud Function
    // to call https://appleid.apple.com/auth/revoke with a server-generated
    // client-secret JWT. Apple App Store guideline 5.1.1(v) requires this
    // for users who registered via Apple Sign-In. Skipped on Spark plan;
    // will need to be added when Cloud Functions become available.
  }

  // ── Saved Locations ──────────────────────────────────────────────────────

  static String buildAddressString({
    required String street,
    required String city,
    required String building,
    required String notes,
  }) {
    final parts = <String>[];
    if (street.isNotEmpty) parts.add(street);
    if (building.isNotEmpty) parts.add(building);
    if (city.isNotEmpty) parts.add(city);
    if (notes.isNotEmpty) parts.add(notes);
    return parts.join(', ');
  }

  /// Returns all saved locations for a user.
  static Future<List<Map<String, dynamic>>> getSavedLocations(String uid) async {
    final snap = await firestore
        .collection('users')
        .doc(uid)
        .collection('locations')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();
    return snap.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data());
      final street = (data['street'] as String? ?? '').trim();
      final city = (data['city'] as String? ?? '').trim();
      final building = (data['building'] as String? ?? '').trim();
      final notes = (data['notes'] as String? ?? '').trim();
      final address = (data['address'] as String? ?? '').trim();
      final double? lat = (data['lat'] as num?)?.toDouble();
      final double? lng = (data['lng'] as num?)?.toDouble();

      return {
        'id': d.id,
        ...data,
        'street': street,
        'city': city,
        'building': building,
        'notes': notes,
        'address': address.isNotEmpty
            ? address
            : buildAddressString(
                street: street,
                city: city,
                building: building,
                notes: notes,
              ),
        'lat': lat,
        'lng': lng,
      };
    }).toList();
  }

  /// Adds a new saved location and returns its document ID.
  ///
  /// `lat`/`lng` are optional but recommended — when present they flow onto
  /// the job document at order-create time so technicians and admins can
  /// open the exact pin in Google Maps.
  static Future<String> addSavedLocation(String uid, Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data);
    final label = (payload['label'] as String? ?? '').trim();
    final street = (payload['street'] as String? ?? '').trim();
    final city = (payload['city'] as String? ?? '').trim();
    final building = (payload['building'] as String? ?? '').trim();
    final notes = (payload['notes'] as String? ?? '').trim();
    final address = (payload['address'] as String? ?? '').trim();
    final double? lat = (payload['lat'] as num?)?.toDouble();
    final double? lng = (payload['lng'] as num?)?.toDouble();

    if (label.length > 50 || street.length > 100 || city.length > 50 ||
        building.length > 100 || notes.length > 200) {
      throw ArgumentError('Location field exceeds maximum length');
    }
    // NaN check first — every comparison with NaN is false, so a NaN value
    // would silently bypass the range check below. `x.isNaN` is the safest
    // form and works for both `int` and `double`.
    if (lat != null && (lat.isNaN || lat < -90 || lat > 90)) {
      throw ArgumentError('lat out of range or NaN');
    }
    if (lng != null && (lng.isNaN || lng < -180 || lng > 180)) {
      throw ArgumentError('lng out of range or NaN');
    }

    payload['street'] = street;
    payload['city'] = city;
    payload['building'] = building;
    payload['notes'] = notes;
    payload['address'] = address.isNotEmpty
        ? address
        : buildAddressString(
            street: street,
            city: city,
            building: building,
            notes: notes,
          );
    if (lat != null) payload['lat'] = lat;
    if (lng != null) payload['lng'] = lng;
    payload['createdAt'] = FieldValue.serverTimestamp();
    final ref = await firestore
        .collection('users')
        .doc(uid)
        .collection('locations')
        .add(payload);
    return ref.id;
  }

  /// Retrofits a `lat`/`lng` pin onto an existing saved location.
  ///
  /// Used to migrate pre-feature saved-locations that have only address text
  /// (see project_maps_feature memory). Does NOT propagate the new pin to
  /// in-flight jobs — coords on `jobs/*` are write-once at create time.
  static Future<void> updateSavedLocationPin(
      String uid, String locationId, double lat, double lng) async {
    if (lat.isNaN || lat < -90 || lat > 90) {
      throw ArgumentError('lat out of range or NaN');
    }
    if (lng.isNaN || lng < -180 || lng > 180) {
      throw ArgumentError('lng out of range or NaN');
    }
    await firestore
        .collection('users')
        .doc(uid)
        .collection('locations')
        .doc(locationId)
        .update({'lat': lat, 'lng': lng});
  }

  /// Sets the active location for a user by storing the location ID on the user doc.
  static Future<void> setActiveLocation(String uid, String locationId) async {
    await firestore.collection('users').doc(uid).update({
      'activeLocationId': locationId,
    });
  }

  /// Deletes a saved location.
  static Future<void> deleteSavedLocation(String uid, String locationId) async {
    await firestore
        .collection('users')
        .doc(uid)
        .collection('locations')
        .doc(locationId)
        .delete();
  }

  /// Creates a user record. Use for both customers and technicians.
  /// Creates (or idempotently updates) the user profile document.
  /// Returns `true` if this was a genuinely new account creation.
  /// Returns `false` if the document already existed (e.g. retry after a
  /// crash during social sign-in onboarding) — counters are NOT incremented
  /// in that case to prevent double-counting.
  static Future<bool> createUser({
    required String uid,
    required String email,
    required String username,
    required String role, // 'customer' | 'technician'
    String city = '',
    String phone = '',
    String service = '',
    String language = 'en',
    bool featured = false,
    bool available = true,
    GeoPoint? location,
    String photoUrl = '',
  }) async {
    assert(role == 'customer' || role == 'technician',
        'createUser: role must be customer or technician, got "$role"');
    if (role != 'customer' && role != 'technician') {
      throw ArgumentError('Invalid role: $role');
    }
    if (phone.isNotEmpty && !isValidEgyptianMobile(phone)) {
      throw ArgumentError('Invalid Egyptian mobile number');
    }

    final ref = firestore.collection('users').doc(uid);

    final Map<String, dynamic> baseData = {
      'email': email,
      'username': username,
      'role': role,
      'city': city,
      'service': service,
      'language': language,
      'rating': 0.0,
      'ratingCount': 0,
      'earnings': 0.0,
      'available': available,
      'featured': featured,
    };
    if (phone.isNotEmpty) baseData['phone'] = phone;
    if (location != null) baseData['location'] = location;
    if (photoUrl.isNotEmpty) baseData['photoUrl'] = photoUrl;

    // Admin-web contract (Spec 005): the picker queries
    // `users.where('availableForServices', arrayContains: serviceKey)
    //       .where('isAvailable', isEqualTo: true)`. The legacy `service` and
    // `available` scalars are kept above for backwards-compatibility with
    // existing rules, queries, and dashboards, but we also write the array
    // form here so a newly onboarded technician appears in the admin picker
    // immediately. New technicians currently only have one skill; the field
    // is an array so multi-skill techs can be supported without a migration.
    if (role == 'technician' && service.isNotEmpty) {
      baseData['availableForServices'] = <String>[service];
    }
    if (role == 'technician') {
      baseData['isAvailable'] = available;
    }

    // Transaction: check existence first so counters are only incremented once,
    // even if the user retries after a mid-submission crash.
    bool isNew = false;
    await firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      isNew = !snap.exists;
      if (isNew) {
        tx.set(ref, {...baseData, 'createdAt': FieldValue.serverTimestamp()});
      } else {
        tx.update(ref, {...baseData, 'updatedAt': FieldValue.serverTimestamp()});
      }
    });

    if (!isNew) return false;

    // Post-signup side effects — activity_log only. Stats counters now bump
    // via the `onUserCreated` Cloud Function trigger (Spec 003). The isNew
    // guard above prevents duplicate activity entries.
    try {
      await firestore.collection('activity_log').add({
        'type': 'account_created',
        'description': username.isNotEmpty ? username : email,
        'userId': uid,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    return true;
  }

  /// Helper: create a technician user and ensure its service entry exists.
  static Future<void> createTechnician({
    required String uid,
    required String email,
    required String username,
    required String serviceId,
    String city = '',
    String phone = '',
    String language = 'en',
    bool featured = false,
    GeoPoint? location,
    String photoUrl = '',
  }) async {
    final isNew = await createUser(
      uid: uid,
      email: email,
      username: username,
      role: 'technician',
      city: city,
      phone: phone,
      service: serviceId,
      language: language,
      featured: featured,
      available: true,
      location: location,
      photoUrl: photoUrl,
    );

    // Increment techCount for new accounts only.
    // Service documents are admin-managed; clients may only touch techCount.
    if (isNew) {
      await firestore.collection('services').doc(serviceId).update({
        'techCount': FieldValue.increment(1),
      });
      // Mirror to the PII-free tech_availability index used for notification
      // fan-out, so customers never need to read the users collection.
      await firestore.collection('tech_availability').doc(uid).set({
        'serviceKey': serviceId,
        'available': true,
      });
    }
  }

  static String _prettyServiceLabel(String id) {
    final parts = id.split(RegExp(r'[_\-\s]+'));
    return parts.map((p) => p.isEmpty ? '' : p[0].toUpperCase() + (p.length > 1 ? p.substring(1) : '')).join(' ');
  }

  /// Reads the `services` collection directly — O(services), no technician scan.
  /// Falls back to a pretty-printed key label when name fields are missing.
  static Future<List<Map<String, dynamic>>> getServices() async {
    final snap = await firestore.collection('services').get();
    final List<Map<String, dynamic>> result = snap.docs.map((d) {
      final data = d.data();
      return {
        'key': d.id,
        'name_en': (data['name_en'] as String?)?.trim().isNotEmpty == true
            ? (data['name_en'] as String).trim()
            : _prettyServiceLabel(d.id),
        'name_ar': (data['name_ar'] as String?)?.trim().isNotEmpty == true
            ? (data['name_ar'] as String).trim()
            : _prettyServiceLabel(d.id),
        'icon': (data['icon'] as String?) ?? '',
        'techCount': (data['techCount'] as num?)?.toInt() ?? 0,
      };
    }).toList();
    result.sort((a, b) => (a['name_en'] as String).compareTo(b['name_en'] as String));
    return result;
  }

  /// Returns services as a single-emission stream backed by a one-time read.
  /// Services data is semi-static; a permanent listener on the full collection
  /// is wasteful. Callers that need live updates should schedule a manual refresh.
  static Stream<List<Map<String, dynamic>>> streamServices() {
    return Stream.fromFuture(getServices());
  }

  // ----------------------
  // JOBS
  // ----------------------
  static Future<String> createJob({
    required String customerId,
    String? technicianId,
    required String serviceKey,
    required String description,
    double price = 0.0,
    List<String>? photos,
  }) async {
    if (description.trim().isEmpty || description.trim().length > 500) {
      throw ArgumentError('Description must be 1–500 characters');
    }
    // Batched write: create job + bump lastOrderAt for server-side cooldown.
    final batch = firestore.batch();
    final userRef = firestore.collection('users').doc(customerId);
    batch.update(userRef, {'lastOrderAt': FieldValue.serverTimestamp()});
    final jobRef = firestore.collection('jobs').doc();
    batch.set(jobRef, {
      'customerId': customerId,
      'technicianId': technicianId ?? '',
      'serviceKey': serviceKey,
      'description': description,
      'price': price,
      'photos': photos ?? [],
      'status': 'requested',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return jobRef.id;
  }

  static Stream<List<Map<String, dynamic>>> streamJobs({required String uid, required String role}) {
    Query query = firestore.collection('jobs');
    if (role == 'customer') query = query.where('customerId', isEqualTo: uid);
    if (role == 'technician') query = query.where('assignedTechnicianId', isEqualTo: uid);
    return query
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) {
      return snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data() as Map<String, dynamic>);

        data['id'] = d.id;
        return data;
      }).toList();
    });
  }

  /// Cancel a job by updating its status to 'cancelled'.
  /// Uses a transaction so we know the previous status for accurate counter
  /// updates: a 'requested' job decrements jobsRequested; an active job
  /// decrements jobsOngoing.
  static Future<void> cancelJob(String jobId) async {
    String prevStatus = '';
    await firestore.runTransaction((tx) async {
      final ref = firestore.collection('jobs').doc(jobId);
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      prevStatus = (snap.data()!['status'] as String?) ?? '';
      tx.update(ref, {
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    if (prevStatus.isEmpty) return;
    // Stats counters now move via the `onJobStatusChanged` Cloud Function
    // trigger (Spec 003). Only the audit entry is written client-side.
    try {
      await firestore.collection('activity_log').add({
        'type': 'job_cancelled',
        'description': 'Job cancelled',
        'jobId': jobId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Soft-delete a cancelled/completed job from the customer's view.
  /// The document is preserved for audit; only [hiddenForCustomer] is set.
  /// Only allowed for terminal statuses (cancelled, completed) by Firestore rules.
  static Future<void> hideJobForCustomer(String jobId) async {
    await firestore.collection('jobs').doc(jobId).update({
      'hiddenForCustomer': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ----------------------
  // CHATS & MESSAGES
  // ----------------------
  static Future<String> getOrCreateChat(String customerId, String technicianId, {String? jobId}) async {
    final query = await firestore
        .collection('chats')
        .where('customerId', isEqualTo: customerId)
        .where('technicianId', isEqualTo: technicianId)
        .get();
    if (query.docs.isNotEmpty) return query.docs.first.id;

    final docRef = await firestore.collection('chats').add({
      'customerId': customerId,
      'technicianId': technicianId,
      'jobId': jobId ?? '',
      'customerMessageCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  static Stream<List<Map<String, dynamic>>> streamChats({required String uid, required String role}) {
    Query query = firestore.collection('chats');
    if (role == 'customer') query = query.where('customerId', isEqualTo: uid);
    if (role == 'technician') query = query.where('technicianId', isEqualTo: uid);
    return query.orderBy('createdAt', descending: true).limit(20).snapshots().map((snap) {
      return snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data() as Map<String, dynamic>);

        data['id'] = d.id;
        return data;
      }).toList();
    });
  }

  static Stream<List<Map<String, dynamic>>> streamMessages(String chatId) {
    return firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt')
        .limitToLast(50)
        .snapshots()
        .map((snap) {
      return snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        return data;
      }).toList();
    });
  }

  // ----------------------
  // SUPPORT CHAT
  // ----------------------

  /// Returns the ID of an existing open support chat for [userId], or null.
  /// Does NOT create a new chat — call this on screen open to avoid phantom
  /// admin-side tickets when the user merely opens the help screen.
  static Future<String?> getExistingSupportChat(String userId) async {
    final snap = await firestore
        .collection('support_chats')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'open')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty ? snap.docs.first.id : null;
  }

  /// Returns the existing open support chat for [userId], or creates a new one.
  static Future<String> getOrCreateSupportChat({
    required String userId,
    required String userName,
  }) async {
    final existing = await firestore
        .collection('support_chats')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'open')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return existing.docs.first.id;

    final docRef = await firestore.collection('support_chats').add({
      'userId': userId,
      'userName': userName,
      'status': 'open',
      'unreadByAdmin': true,
      'userMessageCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Sends a message in a support chat and bumps [lastMessageAt].
  /// Set [setUnreadForAdmin] = true when the user sends (not admin).
  static Future<void> sendSupportMessage({
    required String chatId,
    required String senderId,
    required String text,
    bool setUnreadForAdmin = false,
  }) async {
    final batch = firestore.batch();
    final msgRef = firestore
        .collection('support_chats')
        .doc(chatId)
        .collection('messages')
        .doc();
    batch.set(msgRef, {
      'senderId': senderId,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    final Map<String, dynamic> chatUpdate = {
      'lastMessageAt': FieldValue.serverTimestamp(),
    };
    if (setUnreadForAdmin) {
      chatUpdate['unreadByAdmin'] = true;
      // Throttle fields — only bumped for user-sent messages.
      chatUpdate['lastUserMessageAt'] = FieldValue.serverTimestamp();
      chatUpdate['userMessageCount'] = FieldValue.increment(1);
    }
    batch.update(
        firestore.collection('support_chats').doc(chatId), chatUpdate);
    await batch.commit();
  }

  // ----------------------
  // IMAGE COMPRESSION
  // ----------------------
  /// Compresses [file] to JPEG with max dimension [maxDimension]px and
  /// [quality] (0–100). Returns the compressed bytes.
  ///
  /// On mobile uses `flutter_image_compress` (native). On web,
  /// `flutter_image_compress` has no implementation, so we decode + resize +
  /// re-encode with pure-Dart `package:image`. Throws [ImageDecodeException]
  /// if the web decoder cannot interpret the raw bytes.
  static Future<List<int>> compressImage(
    XFile file, {
    int maxDimension = 480,
    int quality = 60,
  }) async {
    final rawBytes = await file.readAsBytes();
    if (kDebugMode) {
      debugPrint(
        '[compressImage] raw: ${rawBytes.length} B '
        '(${(rawBytes.length / 1024 / 1024).toStringAsFixed(2)} MB, '
        'web=$kIsWeb)',
      );
    }

    final List<int> compressed;
    if (kIsWeb) {
      compressed = _compressOnWebWithImagePackage(
        rawBytes,
        maxDimension: maxDimension,
        quality: quality,
      );
    } else {
      compressed = await FlutterImageCompress.compressWithList(
        rawBytes,
        minWidth: maxDimension,
        minHeight: maxDimension,
        quality: quality,
        format: CompressFormat.jpeg,
      );
    }

    if (kDebugMode) {
      debugPrint(
        '[compressImage] out: ${compressed.length} B '
        '(${(compressed.length / 1024 / 1024).toStringAsFixed(2)} MB, '
        'maxDim=$maxDimension, q=$quality)',
      );
    }
    return compressed;
  }

  // Synchronous; a typical 5 MP photo runs ~300-700 ms on the main isolate.
  // Callers show a spinner around the awaited `compressImage` call, and
  // `readAsBytes` above yields before we get here, so one paint gets in.
  static List<int> _compressOnWebWithImagePackage(
    Uint8List rawBytes, {
    required int maxDimension,
    required int quality,
  }) {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) throw ImageDecodeException();

    img.Image working = decoded;
    final longest =
        decoded.width > decoded.height ? decoded.width : decoded.height;
    if (longest > maxDimension) {
      if (decoded.width >= decoded.height) {
        working = img.copyResize(decoded, width: maxDimension);
      } else {
        working = img.copyResize(decoded, height: maxDimension);
      }
    }
    return img.encodeJpg(working, quality: quality);
  }

  // ----------------------
  // UPLOAD PHOTO
  // ----------------------
  /// Compresses [file] before uploading to Firebase Storage.
  /// Max dimension: 480 px · JPEG quality: 60 → typical reduction ~92 %.
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

  // ----------------------
  // TECHNICIAN STATUS / RATINGS / EARNINGS
  // ----------------------
  static Future<void> updateAvailability(String uid, bool available) async {
    // Write both keys so the admin-web picker (`isAvailable`) and the legacy
    // mobile consumers (`available`) stay in sync. Dropping either side
    // regresses the other.
    await firestore.collection('users').doc(uid).update({
      'available': available,
      'isAvailable': available,
    });
    // Keep the PII-free notification-routing index in sync.
    await firestore.collection('tech_availability').doc(uid).update({
      'available': available,
    });
  }

  static Future<void> updateFeatured(String uid, bool featured) async {
    await firestore.collection('users').doc(uid).update({'featured': featured});
  }

  static Future<void> addEarnings(String uid, double amount) async {
    // FieldValue.increment is atomic and requires no prior read.
    // `stats/global.totalEarnings` is now bumped by the `onJobStatusChanged`
    // Cloud Function trigger on job completion (Spec 003).
    await firestore.collection('users').doc(uid).update({
      'earnings': FieldValue.increment(amount),
    });
  }

  static Future<void> updateRating(String uid, double rating) async {
    final doc = firestore.collection('users').doc(uid);
    // Wrap in a transaction so the read-compute-write is atomic.
    // Firestore retries the transaction automatically if the document is
    // modified by another writer between the read and the commit, eliminating
    // the race condition that would otherwise silently drop concurrent ratings.
    await firestore.runTransaction((tx) async {
      final snapshot = await tx.get(doc);
      if (!snapshot.exists) return;
      final data = snapshot.data()!;
      final currentRating = (data['rating'] as num?)?.toDouble() ?? 0.0;
      final ratingCount = (data['ratingCount'] as num?)?.toInt() ?? 0;
      final newCount = ratingCount + 1;
      final newRating = ((currentRating * ratingCount) + rating) / newCount;
      tx.update(doc, {'rating': newRating, 'ratingCount': newCount});
    });
  }

  // ----------------------
  // INVENTORY (deprecated)
  //
  // The per-technician inventory feature was retired in release 006
  // (April 2026). Write methods (`addInventoryItem`, `updateInventoryItem`,
  // `deleteInventoryItem`, `streamInventory`) have been removed along with
  // the /inventory Firestore rules.
  //
  // `getInventory` is retained on a short leash because
  // `lib/user_item_prices_screen.dart` (a customer-facing price viewer) still
  // references it. Under the new model the `inventory` collection is frozen
  // and no new documents will ever be created, so this method will always
  // return an empty list. It is scheduled for removal together with
  // `user_item_prices_screen.dart` in a follow-up cleanup.
  // ----------------------
  static Future<List<Map<String, dynamic>>> getInventory(
      String technicianId) async {
    final snap = await firestore
        .collection('inventory')
        .where('technicianId', isEqualTo: technicianId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    return snap.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data());
      data['id'] = d.id;
      return data;
    }).toList();
  }

  // ----------------------
  // PAYMENTS
  // ----------------------

  /// Creates a payment document and returns its ID.
  static Future<String> createPayment({
    required String orderId,
    required String userId,
    required double amount,
    required String method,
    String transactionReference = '',
    String screenshotUrl = '',
  }) async {
    final docRef = await firestore.collection('payments').add({
      'orderId': orderId,
      'userId': userId,
      'amount': amount,
      'method': method,
      'status': 'PENDING',
      'transactionReference': transactionReference,
      'screenshotUrl': screenshotUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Updates the screenshot URL on an existing payment (after upload).
  static Future<void> updatePaymentScreenshot(
      String paymentId, String screenshotUrl) async {
    await firestore.collection('payments').doc(paymentId).update({
      'screenshotUrl': screenshotUrl,
    });
  }

  /// Streams payments for a specific user.
  static Stream<List<Map<String, dynamic>>> streamUserPayments(String userId) {
    return firestore
        .collection('payments')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = Map<String, dynamic>.from(d.data());
              data['id'] = d.id;
              return data;
            }).toList());
  }

  /// Gets the payment linked to a specific job/order.
  static Future<Map<String, dynamic>?> getPaymentForOrder(String orderId) async {
    final snap = await firestore
        .collection('payments')
        .where('orderId', isEqualTo: orderId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final data = Map<String, dynamic>.from(snap.docs.first.data());
    data['id'] = snap.docs.first.id;
    return data;
  }

  /// Uploads a payment proof screenshot and returns the download URL.
  static Future<String> uploadPaymentProof(XFile file, String paymentId) async {
    final ref = storage.ref().child('payment_proofs/$paymentId.jpg');
    final compressed = await compressImage(file);
    await ref
        .putData(
          Uint8List.fromList(compressed),
          SettableMetadata(contentType: 'image/jpeg'),
        )
        .timeout(const Duration(seconds: 30));
    return await ref.getDownloadURL().timeout(const Duration(seconds: 10));
  }

  /// Uploads a technician's payment-proof photo keyed by job and returns
  /// the download URL (release 006). Currently unused — `verifyPayment` no
  /// longer requires a proof URL while Storage is not initialized on the
  /// Spark plan. Kept in place to be re-wired when Blaze is enabled. See
  /// `TODO(BLAZE)` markers for the full restoration checklist.
  ///
  /// Compresses at 1600 px / JPEG q70 — higher quality than the default
  /// `uploadPaymentProof` because admins review cash/bill detail. Writes to
  /// `payment_proofs/{jobId}_{timestamp}.jpg` (flat path, matches the
  /// existing `storage.rules` match block).
  static Future<String> uploadJobPaymentProof(
      XFile file, String jobId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref =
        storage.ref().child('payment_proofs/${jobId}_$timestamp.jpg');
    final compressed =
        await compressImage(file, maxDimension: 1600, quality: 70);

    // `storage.rules` caps payment_proofs/* at 5 MB. Compression should bring
    // any photograph well below 1 MB; if we're still over the cap here it
    // means the decoder couldn't meaningfully shrink unusual input (e.g. a
    // huge non-photographic image). Abort before `putData` so the user gets
    // a specific error instead of a rules-rejection that masquerades as a
    // timeout.
    const int sizeCap = 5 * 1024 * 1024;
    if (compressed.length >= sizeCap) {
      throw ImageTooLargeException(compressed.length);
    }

    await ref
        .putData(
          Uint8List.fromList(compressed),
          SettableMetadata(contentType: 'image/jpeg'),
        )
        .timeout(const Duration(seconds: 30));
    return await ref.getDownloadURL().timeout(const Duration(seconds: 10));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MANAGED MARKETPLACE ORDER REQUEST
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates a new order request (no technician assigned yet).
  /// Returns the new job document ID.
  static Future<String> createOrderRequest({
    required String customerId,
    required String customerName,
    required String serviceKey,
    String serviceCategory = '',
    String subservice = '',
    required String description,
    required String phoneNumber,
    required String locationLabel,
    required String locationAddress,
    double? locationLat,
    double? locationLng,
    required String urgencyType, // 'urgent' | 'scheduled'
    DateTime? scheduledTime,
    double price = 0.0,
  }) async {
    if (description.trim().isEmpty || description.trim().length > 500) {
      throw ArgumentError('Description must be 1–500 characters');
    }
    // Defensive normalization: accept whatever the caller passed and canonicalize
    // to E.164 so the wire payload is always +201XXXXXXXXX.
    final String phoneTrimmed = phoneNumber.trim();
    final String phoneE164 = _canonicalizeEgyptianPhone(phoneTrimmed);
    if (phoneE164.isEmpty) {
      throw ArgumentError(
          'Invalid Egyptian mobile number: "$phoneTrimmed"');
    }
    if (locationLabel.length > 50) {
      throw ArgumentError(
          'Location label must be 50 characters or less (got ${locationLabel.length}).');
    }
    if (locationAddress.length > 500) {
      throw ArgumentError(
          'Location address must be 500 characters or less (got ${locationAddress.length}).');
    }
    if (locationLat != null &&
        (locationLat.isNaN || locationLat < -90 || locationLat > 90)) {
      throw ArgumentError(
          'locationLat out of range or NaN (got $locationLat).');
    }
    if (locationLng != null &&
        (locationLng.isNaN || locationLng < -180 || locationLng > 180)) {
      throw ArgumentError(
          'locationLng out of range or NaN (got $locationLng).');
    }

    // ── Pre-flight: read the user doc so we can distinguish failure modes
    // from the single Firestore "permission-denied" code. Without this,
    // ANY rule failure (cooldown, stored-phone-invalid, missing doc) collapses
    // into the same opaque error.
    final userRef = firestore.collection('users').doc(customerId);
    final userSnap = await userRef.get();
    if (!userSnap.exists) {
      if (kDebugMode) {
        debugPrint(
            '[createOrderRequest] user doc missing for uid=$customerId');
      }
      throw MissingUserProfileException();
    }
    final userData = userSnap.data() ?? <String, dynamic>{};
    final String? storedPhone = userData['phone'] as String?;
    if (storedPhone != null &&
        storedPhone.isNotEmpty &&
        !_egyptianMobileRegex.hasMatch(storedPhone)) {
      if (kDebugMode) {
        debugPrint(
            '[createOrderRequest] stored phone fails phoneValid: "$storedPhone"');
      }
      throw StoredPhoneInvalidException(storedPhone);
    }
    final Timestamp? lastOrderAt = userData['lastOrderAt'] as Timestamp?;
    if (lastOrderAt != null) {
      final int elapsedMs =
          DateTime.now().millisecondsSinceEpoch - lastOrderAt.millisecondsSinceEpoch;
      if (elapsedMs < 60 * 1000) {
        final int remaining = ((60 * 1000 - elapsedMs) / 1000).ceil();
        if (kDebugMode) {
          debugPrint(
              '[createOrderRequest] cooldown active: remaining=${remaining}s');
        }
        throw OrderCooldownException(remaining);
      }
    }

    // IMPORTANT: firestore.rules enforces `!('amountPaid' in
    // request.resource.data)` on job create. Setting the key to `null` still
    // counts as "in" the map in Firestore CEL, so we must NOT include it here.
    // The same goes for `adminClosedAt` (keys absent → rules happy).
    final data = <String, dynamic>{
      'customerId': customerId,
      'customerName': customerName,
      'technicianId': '',
      'assignedTechnicianId': null,
      'assignedTechnicianName': null,
      'serviceKey': serviceKey,
      'serviceCategory': serviceCategory,
      'subservice': subservice,
      'description': description,
      'phoneNumber': phoneE164,
      'locationLabel': locationLabel,
      'locationAddress': locationAddress,
      if (locationLat != null) 'locationLat': locationLat,
      if (locationLng != null) 'locationLng': locationLng,
      'urgencyType': urgencyType,
      if (scheduledTime != null)
        'scheduledTime': Timestamp.fromDate(scheduledTime),
      'status': 'requested',
      'price': price,
      'photos': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    // Batched write: create the job AND bump the user's lastOrderAt so the
    // 60-second cooldown (enforced server-side on jobs/create by reading the
    // caller's prior users/{uid}.lastOrderAt) is immediately visible on the
    // next attempt. The Cloud Function onJobCreated also bumps lastOrderAt as
    // a safety net — whichever write lands later wins (both are idempotent).
    final batch = firestore.batch();
    batch.set(
      userRef,
      {'lastOrderAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    final jobRef = firestore.collection('jobs').doc();
    batch.set(jobRef, data);
    if (kDebugMode) {
      final Map<String, Object?> loggable = <String, Object?>{};
      data.forEach((k, v) {
        if (v is FieldValue) {
          loggable[k] = '<FieldValue>';
        } else if (v is Timestamp) {
          loggable[k] = v.toDate().toIso8601String();
        } else {
          loggable[k] = v;
        }
      });
      debugPrint(
          '[createOrderRequest] committing jobId=${jobRef.id} uid=$customerId '
          'payload=${jsonEncode(loggable)}');
    }
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[createOrderRequest] batch.commit FAILED code=${e.code} '
            'message=${e.message} plugin=${e.plugin}');
      }
      rethrow;
    }

    // `jobsRequested` now increments via the `onJobCreated` Cloud Function
    // trigger (Spec 003). Only the audit entry is written client-side.
    try {
      // Inspect orders carry serviceCategory='inspect' (canonical key).
      // Translate to a human-friendly EN label here so the admin-facing
      // activity log doesn't echo the raw key. Other categories pass
      // through their stored label.
      final String categoryForLog =
          serviceCategory.toLowerCase() == 'inspect' ||
                  serviceKey.toLowerCase() == 'inspect'
              ? 'Inspect'
              : (serviceCategory.isNotEmpty ? serviceCategory : serviceKey);
      await firestore.collection('activity_log').add({
        'type': 'job_requested',
        'description': '$categoryForLog — $customerName',
        'jobId': jobRef.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    return jobRef.id;
  }

  /// Plural active-jobs stream — returns ALL non-terminal jobs assigned to
  /// the technician. Replaces the singular `streamTechnicianActiveJob` used
  /// in earlier releases when a tech could only have one active job at a
  /// time. Multi-assignment is now allowed (the data model has always
  /// supported it; this is a UX unlock).
  ///
  /// Same 9-status whereIn list as the historical singular version — keep
  /// in lockstep with the tech-side active-job slider
  /// (`technician_active_job_screen.dart`). 9 values is safely under
  /// Firestore's 10-value whereIn cap.
  ///
  /// IMPORTANT: no `orderBy('scheduledTime')` here. Firestore silently
  /// drops docs that lack the field, and `scheduledTime` is null for
  /// urgent/now orders — sorting by it server-side would hide them. Sort
  /// client-side instead (see `_sortActiveJobs` in tech_home_screen.dart).
  ///
  /// Bounded at 20 — a tech is unlikely to have more than a handful of
  /// simultaneous active jobs, but the cap defends against runaway data.
  static Stream<List<Map<String, dynamic>>> streamTechnicianActiveJobs(
      String technicianId) {
    return firestore
        .collection('jobs')
        .where('assignedTechnicianId', isEqualTo: technicianId)
        .where('status', whereIn: [
          'active',
          'technician_accepted',
          'on_the_way',
          'technician_arrived',
          'work_finished',
          'awaiting_customer_approval',
          'awaiting_payment',
          'awaiting_payment_verification',
          'receipt_disputed',
        ])
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = Map<String, dynamic>.from(d.data());
              data['id'] = d.id;
              return data;
            }).toList());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TECHNICIAN AVAILABILITY (notification fan-out)
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns available technicians for a specific service key (same category).
  /// Limited to 30 to avoid large reads.
  /// Returns IDs of available technicians for a service via the PII-free
  /// tech_availability index.  Never reads the users collection.
  static Future<List<String>> getAvailableTechnicianIdsByService(
      String serviceKey) async {
    final snap = await firestore
        .collection('tech_availability')
        .where('serviceKey', isEqualTo: serviceKey)
        .where('available', isEqualTo: true)
        .limit(30)
        .get();
    return snap.docs.map((d) => d.id).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SERVICE-TARGETED TECHNICIAN NOTIFICATIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Writes notification records to the `notifications` collection for all
  /// available technicians in the given service category.
  /// Fire-and-forget: errors are swallowed so order creation is not blocked.
  ///
  /// [customerId] (Spec W3) is the customer's uid; stored on each
  /// notification so the account-deletion path can scrub PII fanned out
  /// to technicians. Optional with default `''` for source-compat with
  /// existing call sites; pass it from any new caller. Empty values are
  /// written through unchanged — the rule's customer-scoped delete branch
  /// gates on `customerId == auth.uid`, so empty-string notifications stay
  /// admin-only-deletable.
  static Future<void> notifyAvailableTechnicians({
    required String jobId,
    required String serviceKey,
    required String serviceCategory,
    required String customerName,
    required String locationAddress,
    required String urgencyType,
    String customerId = '',
  }) async {
    try {
      // Idempotency: skip if notifications were already sent for this job.
      final jobSnap = await firestore.collection('jobs').doc(jobId).get();
      if (jobSnap.data()?['notificationsSentAt'] != null) return;

      // Query the PII-free index — never reads the users collection.
      final techIds = await getAvailableTechnicianIdsByService(serviceKey);
      if (techIds.isEmpty) return;

      // Deterministic doc IDs prevent duplicates on replay.
      // Batch size capped at 499 techs + 1 job update = 500 (Firestore limit).
      const maxTechsPerBatch = 499;
      final capped = techIds.length > maxTechsPerBatch
          ? techIds.sublist(0, maxTechsPerBatch)
          : techIds;

      final batch = firestore.batch();
      for (final techId in capped) {
        if (techId.isEmpty) continue;
        // Deterministic ID: ensures re-invocation overwrites, not duplicates.
        final ref = firestore.collection('notifications').doc('${jobId}_$techId');
        batch.set(ref, {
          'technicianId': techId,
          'jobId': jobId,
          'serviceKey': serviceKey,
          'serviceCategory': serviceCategory,
          'customerId': customerId,
          'customerName': customerName,
          'locationAddress': locationAddress,
          'urgencyType': urgencyType,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      // Mark the job so subsequent calls are no-ops.
      batch.update(firestore.collection('jobs').doc(jobId), {
        'notificationsSentAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } catch (e) {
      // Surface the failure so it is observable — but never block order creation.
      debugPrint('[notifyAvailableTechnicians] notification fan-out failed: $e');
    }
  }

  /// Streams a technician's notifications (newest first, limit 20).
  static Stream<List<Map<String, dynamic>>> streamTechnicianNotifications(
      String techId) {
    return firestore
        .collection('notifications')
        .where('technicianId', isEqualTo: techId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = Map<String, dynamic>.from(d.data());
              data['id'] = d.id;
              return data;
            }).toList());
  }

  /// Streams the count of unread notifications for a technician (badge use).
  /// Uses a count() aggregation polled every 30 seconds — costs 1 read per
  /// poll instead of reading N full documents on every snapshot change.
  static Stream<int> streamTechnicianUnreadNotifCount(String techId) async* {
    final query = firestore
        .collection('notifications')
        .where('technicianId', isEqualTo: techId)
        .where('read', isEqualTo: false);
    // Emit immediately, then poll every 30 seconds.
    while (true) {
      try {
        final snap = await query.count().get();
        yield snap.count ?? 0;
      } catch (_) {
        yield 0;
      }
      await Future.delayed(const Duration(seconds: 30));
    }
  }

  /// Marks a notification as read.
  static Future<void> markNotificationRead(String notifId) async {
    await firestore
        .collection('notifications')
        .doc(notifId)
        .update({'read': true});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TECHNICIAN EXECUTION FLOW (new 3-step flow)
  // ─────────────────────────────────────────────────────────────────────────

  /// Step 1: Technician accepts an assigned job.
  /// Transitions: active → technician_accepted.
  static Future<void> acceptAssignment(
      String jobId, String technicianId) async {
    await firestore.runTransaction((tx) async {
      final ref = firestore.collection('jobs').doc(jobId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Job not found');
      final data = snap.data()!;
      if (data['status'] != 'active') {
        throw Exception('Job is not ready for acceptance');
      }
      if (data['assignedTechnicianId'] != technicianId) {
        throw Exception('You are not assigned to this job');
      }
      tx.update(ref, {
        'status': 'technician_accepted',
        'technicianAcceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Step 2a (release 006): Technician starts the trip to the customer.
  /// Transitions: technician_accepted → on_the_way.
  /// Idempotent: re-calling while already `on_the_way` is a no-op.
  ///
  /// Time-gated: rejects when `scheduledTime` is more than 60 minutes in
  /// the future. The same gate exists server-side in `firestore.rules`; we
  /// also enforce it inside the transaction so a stale UI snapshot can't
  /// slip a too-early start past the rule with a misleading error code.
  ///
  /// [scheduledTimeFastFail] is the in-memory scheduledTime the caller
  /// already has on hand. When provided we use it for a fast-fail check
  /// before opening the transaction, saving a wasted transaction round-
  /// trip on rejection. The in-transaction check below remains as defense
  /// in depth — it uses the freshly-read scheduledTime and is the only
  /// authoritative source if the two ever disagree.
  static Future<void> markOnTheWay(
      String jobId, String technicianId,
      {DateTime? scheduledTimeFastFail}) async {
    if (scheduledTimeFastFail != null &&
        !canStartTrip(scheduledTimeFastFail, DateTime.now())) {
      throw StateError(
          'Cannot start trip yet — scheduled time is more than 60 minutes away.');
    }
    await firestore.runTransaction((tx) async {
      final ref = firestore.collection('jobs').doc(jobId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Job not found');
      final data = snap.data()!;
      final currentStatus = (data['status'] as String?) ?? '';
      if (currentStatus == 'on_the_way') return;
      if (currentStatus != 'technician_accepted') {
        throw StateError(
            'Unexpected job status: got $currentStatus, expected technician_accepted');
      }
      if (data['assignedTechnicianId'] != technicianId) {
        throw Exception('You are not assigned to this job');
      }
      final dynamic scheduledRaw = data['scheduledTime'];
      final DateTime? scheduledAt =
          scheduledRaw is Timestamp ? scheduledRaw.toDate() : null;
      if (!canStartTrip(scheduledAt, DateTime.now())) {
        throw StateError(
            'Cannot start trip yet — scheduled time is more than 60 minutes away.');
      }
      tx.update(ref, {
        'status': 'on_the_way',
        'onTheWayAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Step 2b: Technician confirms arrival at the customer location.
  /// Transitions: on_the_way → technician_arrived. (Release-006 moved the
  /// source state from `technician_accepted` to `on_the_way`; the tech
  /// must now swipe "on the way" first.)
  /// Idempotent: re-calling while already `technician_arrived` is a no-op.
  static Future<void> markTechnicianArrived(
      String jobId, String technicianId) async {
    await firestore.runTransaction((tx) async {
      final ref = firestore.collection('jobs').doc(jobId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Job not found');
      final data = snap.data()!;
      final currentStatus = (data['status'] as String?) ?? '';
      if (currentStatus == 'technician_arrived') return;
      if (currentStatus != 'on_the_way') {
        throw StateError(
            'Unexpected job status: got $currentStatus, expected on_the_way');
      }
      if (data['assignedTechnicianId'] != technicianId) {
        throw Exception('You are not assigned to this job');
      }
      tx.update(ref, {
        'status': 'technician_arrived',
        'technicianArrivedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Step 3: Technician confirms the physical work is done.
  /// Transitions: technician_arrived → work_finished.
  /// Does NOT complete the order — receipt + customer approval still required.
  static Future<void> markWorkFinished(
      String jobId, String technicianId) async {
    await firestore.runTransaction((tx) async {
      final ref = firestore.collection('jobs').doc(jobId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Job not found');
      final data = snap.data()!;
      if (data['status'] != 'technician_arrived') {
        throw Exception('Job is not ready for work completion');
      }
      if (data['assignedTechnicianId'] != technicianId) {
        throw Exception('You are not assigned to this job');
      }
      tx.update(ref, {
        'status': 'work_finished',
        'workFinishedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Technician cancels an assigned job BEFORE accepting it.
  /// Transitions: active → cancelled.
  /// Only the assigned technician may cancel, and only from 'active' status.
  ///
  /// Kept as a thin shim over [cancelJobByTech] so existing call sites
  /// continue to work; new UI flows should call [cancelJobByTech] directly.
  static Future<void> technicianCancelJob(
      String jobId, String technicianId) async {
    await cancelJobByTech(jobId: jobId, technicianId: technicianId);
  }

  /// Technician cancels an assigned job. Transitions:
  ///   - `active`               → `cancelled` (no penalty, no escalation)
  ///   - `technician_accepted`  → `cancelled` (penalty per scheduling tier)
  ///
  /// Penalty is computed via [calculateCancellationPenalty] using the local
  /// clock at cancel time. The amount is stored on the job for audit/wallet
  /// integration, but no money moves here — wallet wiring is a future task.
  ///
  /// `cancellationPenalty` and `escalateForReview` are written even from
  /// `active` (as 0 / false) so the rule's affectedKeys whitelist can match
  /// the same field shape regardless of source status.
  static Future<void> cancelJobByTech({
    required String jobId,
    required String technicianId,
    String reason = '',
  }) async {
    if (reason.length > 500) {
      throw ArgumentError.value(reason, 'reason', 'max 500 chars');
    }
    String prevStatus = '';
    num penaltyAmount = 0;
    bool escalate = false;
    await firestore.runTransaction((tx) async {
      final ref = firestore.collection('jobs').doc(jobId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Job not found');
      final data = snap.data()!;
      prevStatus = (data['status'] as String?) ?? '';
      // Idempotent: re-calling on an already-cancelled job is a no-op so a
      // double-tap (or a retried call after a flaky network) doesn't surface
      // an error to the tech. Same shape as approveReceipt's early return.
      if (prevStatus == 'cancelled') return;
      if (prevStatus != 'active' && prevStatus != 'technician_accepted') {
        throw Exception('Job cannot be cancelled in its current state');
      }
      if (data['assignedTechnicianId'] != technicianId) {
        throw Exception('You are not assigned to this job');
      }

      // Penalty applies only to cancels after acceptance. Pre-acceptance
      // cancels still write the penalty fields (as zeros) so a single rule
      // shape covers both branches.
      if (prevStatus == 'technician_accepted') {
        final dynamic schedRaw = data['scheduledTime'];
        final DateTime? scheduled =
            schedRaw is Timestamp ? schedRaw.toDate() : null;
        final result = calculateCancellationPenalty(scheduled, DateTime.now());
        penaltyAmount = result.penalty;
        escalate = result.escalate;
      }

      tx.update(ref, {
        'status': 'cancelled',
        'cancelledBy': 'technician',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelReason': reason,
        'cancellationPenalty': penaltyAmount,
        'escalateForReview': escalate,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    // Counters move via the `onJobStatusChanged` Cloud Function trigger
    // (Spec 003). Activity log entry is fire-and-forget audit. Skip on the
    // idempotent path — a double-tap shouldn't write a second log entry.
    // The transaction's early-return only exits the tx callback; this second
    // guard prevents writing a duplicate activity_log row on the idempotent path.
    if (prevStatus == 'cancelled') return;
    try {
      final desc = penaltyAmount > 0
          ? 'Technician cancelled (from $prevStatus, penalty ${penaltyAmount.toStringAsFixed(0)} EGP${escalate ? ', escalated' : ''})'
          : 'Technician cancelled (from $prevStatus, no penalty)';
      await firestore.collection('activity_log').add({
        'type': 'job_cancelled',
        'description': desc,
        'jobId': jobId,
        'userId': technicianId,
        'role': 'technician',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Technician submits a structured receipt after finishing work.
  /// Transitions: work_finished → awaiting_customer_approval.
  ///
  /// Release-006 downstream flow: the customer reviews the receipt, calls
  /// `approveReceipt` (→ awaiting_payment), pays the technician in person,
  /// calls `initiatePayment` (→ awaiting_payment_verification), and the
  /// technician closes the job with `verifyPayment`. `completedAt`
  /// is set only on that final tech-verify step.
  ///
  /// Totals are RECOMPUTED from the line items here and override any values
  /// passed in from the client, so a buggy or modified client cannot persist
  /// inconsistent billing numbers. A top-level `receiptTotal` numeric field
  /// is also written so the completion rule can gate on
  /// `amountPaid >= receiptTotal` without traversing into the `receipt` map.
  static Future<void> submitReceipt({
    required String jobId,
    required String technicianId,
    required List<Map<String, dynamic>> services,
    required List<Map<String, dynamic>> parts,
    String notes = '',
    // subtotals/grandTotal params kept for call-site compat but ignored —
    // values are always recomputed from line items below.
    double servicesSubtotal = 0,
    double partsSubtotal = 0,
    double grandTotal = 0,
  }) async {
    if (services.isEmpty) {
      throw ArgumentError('Receipt must include at least one service');
    }

    // Recompute from line items — never trust client-aggregated totals.
    double computedServicesSub = 0;
    for (final s in services) {
      final p = (s['price'] as num?)?.toDouble() ?? 0.0;
      if (!p.isFinite || p < 0) throw ArgumentError('Invalid service price');
      computedServicesSub += p;
    }
    double computedPartsSub = 0;
    for (final p in parts) {
      final price = (p['price'] as num?)?.toDouble() ?? 0.0;
      if (!price.isFinite || price < 0) throw ArgumentError('Invalid part price');
      computedPartsSub += price;
    }
    final computedGrand = computedServicesSub + computedPartsSub;

    await firestore.runTransaction((tx) async {
      final ref = firestore.collection('jobs').doc(jobId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Job not found');
      final data = snap.data()!;
      if (data['status'] != 'work_finished') {
        throw Exception('Work must be finished before submitting receipt');
      }
      if (data['assignedTechnicianId'] != technicianId) {
        throw Exception('You are not assigned to this job');
      }
      tx.update(ref, {
        'status': 'awaiting_customer_approval',
        'receipt': {
          'services': services,
          'parts': parts,
          'servicesSubtotal': computedServicesSub,
          'partsSubtotal': computedPartsSub,
          'grandTotal': computedGrand,
          'notes': notes,
        },
        'receiptTotal': computedGrand,
        'receiptSubmittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Customer approves the receipt line items (release 006 step 1 of 3).
  /// Transitions: awaiting_customer_approval → awaiting_payment.
  ///
  /// No money moves here — `amountPaid`, `paidAt`, `completedAt` are NOT
  /// written. The customer then pays the technician in person and signals it
  /// by calling `initiatePayment`; the technician taps to confirm and calls
  /// `verifyPayment` to close the order.
  ///
  /// Idempotent: re-calling while already `awaiting_payment` is a no-op.
  static Future<void> approveReceipt(
      String jobId, String customerId) async {
    await firestore.runTransaction((tx) async {
      final ref = firestore.collection('jobs').doc(jobId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Job not found');
      final data = snap.data()!;
      final currentStatus = (data['status'] as String?) ?? '';
      if (currentStatus == 'awaiting_payment') return;
      if (currentStatus != 'awaiting_customer_approval') {
        throw StateError(
            'Unexpected job status: got $currentStatus, expected awaiting_customer_approval');
      }
      if (data['customerId'] != customerId) {
        throw Exception('You are not authorized to approve this order');
      }
      final now = FieldValue.serverTimestamp();
      tx.update(ref, {
        'status': 'awaiting_payment',
        'customerApprovedAt': now,
        'approvedAt': now,
        'updatedAt': now,
      });
    });
    // Activity log is fire-and-forget (non-critical audit trail only).
    // Release-006 note: `customer_approved` now logs line-item approval only
    // (see SECURITY/SEMANTIC NOTE in firestore.rules).
    try {
      await firestore.collection('activity_log').add({
        'type': 'customer_approved',
        'description': 'Customer approved receipt — awaiting payment',
        'jobId': jobId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Customer marks that they paid the technician in person (release 006
  /// step 2 of 3). Transitions: awaiting_payment → awaiting_payment_verification.
  ///
  /// No money data is written here — the technician then taps to confirm
  /// and writes `amountPaid` via `verifyPayment`. The customer cannot reach
  /// `completed` directly; only the tech or an admin (via dispute resolution
  /// or force-close) can.
  ///
  /// Idempotent: re-calling while already `awaiting_payment_verification` is
  /// a no-op.
  static Future<void> initiatePayment(
      String jobId, String customerId) async {
    await firestore.runTransaction((tx) async {
      final ref = firestore.collection('jobs').doc(jobId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Job not found');
      final data = snap.data()!;
      final currentStatus = (data['status'] as String?) ?? '';
      if (currentStatus == 'awaiting_payment_verification') return;
      if (currentStatus != 'awaiting_payment') {
        throw StateError(
            'Unexpected job status: got $currentStatus, expected awaiting_payment');
      }
      if (data['customerId'] != customerId) {
        throw Exception('You are not authorized to mark this order paid');
      }
      tx.update(ref, {
        'status': 'awaiting_payment_verification',
        'paymentInitiatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    try {
      await firestore.collection('activity_log').add({
        'type': 'payment_initiated',
        'description': 'Customer marked payment sent — awaiting verification',
        'jobId': jobId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // TODO(BLAZE): restore photo proof upload — see firestore.rules branch 5
  /// Technician confirms payment received (release 006 step 3 of 3).
  /// Transitions: awaiting_payment_verification → completed. This is one of
  /// three paths that can write `status: 'completed'` — see the SECURITY
  /// INVARIANT comment in firestore.rules (branch 5). The others are admin
  /// dispute-resolve (branch 6) and admin force-close (branch 7).
  ///
  /// Photo-proof upload is intentionally OFF on the Spark plan: the
  /// `paymentProofUrl` parameter and Firestore field are dropped pending
  /// the Blaze upgrade that lets `Storage` initialize. The integrity floor
  /// is preserved by the rules-side `amountPaid >= receiptTotal` gate, so
  /// the tech still cannot record less paid than the customer's approved
  /// receipt says they owe.
  ///
  /// Rule gates, all of which must pass: `assignedTechnicianId == auth.uid`,
  /// `amountPaid >= receiptTotal`, `amountPaid <= 50000`. Client-side we
  /// fail fast on the same checks so the error surface is specific instead
  /// of a generic permission-denied.
  ///
  /// `'price': amountPaid` is written deliberately — the original quote is
  /// overwritten with the actual paid amount on completion so historical
  /// reports and the admin dashboard show the true number, not the stale
  /// pre-receipt quote.
  ///
  /// Revenue + counter movement is bumped by the `onJobStatusChanged` Cloud
  /// Function trigger (Spec 003) when the status lands at `completed`.
  ///
  /// Idempotent: re-calling while already `completed` is a no-op.
  static Future<void> verifyPayment({
    required String jobId,
    required String technicianId,
    required double amountPaid,
  }) async {
    if (!amountPaid.isFinite || amountPaid < 0 || amountPaid > 50000) {
      throw ArgumentError('amountPaid must be in [0, 50000]');
    }

    await firestore.runTransaction((tx) async {
      final ref = firestore.collection('jobs').doc(jobId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Job not found');
      final data = snap.data()!;
      final currentStatus = (data['status'] as String?) ?? '';
      if (currentStatus == 'completed') return;
      if (currentStatus != 'awaiting_payment_verification') {
        throw StateError(
            'Unexpected job status: got $currentStatus, expected awaiting_payment_verification');
      }
      if (data['assignedTechnicianId'] != technicianId) {
        throw Exception('You are not assigned to this job');
      }
      final receiptTotal =
          (data['receiptTotal'] as num?)?.toDouble() ?? 0.0;
      if (amountPaid < receiptTotal) {
        throw ArgumentError(
            'amountPaid ($amountPaid) must be >= receiptTotal ($receiptTotal)');
      }

      final now = FieldValue.serverTimestamp();
      tx.update(ref, {
        'status': 'completed',
        'amountPaid': amountPaid,
        'price': amountPaid,
        'paidAt': now,
        'completedAt': now,
        'paymentVerifiedAt': now,
        'updatedAt': now,
      });
    });
    try {
      await firestore.collection('activity_log').add({
        'type': 'payment_verified',
        'description':
            'Payment verified — ${amountPaid.toStringAsFixed(0)} EGP',
        'jobId': jobId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Customer rejects the submitted receipt.
  /// Transitions: awaiting_customer_approval → receipt_disputed.
  /// The job moves to a distinct status so it no longer surfaces as a pending
  /// receipt and cannot be approved until admin mediates.
  ///
  /// [reason] is the customer's free-text explanation of why they're
  /// disputing — required by the customer UI, capped at 500 chars to mirror
  /// the firestore.rules validator on this branch.
  static Future<void> rejectReceipt(
      String jobId, String customerId,
      {required String reason}) async {
    final String trimmedReason = reason.trim();
    if (trimmedReason.length > 500) {
      throw ArgumentError.value(reason, 'reason', 'max 500 chars');
    }
    await firestore.runTransaction((tx) async {
      final ref = firestore.collection('jobs').doc(jobId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Job not found');
      final data = snap.data()!;
      final currentStatus = (data['status'] as String?) ?? '';
      if (currentStatus == 'receipt_disputed') return;
      if (currentStatus != 'awaiting_customer_approval') {
        throw StateError(
            'Unexpected job status: got $currentStatus, expected awaiting_customer_approval');
      }
      if (data['customerId'] != customerId) {
        throw Exception('You are not authorized to reject this order');
      }
      tx.update(ref, {
        'status': 'receipt_disputed',
        'receiptRejected': true,
        'receiptRejectedAt': FieldValue.serverTimestamp(),
        'disputeReason': trimmedReason,
        'disputedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    try {
      await firestore.collection('activity_log').add({
        'type': 'receipt_rejected',
        'description': 'Customer rejected receipt — admin review needed',
        'jobId': jobId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Streams the job awaiting customer receipt approval for a given customer.
  /// Narrow stream — covers only `awaiting_customer_approval`. Kept for the
  /// "review receipt" card UI. For a full non-terminal customer-job stream,
  /// use `streamCustomerActiveOrder`.
  static Stream<Map<String, dynamic>?> streamCustomerPendingReceipt(
      String customerId) {
    return firestore
        .collection('jobs')
        .where('customerId', isEqualTo: customerId)
        .where('status', isEqualTo: 'awaiting_customer_approval')
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return {'id': doc.id, ...Map<String, dynamic>.from(doc.data())};
    });
  }

  /// Streams the customer's currently-active (non-terminal) job. Added in
  /// release 006 to back the customer's order-progress view across the
  /// approve → initiate → verify payment flow.
  ///
  /// whereIn covers all 10 non-terminal statuses — exactly at Firestore's
  /// 10-value cap. Any future non-terminal status MUST either collapse into
  /// an existing one or this stream will need to be split. Limit 1 is a
  /// convenience for the common case; concurrent customer orders are rare
  /// (rate-limited to 1 order per 60 s at create time) but the UI layer
  /// should be prepared to pick one deterministically if multiple exist.
  ///
  /// Callers in Phase 6 should prefer this over
  /// `streamCustomerPendingReceipt` for anything that needs lifecycle-wide
  /// visibility (active order card, status banner, progress indicator).
  static Stream<Map<String, dynamic>?> streamCustomerActiveOrder(
      String customerId) {
    return firestore
        .collection('jobs')
        .where('customerId', isEqualTo: customerId)
        .where('status', whereIn: [
          'requested',
          'active',
          'technician_accepted',
          'on_the_way',
          'technician_arrived',
          'work_finished',
          'awaiting_customer_approval',
          'awaiting_payment',
          'awaiting_payment_verification',
          'receipt_disputed',
        ])
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return {'id': doc.id, ...Map<String, dynamic>.from(doc.data())};
    });
  }

  /// One-time migration: converts legacy job statuses to canonical names.
  /// Run once from an admin context, then remove.
  ///   accepted       → active
  ///   en_route       → technician_arrived
  ///   in_progress    → work_finished
  ///   inprogress     → work_finished
  ///   payment_pending → awaiting_customer_approval
  static Future<int> migrateLegacyJobStatuses() async {
    const mapping = {
      'accepted': 'active',
      'en_route': 'technician_arrived',
      'in_progress': 'work_finished',
      'inprogress': 'work_finished',
      'payment_pending': 'awaiting_customer_approval',
    };

    int migrated = 0;
    for (final entry in mapping.entries) {
      final snap = await firestore
          .collection('jobs')
          .where('status', isEqualTo: entry.key)
          .get();
      if (snap.docs.isEmpty) continue;

      // Batch in groups of 500 (Firestore limit).
      for (var i = 0; i < snap.docs.length; i += 500) {
        final batch = firestore.batch();
        final chunk = snap.docs.skip(i).take(500);
        for (final doc in chunk) {
          batch.update(doc.reference, {
            'status': entry.value,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          migrated++;
        }
        await batch.commit();
      }
    }
    debugPrint('[migrateLegacyJobStatuses] migrated $migrated jobs.');
    return migrated;
  }
}
