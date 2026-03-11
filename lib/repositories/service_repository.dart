import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/service.dart';

/// Repository for managing Service data from Firestore.
/// Provides clean data access patterns for the Flutter app.
class ServiceRepository {
  final FirebaseFirestore _firestore;
  
  static const String _collectionName = 'services';

  ServiceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Fetch all services from Firestore
  Future<List<Service>> getAllServices() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).get();
      return snapshot.docs
          .map((doc) => Service.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch services: $e');
    }
  }

  /// Fetch a single service by ID
  Future<Service?> getServiceById(String serviceId) async {
    try {
      final doc = await _firestore
          .collection(_collectionName)
          .doc(serviceId)
          .get();
      
      if (doc.exists) {
        return Service.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch service: $e');
    }
  }

  /// Get all services for a specific category
  Future<List<Service>> getServicesByCategory(String categoryEn) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('category_en', isEqualTo: categoryEn)
          .get();
      return snapshot.docs
          .map((doc) => Service.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch services by category: $e');
    }
  }

  /// Get services by category and subcategory
  Future<List<Service>> getServicesBySubcategory(
    String categoryEn,
    String subcategoryEn,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('category_en', isEqualTo: categoryEn)
          .where('subcategory_en', isEqualTo: subcategoryEn)
          .get();
      return snapshot.docs
          .map((doc) => Service.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch services by subcategory: $e');
    }
  }

  /// Get unique list of all categories
  Future<List<String>> getCategories() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).get();
      final categories = <String>{};
      
      for (final doc in snapshot.docs) {
        final service = Service.fromFirestore(doc);
        categories.add(service.categoryEn);
      }
      
      return categories.toList()..sort();
    } catch (e) {
      throw Exception('Failed to fetch categories: $e');
    }
  }

  /// Get unique list of subcategories for a category
  Future<List<String>> getSubcategories(String categoryEn) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('category_en', isEqualTo: categoryEn)
          .get();
      
      final subcategories = <String>{};
      for (final doc in snapshot.docs) {
        final service = Service.fromFirestore(doc);
        subcategories.add(service.subcategoryEn);
      }
      
      return subcategories.toList()..sort();
    } catch (e) {
      throw Exception('Failed to fetch subcategories: $e');
    }
  }

  /// Search services by name (English or Arabic)
  Future<List<Service>> searchServices(String query) async {
    try {
      final lowerQuery = query.toLowerCase();
      final snapshot = await _firestore.collection(_collectionName).get();
      
      return snapshot.docs
          .map((doc) => Service.fromFirestore(doc))
          .where((service) =>
              service.serviceNameEn.toLowerCase().contains(lowerQuery) ||
              service.serviceNameAr.contains(query))
          .toList();
    } catch (e) {
      throw Exception('Failed to search services: $e');
    }
  }

  /// Get services with prices (filter out null prices)
  Future<List<Service>> getServicesWithPrices() async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('price', isNotEqualTo: null)
          .get();
      return snapshot.docs
          .map((doc) => Service.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch services with prices: $e');
    }
  }

  /// Get services within a price range
  Future<List<Service>> getServicesByPriceRange(double minPrice, double maxPrice) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('price', isGreaterThanOrEqualTo: minPrice)
          .where('price', isLessThanOrEqualTo: maxPrice)
          .get();
      return snapshot.docs
          .map((doc) => Service.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch services by price range: $e');
    }
  }

  /// Stream all services (for real-time updates)
  Stream<List<Service>> streamAllServices() {
    return _firestore
        .collection(_collectionName)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Service.fromFirestore(doc)).toList());
  }

  /// Stream services for a specific category (for real-time updates)
  Stream<List<Service>> streamServicesByCategory(String categoryEn) {
    return _firestore
        .collection(_collectionName)
        .where('category_en', isEqualTo: categoryEn)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Service.fromFirestore(doc)).toList());
  }

  /// Stream services for a subcategory (for real-time updates)
  Stream<List<Service>> streamServicesBySubcategory(
    String categoryEn,
    String subcategoryEn,
  ) {
    return _firestore
        .collection(_collectionName)
        .where('category_en', isEqualTo: categoryEn)
        .where('subcategory_en', isEqualTo: subcategoryEn)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Service.fromFirestore(doc)).toList());
  }

  /// Add a new service (admin only)
  Future<String> addService(Service service) async {
    try {
      final docRef = await _firestore
          .collection(_collectionName)
          .add(service.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add service: $e');
    }
  }

  /// Update an existing service (admin only)
  Future<void> updateService(String serviceId, Service service) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(serviceId)
          .update(service.toMap());
    } catch (e) {
      throw Exception('Failed to update service: $e');
    }
  }

  /// Delete a service (admin only)
  Future<void> deleteService(String serviceId) async {
    try {
      await _firestore.collection(_collectionName).doc(serviceId).delete();
    } catch (e) {
      throw Exception('Failed to delete service: $e');
    }
  }

  /// Batch update service prices
  Future<void> updatePrices(Map<String, double> priceMap) async {
    try {
      final batch = _firestore.batch();
      
      for (final entry in priceMap.entries) {
        batch.update(
          _firestore.collection(_collectionName).doc(entry.key),
          {'price': entry.value},
        );
      }
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to update prices: $e');
    }
  }

  /// Get count of services by category
  Future<Map<String, int>> getServiceCountByCategory() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).get();
      final counts = <String, int>{};
      
      for (final doc in snapshot.docs) {
        final service = Service.fromFirestore(doc);
        counts[service.categoryEn] = (counts[service.categoryEn] ?? 0) + 1;
      }
      
      return counts;
    } catch (e) {
      throw Exception('Failed to get service count: $e');
    }
  }
}
