import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:scan__pay/models/payment_intent.dart';
import 'package:scan__pay/services/payment_service.dart';
import 'package:scan__pay/theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<PaymentIntent> _allPayments = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadPayments();
  }
  
  void _loadPayments() {
    setState(() {
      _isLoading = true;
    });
    
    _allPayments = PaymentService.getPaymentHistory();
    
    setState(() {
      _isLoading = false;
    });
  }
  
  Color _getStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return LightModeColors.pendingAmber;
      case PaymentStatus.paid:
        return LightModeColors.successGreen;
      case PaymentStatus.failed:
      case PaymentStatus.expired:
        return LightModeColors.errorRed;
    }
  }
  
  IconData _getStatusIcon(PaymentStatus status) {
    switch (status) {
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightModeColors.lightSurface,
      appBar: AppBar(
        title: Text(
          'Payment History',
          style: TextStyle(color: LightModeColors.lightOnPrimaryContainer),
        ),
        backgroundColor: LightModeColors.lightAppBarBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: LightModeColors.lightOnPrimaryContainer,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allPayments.isEmpty
              ? _buildEmptyState()
              : _buildPaymentList(),
    );
  }
  
  Widget _buildPaymentList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _allPayments.length,
      itemBuilder: (context, index) {
        final payment = _allPayments[index];
        return _buildPaymentCard(payment);
      },
    );
  }
  
  Widget _buildPaymentCard(PaymentIntent payment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _getStatusColor(payment.status),
                shape: BoxShape.circle,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Payment details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        payment.formattedAmount,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: LightModeColors.lightOnSurface,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('MMM dd, HH:mm').format(payment.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: LightModeColors.lightOnSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 4),
                  
                  Text(
                    payment.reference,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: LightModeColors.lightOnSurface.withValues(alpha: 0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Icon(
                        _getStatusIcon(payment.status),
                        size: 16,
                        color: _getStatusColor(payment.status),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        payment.statusText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _getStatusColor(payment.status),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'ID: ${payment.id}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: LightModeColors.lightOnSurface.withValues(alpha: 0.5),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 64,
            color: LightModeColors.lightOnSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No payment history',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: LightModeColors.lightOnSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Payment history will appear here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: LightModeColors.lightOnSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}