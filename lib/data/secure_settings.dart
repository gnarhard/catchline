import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kAnthropicApiKey = 'anthropic_api_key';
const _kJournalPinHash = 'journal_pin_hash_v1';

/// Minimal abstraction over a secure key/value store. Lets tests substitute
/// an in-memory implementation for [FlutterSecureStorage].
abstract class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class _FssStore implements SecureKeyValueStore {
  const _FssStore(this._fss);
  final FlutterSecureStorage _fss;

  @override
  Future<String?> read(String key) => _fss.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _fss.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _fss.delete(key: key);
}

/// Secure storage for sensitive settings (API keys, PINs, etc.). Backed by:
/// - iOS / macOS: Keychain
/// - Android: EncryptedSharedPreferences
/// - Windows: DPAPI
/// - Linux: libsecret
/// - Web: encrypted Web Crypto entry in localStorage
class SecureSettings {
  SecureSettings({SecureKeyValueStore? store})
    : _store = store ?? const _FssStore(FlutterSecureStorage());

  final SecureKeyValueStore _store;

  Future<String?> getAnthropicApiKey() async {
    final value = await _store.read(_kAnthropicApiKey);
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> setAnthropicApiKey(String? value) async {
    if (value == null || value.isEmpty) {
      await _store.delete(_kAnthropicApiKey);
    } else {
      await _store.write(_kAnthropicApiKey, value);
    }
  }

  /// Whether a journal PIN is currently configured.
  Future<bool> hasJournalPin() async {
    final stored = await _store.read(_kJournalPinHash);
    return stored != null && stored.isNotEmpty;
  }

  /// Stores [pin] as a sha256 hash. Passing `null` or an empty string clears
  /// any existing PIN. The plaintext is never persisted.
  Future<void> setJournalPin(String? pin) async {
    if (pin == null || pin.isEmpty) {
      await _store.delete(_kJournalPinHash);
      return;
    }
    await _store.write(_kJournalPinHash, hashJournalPin(pin));
  }

  /// Returns true iff the supplied [pin] hashes to the stored value.
  /// Returns false when no PIN has been set.
  Future<bool> verifyJournalPin(String pin) async {
    final stored = await _store.read(_kJournalPinHash);
    if (stored == null || stored.isEmpty) return false;
    return _constantTimeEquals(hashJournalPin(pin), stored);
  }
}

/// Hashes a journal PIN with a fixed app-scoped prefix. Exposed for tests.
String hashJournalPin(String pin) {
  final bytes = utf8.encode('catchline:journal-pin:v1:$pin');
  return sha256.convert(bytes).toString();
}

bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}

/// In-memory [SecureKeyValueStore] for tests.
class InMemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}
