import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/service.dart';

/// Service integration layer - connects the app's service keys to the real services from CSV
class ServiceIntegration {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Maps app service keys to CSV category names
  static const Map<String, String> keyToCategoryMap = {
    'ac': 'AC Services',
    'plumbing': 'Plumbing',
    'electricity': 'Electricity',
    'security_intercom': 'Security & Intercom',
    'large_appliances': 'Large Appliances',
    'small_appliances': 'Small Appliances',
    'carpentry': 'Carpentry',
    'pest_control': 'Pest Control',
    'aluminum': 'Alometal',
    'finishing': 'Finishing',
  };

  /// Get all services for a specific service key (category)
  /// Returns list of real services from Firebase CSV collection
  Future<List<Service>> getServicesByKey(String serviceKey) async {
    final categoryName = keyToCategoryMap[serviceKey];
    if (categoryName == null) {
      throw Exception('Unknown service key: $serviceKey');
    }

    try {
      final snapshot = await _firestore
          .collection('services')
          .where('category_en', isEqualTo: categoryName)
          .get();

      return snapshot.docs
          .map((doc) => Service.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch services: $e');
    }
  }

  /// Get all unique subcategories for a service key
  Future<List<String>> getSubcategoriesForKey(String serviceKey) async {
    final services = await getServicesByKey(serviceKey);
    final subcategories = <String>{};

    for (final service in services) {
      subcategories.add(service.subcategoryEn);
    }

    return subcategories.toList()..sort();
  }

  /// Get all services for a specific subcategory.
  /// Uses a compound Firestore query instead of a double-fetch.
  Future<List<Service>> getServicesBySubcategory(
    String serviceKey,
    String subcategoryEn,
  ) async {
    final categoryName = keyToCategoryMap[serviceKey];
    if (categoryName == null) {
      throw Exception('Unknown service key: $serviceKey');
    }
    try {
      final snapshot = await _firestore
          .collection('services')
          .where('category_en', isEqualTo: categoryName)
          .where('subcategoryEn', isEqualTo: subcategoryEn)
          .get();
      return snapshot.docs.map((doc) => Service.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch subcategory services: $e');
    }
  }

  /// Stream all services for real-time updates
  Stream<List<Service>> streamServicesByKey(String serviceKey) {
    final categoryName = keyToCategoryMap[serviceKey];
    if (categoryName == null) {
      throw Exception('Unknown service key: $serviceKey');
    }

    return _firestore
        .collection('services')
        .where('category_en', isEqualTo: categoryName)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Service.fromFirestore(doc)).toList());
  }

  /// Get services matching a search query.
  /// When the query matches a known category key, queries Firestore directly.
  /// Otherwise fetches with a .limit(100) safety cap and filters client-side,
  /// since Firestore does not support native full-text search.
  Future<List<Service>> searchServices(String query) async {
    if (query.trim().isEmpty) return [];
    final lowerQuery = query.toLowerCase().trim();

    // Check if the query matches a known category — use a direct Firestore filter.
    final matchedKey = keyToCategoryMap.entries
        .where((e) =>
            e.key.contains(lowerQuery) ||
            e.value.toLowerCase().contains(lowerQuery))
        .map((e) => e.value)
        .toList();

    try {
      if (matchedKey.isNotEmpty) {
        // Targeted read: only fetch the matching category.
        final snapshot = await _firestore
            .collection('services')
            .where('category_en', isEqualTo: matchedKey.first)
            .get();
        return snapshot.docs
            .map((doc) => Service.fromFirestore(doc))
            .toList();
      }

      // Free-text fallback: cap at 100 docs to avoid unbounded full-collection reads.
      final snapshot = await _firestore
          .collection('services')
          .limit(100)
          .get();
      return snapshot.docs
          .map((doc) => Service.fromFirestore(doc))
          .where((service) =>
              service.serviceNameEn.toLowerCase().contains(lowerQuery) ||
              service.serviceNameAr.contains(query) ||
              service.categoryEn.toLowerCase().contains(lowerQuery) ||
              service.subcategoryEn.toLowerCase().contains(lowerQuery))
          .toList();
    } catch (e) {
      throw Exception('Failed to search services: $e');
    }
  }
}
