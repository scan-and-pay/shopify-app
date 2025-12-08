import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:scan__pay/services/auth_service.dart';
import 'package:scan__pay/screens/kiosk_home_screen.dart';
import 'package:scan__pay/screens/complete_profile_screen.dart';
import 'package:scan__pay/theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  final _emailFormKey = GlobalKey<FormState>();
  final _smsFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  late TabController _tabController;
  bool _isLoading = false;
  bool _codeSent = false;
  bool _isCodeValid = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        // Reset state when switching tabs
        _codeSent = false;
        _errorMessage = null;
        _successMessage = null;
        _codeController.clear();
        _isCodeValid = false;
      });
    });

    // Listen to code input changes to validate length
    _codeController.addListener(() {
      final isValid = _codeController.text.length == 6;
      if (_isCodeValid != isValid) {
        setState(() {
          _isCodeValid = isValid;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendEmailOTP() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await AuthService.sendEmailOTP(_emailController.text.trim());
      setState(() {
        _codeSent = true;
        _successMessage = 'OTP code sent! Please check your email.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _successMessage = null;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendSmsOtp() async {
    if (!_smsFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await AuthService.sendSmsOtp(_phoneController.text.trim());
      setState(() {
        _codeSent = true;
        _successMessage = 'SMS OTP sent! Please check your messages.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _successMessage = null;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the verification code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      bool isVerified = false;

      if (_tabController.index == 0) {
        // Email OTP verification
        isVerified =
            await AuthService.verifyEmailCode(_codeController.text.trim());
      } else {
        // SMS verification
        isVerified =
            await AuthService.verifySmsOtp(_codeController.text.trim());
      }

      if (isVerified) {
        // Check if profile is complete
        final profile = await AuthService.getProfile();

        if (profile['name'] != null && profile['payId'] != null) {
          // Profile complete, go to home screen
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const KioskHomeScreen()),
            );
          }
        } else {
          // Profile or PIN incomplete, go to complete profile screen
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                  builder: (context) => const CompleteProfileScreen()),
            );
          }
        }
      } else {
        // Clear the code input on error
        _codeController.clear();
        if (mounted) {
          setState(() {
            _isCodeValid = false;
            _errorMessage = 'Invalid verification code. Please try again.';
          });
        }
      }
    } catch (e) {
      // Clear the code input on error
      _codeController.clear();
      if (mounted) {
        setState(() {
          _isCodeValid = false;
          // Make error message user-friendly
          String errorMsg = e.toString().replaceAll('Exception: ', '');
          if (errorMsg.contains('Invalid OTP') || errorMsg.contains('Invalid verification')) {
            _errorMessage = 'Incorrect code. Please check your email and try again.';
          } else if (errorMsg.contains('expired')) {
            _errorMessage = 'Code expired. Please request a new code.';
          } else if (errorMsg.contains('not found')) {
            _errorMessage = 'Code not found. Please request a new code.';
          } else if (errorMsg.contains('already been used')) {
            _errorMessage = 'This code has already been used. Please request a new code.';
          } else {
            _errorMessage = 'Verification failed. Please try again or request a new code.';
          }
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

  Future<void> _checkAuthStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Force reload current user
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // User is authenticated, check profile completeness
        final profile = await AuthService.getProfile();

        if (profile['name'] != null && profile['payId'] != null) {
          // Profile complete, go to home screen
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const KioskHomeScreen()),
            );
          }
        } else {
          // Profile or PIN incomplete, go to complete profile screen
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                  builder: (context) => const CompleteProfileScreen()),
            );
          }
        }
      } else {
        // User is not authenticated yet
        if (mounted) {
          setState(() {
            _successMessage =
                'Not signed in yet. Please enter the verification code from your email.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error checking status: ${e.toString()}';
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // App Logo and Title
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      LightModeColors.lightPrimary,
                      LightModeColors.lightSecondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color:
                          LightModeColors.lightPrimary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  // THIS LINE FIXES THE ALIGNMENT:
                  crossAxisAlignment: CrossAxisAlignment.center,

                  children: [
                    // Logo with glow effect
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/log3.jpg',
                          width: 80,
                          height: 80,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'ScanPay',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 42,
                            letterSpacing: 1.2,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Secure Payment Solutions',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 3,
                      width: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              _buildAuthForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthForm() {
    return Column(
      children: [
        // Tab Bar
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: LightModeColors.lightPrimaryContainer,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: LightModeColors.lightPrimary.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                height: 56,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: LightModeColors.lightPrimary
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.email_outlined,
                          size: 20,
                          color: LightModeColors.lightPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Email',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Tab(
                height: 56,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: LightModeColors.lightPrimary
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.sms_outlined,
                          size: 20,
                          color: LightModeColors.lightPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'SMS',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            labelColor: LightModeColors.lightPrimary,
            unselectedLabelColor:
                LightModeColors.lightOnPrimaryContainer.withValues(alpha: 0.7),
            indicator: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  LightModeColors.lightPrimary.withValues(alpha: 0.1),
                  LightModeColors.lightSecondary.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: LightModeColors.lightPrimary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            indicatorPadding: const EdgeInsets.all(2),
            dividerColor: Colors.transparent,
          ),
        ),

        const SizedBox(height: 24),

        // Tab Content
        SizedBox(
          height: 400,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildEmailAuthTab(),
              _buildSmsAuthTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmailAuthTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 12),
      child: Form(
        key: _emailFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_codeSent) _buildEmailInput() else _buildCodeInput(),
            const SizedBox(height: 16),
            // Fixed height container for messages - prevents button jumping
            _buildMessageContainer(),
            const SizedBox(height: 16),
            _buildActionButton(),
            const SizedBox(height: 12),
            // Hint text below button
            _buildHintText(),
          ],
        ),
      ),
    );
  }

  Widget _buildSmsAuthTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 12),
      child: Form(
        key: _smsFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_codeSent) _buildPhoneInput() else _buildCodeInput(),
            const SizedBox(height: 16),
            // Fixed height container for messages - prevents button jumping
            _buildMessageContainer(),
            const SizedBox(height: 16),
            _buildActionButton(),
            const SizedBox(height: 12),
            // Hint text below button
            _buildHintText(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailInput() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: TextStyle(
        color: LightModeColors.lightOnSurface,
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        labelText: 'Email Address',
        hintText: 'Enter your email',
        labelStyle: TextStyle(
          color: LightModeColors.lightPrimary,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: TextStyle(
          color: LightModeColors.lightPrimary,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        hintStyle: TextStyle(
          color: LightModeColors.lightOnSurface.withValues(alpha: 0.6),
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
            Icons.email,
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
            color: LightModeColors.lightOnSurface.withValues(alpha: 0.3),
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
        fillColor: LightModeColors.lightPrimaryContainer.withValues(alpha: 0.1),
        contentPadding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your email address';
        }
        if (!value.contains('@') || !value.contains('.')) {
          return 'Please enter a valid email address';
        }
        return null;
      },
    );
  }

  Widget _buildPhoneInput() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      style: TextStyle(
        color: LightModeColors.lightOnSurface,
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        labelText: 'Phone Number',
        hintText: '+61 4XX XXX XXX',
        labelStyle: TextStyle(
          color: LightModeColors.lightPrimary,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: TextStyle(
          color: LightModeColors.lightPrimary,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        hintStyle: TextStyle(
          color: LightModeColors.lightOnSurface.withValues(alpha: 0.6),
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
            Icons.phone,
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
            color: LightModeColors.lightOnSurface.withValues(alpha: 0.3),
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
        fillColor: LightModeColors.lightPrimaryContainer.withValues(alpha: 0.1),
        contentPadding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your phone number';
        }
        if (value.length < 10) {
          return 'Please enter a valid phone number';
        }
        return null;
      },
    );
  }

  Widget _buildCodeInput() {
    return TextFormField(
      controller: _codeController,
      keyboardType: TextInputType.number,
      maxLength: 6,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      style: TextStyle(
        color: LightModeColors.lightOnSurface,
        fontWeight: FontWeight.w600,
        fontSize: 16,
        letterSpacing: 2,
      ),
      decoration: InputDecoration(
        labelText: 'Verification Code',
        hintText: '123456',
        labelStyle: TextStyle(
          color: LightModeColors.lightPrimary,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: LightModeColors.lightOnSurface.withValues(alpha: 0.6),
          letterSpacing: 2,
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
            Icons.security,
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
            color: LightModeColors.lightOnSurface.withValues(alpha: 0.3),
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
        fillColor: LightModeColors.lightPrimaryContainer.withValues(alpha: 0.1),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      ),
    );
  }

  Widget _buildActionButton() {
    // Check if button should be disabled
    final isButtonDisabled = _isLoading || (_codeSent && !_isCodeValid);

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: isButtonDisabled
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.grey.shade300,
                  Colors.grey.shade400,
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  LightModeColors.lightPrimary,
                  LightModeColors.lightSecondary,
                ],
              ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isButtonDisabled
            ? []
            : [
                BoxShadow(
                  color: LightModeColors.lightPrimary.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading
            ? null
            : (_codeSent && !_isCodeValid)
                ? null // Disable button when code is sent but not valid (not 6 digits)
                : () {
                    if (!_codeSent) {
                      if (_tabController.index == 0) {
                        _sendEmailOTP();
                      } else {
                        _sendSmsOtp();
                      }
                    } else {
                      _verifyCode();
                    }
                  },
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
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    !_codeSent
                        ? (_tabController.index == 0
                            ? Icons.email_outlined
                            : Icons.sms_outlined)
                        : Icons.verified_outlined,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    !_codeSent
                        ? (_tabController.index == 0
                            ? 'Send Email OTP'
                            : 'Send SMS OTP')
                        : 'Verify Code',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
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

  Widget _buildMessageContainer() {
    // Fixed height container to prevent button jumping
    return SizedBox(
      height: 70, // Fixed height for message area (fits 2 lines of text)
      child: (_errorMessage != null)
          ? _buildErrorMessage()
          : (_successMessage != null)
              ? _buildSuccessMessage()
              : const SizedBox.shrink(), // Empty when no message
    );
  }

  Widget _buildHintText() {
    // Fixed height container for hint text below button
    return SizedBox(
      height: 40, // Fixed height for hint area
      child: Center(
        child: Text(
          _codeSent
              ? 'Enter the 6-digit code sent to your ${_tabController.index == 0 ? 'email' : 'phone'}'
              : 'We\'ll send you a verification code',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: LightModeColors.lightOnSurface.withValues(alpha: 0.6),
                fontSize: 13,
              ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

}
