import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:scan__pay/theme.dart';
import 'package:scan__pay/screens/kiosk_home_screen.dart';
import 'package:scan__pay/screens/auth_screen.dart';
import 'package:scan__pay/screens/complete_profile_screen.dart';
import 'package:scan__pay/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';

// Use dart-define (or a generated .env) to supply your Recaptcha v3 site key.
const _webRecaptchaSiteKey = String.fromEnvironment(
  'RECAPTCHA_V3_SITE_KEY',
  defaultValue: 'recaptcha-v3-site-key',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseOptions = DefaultFirebaseOptions.currentPlatform;

  await Firebase.initializeApp(options: firebaseOptions);

  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode
        ? AndroidProvider.debug
        : AndroidProvider.playIntegrity,
    appleProvider: AppleProvider.appAttest,
    webProvider: ReCaptchaV3Provider(_webRecaptchaSiteKey),
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(const ScanPayApp());
}

class ScanPayApp extends StatelessWidget {
  const ScanPayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scan & Pay',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.light,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        debugPrint('[Auth] state: ');
        debugPrint('[Auth] hasData: ');
        debugPrint('[Auth] user: ');

        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint('[Auth] waiting for auth state...');
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          debugPrint('[Auth] user is signed in: ');
          return FutureBuilder<Map<String, String?>>(
            future: AuthService.getProfile(),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                debugPrint('[Auth] loading profile...');
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final profile = profileSnapshot.data;
              if (profile == null) {
                debugPrint('[Auth] failed to load profile data');
                return const CompleteProfileScreen();
              }

              debugPrint('[Auth] profile: C:\Users\kirme\OneDrive\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1');

              if (profile['name'] != null && profile['payId'] != null) {
                debugPrint('[Auth] profile complete, showing home');
                return const KioskHomeScreen();
              } else {
                debugPrint('[Auth] profile incomplete, showing complete profile screen');
                return const CompleteProfileScreen();
              }
            },
          );
        }

        debugPrint('[Auth] user not signed in, showing auth');
        return const AuthScreen();
      },
    );
  }
}
