import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppLockService {
  final LocalAuthentication auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  static const String _isLockedKey = 'is_app_locked';

  Future<bool> isAppLockEnabled() async {
    String? value = await _storage.read(key: _isLockedKey);
    return value == 'true';
  }

  Future<void> setAppLock(bool enabled) async {
    await _storage.write(key: _isLockedKey, value: enabled.toString());
  }

  Future<bool> authenticate() async {
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) {
          // If hardware not supported, assume true. 
          // Ideally should offer passcode fallback if configured.
          return true; 
      }

      return await auth.authenticate(
        localizedReason: 'Please authenticate to access Expense Tracker',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN/Pattern if biometric fails
        ),
      );
    } on PlatformException catch (_) {
      // If error occurs (e.g., user canceled, not enrolled), treat as failed auth unless specific case
      return false;
    }
  }
}
