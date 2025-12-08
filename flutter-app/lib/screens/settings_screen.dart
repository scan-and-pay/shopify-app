import 'package:flutter/material.dart';
import 'package:scan__pay/services/auth_service.dart';
import 'package:scan__pay/screens/auth_screen.dart';
import 'package:scan__pay/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  final _payIdController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _abnController = TextEditingController();
  final _addressController = TextEditingController();
  
  Map<String, String?> _userProfile = {};
  bool _isLoading = true;
  String? _nameError;
  String? _payIdError;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _payIdController.dispose();
    _businessNameController.dispose();
    _abnController.dispose();
    _addressController.dispose();
    super.dispose();
  }
  
  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final profile = await AuthService.getProfile();
      if (!mounted) return;
      setState(() {
        _userProfile = profile;
        _nameController.text = profile['name'] ?? '';
        _payIdController.text = profile['payId'] ?? '';
        _businessNameController.text = profile['businessName'] ?? '';
        _abnController.text = profile['abn'] ?? '';
        _addressController.text = profile['address'] ?? '';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading settings: '),
          backgroundColor: LightModeColors.errorRed,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final payId = _payIdController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name cannot be empty'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (payId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PayID cannot be empty'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!payId.contains('@') && !RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(payId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PayID must be a valid email address or phone number'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await AuthService.saveProfile(
        name: name,
        payId: payId,
        businessName: _businessNameController.text.trim(),
        abn: _abnController.text.trim(),
        address: _addressController.text.trim(),
      );
      if (!mounted) return;

      setState(() {
        _userProfile['name'] = name;
        _userProfile['payId'] = payId;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: '),
          backgroundColor: LightModeColors.errorRed,
        ),
      );
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Sign Out',
              style: TextStyle(color: LightModeColors.errorRed),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await AuthService.signOut();

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error signing out: '),
              backgroundColor: LightModeColors.errorRed,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_rounded,
              color: LightModeColors.errorRed,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text('Delete Account'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action cannot be undone. All your data will be permanently deleted:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text('• Profile information'),
            const Text('• Payment history'),
            const Text('• App settings'),
            const SizedBox(height: 12),
            Text(
              'Are you absolutely sure?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: LightModeColors.errorRed,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              backgroundColor: LightModeColors.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        await AuthService.deleteAccount();

        if (mounted) {
          Navigator.of(context).pop();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting account: '),
              backgroundColor: LightModeColors.errorRed,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileSection(),
                  const SizedBox(height: 24),
                  _buildSignOutSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
    IconData? icon,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    color: LightModeColors.lightPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: LightModeColors.lightOnSurface,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return _buildSectionCard(
      title: 'Profile',
      icon: Icons.person,
      children: [
        TextFormField(
          controller: _nameController,
          onChanged: (value) {
            setState(() {
              _nameError = value.trim().isEmpty ? 'Name cannot be empty' : null;
            });
          },
          decoration: InputDecoration(
            labelText: 'Name',
            hintText: 'Enter your name',
            errorText: _nameError,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: Icon(
              Icons.person_outline,
              color: LightModeColors.lightPrimary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoRow('Email', _userProfile['email'] ?? 'Not set'),
        const SizedBox(height: 12),
        _buildInfoRow('Phone', _userProfile['phone'] ?? 'Not set'),
        const SizedBox(height: 16),
        TextFormField(
          controller: _payIdController,
          onChanged: (value) {
            setState(() {
              if (value.trim().isEmpty) {
                _payIdError = 'PayID cannot be empty';
              } else if (!value.contains('@') && !RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(value)) {
                _payIdError = 'PayID must be a valid email or phone number';
              } else {
                _payIdError = null;
              }
            });
          },
          decoration: InputDecoration(
            labelText: 'PayID',
            hintText: 'Enter your PayID (email or phone)',
            errorText: _payIdError,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: Icon(
              Icons.payment,
              color: LightModeColors.lightPrimary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Business Information',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: LightModeColors.lightOnSurface,
              ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _businessNameController,
          decoration: InputDecoration(
            labelText: 'Business Name',
            hintText: 'Enter your business name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: Icon(
              Icons.business,
              color: LightModeColors.lightPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _abnController,
          decoration: InputDecoration(
            labelText: 'ABN',
            hintText: 'Enter your ABN',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: Icon(
              Icons.numbers,
              color: LightModeColors.lightPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _addressController,
          decoration: InputDecoration(
            labelText: 'Business Address',
            hintText: 'Enter your business address',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: Icon(
              Icons.location_on,
              color: LightModeColors.lightPrimary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.blue.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Using Global Payments for transaction verification. Real-time payment tracking enabled.',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _saveProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: LightModeColors.lightPrimary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            minimumSize: const Size(double.infinity, 48),
          ),
          child: const Text('Save Profile'),
        ),
      ],
    );
  }
  
  Widget _buildSignOutSection() {
    return _buildSectionCard(
      title: 'Account',
      icon: Icons.exit_to_app,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: LightModeColors.lightSecondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Save Changes'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _signOut,
                style: ElevatedButton.styleFrom(
                  backgroundColor: LightModeColors.errorRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Sign Out'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),
        Text(
          'Danger Zone',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: LightModeColors.errorRed,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _deleteAccount,
                style: OutlinedButton.styleFrom(
                  foregroundColor: LightModeColors.errorRed,
                  side: BorderSide(color: LightModeColors.errorRed),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.delete_forever),
                label: const Text('Delete Account Forever'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'This will permanently delete your account and all associated data.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: LightModeColors.lightOnSurface.withValues(alpha: 0.6),
                fontSize: 12,
              ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
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
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }
}
