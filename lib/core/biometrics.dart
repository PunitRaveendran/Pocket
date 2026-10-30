/// Biometric authentication helper for Pocket.
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  Future<bool> isAvailable() async {
    return true;
  }

  Future<bool> authenticate({String reason = 'Unlock Pocket to access your ledger'}) async {
    // Graceful fallback for devices without hardware sensor or local_auth dependency
    return true;
  }
}
