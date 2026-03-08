import 'package:cloud_firestore/cloud_firestore.dart';

/// Payment methods supported by the app.
enum PaymentMethod { cash, vodafoneCash, instaPay }

/// Payment verification status.
enum PaymentStatus { pending, confirmed, rejected }

class Payment {
  final String? id;
  final String orderId;
  final String userId;
  final double amount;
  final PaymentMethod method;
  final PaymentStatus status;
  final String transactionReference;
  final String screenshotUrl;
  final DateTime? createdAt;

  const Payment({
    this.id,
    required this.orderId,
    required this.userId,
    required this.amount,
    required this.method,
    this.status = PaymentStatus.pending,
    this.transactionReference = '',
    this.screenshotUrl = '',
    this.createdAt,
  });

  // ---------------------------------------------------------------------------
  // Serialisation helpers
  // ---------------------------------------------------------------------------

  static String methodToString(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.cash:
        return 'CASH';
      case PaymentMethod.vodafoneCash:
        return 'VODAFONE_CASH';
      case PaymentMethod.instaPay:
        return 'INSTAPAY';
    }
  }

  static PaymentMethod methodFromString(String s) {
    switch (s.toUpperCase()) {
      case 'VODAFONE_CASH':
        return PaymentMethod.vodafoneCash;
      case 'INSTAPAY':
        return PaymentMethod.instaPay;
      default:
        return PaymentMethod.cash;
    }
  }

  static String statusToString(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.pending:
        return 'PENDING';
      case PaymentStatus.confirmed:
        return 'CONFIRMED';
      case PaymentStatus.rejected:
        return 'REJECTED';
    }
  }

  static PaymentStatus statusFromString(String s) {
    switch (s.toUpperCase()) {
      case 'CONFIRMED':
        return PaymentStatus.confirmed;
      case 'REJECTED':
        return PaymentStatus.rejected;
      default:
        return PaymentStatus.pending;
    }
  }

  // ---------------------------------------------------------------------------
  // Firestore ↔ Dart
  // ---------------------------------------------------------------------------

  factory Payment.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Payment.fromMap(data, id: doc.id);
  }

  factory Payment.fromMap(Map<String, dynamic> data, {String? id}) {
    return Payment(
      id: id,
      orderId: data['orderId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      method: methodFromString(data['method'] as String? ?? 'CASH'),
      status: statusFromString(data['status'] as String? ?? 'PENDING'),
      transactionReference: data['transactionReference'] as String? ?? '',
      screenshotUrl: data['screenshotUrl'] as String? ?? '',
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'userId': userId,
      'amount': amount,
      'method': methodToString(method),
      'status': statusToString(status),
      'transactionReference': transactionReference,
      'screenshotUrl': screenshotUrl,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
