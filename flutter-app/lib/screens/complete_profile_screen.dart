import 'package:flutter/material.dart';
import 'package:scan__pay/services/auth_service.dart';
import 'package:scan__pay/screens/kiosk_home_screen.dart';
import 'package:scan__pay/theme.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _payIdController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _payIdController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingProfile() async {
    try {
      final profile = await AuthService.getProfile();
      if (mounted) {
        setState(() {
          _nameController.text = profile['name'] ?? '';
          _payIdController.text = profile['payId'] ?? '';
          _successMessage = 'Please complete your profile information to continue.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load profile: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _completeProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_nameController.text.trim().isEmpty ||
        _payIdController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all required fields';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService.saveProfile(
        name: _nameController.text.trim(),
        payId: _payIdController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const KioskHomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () async {
              await AuthService.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushReplacementNamed('/auth');
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // Header
              Text(
                'Complete Your Profile',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: LightModeColors.lightOnSurface,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please fill in the required information to continue',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color:
                          LightModeColors.lightOnSurface.withValues(alpha: 0.7),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Success/Error Messages
              if (_successMessage != null) _buildSuccessMessage(),
              if (_errorMessage != null) _buildErrorMessage(),
              if (_successMessage != null || _errorMessage != null)
                const SizedBox(height: 16),

              // Name Field
              TextFormField(
                controller: _nameController,
                style: TextStyle(
                  color: LightModeColors.lightOnSurface,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  labelText: 'Legal Name',
                  hintText: 'Enter your full name',
                  labelStyle: TextStyle(
                    color: LightModeColors.lightPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  hintStyle: TextStyle(
                    color:
                        LightModeColors.lightOnSurface.withValues(alpha: 0.6),
                  ),
                  prefixIcon: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          LightModeColors.lightPrimary.withValues(alpha: 0.1),
                          LightModeColors.lightSecondary.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.person,
                      color: LightModeColors.lightPrimary,
                      size: 20,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color:
                          LightModeColors.lightOnSurface.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: LightModeColors.lightPrimary,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: LightModeColors.lightPrimaryContainer
                      .withValues(alpha: 0.1),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // PayID Field
              TextFormField(
                controller: _payIdController,
                style: TextStyle(
                  color: LightModeColors.lightOnSurface,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  labelText: 'PayID Alias',
                  hintText: 'email@example.com or +61XXXXXXXXX',
                  labelStyle: TextStyle(
                    color: LightModeColors.lightPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  hintStyle: TextStyle(
                    color:
                        LightModeColors.lightOnSurface.withValues(alpha: 0.6),
                  ),
                  prefixIcon: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          LightModeColors.lightPrimary.withValues(alpha: 0.1),
                          LightModeColors.lightSecondary.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet,
                      color: LightModeColors.lightPrimary,
                      size: 20,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color:
                          LightModeColors.lightOnSurface.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: LightModeColors.lightPrimary,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: LightModeColors.lightPrimaryContainer
                      .withValues(alpha: 0.1),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your PayID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              const SizedBox(height: 32),

              // Complete Button
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      LightModeColors.lightPrimary,
                      LightModeColors.lightSecondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color:
                          LightModeColors.lightPrimary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _completeProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Complete Setup',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
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

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LightModeColors.lightErrorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: LightModeColors.lightError,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: LightModeColors.lightOnErrorContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LightModeColors.lightPrimaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: LightModeColors.lightPrimary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _successMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: LightModeColors.lightOnPrimaryContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
