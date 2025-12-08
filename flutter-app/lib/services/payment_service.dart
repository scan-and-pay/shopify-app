import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scan__pay/models/payment_intent.dart';
import 'package:scan__pay/services/payid_service.dart';

enum PaymentStatus { pending, paid, failed, expired }

class PaymentService {
  static List<PaymentIntent> _paymentHistory = [];
  static PaymentIntent? _currentPayment;
  
  // Generate QR code data for payment
  static Future<String> generatePaymentQR({
    required double amount,
    String? reference,
    String? payId,
    String? merchantName,
    bool useRealPayID = true,
  }) async {
    try {
      if (useRealPayID && payId != null) {
        // Use real PayID QR generation via Firebase function
        final result = await PayIDService.generatePayIDQR(
          amount: amount,
          payId: payId,
          reference: reference,
          merchantName: merchantName,
        );
        
        // Create PaymentIntent from Firebase result
        final paymentIntent = PaymentIntent(
          id: result['paymentId'],
          amount: amount,
          reference: result['reference'] ?? reference ?? 'Payment ${DateTime.now().millisecondsSinceEpoch}',
          status: PaymentStatus.pending,
          createdAt: DateTime.now(),
          expiresAt: DateTime.parse(result['expiresAt']),
        );
        
        _currentPayment = paymentIntent;
        _paymentHistory.insert(0, paymentIntent);
        
        return result['qrData'];
      } else {
        // Fallback to mock QR generation
        final paymentIntent = PaymentIntent(
          id: _generatePaymentId(),
          amount: amount,
          reference: reference ?? 'Payment ${DateTime.now().millisecondsSinceEpoch}',
          status: PaymentStatus.pending,
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        );
        
        _currentPayment = paymentIntent;
        _paymentHistory.insert(0, paymentIntent);
        
        // Generate mock QR data
        final qrData = jsonEncode({
          'paymentId': paymentIntent.id,
          'amount': amount,
          'reference': reference,
          'payIdUrl': 'https://payid.pay.to/${paymentIntent.id}',
          'expiresAt': paymentIntent.expiresAt.toIso8601String(),
        });
        
        return qrData;
      }
    } catch (e) {
      throw Exception('Failed to generate payment QR: $e');
    }
  }
  
  // Get current payment status
  static PaymentIntent? getCurrentPayment() {
    return _currentPayment;
  }
  
  // Check payment status (simulates webhook from Basiq API)
  static Future<PaymentStatus> checkPaymentStatus(String paymentId) async {
    try {
      // Simulate API call to check payment status
      await Future.delayed(const Duration(seconds: 1));
      
      final payment = _paymentHistory.firstWhere(
        (p) => p.id == paymentId,
        orElse: () => throw Exception('Payment not found'),
      );
      
      // Simulate random payment completion for demo
      if (payment.status == PaymentStatus.pending) {
        // Check if expired
        if (DateTime.now().isAfter(payment.expiresAt)) {
          payment.status = PaymentStatus.expired;
        } else {
          // Random simulation: 30% success, 10% fail, 60% still pending
          final random = Random();
          final outcome = random.nextInt(100);
          if (outcome < 30) {
            payment.status = PaymentStatus.paid;
            payment.paidAt = DateTime.now();
            payment.txId = _generateTransactionId();
          } else if (outcome < 40) {
            payment.status = PaymentStatus.failed;
          }
        }
      }
      
      return payment.status;
    } catch (e) {
      throw Exception('Failed to check payment status: $e');
    }
  }
  
  // Get payment history
  static List<PaymentIntent> getPaymentHistory() {
    return List.unmodifiable(_paymentHistory);
  }
  
  // Filter payment history
  static List<PaymentIntent> filterPaymentHistory({
    DateTime? fromDate,
    DateTime? toDate,
    PaymentStatus? status,
  }) {
    var filtered = _paymentHistory.where((payment) {
      bool matchesDate = true;
      bool matchesStatus = true;
      
      if (fromDate != null) {
        matchesDate = payment.createdAt.isAfter(fromDate) || 
                     payment.createdAt.isAtSameMomentAs(fromDate);
      }
      if (toDate != null && matchesDate) {
        matchesDate = payment.createdAt.isBefore(toDate.add(const Duration(days: 1)));
      }
      if (status != null) {
        matchesStatus = payment.status == status;
      }
      
      return matchesDate && matchesStatus;
    }).toList();
    
    return filtered;
  }
  
  // Clear current payment
  static void clearCurrentPayment() {
    _currentPayment = null;
  }
  
  // Simulate webhook handling (in real app, this would be triggered by Basiq API)
  static void simulateWebhookUpdate(String paymentId, PaymentStatus newStatus) {
    final paymentIndex = _paymentHistory.indexWhere((p) => p.id == paymentId);
    if (paymentIndex != -1) {
      _paymentHistory[paymentIndex].status = newStatus;
      if (newStatus == PaymentStatus.paid) {
        _paymentHistory[paymentIndex].paidAt = DateTime.now();
        _paymentHistory[paymentIndex].txId = _generateTransactionId();
      }
    }
  }
  
  // Generate payment ID
  static String _generatePaymentId() {
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
  }
  
  // Generate transaction ID
  static String _generateTransactionId() {
    final random = Random();
    const chars = '0123456789abcdef';
    return List.generate(16, (index) => chars[random.nextInt(chars.length)]).join();
  }
  
  // Get random demo QR data
  static String getDemoQRData() {
    return jsonEncode({
      'demo': true,
      'message': 'Scan & Pay with PayID',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  // Check network connection
  static Future<bool> checkNetworkConnection() async {
    try {
      final response = await http.get(
        Uri.parse('https://www.google.com'),
        headers: {'Connection': 'close'},
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  // Save payment data locally
  static Future<void> savePaymentHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = _paymentHistory.map((p) => p.toJson()).toList();
      await prefs.setString('payment_history', jsonEncode(historyJson));
    } catch (e) {
      debugPrint('Error saving payment history: $e');
    }
  }
  
  // Load payment data from local storage
  static Future<void> loadPaymentHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyString = prefs.getString('payment_history');
      if (historyString != null) {
        final historyJson = jsonDecode(historyString) as List;
        _paymentHistory = historyJson.map((json) => PaymentIntent.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error loading payment history: $e');
    }
  }
}