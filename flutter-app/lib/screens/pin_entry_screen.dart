import 'package:flutter/material.dart';
import 'package:scan__pay/screens/kiosk_home_screen.dart';
import 'package:scan__pay/theme.dart';

class PinEntryScreen extends StatelessWidget {
  const PinEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_open,
                size: 64,
                color: LightModeColors.lightPrimary,
              ),
              const SizedBox(height: 16),
              Text(
                'PIN entry is disabled for the web version.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: LightModeColors.lightOnSurface,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const KioskHomeScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: LightModeColors.lightPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
