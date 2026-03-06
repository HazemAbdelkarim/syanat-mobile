import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

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

  /// Creates a user record. Use for both customers and technicians.
  static Future<void> createUser({
    required String uid,
    required String email,
    required String username,
    required String role, // 'customer' | 'technician'
    String city = '',
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
    if (location != null) data['location'] = location;
    if (photoUrl.isNotEmpty) data['photoUrl'] = photoUrl;

    await firestore.collection('users').doc(uid).set(data, SetOptions(merge: true));
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
      service: serviceId,
      language: language,
      featured: featured,
      available: true,
      location: location,
      photoUrl: photoUrl,
    );

    // Ensure service document exists (merge so it doesn't overwrite)
    final nameEn = serviceNameEn.trim().isNotEmpty ? serviceNameEn : _prettyServiceLabel(serviceId);
    final nameAr = serviceNameAr.trim().isNotEmpty ? serviceNameAr : nameEn;
    await ensureServiceExists(serviceId, nameEn, nameAr);
  }

  // ----------------------
  // SERVICES
  // ----------------------
  static Future<void> ensureServiceExists(String serviceId, String nameEn, String nameAr, {String icon = ''}) async {
    if (serviceId.trim().isEmpty) return;
    final docRef = firestore.collection('services').doc(serviceId);
    await docRef.set({
      'name_en': nameEn,
      'name_ar': nameAr,
      'icon': icon,
    }, SetOptions(merge: true));
  }

  static String _prettyServiceLabel(String id) {
    final parts = id.split(RegExp(r'[_\-\s]+'));
    return parts.map((p) => p.isEmpty ? '' : p[0].toUpperCase() + (p.length > 1 ? p.substring(1) : '')).join(' ');
  }

  static Future<List<Map<String, dynamic>>> getServices() async {
    final techSnapshot = await firestore.collection('users').where('role', isEqualTo: 'technician').get();
    final Set<String> serviceKeys = {};
    for (final d in techSnapshot.docs) {
      final s = d.data()['service'];
      if (s != null) {
        final val = s.toString().trim();
        if (val.isNotEmpty) serviceKeys.add(val);
      }
    }

    final servicesSnapshot = await firestore.collection('services').get();
    final Map<String, Map<String, dynamic>> serviceDocs = {};
    for (final d in servicesSnapshot.docs) {
      serviceDocs[d.id] = Map<String, dynamic>.from(d.data());
    }

    final List<Map<String, dynamic>> result = [];
    for (final key in serviceKeys) {
      if (serviceDocs.containsKey(key)) {
        final data = serviceDocs[key]!;
        result.add({
          'key': key,
          'name_en': (data['name_en'] as String?)?.trim() ?? _prettyServiceLabel(key),
          'name_ar': (data['name_ar'] as String?)?.trim() ?? _prettyServiceLabel(key),
          'icon': (data['icon'] as String?) ?? '',
        });
      } else {
        final pretty = _prettyServiceLabel(key);
        result.add({'key': key, 'name_en': pretty, 'name_ar': pretty, 'icon': ''});
      }
    }

    result.sort((a, b) => (a['name_en'] as String).compareTo(b['name_en'] as String));
    return result;
  }

  static Stream<List<Map<String, dynamic>>> streamServices() async* {
    final usersStream = firestore.collection('users').where('role', isEqualTo: 'technician').snapshots();
    await for (final _ in usersStream) {
      final servicesList = await getServices();
      yield servicesList;
    }
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
    return query.orderBy('createdAt', descending: true).snapshots().map((snap) {
      return snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data() as Map<String, dynamic>);

        data['id'] = d.id;
        return data;
      }).toList();
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
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  static Stream<List<Map<String, dynamic>>> streamChats({required String uid, required String role}) {
    Query query = firestore.collection('chats');
    if (role == 'customer') query = query.where('customerId', isEqualTo: uid);
    if (role == 'technician') query = query.where('technicianId', isEqualTo: uid);
    return query.orderBy('createdAt', descending: true).snapshots().map((snap) {
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
        .orderBy('timestamp')
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
    required String sender,
    required String content,
    String type = 'text',
    String photoUrl = '',
  }) async {
    await firestore.collection('chats').doc(chatId).collection('messages').add({
      'sender': sender,
      'content': content,
      'type': type,
      'photoUrl': photoUrl,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ----------------------
  // UPLOAD PHOTO
  // ----------------------
  static Future<String> uploadPhoto(XFile file, {String? folder}) async {
    final ref = storage.ref().child('${folder ?? 'uploads'}/${DateTime.now().millisecondsSinceEpoch}');
    final bytes = await file.readAsBytes();
    await ref.putData(bytes).timeout(const Duration(seconds: 30));
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

  static Future<void> updateRating(String uid, double rating) async {
    final doc = firestore.collection('users').doc(uid);
    final snapshot = await doc.get();
    if (!snapshot.exists) return;
    final data = snapshot.data()!;
    final currentRating = (data['rating'] as num?)?.toDouble() ?? 0.0;
    final ratingCount = (data['ratingCount'] as num?)?.toInt() ?? 0;
    final newCount = ratingCount + 1;
    final newRating = ((currentRating * ratingCount) + rating) / newCount;
    await doc.update({'rating': newRating, 'ratingCount': newCount});
  }

  static Future<void> addEarnings(String uid, double amount) async {
    final doc = firestore.collection('users').doc(uid);
    final snapshot = await doc.get();
    if (!snapshot.exists) return;
    final current = (snapshot.data()?['earnings'] as num?)?.toDouble() ?? 0.0;
    await doc.update({'earnings': current + amount});
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
        .get();
    return snap.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data());
      data['id'] = d.id;
      return data;
    }).toList();
  }
}
