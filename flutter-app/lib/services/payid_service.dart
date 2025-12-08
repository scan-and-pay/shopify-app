import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PayIDService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'australia-southeast1');
  
  /// Generate real PayID QR code using Firebase function
  static Future<Map<String, dynamic>> generatePayIDQR({
    required double amount,
    required String payId,
    String? reference,
    String? merchantName,
  }) async {
    try {
      // Ensure user is authenticated
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to generate PayID QR');
      }

      final callable = _functions.httpsCallable('generatePayIDQR');
      
      final result = await callable.call({
        'amount': amount,
        'reference': reference,
        'payId': payId,
        'merchantName': merchantName,
      });

      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw Exception('PayID QR generation failed: ${e.message}');
    } catch (e) {
      throw Exception('PayID QR generation failed: $e');
    }
  }

  /// Check payment status using Firebase function
  static Future<Map<String, dynamic>> checkPaymentStatus(String paymentId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to check payment status');
      }

      final callable = _functions.httpsCallable('checkPayIDStatus');
      
      final result = await callable.call({
        'paymentId': paymentId,
      });

      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Payment status check failed: ${e.message}');
    } catch (e) {
      throw Exception('Payment status check failed: $e');
    }
  }
  
  /// Validate PayID format
  static bool isValidPayID(String payId) {
    // Email format
    if (payId.contains('@')) {
      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
      return emailRegex.hasMatch(payId);
    }
    
    // Australian mobile number format
    final mobileRegex = RegExp(r'^(\+61|04)[0-9]{8,9}$');
    return mobileRegex.hasMatch(payId);
  }
  
  /// Format amount for display
  static String formatAmount(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }
}