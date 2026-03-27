import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
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
    // Debug provider is used automatically on debug builds; swap in production
    // providers before releasing. Replace the reCAPTCHA key with the real one
    // from the Firebase console before deploying the web build.
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

  /// Updates specific fields on the user profile document.
  static Future<void> updateProfile(String uid, Map<String, dynamic> fields) async {
    await firestore.collection('users').doc(uid).update(fields);
  }

  // ── Saved Locations ──────────────────────────────────────────────────────

  /// Returns all saved locations for a user.
  static Future<List<Map<String, dynamic>>> getSavedLocations(String uid) async {
    final snap = await firestore
        .collection('users')
        .doc(uid)
        .collection('locations')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  /// Adds a new saved location and returns its document ID.
  static Future<String> addSavedLocation(String uid, Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    final ref = await firestore
        .collection('users')
        .doc(uid)
        .collection('locations')
        .add(data);
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
  static Future<void> createUser({
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
    final data = {
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
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (phone.isNotEmpty) data['phone'] = phone;
    if (location != null) data['location'] = location;
    if (photoUrl.isNotEmpty) data['photoUrl'] = photoUrl;

    await firestore.collection('users').doc(uid).set(data, SetOptions(merge: true));

    // Increment aggregate counters atomically — one doc read saved on every
    // dashboard load because stats/global is kept current at write time.
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

    // Activity log — fire-and-forget, must not block account creation.
    try {
      await firestore.collection('activity_log').add({
        'type': 'account_created',
        'description': username.isNotEmpty ? username : email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Helper: create a technician user and ensure its service entry exists.
  static Future<void> createTechnician({
    required String uid,
    required String email,
    required String username,
    required String serviceId,
    String serviceNameEn = '',
    String serviceNameAr = '',
    String city = '',
    String phone = '',
    String language = 'en',
    bool featured = false,
    GeoPoint? location,
    String photoUrl = '',
  }) async {
    await createUser(
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

    // Ensure service document exists (merge so it doesn't overwrite existing data),
    // then atomically increment the technician count for that service.
    // FieldValue.increment is crash-safe and requires no prior read.
    final nameEn = serviceNameEn.trim().isNotEmpty ? serviceNameEn : _prettyServiceLabel(serviceId);
    final nameAr = serviceNameAr.trim().isNotEmpty ? serviceNameAr : nameEn;
    await ensureServiceExists(serviceId, nameEn, nameAr);
    await firestore.collection('services').doc(serviceId).update({
      'techCount': FieldValue.increment(1),
    });
  }

  // ----------------------
  // SERVICES
  // ----------------------
  static Future<void> ensureServiceExists(
    String serviceId,
    String nameEn,
    String nameAr, {
    String icon = '',
  }) async {
    if (serviceId.trim().isEmpty) return;
    final docRef = firestore.collection('services').doc(serviceId);
    // merge: true so we never overwrite an existing techCount.
    // techCount is only set here on first creation (when the field is absent).
    await docRef.set({
      'name_en': nameEn,
      'name_ar': nameAr,
      'icon': icon,
      'techCount': 0, // initialised to 0; incremented by createTechnician()
    }, SetOptions(merge: true));
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
    final docRef = await firestore.collection('jobs').add({
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
    return docRef.id;
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
      } else if (prevStatus == 'accepted' ||
          prevStatus == 'in_progress' ||
          prevStatus == 'inprogress') {
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

  static Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
    String type = 'text',
    String photoUrl = '',
  }) async {
    await firestore.collection('chats').doc(chatId).collection('messages').add({
      'senderId': senderId,
      'text': text,
      'type': type,
      'photoUrl': photoUrl,
      'createdAt': FieldValue.serverTimestamp(),
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
    if (setUnreadForAdmin) chatUpdate['unreadByAdmin'] = true;
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
  }) async {
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
      'phoneNumber': phoneNumber,
      'locationLabel': locationLabel,
      'locationAddress': locationAddress,
      'urgencyType': urgencyType,
      'scheduledTime':
          scheduledTime != null ? Timestamp.fromDate(scheduledTime) : null,
      'status': 'requested',
      'price': 0.0,
      'amountPaid': null,
      'adminClosedAt': null,
      'photos': [],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final docRef = await firestore.collection('jobs').add(data);

    // Increment jobsRequested counter and append activity event.
    try {
      await firestore
          .doc('stats/global')
          .set({'jobsRequested': FieldValue.increment(1)}, SetOptions(merge: true));
      await firestore.collection('activity_log').add({
        'type': 'job_requested',
        'description':
            '${serviceCategory.isNotEmpty ? serviceCategory : serviceKey} — $customerName',
        'jobId': docRef.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    return docRef.id;
  }

  /// Admin assigns a technician to a requested job → status becomes 'accepted'.
  static Future<void> assignJob({
    required String jobId,
    required String technicianId,
    required String technicianName,
  }) async {
    await firestore.collection('jobs').doc(jobId).update({
      'assignedTechnicianId': technicianId,
      'technicianId': technicianId, // kept for existing stream queries
      'assignedTechnicianName': technicianName,
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // Move counter: one fewer requested, one more ongoing.
    try {
      await firestore.doc('stats/global').set({
        'jobsRequested': FieldValue.increment(-1),
        'jobsOngoing': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (_) {}
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
        .where('status', whereIn: ['accepted', 'in_progress', 'inprogress'])
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
  static Future<List<Map<String, dynamic>>> getAvailableTechniciansByService(
      String serviceKey) async {
    final snap = await firestore
        .collection('users')
        .where('role', isEqualTo: 'technician')
        .where('service', isEqualTo: serviceKey)
        .where('available', isEqualTo: true)
        .limit(30)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
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
      final techs = await getAvailableTechniciansByService(serviceKey);
      if (techs.isEmpty) return;
      // Batch-write all notifications in a single round-trip.
      final batch = firestore.batch();
      for (final tech in techs) {
        final techId = tech['id'] as String? ?? '';
        if (techId.isEmpty) continue;
        final ref = firestore.collection('notifications').doc();
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
      await batch.commit();
    } catch (_) {
      // Notification failure must not block the customer's order creation.
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
  static Stream<int> streamTechnicianUnreadNotifCount(String techId) {
    return firestore
        .collection('notifications')
        .where('technicianId', isEqualTo: techId)
        .where('read', isEqualTo: false)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Marks a notification as read.
  static Future<void> markNotificationRead(String notifId) async {
    await firestore
        .collection('notifications')
        .doc(notifId)
        .update({'read': true});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CANCELLED JOBS COUNT (for admin overview)
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns total count of cancelled jobs via aggregation (1 read).
  static Future<int> getCancelledJobsCount() async {
    final snap = await firestore
        .collection('jobs')
        .where('status', isEqualTo: 'cancelled')
        .count()
        .get();
    return snap.count ?? 0;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RECENT USERS (admin dashboard — latest signups)
  // ─────────────────────────────────────────────────────────────────────────

  /// Streams the [limit] most recently created user documents, newest first.
  /// Uses the auto-indexed single-field orderBy on createdAt — no composite
  /// index required. Includes all roles; callers filter display as needed.
  static Stream<List<Map<String, dynamic>>> streamRecentUsers(
      {int limit = 3}) {
    return firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = Map<String, dynamic>.from(d.data());
              data['id'] = d.id;
              return data;
            }).toList());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RECENT ACTIVITY FEED (admin-only reads, append-only writes)
  // ─────────────────────────────────────────────────────────────────────────

  /// Streams the [limit] most recent activity events ordered newest-first.
  /// Each document has: type, description, createdAt, and optional jobId/role.
  static Stream<List<Map<String, dynamic>>> streamRecentActivity(
      {int limit = 10}) {
    return firestore
        .collection('activity_log')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = Map<String, dynamic>.from(d.data());
              data['id'] = d.id;
              return data;
            }).toList());
  }
}
