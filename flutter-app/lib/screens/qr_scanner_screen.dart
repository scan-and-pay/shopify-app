import 'package:flutter/material.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:scan__pay/services/payment_service.dart';
import 'package:scan__pay/models/payment_intent.dart';
import 'package:scan__pay/screens/payment_status_screen.dart';
import 'package:scan__pay/theme.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool isProcessing = false;
  String? errorMessage;
  bool flashOn = false;

  @override
  void reassemble() {
    super.reassemble();
    if (controller != null) {
      controller!.pauseCamera();
      controller!.resumeCamera();
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;

    controller.scannedDataStream.listen((scanData) {
      if (!isProcessing && scanData.code != null) {
        _handleScannedData(scanData.code!);
      }
    });
  }

  Future<void> _handleScannedData(String qrData) async {
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
      errorMessage = null;
    });

    // Pause scanning while processing
    await controller?.pauseCamera();

    try {
      debugPrint('📱 Scanned QR Code: $qrData');

      // Parse QR code data
      // Expected format: "payid://scan-and-pay?paymentId=xxx&amount=xxx&reference=xxx"
      final uri = Uri.parse(qrData);

      if (uri.scheme != 'payid' && !qrData.contains('paymentId=')) {
        throw Exception('Invalid payment QR code format');
      }

      // Extract payment details
      final paymentId = uri.queryParameters['paymentId'] ??
                       _extractParameter(qrData, 'paymentId');
      final amount = uri.queryParameters['amount'] ??
                    _extractParameter(qrData, 'amount');
      final reference = uri.queryParameters['reference'] ??
                       _extractParameter(qrData, 'reference');

      if (paymentId == null || paymentId.isEmpty) {
        throw Exception('Payment ID not found in QR code');
      }

      debugPrint('💰 Processing payment: $paymentId, amount: $amount, ref: $reference');

      // Show confirmation dialog
      final confirm = await _showPaymentConfirmation(
        amount: amount,
        reference: reference,
      );

      if (!confirm) {
        setState(() {
          isProcessing = false;
        });
        await controller?.resumeCamera();
        return;
      }

      // Process payment
      await _processPayment(paymentId, amount, reference);

    } catch (e) {
      debugPrint('❌ Error processing QR code: $e');
      setState(() {
        errorMessage = 'Failed to process payment: ${e.toString()}';
        isProcessing = false;
      });
      await controller?.resumeCamera();

      // Show error dialog
      if (mounted) {
        _showErrorDialog(errorMessage!);
      }
    }
  }

  String? _extractParameter(String data, String param) {
    final regex = RegExp('$param=([^&]+)');
    final match = regex.firstMatch(data);
    return match?.group(1);
  }

  Future<bool> _showPaymentConfirmation({
    String? amount,
    String? reference,
  }) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (amount != null) ...[
              const Text('Amount:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('\$${double.parse(amount).toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
            ],
            if (reference != null) ...[
              const Text('Reference:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(reference),
              const SizedBox(height: 16),
            ],
            const Text('Do you want to proceed with this payment?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: LightModeColors.successGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Pay Now'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _processPayment(
    String paymentId,
    String? amount,
    String? reference,
  ) async {
    try {
      // TODO: Implement actual payment processing with Global Payments
      // For now, we'll create a mock payment intent and navigate to status screen

      // Simulate API call delay
      await Future.delayed(const Duration(seconds: 1));

      final paymentIntent = PaymentIntent(
        id: paymentId,
        amount: amount != null ? double.parse(amount) : 0.0,
        reference: reference ?? 'Scanned Payment',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        status: PaymentStatus.pending,
      );

      if (mounted) {
        // Navigate to payment status screen
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PaymentStatusScreen(
              paymentIntent: paymentIntent,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error processing payment: $e');
      throw Exception('Payment processing failed: ${e.toString()}');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                errorMessage = null;
              });
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _toggleFlash() async {
    if (controller != null) {
      await controller!.toggleFlash();
      setState(() {
        flashOn = !flashOn;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // QR Scanner View
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: LightModeColors.lightPrimary,
              borderRadius: 16,
              borderLength: 40,
              borderWidth: 8,
              cutOutSize: MediaQuery.of(context).size.width * 0.75,
            ),
          ),

          // Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),

                  // Flash button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(
                        flashOn ? Icons.flash_on : Icons.flash_off,
                        color: flashOn ? Colors.amber : Colors.white,
                      ),
                      onPressed: _toggleFlash,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Instructions overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                    Colors.black,
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    const Text(
                      'Scan QR Code to Pay',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Instructions
                    const Text(
                      'Align the QR code within the frame to scan',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    // Processing indicator
                    if (isProcessing) ...[
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Processing payment...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],

                    // Error message
                    if (errorMessage != null && !isProcessing) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
