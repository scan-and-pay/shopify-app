import 'package:flutter/material.dart';
import 'dart:async';
import 'package:scan__pay/services/payment_service.dart';
import 'package:scan__pay/screens/history_screen.dart';
import 'package:scan__pay/screens/settings_screen.dart';
import 'package:scan__pay/screens/analytics_dashboard_screen.dart';
import 'package:scan__pay/theme.dart';
import 'package:package_info_plus/package_info_plus.dart';

class KioskHomeScreen extends StatefulWidget {
  const KioskHomeScreen({super.key});
  
  @override
  State<KioskHomeScreen> createState() => _KioskHomeScreenState();
}

class _KioskHomeScreenState extends State<KioskHomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  String _appVersion = '';
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadPaymentHistory();
    _loadAppVersion();
  }
  
  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = 'v${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }
  
  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }
  
  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _slideController.forward();
  }
  
  void _loadPaymentHistory() async {
    await PaymentService.loadPaymentHistory();
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
                      Icons.analytics,
                      size: 28,
                      color: LightModeColors.lightOnPrimary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Business Analytics',
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

        // Analytics Dashboard
        const Expanded(
          child: AnalyticsDashboardScreen(),
        ),
      ],
    );
  }
}
