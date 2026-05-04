import 'package:catchline/data/secure_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemorySecureStore store;
  late SecureSettings settings;

  setUp(() {
    store = InMemorySecureStore();
    settings = SecureSettings(store: store);
  });

  group('Anthropic API key', () {
    test('returns null when nothing is stored', () async {
      expect(await settings.getAnthropicApiKey(), isNull);
    });

    test('round-trips a non-empty value', () async {
      await settings.setAnthropicApiKey('sk-ant-abc');
      expect(await settings.getAnthropicApiKey(), 'sk-ant-abc');
    });

    test('clearing with null deletes the entry', () async {
      await settings.setAnthropicApiKey('sk-ant-abc');
      await settings.setAnthropicApiKey(null);
      expect(await settings.getAnthropicApiKey(), isNull);
    });

    test('clearing with empty string deletes the entry', () async {
      await settings.setAnthropicApiKey('sk-ant-abc');
      await settings.setAnthropicApiKey('');
      expect(await settings.getAnthropicApiKey(), isNull);
    });
  });

  group('journal PIN', () {
    test('hasJournalPin is false initially', () async {
      expect(await settings.hasJournalPin(), isFalse);
    });

    test('verifyJournalPin returns false when no PIN is set', () async {
      expect(await settings.verifyJournalPin('1234'), isFalse);
    });

    test('setJournalPin stores a hashed value, not the plaintext', () async {
      await settings.setJournalPin('1234');
      // The store should contain *something*, but never the plaintext.
      final raw = await store.read('journal_pin_hash_v1');
      expect(raw, isNotNull);
      expect(raw, isNot(contains('1234')));
      expect(raw, hasLength(64)); // sha256 hex digest length
    });

    test('verifyJournalPin returns true for the correct PIN', () async {
      await settings.setJournalPin('1234');
      expect(await settings.verifyJournalPin('1234'), isTrue);
    });

    test('verifyJournalPin returns false for an incorrect PIN', () async {
      await settings.setJournalPin('1234');
      expect(await settings.verifyJournalPin('4321'), isFalse);
      expect(await settings.verifyJournalPin('12345'), isFalse);
      expect(await settings.verifyJournalPin(''), isFalse);
    });

    test('setJournalPin(null) clears the stored PIN', () async {
      await settings.setJournalPin('1234');
      await settings.setJournalPin(null);
      expect(await settings.hasJournalPin(), isFalse);
      expect(await settings.verifyJournalPin('1234'), isFalse);
    });

    test('setJournalPin("") clears the stored PIN', () async {
      await settings.setJournalPin('1234');
      await settings.setJournalPin('');
      expect(await settings.hasJournalPin(), isFalse);
    });

    test('changing the PIN replaces the previous value', () async {
      await settings.setJournalPin('1234');
      await settings.setJournalPin('9876');
      expect(await settings.verifyJournalPin('1234'), isFalse);
      expect(await settings.verifyJournalPin('9876'), isTrue);
    });
  });

  group('hashJournalPin', () {
    test('is deterministic for the same input', () {
      expect(hashJournalPin('1234'), hashJournalPin('1234'));
    });

    test('produces a 64-char hex sha256 digest', () {
      final hash = hashJournalPin('1234');
      expect(hash, hasLength(64));
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(hash), isTrue);
    });

    test('produces different hashes for different inputs', () {
      expect(hashJournalPin('1234'), isNot(hashJournalPin('4321')));
      expect(hashJournalPin('1234'), isNot(hashJournalPin('12345')));
    });
  });
}
