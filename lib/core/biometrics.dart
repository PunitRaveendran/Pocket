import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Biometric authentication helper for Pocket using local_auth.
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();

  /// Checks if the device has biometric hardware or screen lock security configured.
  Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Prompts the user with biometric (fingerprint/face) or device credentials (PIN/pattern).
  Future<bool> authenticate({String reason = 'Unlock Pocket to access your ledger'}) async {
    try {
      final available = await isAvailable();
      if (!available) {
        // Allow pass-through if device has no hardware sensor or credentials setup
        return true;
      }
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }
}
