import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:scan__pay/models/payment_intent.dart';
import 'package:scan__pay/services/payment_service.dart';
import 'package:scan__pay/theme.dart';

class PaymentDetailDialog extends StatelessWidget {
  final PaymentIntent payment;
  
  const PaymentDetailDialog({
    super.key,
    required this.payment,
  });
  
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
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _getStatusColor(payment.status),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _getStatusIcon(payment.status),
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Text(
                  payment.statusText,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  payment.formattedAmount,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Payment ID', payment.id, isMonospace: true),
                const SizedBox(height: 12),
                
                _buildDetailRow('Reference', payment.reference),
                const SizedBox(height: 12),
                
                _buildDetailRow(
                  'Created At',
                  DateFormat('MMM dd, yyyy HH:mm:ss').format(payment.createdAt),
                ),
                const SizedBox(height: 12),
                
                if (payment.paidAt != null) ...[
                  _buildDetailRow(
                    'Paid At',
                    DateFormat('MMM dd, yyyy HH:mm:ss').format(payment.paidAt!),
                  ),
                  const SizedBox(height: 12),
                ],
                
                if (payment.txId != null) ...[
                  _buildDetailRow('Transaction ID', payment.txId!, isMonospace: true),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          
          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: BorderSide(
                        color: LightModeColors.lightOnSurface.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: TextStyle(
                        color: LightModeColors.lightOnSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value, {bool isMonospace = false}) {
    return Builder(
      builder: (context) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: LightModeColors.lightOnSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: LightModeColors.lightOnSurface,
                  fontFamily: isMonospace ? 'monospace' : null,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}