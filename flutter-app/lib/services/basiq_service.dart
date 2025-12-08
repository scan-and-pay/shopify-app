import 'package:cloud_functions/cloud_functions.dart';

class BasiqService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'australia-southeast1');
  
  /// Creates a Basiq Connect session and returns the connection URL
  /// This method calls the Cloud Function which handles all Basiq API interactions
  static Future<Map<String, dynamic>> createConnectSession({
    required String userId,
    required String name,
    required String payId,
    String? email,
    String? mobile,
  }) async {
    try {
      final callable = _functions.httpsCallable('createBasiqConnect');
      final result = await callable.call({
        'userId': userId,
        'name': name,
        'payId': payId,
        'email': email,
        'mobile': mobile,
      });
      
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception('Failed to create Basiq Connect session: $e');
    }
  }
  
  /// Gets the current Basiq connection status for the authenticated user
  static Future<Map<String, dynamic>> getConnectionStatus() async {
    try {
      final callable = _functions.httpsCallable('getBasiqStatus');
      final result = await callable.call();
      
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception('Failed to get Basiq status: $e');
    }
  }
  
  /// Register PayID seller - this is now handled through the connect flow
  /// and webhook updates from the Cloud Function
  static Future<Map<String, dynamic>> registerPayIDSeller({
    required String userId,
    required String payId,
    required String payIdName,
    required String legalName,
    String? businessNumber,
    String? businessAddress,
  }) async {
    // This is now handled automatically through the Basiq Connect flow
    // The Cloud Function will update the user's seller status via webhooks
    return {
      'success': true,
      'message': 'Seller registration will be completed through Basiq Connect flow'
    };
  }
  
  /// Legacy methods - these are now handled by Cloud Functions but kept for compatibility
  
  @Deprecated('Use createConnectSession instead')
  static Future<Map<String, dynamic>> createUser({
    required String email,
    required String mobile,
    String? firstName,
    String? lastName,
  }) async {
    throw UnsupportedError('Direct API calls are no longer supported. Use createConnectSession instead.');
  }
  
  @Deprecated('Use getConnectionStatus instead')
  static Future<Map<String, dynamic>> getUserById(String userId) async {
    throw UnsupportedError('Direct API calls are no longer supported. Use getConnectionStatus instead.');
  }
  
  @Deprecated('Handled automatically by Cloud Functions')
  static Future<Map<String, dynamic>> createConnection({
    required String userId,
    required String institutionId,
    Map<String, dynamic>? credentials,
  }) async {
    throw UnsupportedError('Connection creation is now handled automatically by Cloud Functions.');
  }
  
  @Deprecated('Use getConnectionStatus instead')
  static Future<Map<String, dynamic>> getAccounts(String userId) async {
    throw UnsupportedError('Direct API calls are no longer supported. Use Cloud Functions instead.');
  }
  
  @Deprecated('Handled automatically by Cloud Functions')
  static Future<Map<String, dynamic>> verifyPayID({
    required String payId,
    required String payIdName,
    String? accountId,
  }) async {
    throw UnsupportedError('PayID verification is now handled automatically by Cloud Functions.');
  }
  
  @Deprecated('Use Cloud Functions for payment operations')
  static Future<List<Map<String, dynamic>>> getInstitutions() async {
    throw UnsupportedError('Direct API calls are no longer supported. Use Cloud Functions instead.');
  }
  
  @Deprecated('Use Cloud Functions for payment operations')
  static Future<Map<String, dynamic>> initiatePayment({
    required String fromAccount,
    required String toPayId,
    required double amount,
    required String currency,
    String? description,
    String? reference,
  }) async {
    throw UnsupportedError('Payment initiation should be handled by dedicated Cloud Functions.');
  }
}