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
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class FirebaseService {
  static FirebaseAuth auth = FirebaseAuth.instance;
  static FirebaseFirestore firestore = FirebaseFirestore.instance;
  static FirebaseStorage storage = FirebaseStorage.instance;

  /// Egyptian mobile: 01 + (0|1|2|5) + 8 digits = 11 digits.
  static final _egyptianMobileRegex = RegExp(r'^01[0125]\d{8}$');

  /// Returns true when [phone] is a valid Egyptian mobile number.
  static bool isValidEgyptianMobile(String phone) =>
      _egyptianMobileRegex.hasMatch(phone.trim());

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

    // App Check �� blocks unauthorized clients from reaching Firebase APIs.
    // IMPORTANT: Replace the placeholder reCAPTCHA key with a real one for web
    // builds, and enable App Check enforcement for Firestore, Storage, and Auth
    // in the Firebase Console.
    await FirebaseAppCheck.instance.activate(
      webProvider: ReCaptchaV3Provider('YOUR_RECAPTCHA_V3_SITE_KEY'),
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider:
          kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
    );
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
      };
    }).toList();
  }

  /// Adds a new saved location and returns its document ID.
  static Future<String> addSavedLocation(String uid, Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data);
    final label = (payload['label'] as String? ?? '').trim();
    final street = (payload['street'] as String? ?? '').trim();
    final city = (payload['city'] as String? ?? '').trim();
    final building = (payload['building'] as String? ?? '').trim();
    final notes = (payload['notes'] as String? ?? '').trim();
    final address = (payload['address'] as String? ?? '').trim();

    if (label.length > 50 || street.length > 100 || city.length > 50 ||
        building.length > 100 || notes.length > 200) {
      throw ArgumentError('Location field exceeds maximum length');
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
    payload['createdAt'] = FieldValue.serverTimestamp();
    final ref = await firestore
        .collection('users')
        .doc(uid)
        .collection('locations')
        .add(payload);
    return ref.id;
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

    // Post-signup side effects — only for genuinely new accounts.
    // Wrapped in a single try/catch so a failure in stats/log never blocks
    // account creation.  The isNew guard above prevents duplicate increments.
    // TODO: migrate these to a Cloud Function triggered on Auth user creation
    // to eliminate client-side amplification risk entirely.
    try {
      final Map<String, dynamic> statsInc = {
        'totalUsers': FieldValue.increment(1),
      };
      if (role == 'customer') {
        statsInc['customers'] = FieldValue.increment(1);
      } else if (role == 'technician') {
        statsInc['technicians'] = FieldValue.increment(1);
      }
      await firestore
          .doc('stats/global')
          .set(statsInc, SetOptions(merge: true));

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
    if (role == 'technician') query = query.where('technicianId', isEqualTo: uid);
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
    try {
      final Map<String, dynamic> statsUpdate = {
        'jobsCancelled': FieldValue.increment(1),
      };
      if (prevStatus == 'requested') {
        statsUpdate['jobsRequested'] = FieldValue.increment(-1);
      } else if (const {
        'active', 'technician_accepted', 'technician_arrived',
        'work_finished', 'awaiting_customer_approval', 'receipt_disputed',
      }.contains(prevStatus)) {
        statsUpdate['jobsOngoing'] = FieldValue.increment(-1);
      }
      await firestore
          .doc('stats/global')
          .set(statsUpdate, SetOptions(merge: true));
      await firestore.collection('activity_log').add({
        'type': 'job_cancelled',
        'description': 'Job cancelled',
        'jobId': jobId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
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

  /// Streams all support chats ordered by most recent activity (admin use).
  static Stream<List<Map<String, dynamic>>> streamSupportChats() {
    return firestore
        .collection('support_chats')
        .orderBy('lastMessageAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = Map<String, dynamic>.from(d.data());
              data['id'] = d.id;
              return data;
            }).toList());
  }

  /// Streams the count of open support chats with unread messages (admin badge).
  static Stream<int> streamUnreadSupportCount() {
    return firestore
        .collection('support_chats')
        .where('unreadByAdmin', isEqualTo: true)
        .where('status', isEqualTo: 'open')
        .snapshots()
        .map((snap) => snap.docs.length);
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

  /// Marks a support chat as closed (called by admin).
  static Future<void> closeSupportChat(String chatId) async {
    await firestore.collection('support_chats').doc(chatId).update({
      'status': 'closed',
      'closedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Clears the unread flag when admin opens a support chat.
  static Future<void> markSupportChatReadByAdmin(String chatId) async {
    await firestore
        .collection('support_chats')
        .doc(chatId)
        .update({'unreadByAdmin': false});
  }

  // ----------------------
  // IMAGE COMPRESSION
  // ----------------------
  /// Compresses [file] to JPEG with max dimension [maxDimension]px and
  /// [quality] (0–100). Returns the compressed bytes, or falls back to the
  /// original bytes if compression is unavailable (e.g. web).
  static Future<List<int>> compressImage(
    XFile file, {
    int maxDimension = 480,
    int quality = 60,
  }) async {
    // Web: flutter_image_compress is not supported — fall back to raw bytes.
    if (kIsWeb) return await file.readAsBytes();

    final rawBytes = await file.readAsBytes();
    final compressed = await FlutterImageCompress.compressWithList(
      rawBytes,
      minWidth: maxDimension,
      minHeight: maxDimension,
      quality: quality,
      format: CompressFormat.jpeg,
    );
    return compressed;
  }

  // ----------------------
  // UPLOAD PHOTO
  // ----------------------
  /// Compresses [file] before uploading to Firebase Storage.
  /// Max dimension: 480 px · JPEG quality: 60 → typical reduction ~92 %.
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

  // ----------------------
  // TECHNICIAN STATUS / RATINGS / EARNINGS
  // ----------------------
  static Future<void> updateAvailability(String uid, bool available) async {
    await firestore.collection('users').doc(uid).update({'available': available});
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
    await firestore.collection('users').doc(uid).update({
      'earnings': FieldValue.increment(amount),
    });
    // Keep a global running total so the admin dashboard can read one doc
    // instead of scanning all technician docs.
    await firestore.doc('stats/global').set(
      {'totalEarnings': FieldValue.increment(amount)},
      SetOptions(merge: true),
    );
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
  // INVENTORY MANAGEMENT
  // ----------------------
  static Future<void> addInventoryItem({
    required String technicianId,
    required String itemName,
    required int quantity,
    required double costPerItem,
    String description = '',
  }) async {
    await firestore.collection('inventory').add({
      'technicianId': technicianId,
      'itemName': itemName,
      'quantity': quantity,
      'costPerItem': costPerItem,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateInventoryItem({
    required String itemId,
    required String itemName,
    required int quantity,
    required double costPerItem,
    String description = '',
  }) async {
    await firestore.collection('inventory').doc(itemId).update({
      'itemName': itemName,
      'quantity': quantity,
      'costPerItem': costPerItem,
      'description': description,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteInventoryItem(String itemId) async {
    await firestore.collection('inventory').doc(itemId).delete();
  }

  static Stream<List<Map<String, dynamic>>> streamInventory(String technicianId) {
    return firestore
        .collection('inventory')
        .where('technicianId', isEqualTo: technicianId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = Map<String, dynamic>.from(d.data());
              data['id'] = d.id;
              return data;
            }).toList());
  }

  static Future<List<Map<String, dynamic>>> getInventory(String technicianId) async {
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

  /// Admin: update payment status to CONFIRMED or REJECTED.
  static Future<void> updatePaymentStatus(
      String paymentId, String status) async {
    await firestore.collection('payments').doc(paymentId).update({
      'status': status,
    });
  }

  /// Streams all payments (admin view).
  static Stream<List<Map<String, dynamic>>> streamAllPayments() {
    return firestore
        .collection('payments')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = Map<String, dynamic>.from(d.data());
              data['id'] = d.id;
              return data;
            }).toList());
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
    required String urgencyType, // 'urgent' | 'scheduled'
    DateTime? scheduledTime,
    double price = 0.0,
  }) async {
    if (description.trim().isEmpty || description.trim().length > 500) {
      throw ArgumentError('Description must be 1–500 characters');
    }
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
      'locationLabel': locationLabel,
      'locationAddress': locationAddress,
      'urgencyType': urgencyType,
      'scheduledTime':
          scheduledTime != null ? Timestamp.fromDate(scheduledTime) : null,
      'status': 'requested',
      'price': price,
      'amountPaid': null,
      'adminClosedAt': null,
      'photos': [],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    // Batched write: create the job AND bump the user's lastOrderAt in one
    // atomic operation.  Firestore rules use getAfter() to verify the batch
    // includes the cooldown update, and enforce a 60-second gap on the user doc.
    final batch = firestore.batch();
    final userRef = firestore.collection('users').doc(customerId);
    batch.update(userRef, {'lastOrderAt': FieldValue.serverTimestamp()});
    final jobRef = firestore.collection('jobs').doc();
    batch.set(jobRef, data);
    await batch.commit();

    // Increment jobsRequested counter and append activity event.
    try {
      await firestore
          .doc('stats/global')
          .set({'jobsRequested': FieldValue.increment(1)}, SetOptions(merge: true));
      await firestore.collection('activity_log').add({
        'type': 'job_requested',
        'description':
            '${serviceCategory.isNotEmpty ? serviceCategory : serviceKey} — $customerName',
        'jobId': jobRef.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    return jobRef.id;
  }

  /// Admin assigns a technician to a requested job → status becomes 'accepted'.
  static Future<void> assignJob({
    required String jobId,
    required String technicianId,
    required String technicianName,
  }) async {
    await firestore.runTransaction((tx) async {
      final ref = firestore.collection('jobs').doc(jobId);
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw Exception('Job not found');
      }

      final data = snap.data()!;
      if (data['status'] != 'requested') {
        throw Exception('Job is no longer available for assignment');
      }

      tx.update(ref, {
        'assignedTechnicianId': technicianId,
        'technicianId': technicianId, // kept for existing stream queries
        'assignedTechnicianName': technicianName,
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    // Move counter: one fewer requested, one more ongoing.
    try {
      await firestore.doc('stats/global').set({
        'jobsRequested': FieldValue.increment(-1),
        'jobsOngoing': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  static Stream<Map<String, dynamic>?> streamTechnicianActiveJob(String technicianId) {
    return firestore
        .collection('jobs')
        .where('assignedTechnicianId', isEqualTo: technicianId)
        .where('status', whereIn: [
          'active',
          'technician_accepted',
          'technician_arrived',
          'work_finished',
          'awaiting_customer_approval',
          'receipt_disputed',
        ])
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return {
        'id': doc.id,
        ...Map<String, dynamic>.from(doc.data()),
      };
    });
  }

  /// Admin closes an active job with the exact amount paid.
  /// Uses a transaction to ensure revenue is incremented only once.
  /// Returns true if the job was newly closed; false if already closed.
  static Future<bool> adminCloseJob({
    required String jobId,
    required double amountPaid,
  }) async {
    bool closed = false;
    await firestore.runTransaction((tx) async {
      final ref = firestore.collection('jobs').doc(jobId);
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      // Idempotency guard: if adminClosedAt is already set, skip.
      if (data['adminClosedAt'] != null) return;
      tx.update(ref, {
        'status': 'completed',
        'amountPaid': amountPaid,
        'price': amountPaid,
        'adminClosedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      closed = true;
    });
    if (closed) {
      // Batch all stats changes in one write: revenue + job counters.
      await firestore.doc('stats/global').set({
        'totalEarnings': FieldValue.increment(amountPaid),
        'jobsCompleted': FieldValue.increment(1),
        'jobsOngoing': FieldValue.increment(-1),
      }, SetOptions(merge: true));
      try {
        await firestore.collection('activity_log').add({
          'type': 'job_completed',
          'description': 'Job closed — ${amountPaid.toStringAsFixed(0)} EGP',
          'jobId': jobId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
    return closed;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ADMIN JOB STREAMS (by status)
  // ─────────────────────────────────────────────────────────────────────────

  /// Streams all jobs with a given single status (e.g., 'requested', 'completed').
  static Stream<List<Map<String, dynamic>>> streamJobsByStatus(String status) {
    return firestore
        .collection('jobs')
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = Map<String, dynamic>.from(d.data() as Map);
              data['id'] = d.id;
              return data;
            }).toList());
  }

  /// Streams active jobs (accepted + in_progress) for admin view.
  static Stream<List<Map<String, dynamic>>> streamActiveJobsAdmin() {
    return firestore
        .collection('jobs')
        .where('status', whereIn: [
          'active',
          'technician_accepted',
          'technician_arrived',
          'work_finished',
          'awaiting_customer_approval',
          'receipt_disputed',
        ])
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = Map<String, dynamic>.from(d.data() as Map);
              data['id'] = d.id;
              return data;
            }).toList());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TECHNICIAN FILTERING (for admin assignment)
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
  static Future<void> notifyAvailableTechnicians({
    required String jobId,
    required String serviceKey,
    required String serviceCategory,
    required String customerName,
    required String locationAddress,
    required String urgencyType,
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
  // RECENT USERS (admin dashboard — latest signups)
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetches the [limit] most recently created user documents, newest first.
  /// One-time read — no open subscription. Callers trigger refresh explicitly.
  static Future<List<Map<String, dynamic>>> fetchRecentUsers(
      {int limit = 3}) async {
    final snap = await firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data());
      data['id'] = d.id;
      return data;
    }).toList();
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

  /// Step 2: Technician confirms arrival at the customer location.
  /// Transitions: technician_accepted → technician_arrived.
  static Future<void> markTechnicianArrived(
      String jobId, String technicianId) async {
    await firestore.runTransaction((tx) async {
      final ref = firestore.collection('jobs').doc(jobId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Job not found');
      final data = snap.data()!;
      if (data['status'] != 'technician_accepted') {
        throw Exception('Job is not ready for arrival confirmation');
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

  /// Technician submits a structured receipt after finishing work.
  /// Transitions: work_finished → awaiting_customer_approval.
  ///
  /// Totals are RECOMPUTED from the line items here and override any values
  /// passed in from the client, so a buggy or modified client cannot persist
  /// inconsistent billing numbers.
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
        'receiptSubmittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Customer approves the submitted receipt.
  /// Transitions: awaiting_customer_approval → completed.
  ///
  /// The grand total used as amountPaid is the server-stored computed value
  /// from submitReceipt — not a re-read from the client.
  /// Stats/global is updated inside the same transaction so completion and
  /// accounting are atomic and cannot silently diverge on a partial failure.
  static Future<void> approveReceipt(
      String jobId, String customerId) async {
    double amountPaid = 0.0;
    await firestore.runTransaction((tx) async {
      final jobRef = firestore.collection('jobs').doc(jobId);
      final statsRef = firestore.doc('stats/global');

      final snap = await tx.get(jobRef);
      if (!snap.exists) throw Exception('Job not found');
      final data = snap.data()!;
      if (data['status'] != 'awaiting_customer_approval') {
        throw Exception('Order is not awaiting approval');
      }
      if (data['customerId'] != customerId) {
        throw Exception('You are not authorized to approve this order');
      }
      final receipt = data['receipt'] as Map<String, dynamic>?;
      if (receipt == null) throw Exception('No receipt found on this order');
      amountPaid = (receipt['grandTotal'] as num?)?.toDouble() ?? 0.0;

      tx.update(jobRef, {
        'status': 'completed',
        'amountPaid': amountPaid,
        'price': amountPaid,
        'customerApprovedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // Stats increment is inside the same transaction — atomic with completion.
      tx.set(statsRef, {
        'totalEarnings': FieldValue.increment(amountPaid),
        'jobsCompleted': FieldValue.increment(1),
        'jobsOngoing': FieldValue.increment(-1),
      }, SetOptions(merge: true));
    });
    // Activity log is fire-and-forget (non-critical audit trail only).
    try {
      await firestore.collection('activity_log').add({
        'type': 'job_completed',
        'description':
            'Job completed — ${amountPaid.toStringAsFixed(0)} EGP',
        'jobId': jobId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Customer rejects the submitted receipt.
  /// Transitions: awaiting_customer_approval → receipt_disputed.
  /// The job moves to a distinct status so it no longer surfaces as a pending
  /// receipt and cannot be approved until admin mediates.
  static Future<void> rejectReceipt(
      String jobId, String customerId) async {
    await firestore.runTransaction((tx) async {
      final ref = firestore.collection('jobs').doc(jobId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Job not found');
      final data = snap.data()!;
      if (data['status'] != 'awaiting_customer_approval') {
        throw Exception('Order is not awaiting approval');
      }
      if (data['customerId'] != customerId) {
        throw Exception('You are not authorized to reject this order');
      }
      tx.update(ref, {
        'status': 'receipt_disputed',
        'receiptRejected': true,
        'receiptRejectedAt': FieldValue.serverTimestamp(),
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

  /// Admin resolves a disputed receipt.
  /// [resolution] must be one of:
  ///   'reopen'   — send the receipt back for customer approval
  ///   'complete' — admin closes the job as completed
  ///   'cancel'   — admin cancels the job
  static Future<void> adminResolveDispute({
    required String jobId,
    required String resolution,
    double? overrideAmount,
  }) async {
    if (!{'reopen', 'complete', 'cancel'}.contains(resolution)) {
      throw ArgumentError('Invalid resolution: $resolution');
    }

    await firestore.runTransaction((tx) async {
      final ref = firestore.collection('jobs').doc(jobId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Job not found');
      final data = snap.data()!;
      if (data['status'] != 'receipt_disputed') {
        throw Exception('Job is not in disputed state');
      }

      switch (resolution) {
        case 'reopen':
          tx.update(ref, {
            'status': 'awaiting_customer_approval',
            'receiptRejected': false,
            'disputeResolvedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          break;
        case 'complete':
          final receipt = data['receipt'] as Map<String, dynamic>?;
          final amount = overrideAmount ??
              (receipt?['grandTotal'] as num?)?.toDouble() ??
              0.0;
          tx.update(ref, {
            'status': 'completed',
            'amountPaid': amount,
            'price': amount,
            'disputeResolvedAt': FieldValue.serverTimestamp(),
            'adminClosedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          final statsRef = firestore.doc('stats/global');
          tx.set(statsRef, {
            'totalEarnings': FieldValue.increment(amount),
            'jobsCompleted': FieldValue.increment(1),
            'jobsOngoing': FieldValue.increment(-1),
          }, SetOptions(merge: true));
          break;
        case 'cancel':
          tx.update(ref, {
            'status': 'cancelled',
            'disputeResolvedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          final statsRef = firestore.doc('stats/global');
          tx.set(statsRef, {
            'jobsCancelled': FieldValue.increment(1),
            'jobsOngoing': FieldValue.increment(-1),
          }, SetOptions(merge: true));
          break;
      }
    });

    try {
      await firestore.collection('activity_log').add({
        'type': 'dispute_resolved',
        'description': 'Dispute resolved: $resolution',
        'jobId': jobId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Streams the job awaiting customer receipt approval for a given customer.
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

  // ─────────────────────────────────────────────────────────────────────────
  // RECENT ACTIVITY FEED (admin-only reads, append-only writes)
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetches the [limit] most recent activity events ordered newest-first.
  /// One-time read — no open subscription. Callers trigger refresh explicitly.
  static Future<List<Map<String, dynamic>>> fetchRecentActivity(
      {int limit = 10}) async {
    final snap = await firestore
        .collection('activity_log')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data());
      data['id'] = d.id;
      return data;
    }).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STATS INITIALIZATION (admin-only)
  // ─────────────────────────────────────────────────────────────────────────

  /// Seeds `stats/global` from live aggregation queries.
  /// Call once during project setup or whenever the document is missing/incomplete.
  /// Requires admin permissions.
  static Future<void> initializeStatsGlobal() async {
    final results = await Future.wait([
      firestore.collection('users').count().get(),
      firestore.collection('users').where('role', isEqualTo: 'customer').count().get(),
      firestore.collection('users').where('role', isEqualTo: 'technician').count().get(),
      firestore.collection('jobs').where('status', isEqualTo: 'requested').count().get(),
      firestore.collection('jobs').where('status', whereIn: [
        'active', 'technician_accepted', 'technician_arrived', 'work_finished',
        'awaiting_customer_approval', 'receipt_disputed',
      ]).count().get(),
      firestore.collection('jobs').where('status', isEqualTo: 'completed').count().get(),
      firestore.collection('jobs').where('status', isEqualTo: 'cancelled').count().get(),
      firestore.collection('support_chats').where('status', isEqualTo: 'open').count().get(),
    ]);

    await firestore.doc('stats/global').set({
      'totalUsers': (results[0]).count ?? 0,
      'customers': (results[1]).count ?? 0,
      'technicians': (results[2]).count ?? 0,
      'jobsRequested': (results[3]).count ?? 0,
      'jobsOngoing': (results[4]).count ?? 0,
      'jobsCompleted': (results[5]).count ?? 0,
      'jobsCancelled': (results[6]).count ?? 0,
      'activeChats': (results[7]).count ?? 0,
      'totalEarnings': 0.0, // Cannot be derived from count(); admin sets manually.
    });
    debugPrint('[initializeStatsGlobal] stats/global seeded from live counts.');
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
