import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:scan__pay/services/payment_service.dart';
import 'package:scan__pay/models/payment_intent.dart';
import 'package:scan__pay/theme.dart';
import 'package:intl/intl.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  List<PaymentIntent> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await PaymentService.loadPaymentHistory();
      setState(() {
        _payments = PaymentService.getPaymentHistory();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading payments: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Map<String, double> _getMonthlyPayments() {
    final monthlyData = <String, double>{};
    final now = DateTime.now();

    // Initialize last 6 months
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = DateFormat('MMM').format(month);
      monthlyData[monthKey] = 0.0;
    }

    // Aggregate payments by month
    for (final payment in _payments) {
      if (payment.status == PaymentStatus.paid) {
        final monthKey = DateFormat('MMM').format(payment.createdAt);
        if (monthlyData.containsKey(monthKey)) {
          monthlyData[monthKey] = (monthlyData[monthKey] ?? 0.0) + payment.amount;
        }
      }
    }

    return monthlyData;
  }

  Map<PaymentStatus, int> _getPaymentStatusBreakdown() {
    final statusCounts = <PaymentStatus, int>{
      PaymentStatus.pending: 0,
      PaymentStatus.paid: 0,
      PaymentStatus.failed: 0,
    };

    for (final payment in _payments) {
      statusCounts[payment.status] = (statusCounts[payment.status] ?? 0) + 1;
    }

    return statusCounts;
  }

  double _getTotalRevenue() {
    return _payments
        .where((p) => p.status == PaymentStatus.paid)
        .fold(0.0, (sum, payment) => sum + payment.amount);
  }

  int _getSuccessfulPaymentsCount() {
    return _payments.where((p) => p.status == PaymentStatus.paid).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightModeColors.kioskBackground,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPayments,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Cards
                    _buildSummaryCards(),
                    const SizedBox(height: 24),

                    // Monthly Revenue Chart
                    _buildMonthlyRevenueChart(),
                    const SizedBox(height: 24),

                    // Payment Status Pie Chart
                    _buildPaymentStatusChart(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCards() {
    final totalRevenue = _getTotalRevenue();
    final successfulPayments = _getSuccessfulPaymentsCount();
    final totalPayments = _payments.length;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            title: 'Total Revenue',
            value: '\$${totalRevenue.toStringAsFixed(2)}',
            icon: Icons.attach_money,
            color: LightModeColors.successGreen,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            title: 'Successful',
            value: '$successfulPayments',
            subtitle: 'of $totalPayments',
            icon: Icons.check_circle,
            color: LightModeColors.lightPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: LightModeColors.lightOnSurface,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthlyRevenueChart() {
    final monthlyData = _getMonthlyPayments();
    final months = monthlyData.keys.toList();

    // Calculate maxY with a minimum value to prevent division by zero
    final maxValue = monthlyData.values.isEmpty
        ? 0.0
        : monthlyData.values.reduce((a, b) => a > b ? a : b);
    final maxY = maxValue > 0 ? maxValue * 1.2 : 100.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.trending_up,
                color: LightModeColors.lightPrimary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Monthly Revenue Overview',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: LightModeColors.lightOnSurface,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: maxValue == 0
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.show_chart,
                          size: 48,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No payment data available',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY > 0 ? maxY / 5 : 20.0,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey.shade200,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: 1,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              if (value.toInt() >= 0 &&
                                  value.toInt() < months.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    months[value.toInt()],
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: maxY > 0 ? maxY / 5 : 20.0,
                            reservedSize: 42,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              return Text(
                                '\$${value.toInt()}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 11,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade300),
                          left: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      minX: 0,
                      maxX: (months.length - 1).toDouble(),
                      minY: 0,
                      maxY: maxY,
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(
                            months.length,
                            (index) => FlSpot(
                              index.toDouble(),
                              monthlyData[months[index]] ?? 0.0,
                            ),
                          ),
                          isCurved: true,
                          gradient: LinearGradient(
                            colors: [
                              LightModeColors.lightPrimary,
                              LightModeColors.lightSecondary,
                            ],
                          ),
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: Colors.white,
                                strokeWidth: 2,
                                strokeColor: LightModeColors.lightPrimary,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                LightModeColors.lightPrimary.withValues(alpha: 0.2),
                                LightModeColors.lightPrimary.withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStatusChart() {
    final statusBreakdown = _getPaymentStatusBreakdown();
    final total = statusBreakdown.values.fold(0, (sum, count) => sum + count);

    if (total == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.pie_chart,
                  color: LightModeColors.lightPrimary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Payment Status Breakdown',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: LightModeColors.lightOnSurface,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'No payment data available',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pie_chart,
                color: LightModeColors.lightPrimary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Payment Status Breakdown',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: LightModeColors.lightOnSurface,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              // Pie Chart
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 50,
                      sections: [
                        PieChartSectionData(
                          color: LightModeColors.successGreen,
                          value: statusBreakdown[PaymentStatus.paid]!.toDouble(),
                          title: '${((statusBreakdown[PaymentStatus.paid]! / total) * 100).toStringAsFixed(0)}%',
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          color: LightModeColors.pendingAmber,
                          value: statusBreakdown[PaymentStatus.pending]!.toDouble(),
                          title: '${((statusBreakdown[PaymentStatus.pending]! / total) * 100).toStringAsFixed(0)}%',
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          color: LightModeColors.errorRed,
                          value: statusBreakdown[PaymentStatus.failed]!.toDouble(),
                          title: '${((statusBreakdown[PaymentStatus.failed]! / total) * 100).toStringAsFixed(0)}%',
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // Legend
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendItem(
                      'Paid',
                      statusBreakdown[PaymentStatus.paid]!,
                      LightModeColors.successGreen,
                    ),
                    const SizedBox(height: 12),
                    _buildLegendItem(
                      'Pending',
                      statusBreakdown[PaymentStatus.pending]!,
                      LightModeColors.pendingAmber,
                    ),
                    const SizedBox(height: 12),
                    _buildLegendItem(
                      'Failed',
                      statusBreakdown[PaymentStatus.failed]!,
                      LightModeColors.errorRed,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: LightModeColors.lightOnSurface,
                    ),
              ),
              Text(
                '$count payments',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
