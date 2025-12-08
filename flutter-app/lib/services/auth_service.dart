import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:scan__pay/services/user_service.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AuthService {
  static const String _nameKey = 'user_name';
  static const String _payIdKey = 'user_payid';

  static DateTime? _lastEmailSent;
  static DateTime? _lastSmsSent;

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'australia-southeast1');
  
  // Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    final user = _auth.currentUser;
    return user != null;
  }
  
  // Send email OTP
  static Future<bool> sendEmailOTP(String email) async {
    if (kDebugMode) {
      print('📧 [sendEmailOTP] Starting for email: $email');
    }

    // Check rate limiting (60 seconds)
    if (_lastEmailSent != null) {
      final timeDiff = DateTime.now().difference(_lastEmailSent!);
      if (timeDiff.inSeconds < 60) {
        if (kDebugMode) {
          print('⏱️ [sendEmailOTP] Rate limit: wait ${60 - timeDiff.inSeconds}s');
        }
        throw Exception('Please wait ${60 - timeDiff.inSeconds} seconds before requesting another email');
      }
    }

    try {
      if (kDebugMode) {
        print('🔥 [sendEmailOTP] Calling Cloud Function: sendOtp');
        print('🔥 [sendEmailOTP] Region: australia-southeast1');
        print('🔥 [sendEmailOTP] Payload: {email: $email}');
      }

      // Call Firebase Function to send OTP
      final callable = _functions.httpsCallable('sendOtp');
      final result = await callable.call({'email': email});

      if (kDebugMode) {
        print('✅ [sendEmailOTP] Cloud Function response: ${result.data}');
      }

      _lastEmailSent = DateTime.now();

      // Store email for verification
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_email', email);

      if (kDebugMode) {
        print('✅ [sendEmailOTP] Success! Email stored.');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [sendEmailOTP] Error: $e');
        print('❌ [sendEmailOTP] Error type: ${e.runtimeType}');
        if (e is FirebaseFunctionsException) {
          print('❌ [sendEmailOTP] Code: ${e.code}');
          print('❌ [sendEmailOTP] Message: ${e.message}');
          print('❌ [sendEmailOTP] Details: ${e.details}');
        }
      }
      throw Exception('Failed to send email OTP: ${e.toString()}');
    }
  }
  
  // Verify email OTP code
  static Future<bool> verifyEmailCode(String code) async {
    if (kDebugMode) {
      print('🔐 [verifyEmailCode] Starting verification for code: $code');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('pending_email');

      if (kDebugMode) {
        print('🔐 [verifyEmailCode] Pending email: $email');
      }

      if (email == null) {
        if (kDebugMode) {
          print('❌ [verifyEmailCode] No pending email found');
        }
        throw Exception('No pending email found. Please request a new code.');
      }

      if (kDebugMode) {
        print('🔥 [verifyEmailCode] Calling Cloud Function: verifyOtp');
        print('🔥 [verifyEmailCode] Payload: {email: $email, otp: $code}');
      }

      // Call Firebase Function to verify OTP
      final callable = _functions.httpsCallable('verifyOtp');
      final result = await callable.call({'email': email, 'otp': code});

      if (kDebugMode) {
        print('✅ [verifyEmailCode] Cloud Function response: ${result.data}');
      }

      final data = result.data;
      if (data['success'] == true) {
        final customToken = data['customToken'];

        if (kDebugMode) {
          print('🔑 [verifyEmailCode] Got custom token, signing in...');
        }

        // Sign in with custom token
        final userCredential = await _auth.signInWithCustomToken(customToken);

        if (kDebugMode) {
          print('✅ [verifyEmailCode] Signed in as: ${userCredential.user?.uid}');
        }

        // Create/update user in Firestore
        if (userCredential.user != null) {
          await UserService.createOrUpdateUser(
            uid: userCredential.user!.uid,
            email: email,
            authMethod: 'email',
          );
          if (kDebugMode) {
            print('✅ [verifyEmailCode] User created/updated in Firestore');
          }
        }

        // Clear pending email
        await prefs.remove('pending_email');
        return true;
      } else {
        if (kDebugMode) {
          print('❌ [verifyEmailCode] Verification failed: ${data['error']}');
        }
        throw Exception(data['error'] ?? 'Invalid verification code');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [verifyEmailCode] Error: $e');
        print('❌ [verifyEmailCode] Error type: ${e.runtimeType}');
        if (e is FirebaseFunctionsException) {
          print('❌ [verifyEmailCode] Code: ${e.code}');
          print('❌ [verifyEmailCode] Message: ${e.message}');
          print('❌ [verifyEmailCode] Details: ${e.details}');
        }
      }
      throw Exception('Failed to verify code: ${e.toString()}');
    }
  }
  
  // Send SMS OTP
  static Future<bool> sendSmsOtp(String phoneNumber) async {
    // Check rate limiting (60 seconds)
    if (_lastSmsSent != null) {
      final timeDiff = DateTime.now().difference(_lastSmsSent!);
      if (timeDiff.inSeconds < 60) {
        throw Exception('Please wait ${60 - timeDiff.inSeconds} seconds before requesting another SMS');
      }
    }

    try {
      // Enable app verification for all platforms
      await _auth.setSettings(
        appVerificationDisabledForTesting: false,
      );

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification (Android only) - instant verification
          // This happens when SMS is auto-retrieved by Android
          await _auth.signInWithCredential(credential);

          // Create/update user in Firestore
          final user = _auth.currentUser;
          if (user != null) {
            await UserService.createOrUpdateUser(
              uid: user.uid,
              phoneNumber: phoneNumber,
              authMethod: 'phone',
            );
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (kDebugMode) {
            debugPrint('Phone verification failed: ${e.code} - ${e.message}');
          }
          throw Exception('SMS verification failed: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          // Store verification ID and resend token for later use
          _storeVerificationId(verificationId);
          if (resendToken != null) {
            _storeResendToken(resendToken);
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Called when auto-retrieval timeout expires
          _storeVerificationId(verificationId);
        },
        timeout: const Duration(seconds: 120),
      );

      _lastSmsSent = DateTime.now();

      // Store phone number for verification
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_phone', phoneNumber);

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to send SMS: ${e.toString()}');
      }
      throw Exception('Failed to send SMS: ${e.toString()}');
    }
  }
  
  static void _storeVerificationId(String verificationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('verification_id', verificationId);
  }

  static void _storeResendToken(int resendToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('resend_token', resendToken);
  }
  
  // Verify SMS OTP
  static Future<bool> verifySmsOtp(String otp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final verificationId = prefs.getString('verification_id');
      
      if (verificationId == null) {
        throw Exception('No verification ID found. Please request a new SMS.');
      }
      
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      
      final userCredential = await _auth.signInWithCredential(credential);
      
      // Create/update user in Firestore
      if (userCredential.user != null) {
        final prefs = await SharedPreferences.getInstance();
        final phoneNumber = prefs.getString('pending_phone');
        
        await UserService.createOrUpdateUser(
          uid: userCredential.user!.uid,
          phoneNumber: phoneNumber ?? userCredential.user!.phoneNumber,
          authMethod: 'phone',
        );
      }
      
      // Clear stored verification data
      await prefs.remove('verification_id');
      await prefs.remove('pending_phone');
      
      return userCredential.user != null;
    } catch (e) {
      throw Exception('Failed to verify SMS code: ${e.toString()}');
    }
  }
  
  // Save user profile
  static Future<void> saveProfile({
    required String name,
    required String payId,
    String? businessName,
    String? abn,
    String? address,
    String? sellerStatus,
    String? basiqUserId,
  }) async {
    // Save to SharedPreferences for backward compatibility
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name);
    await prefs.setString(_payIdKey, payId);

    if (businessName != null) {
      await prefs.setString('businessName', businessName);
    }
    if (abn != null) {
      await prefs.setString('abn', abn);
    }
    if (address != null) {
      await prefs.setString('address', address);
    }
    
    // Save to Firestore
    final user = _auth.currentUser;
    if (user != null) {
      // Update profile info (without PIN flag)
      await UserService.updateUserProfile(
        uid: user.uid,
        name: name,
        payId: payId,
        businessName: businessName,
        abn: abn,
        address: address,
        sellerStatus: sellerStatus,
        basiqUserId: basiqUserId,
      );
    }
  }
  
  // Get user profile
  static Future<Map<String, String?>> getProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {
        'name': null,
        'email': null,
        'phone': null,
        'payId': null,
        'businessName': null,
        'abn': null,
        'address': null,
      };
    }
    
    try {
      // Try to get from Firestore first
      final firestoreUser = await UserService.getUserByUid(user.uid);
      if (firestoreUser != null) {
        return {
          'name': firestoreUser.name,
          'email': firestoreUser.email,
          'phone': firestoreUser.phoneNumber,
          'payId': firestoreUser.payId,
          'businessName': firestoreUser.businessName,
          'abn': firestoreUser.abn,
          'address': firestoreUser.address,
        };
      }
    } catch (e) {
      // Fall back to SharedPreferences if Firestore fails
    }
    
    // Fallback to SharedPreferences and Firebase Auth
    final prefs = await SharedPreferences.getInstance();
    final profile = {
      'name': prefs.getString(_nameKey),
      'email': user.email,
      'phone': user.phoneNumber,
      'payId': prefs.getString(_payIdKey),
      
      'businessName': prefs.getString('businessName'),
      'abn': prefs.getString('abn'),
      'address': prefs.getString('address'),
    };
    return profile;
  }
  
  // Sign out
  static Future<void> signOut() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Delete account permanently via Cloud Function
  static Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      debugPrint('🗑️ Calling Cloud Function to delete account for user: ${user.uid}');

      // Call Cloud Function to delete user account and all data
      // This will:
      // 1. Delete user document from Firestore
      // 2. Delete all user's payment intents
      // 3. Delete user from Firebase Authentication
      final callable = _functions.httpsCallable('deleteUserAccount');
      final result = await callable.call();

      debugPrint('✅ Cloud Function response: ${result.data}');

      // Clear local data
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      debugPrint('✅ Account deleted successfully');
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ Cloud Function error: ${e.code} - ${e.message}');
      throw Exception('Failed to delete account: ${e.message}');
    } catch (e) {
      debugPrint('❌ Error deleting account: $e');
      throw Exception('Failed to delete account: ${e.toString()}');
    }
  }
  
  // Get current user
  static User? get currentUser => _auth.currentUser;
  
}
