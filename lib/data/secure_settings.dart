import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kAnthropicApiKey = 'anthropic_api_key';

/// Secure storage for sensitive settings (API keys, etc.). Backed by:
/// - iOS / macOS: Keychain
/// - Android: EncryptedSharedPreferences
/// - Windows: DPAPI
/// - Linux: libsecret
/// - Web: encrypted Web Crypto entry in localStorage
class SecureSettings {
  SecureSettings({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<String?> getAnthropicApiKey() async {
    final value = await _storage.read(key: _kAnthropicApiKey);
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> setAnthropicApiKey(String? value) async {
    if (value == null || value.isEmpty) {
      await _storage.delete(key: _kAnthropicApiKey);
    } else {
      await _storage.write(key: _kAnthropicApiKey, value: value);
    }
  }
}
