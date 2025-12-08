import 'package:scan__pay/services/payment_service.dart';

class PaymentIntent {
  final String id;
  final double amount;
  final String reference;
  PaymentStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  DateTime? paidAt;
  String? txId;
  
  PaymentIntent({
    required this.id,
    required this.amount,
    required this.reference,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.paidAt,
    this.txId,
  });
  
  // Check if payment is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  
  // Get remaining time until expiration
  Duration get timeRemaining {
    if (isExpired) return Duration.zero;
    return expiresAt.difference(DateTime.now());
  }
  
  // Get formatted amount
  String get formattedAmount => '\$${amount.toStringAsFixed(2)}';
  
  // Get status display text
  String get statusText {
    switch (status) {
      case PaymentStatus.pending:
        return isExpired ? 'Expired' : 'Pending';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.expired:
        return 'Expired';
    }
  }
  
  // Convert to JSON for local storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'reference': reference,
      'status': status.index,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'paidAt': paidAt?.toIso8601String(),
      'txId': txId,
    };
  }
  
  // Create from JSON
  factory PaymentIntent.fromJson(Map<String, dynamic> json) {
    return PaymentIntent(
      id: json['id'],
      amount: json['amount'].toDouble(),
      reference: json['reference'],
      status: PaymentStatus.values[json['status']],
      createdAt: DateTime.parse(json['createdAt']),
      expiresAt: DateTime.parse(json['expiresAt']),
      paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt']) : null,
      txId: json['txId'],
    );
  }
  
  @override
  String toString() {
    return 'PaymentIntent(id: $id, amount: $formattedAmount, status: $statusText, reference: $reference)';
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentIntent &&
          runtimeType == other.runtimeType &&
          id == other.id;
  
  @override
  int get hashCode => id.hashCode;
}