import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Biometric authentication helper for Pocket.
class BiometricService {
  BiometricService._({LocalAuthentication? auth}) : _auth = auth ?? LocalAuthentication();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth;

  Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({String reason = 'Unlock Pocket to access your ledger'}) async {
    try {
      final available = await isAvailable();
      if (!available) {
        return true;
      }
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
