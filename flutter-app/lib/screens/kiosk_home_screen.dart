import 'package:flutter/material.dart';
import 'dart:async';
import 'package:scan__pay/services/payment_service.dart';
import 'package:scan__pay/services/user_service.dart';
import 'package:scan__pay/models/payment_intent.dart';
import 'package:scan__pay/screens/history_screen.dart';
import 'package:scan__pay/screens/settings_screen.dart';
import 'package:scan__pay/screens/qr_scanner_screen.dart';
import 'package:scan__pay/theme.dart';
import 'package:scan__pay/widgets/animated_qr_code.dart';
import 'package:scan__pay/services/second_screen_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class KioskHomeScreen extends StatefulWidget {
  const KioskHomeScreen({super.key});
  
  @override
  State<KioskHomeScreen> createState() => _KioskHomeScreenState();
}

class _KioskHomeScreenState extends State<KioskHomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  
  String _qrData = '';
  Timer? _qrUpdateTimer;
  Timer? _paymentCheckTimer;
  Timer? _qrExpiryTimer;
  PaymentIntent? _currentPayment;
  bool _isGeneratingPayment = false;
  String _appVersion = '';
  int _remainingSeconds = 0;
  
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();
  final FocusNode _referenceFocusNode = FocusNode();
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startDemoQRCode();
    _loadPaymentHistory();
    _loadAppVersion();
    SecondScreenService.initialize();
  }
  
  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = 'v${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _qrUpdateTimer?.cancel();
    _paymentCheckTimer?.cancel();
    _qrExpiryTimer?.cancel();
    _amountController.dispose();
    _referenceController.dispose();
    _amountFocusNode.dispose();
    _referenceFocusNode.dispose();
    SecondScreenService.clear();
    super.dispose();
  }
  
  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _pulseController.repeat(reverse: true);
    _slideController.forward();
  }
  
  void _startDemoQRCode() {
    // Set initial empty QR data - will be generated when user clicks button
    _qrData = '';
    
    // Comment out auto-regenerating logic - QR will only generate on button click
    // _qrUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
    //   if (_currentPayment == null && mounted) {
    //     setState(() {
    //       _qrData = PaymentService.getDemoQRData();
    //     });
    //   }
    // });
  }
  
  void _loadPaymentHistory() async {
    await PaymentService.loadPaymentHistory();
  }
  
  void _startQRExpiryTimer() {
    _qrExpiryTimer?.cancel();
    
    if (_currentPayment == null) return;
    
    // Calculate time until expiry (max 20 seconds)
    final now = DateTime.now();
    final expiryTime = _currentPayment!.expiresAt;
    final totalDuration = expiryTime.difference(now);
    
    // Use min of payment expiry and 20 seconds
    final maxDuration = const Duration(seconds: 20);
    final actualDuration = totalDuration > maxDuration ? maxDuration : totalDuration;
    
    if (actualDuration.inSeconds <= 0) {
      // Already expired, reset immediately
      _expireQR();
      return;
    }
    
    // Set initial remaining seconds
    _remainingSeconds = actualDuration.inSeconds;
    
    // Update countdown every second
    _qrExpiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _remainingSeconds--;
      });
      
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _expireQR();
      }
    });
  }
  
  void _expireQR() {
    if (mounted) {
      setState(() {
        _currentPayment = null;
        _qrData = '';
        _remainingSeconds = 0;
      });
    }

    // Clear second screen
    SecondScreenService.clear();

    // Clear form fields
    _amountController.clear();
    _referenceController.clear();

    PaymentService.clearCurrentPayment();
    _qrExpiryTimer?.cancel();
    
    // Show expiry message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR code has expired. Please generate a new one.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
  
  Future<void> _generatePaymentQR() async {
    // Validate input
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an amount'),
          backgroundColor: Colors.orange,
        ),
      );
      _amountFocusNode.requestFocus();
      return;
    }
    
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.orange,
        ),
      );
      _amountFocusNode.requestFocus();
      return;
    }
    
    if (mounted) {
      setState(() {
        _isGeneratingPayment = true;
      });
    }
    
    try {
      final reference = _referenceController.text.trim().isNotEmpty 
          ? _referenceController.text.trim()
          : 'Kiosk Sale ${DateTime.now().millisecondsSinceEpoch}';
      
      // Get PayID and merchant info from current user
      final user = await UserService.getCurrentUser();
      String payId;
      String merchantName;
      
      if (user != null && user.payId != null && user.payId!.isNotEmpty) {
        payId = user.payId!;
      } else if (user != null && user.email != null && user.email!.isNotEmpty) {
        payId = user.email!; // Fallback to email as PayID
      } else if (user != null && user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        payId = user.phoneNumber!; // Fallback to phone as PayID
      } else {
        payId = 'merchant@scanandpay.com.au'; // Default fallback
      }
      
      merchantName = user?.name ?? 'ScanPay Merchant';
      
      final qrData = await PaymentService.generatePaymentQR(
        amount: amount,
        reference: reference,
        payId: payId,
        merchantName: merchantName,
        useRealPayID: true, // Set to false for testing with mock data
      );
      
      final payment = PaymentService.getCurrentPayment();
      
      if (mounted) {
        setState(() {
          _qrData = qrData;
          _currentPayment = payment;
          _isGeneratingPayment = false;
        });
      }

      // Show QR on second screen (T6 customer display)
      if (payment != null) {
        SecondScreenService.showQR(
          qrData: qrData,
          title: 'Scan & PayID',
          amount: '\$${payment.amount.toStringAsFixed(2)}',
        );
      }

      debugPrint('Generated payment: ${payment?.id}, amount: ${payment?.formattedAmount}, reference: ${payment?.reference}');
      
      // Start QR expiry timer
      _startQRExpiryTimer();
      
      // Comment out navigation to payment status screen for now - just show QR
      // _startPaymentMonitoring();
      // 
      // if (mounted && payment != null) {
      //   Navigator.of(context).push(
      //     MaterialPageRoute(
      //       builder: (context) => PaymentStatusScreen(paymentIntent: payment),
      //     ),
      //   ).then((_) {
      //     _resetToDemo();
      //   });
      // }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating payment: $e'),
          backgroundColor: LightModeColors.errorRed,
        ),
      );

      setState(() {
        _isGeneratingPayment = false;
      });
    }
  }

  void _startPaymentMonitoring() {
    _paymentCheckTimer?.cancel();

    _paymentCheckTimer = Timer.periodic(
      const Duration(seconds: 2),
      (timer) async {
        if (_currentPayment == null) {
          timer.cancel();
          return;
        }

        try {
          final status = await PaymentService.checkPaymentStatus(_currentPayment!.id);

          if (status != PaymentStatus.pending) {
            timer.cancel();

            // Save payment history
            await PaymentService.savePaymentHistory();
          }
        } catch (e) {
          debugPrint('Error checking payment status: $e');
        }
      },
    );
  }

  void _resetToDemo() {
    if (mounted) {
      setState(() {
        _currentPayment = null;
        _qrData = ''; // Reset to empty QR
      });
    }

    // Clear second screen
    SecondScreenService.clear();

    // Clear form fields
    _amountController.clear();
    _referenceController.clear();

    PaymentService.clearCurrentPayment();
    _paymentCheckTimer?.cancel();
  }

  void _navigateToHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const HistoryScreen(),
      ),
    );
  }
  
  void _navigateToSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  void _navigateToScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const QRScannerScreen(),
      ),
    );
  }

  void _showMenuBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Version info
              if (_appVersion.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16, top: 8),
                  child: Text(
                    'ScanPay $_appVersion',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ),
              // Menu items
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: LightModeColors.lightPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.qr_code_scanner,
                    color: LightModeColors.lightPrimary,
                    size: 24,
                  ),
                ),
                title: const Text(
                  'Scan QR Code',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Scan a payment QR code'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToScanner();
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: LightModeColors.lightSecondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.history,
                    color: LightModeColors.lightSecondary,
                    size: 24,
                  ),
                ),
                title: const Text(
                  'Payment History',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('View past transactions'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToHistory();
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.settings,
                    color: Colors.grey,
                    size: 24,
                  ),
                ),
                title: const Text(
                  'Settings',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('App preferences and profile'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToSettings();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightModeColors.kioskBackground,
      body: SlideTransition(
        position: _slideAnimation,
        child: _buildMainContent(),
      ),
    );
  }
  
  Widget _buildMainContent() {
    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                LightModeColors.lightPrimary,
                LightModeColors.lightPrimary.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.qr_code_scanner,
                      size: 28,
                      color: LightModeColors.lightOnPrimary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Scan & Pay',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: LightModeColors.lightOnPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    // Settings button - opens bottom sheet
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: IconButton(
                        onPressed: _showMenuBottomSheet,
                        icon: const Icon(
                          Icons.menu,
                          size: 20,
                        ),
                        color: LightModeColors.lightOnPrimary,
                        iconSize: 20,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        tooltip: 'Menu',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        // Main QR Section
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // QR Code
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: _qrData.isNotEmpty ? AnimatedQRCode(
                            data: _qrData,
                            size: 180,
                            isDemo: _currentPayment == null,
                          ) : Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.3),
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.qr_code,
                                  size: 64,
                                  color: Colors.grey.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'QR Code will appear here',
                                  style: TextStyle(
                                    color: Colors.grey.withValues(alpha: 0.7),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 20),

                  // Instructions
                  if (_currentPayment == null)
                    _buildDemoInstructions()
                  else
                    _buildPaymentInstructions(),

                  const SizedBox(height: 24),
                  
                  // Payment Form
                  if (_currentPayment == null)
                    _buildPaymentForm(),


                  const SizedBox(height: 16),

                  // Generate Payment Button or Reset Button
                  if (_currentPayment == null)
                    _buildGeneratePaymentButton()
                  else
                    _buildResetButton(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildDemoInstructions() {
    return Column(
      children: [
        Icon(
          Icons.payment,
          size: 36,
          color: LightModeColors.lightPrimary,
        ),
        const SizedBox(height: 12),

        Text(
          'Pay with PayID',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: LightModeColors.lightOnSurface,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 6),

        Text(
          'Enter amount and reference to create a payment QR code',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: LightModeColors.lightOnSurface.withValues(alpha: 0.7),
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 12),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFeatureChip('🔒 Secure', LightModeColors.successGreen),
            const SizedBox(width: 8),
            _buildFeatureChip('⚡ Instant', LightModeColors.lightSecondary),
            const SizedBox(width: 8),
            _buildFeatureChip('📱 Easy', LightModeColors.pendingAmber),
          ],
        ),
      ],
    );
  }
  
  Widget _buildPaymentInstructions() {
    return Column(
      children: [
        Text(
          _currentPayment!.formattedAmount,
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            color: LightModeColors.lightPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        
        Text(
          _currentPayment!.reference,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: LightModeColors.lightOnSurface.withValues(alpha: 0.7),
          ),
        ),
        
        const SizedBox(height: 16),
        
        Text(
          'Scan QR code to pay with PayID',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: LightModeColors.lightOnSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        
        if (_remainingSeconds > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _remainingSeconds <= 5 
                  ? Colors.red.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _remainingSeconds <= 5 
                    ? Colors.red.withValues(alpha: 0.3)
                    : Colors.orange.withValues(alpha: 0.3)
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer,
                  size: 16,
                  color: _remainingSeconds <= 5 ? Colors.red : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  'Expires in ${_remainingSeconds}s',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _remainingSeconds <= 5 ? Colors.red : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildFeatureChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
  
  Widget _buildPaymentForm() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Amount field
          TextField(
            controller: _amountController,
            focusNode: _amountFocusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              labelText: 'Amount (\$)',
              hintText: '0.00',
              prefixText: '\$ ',
              prefixStyle: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: LightModeColors.lightPrimary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: LightModeColors.lightPrimary.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: LightModeColors.lightPrimary,
                  width: 2,
                ),
              ),
              fillColor: Colors.white,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            ),
          ),

          const SizedBox(height: 12),

          // Reference field
          TextField(
            controller: _referenceController,
            focusNode: _referenceFocusNode,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Reference (optional)',
              hintText: 'Payment description',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: LightModeColors.lightPrimary.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: LightModeColors.lightPrimary,
                  width: 2,
                ),
              ),
              fillColor: Colors.white,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratePaymentButton() {
    return ElevatedButton(
      onPressed: _isGeneratingPayment ? null : _generatePaymentQR,
      style: ElevatedButton.styleFrom(
        backgroundColor: LightModeColors.lightPrimary,
        foregroundColor: LightModeColors.lightOnPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
        shadowColor: LightModeColors.lightPrimary.withValues(alpha: 0.4),
        minimumSize: const Size(220, 52),
      ),
      child: _isGeneratingPayment
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.qr_code,
                  size: 20,
                  color: LightModeColors.lightOnPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Generate QR Code',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: LightModeColors.lightOnPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildResetButton() {
    return ElevatedButton(
      onPressed: () {
        if (mounted) {
          setState(() {
            _currentPayment = null;
            _qrData = '';
          });
        }

        // Clear second screen
        SecondScreenService.clear();

        // Clear form fields
        _amountController.clear();
        _referenceController.clear();

        PaymentService.clearCurrentPayment();
        _paymentCheckTimer?.cancel();
        _qrExpiryTimer?.cancel();
        _remainingSeconds = 0;
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey.shade600,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.refresh,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Text(
            'Generate New QR',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
