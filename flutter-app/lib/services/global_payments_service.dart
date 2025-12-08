import 'package:cloud_functions/cloud_functions.dart';

/// Global Payments Service
///
/// This service handles real-time transaction verification using Global Payments API.
///
/// Business Model: Transaction-based fee (small percentage per transaction)
/// - No subscription required for users
/// - Real-time payment verification
/// - Transaction tracking and reporting
///
/// NOTE: This replaces the Basiq API integration which is temporarily disabled
/// pending CDR (Consumer Data Right) regulatory compliance.
class GlobalPaymentsService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'australia-southeast1',
  );

  /// Verify a payment transaction in real-time
  ///
  /// [transactionId] - The unique transaction identifier
  /// [amount] - Expected payment amount
  /// [merchantId] - Merchant identifier
  ///
  /// Returns a map containing:
  /// - success: bool
  /// - status: 'verified' | 'pending' | 'failed'
  /// - transactionFee: double (percentage charged)
  /// - timestamp: DateTime
  static Future<Map<String, dynamic>> verifyTransaction({
    required String transactionId,
    required double amount,
    required String merchantId,
  }) async {
    try {
      final callable = _functions.httpsCallable('verifyGlobalPayment');
      final result = await callable.call({
        'transactionId': transactionId,
        'amount': amount,
        'merchantId': merchantId,
      });

      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception('Failed to verify transaction: $e');
    }
  }

  /// Get transaction status
  ///
  /// [transactionId] - The unique transaction identifier
  ///
  /// Returns transaction details including current status
  static Future<Map<String, dynamic>> getTransactionStatus({
    required String transactionId,
  }) async {
    try {
      final callable = _functions.httpsCallable('getGlobalPaymentStatus');
      final result = await callable.call({
        'transactionId': transactionId,
      });

      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception('Failed to get transaction status: $e');
    }
  }

  /// Register merchant with Global Payments
  ///
  /// [merchantName] - Business/merchant name
  /// [payId] - PayID for receiving payments
  /// [abn] - Australian Business Number (optional)
  /// [email] - Contact email
  ///
  /// Returns merchant registration details including merchant ID
  static Future<Map<String, dynamic>> registerMerchant({
    required String merchantName,
    required String payId,
    String? abn,
    String? email,
  }) async {
    try {
      final callable = _functions.httpsCallable('registerGlobalPaymentsMerchant');
      final result = await callable.call({
        'merchantName': merchantName,
        'payId': payId,
        'abn': abn,
        'email': email,
      });

      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception('Failed to register merchant: $e');
    }
  }

  /// Get merchant transaction history
  ///
  /// [merchantId] - Merchant identifier
  /// [startDate] - Start date for transaction history (optional)
  /// [endDate] - End date for transaction history (optional)
  /// [limit] - Maximum number of transactions to return (default: 50)
  ///
  /// Returns list of transactions with fees and status
  static Future<Map<String, dynamic>> getMerchantTransactions({
    required String merchantId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    try {
      final callable = _functions.httpsCallable('getGlobalPaymentsMerchantTransactions');
      final result = await callable.call({
        'merchantId': merchantId,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'limit': limit,
      });

      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception('Failed to get merchant transactions: $e');
    }
  }

  /// Calculate transaction fee
  ///
  /// [amount] - Transaction amount
  ///
  /// Returns the fee amount and percentage
  static Map<String, dynamic> calculateTransactionFee(double amount) {
    // Example fee structure: 0.5% + $0.10 per transaction
    const feePercentage = 0.005; // 0.5%
    const fixedFee = 0.10;

    final percentageFee = amount * feePercentage;
    final totalFee = percentageFee + fixedFee;

    return {
      'amount': amount,
      'percentageFee': percentageFee,
      'fixedFee': fixedFee,
      'totalFee': totalFee,
      'merchantReceives': amount - totalFee,
      'feePercentage': feePercentage * 100, // Convert to percentage
    };
  }

  /// Webhook handler for real-time payment notifications
  ///
  /// This method should be called when receiving webhook notifications
  /// from Global Payments API about transaction status changes.
  ///
  /// [webhookData] - Data received from webhook
  ///
  /// Returns processed webhook data
  static Future<Map<String, dynamic>> handleWebhook({
    required Map<String, dynamic> webhookData,
  }) async {
    try {
      final callable = _functions.httpsCallable('handleGlobalPaymentsWebhook');
      final result = await callable.call(webhookData);

      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception('Failed to handle webhook: $e');
    }
  }

  /// Check Global Payments API health and connectivity
  ///
  /// Returns status of the Global Payments API connection
  static Future<Map<String, dynamic>> checkApiHealth() async {
    try {
      final callable = _functions.httpsCallable('checkGlobalPaymentsHealth');
      final result = await callable.call();

      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      return {
        'healthy': false,
        'error': e.toString(),
        'message': 'Failed to connect to Global Payments API',
      };
    }
  }
}
