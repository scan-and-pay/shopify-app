import 'dart:async';

/// Web-safe stub for kiosk utilities. All methods are no-ops because
/// kiosk/brightness/PIN flows are removed in the web build.
class KioskService {
  static Future<Map<String, dynamic>> getDeviceSettings() async {
    return {
      'deviceName': 'Scan & Pay',
      'brightness': 0.8,
      'sleepEnabled': false,
      'soundEnabled': true,
      'kioskModeEnabled': false,
    };
  }

  static Future<void> saveDeviceSettings({
    String? deviceName,
    double? brightness,
    bool? sleepEnabled,
    bool? soundEnabled,
  }) async {}

  static Future<void> setScreenBrightness(double brightness) async {}

  static Future<void> setSleepMode(bool sleepEnabled) async {}

  static Future<bool> isSoundEnabled() async => true;

  static Future<void> playSuccessSound() async {}

  static Future<void> playErrorSound() async {}

  static Future<void> playPaymentSound() async {}

  static Future<bool> verifyPin(String pin) async => false;

  static Future<bool> onWillPop() async => true;

  static Future<String> getAppVersion() async => '';

  static Future<Map<String, dynamic>> checkForUpdates() async => {
        'hasUpdate': false,
      };
}
