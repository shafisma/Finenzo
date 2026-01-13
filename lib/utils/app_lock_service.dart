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
          // If hardware not supported, assume true or fallback to PIN (not impl here)
          return true; 
      }

      return await auth.authenticate(
        localizedReason: 'Please authenticate to access Expense Tracker',
        options: const AuthenticationOptions(
          stickyAuth: true,
        ),
      );
    } on PlatformException catch (_) {
      return false;
    }
  }
}
