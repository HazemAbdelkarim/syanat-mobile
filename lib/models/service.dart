import 'package:cloud_firestore/cloud_firestore.dart';

/// Service model representing a service offered in the app.
/// Supports bilingual content (English and Arabic).
class Service {
  final String? id;
  final String categoryEn;
  final String categoryAr;
  final String subcategoryEn;
  final String subcategoryAr;
  final String serviceNameEn;
  final String serviceNameAr;
  final double? price;
  final DateTime? createdAt;

  const Service({
    this.id,
    required this.categoryEn,
    required this.categoryAr,
    required this.subcategoryEn,
    required this.subcategoryAr,
    required this.serviceNameEn,
    required this.serviceNameAr,
    this.price,
    this.createdAt,
  });

  /// Convert Firestore document to Service object
  factory Service.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return Service.fromJson(data, doc.id);
  }

  /// Create Service from JSON/Map
  factory Service.fromJson(Map<String, dynamic> json, [String? docId]) {
    return Service(
      id: docId,
      categoryEn: json['category_en'] as String? ?? '',
      categoryAr: json['category_ar'] as String? ?? '',
      subcategoryEn: json['subcategory_en'] as String? ?? '',
      subcategoryAr: json['subcategory_ar'] as String? ?? '',
      serviceNameEn: json['service_name_en'] as String? ?? '',
      serviceNameAr: json['service_name_ar'] as String? ?? '',
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Convert Service to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'category_en': categoryEn,
      'category_ar': categoryAr,
      'subcategory_en': subcategoryEn,
      'subcategory_ar': subcategoryAr,
      'service_name_en': serviceNameEn,
      'service_name_ar': serviceNameAr,
      'price': price,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  /// Convert Service to JSON (for API responses)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_en': categoryEn,
      'category_ar': categoryAr,
      'subcategory_en': subcategoryEn,
      'subcategory_ar': subcategoryAr,
      'service_name_en': serviceNameEn,
      'service_name_ar': serviceNameAr,
      'price': price,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  /// Create a copy of Service with modified fields
  Service copyWith({
    String? id,
    String? categoryEn,
    String? categoryAr,
    String? subcategoryEn,
    String? subcategoryAr,
    String? serviceNameEn,
    String? serviceNameAr,
    double? price,
    DateTime? createdAt,
  }) {
    return Service(
      id: id ?? this.id,
      categoryEn: categoryEn ?? this.categoryEn,
      categoryAr: categoryAr ?? this.categoryAr,
      subcategoryEn: subcategoryEn ?? this.subcategoryEn,
      subcategoryAr: subcategoryAr ?? this.subcategoryAr,
      serviceNameEn: serviceNameEn ?? this.serviceNameEn,
      serviceNameAr: serviceNameAr ?? this.serviceNameAr,
      price: price ?? this.price,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Service(id: $id, categoryEn: $categoryEn, serviceNameEn: $serviceNameEn, price: $price)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Service &&
        other.id == id &&
        other.categoryEn == categoryEn &&
        other.categoryAr == categoryAr &&
        other.subcategoryEn == subcategoryEn &&
        other.subcategoryAr == subcategoryAr &&
        other.serviceNameEn == serviceNameEn &&
        other.serviceNameAr == serviceNameAr &&
        other.price == price &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      categoryEn,
      categoryAr,
      subcategoryEn,
      subcategoryAr,
      serviceNameEn,
      serviceNameAr,
      price,
      createdAt,
    );
  }
}
