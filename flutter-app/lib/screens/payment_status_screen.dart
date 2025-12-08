import 'package:flutter/material.dart';
import 'dart:async';
import 'package:scan__pay/models/payment_intent.dart';
import 'package:scan__pay/services/payment_service.dart';
import 'package:scan__pay/theme.dart';

class PaymentStatusScreen extends StatefulWidget {
  final PaymentIntent paymentIntent;
  
  const PaymentStatusScreen({
    super.key,
    required this.paymentIntent,
  });
  
  @override
  State<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends State<PaymentStatusScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _checkController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _checkAnimation;
  
  Timer? _statusCheckTimer;
  Timer? _countdownTimer;
  PaymentStatus _currentStatus = PaymentStatus.pending;
  Duration _timeRemaining = Duration.zero;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startStatusMonitoring();
    _startCountdown();
    _currentStatus = widget.paymentIntent.status;
    _timeRemaining = widget.paymentIntent.timeRemaining;
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _checkController.dispose();
    _statusCheckTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }
  
  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _checkController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _checkAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    ));
    
    if (_currentStatus == PaymentStatus.pending) {
      _pulseController.repeat(reverse: true);
    }
  }
  
  void _startStatusMonitoring() {
    _statusCheckTimer = Timer.periodic(
      const Duration(seconds: 2),
      (timer) async {
        if (mounted) {
          try {
            final status = await PaymentService.checkPaymentStatus(
              widget.paymentIntent.id,
            );
            
            if (_currentStatus != status) {
              setState(() {
                _currentStatus = status;
              });
              
              if (status == PaymentStatus.paid) {
                _pulseController.stop();
                _checkController.forward();
                timer.cancel();
                
                // Auto-dismiss after 3 seconds for successful payment
                Timer(const Duration(seconds: 3), () {
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                });
              } else if (status == PaymentStatus.failed || status == PaymentStatus.expired) {
                _pulseController.stop();
                timer.cancel();
                
                // Auto-dismiss after 3 seconds for failed/expired payment
                Timer(const Duration(seconds: 3), () {
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                });
              }
            }
          } catch (e) {
            debugPrint('Error checking payment status: $e');
          }
        }
      },
    );
  }
  
  void _startCountdown() {
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (mounted) {
          final remaining = widget.paymentIntent.timeRemaining;
          
          setState(() {
            _timeRemaining = remaining;
          });
          
          if (remaining.inSeconds <= 0) {
            setState(() {
              _currentStatus = PaymentStatus.expired;
            });
            _pulseController.stop();
            timer.cancel();
            
            // Auto-dismiss after 3 seconds for expired payment
            Timer(const Duration(seconds: 3), () {
              if (mounted) {
                Navigator.of(context).pop();
              }
            });
          }
        }
      },
    );
  }
  
  Color _getStatusColor() {
    switch (_currentStatus) {
      case PaymentStatus.pending:
        return LightModeColors.pendingAmber;
      case PaymentStatus.paid:
        return LightModeColors.successGreen;
      case PaymentStatus.failed:
        return LightModeColors.errorRed;
      case PaymentStatus.expired:
        return LightModeColors.errorRed;
    }
  }
  
  String _getStatusText() {
    switch (_currentStatus) {
      case PaymentStatus.pending:
        return 'Awaiting Payment';
      case PaymentStatus.paid:
        return 'PAID';
      case PaymentStatus.failed:
        return 'FAILED';
      case PaymentStatus.expired:
        return 'EXPIRED';
    }
  }
  
  IconData _getStatusIcon() {
    switch (_currentStatus) {
      case PaymentStatus.pending:
        return Icons.pending;
      case PaymentStatus.paid:
        return Icons.check_circle;
      case PaymentStatus.failed:
        return Icons.error;
      case PaymentStatus.expired:
        return Icons.access_time;
    }
  }
  
  String _formatDuration(Duration duration) {
    if (duration.inSeconds <= 0) {
      return '00:00';
    }
    
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Only allow back if payment is complete or failed
        return _currentStatus != PaymentStatus.pending;
      },
      child: Scaffold(
        backgroundColor: _getStatusColor(),
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (_currentStatus != PaymentStatus.pending)
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 28,
                        ),
                      )
                    else
                      const SizedBox(width: 28),
                    
                    const Spacer(),
                    
                    Text(
                      'Payment Status',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    const Spacer(),
                    
                    const SizedBox(width: 28), // Balance the close button
                  ],
                ),
              ),
              
              // Main content
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Status Icon
                      AnimatedBuilder(
                        animation: _currentStatus == PaymentStatus.paid 
                            ? _checkAnimation 
                            : _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _currentStatus == PaymentStatus.paid
                                ? _checkAnimation.value
                                : (_currentStatus == PaymentStatus.pending 
                                    ? _pulseAnimation.value 
                                    : 1.0),
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getStatusIcon(),
                                size: 60,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Status Text
                      Text(
                        _getStatusText(),
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Amount
                      Text(
                        widget.paymentIntent.formattedAmount,
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Reference
                      Text(
                        widget.paymentIntent.reference,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Status-specific info
                      _buildStatusInfo(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatusInfo() {
    switch (_currentStatus) {
      case PaymentStatus.pending:
        return Column(
          children: [
            Text(
              'Time remaining:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatDuration(_timeRemaining),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Please scan the QR code to complete payment',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      case PaymentStatus.paid:
        return Text(
          'Payment completed successfully!',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        );
      case PaymentStatus.failed:
        return Column(
          children: [
            Text(
              'Payment could not be processed',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Please try again or use a different payment method',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      case PaymentStatus.expired:
        return Column(
          children: [
            Text(
              'Payment request has expired',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Please generate a new QR code to try again',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
    }
  }
}