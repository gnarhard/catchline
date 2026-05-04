import 'package:catchline/data/secure_settings.dart';
import 'package:catchline/state/journal_lock.dart';
import 'package:catchline/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemorySecureStore store;
  late SecureSettings settings;
  late ProviderContainer container;

  setUp(() {
    store = InMemorySecureStore();
    settings = SecureSettings(store: store);
    container = ProviderContainer(
      overrides: [secureSettingsProvider.overrideWithValue(settings)],
    );
  });

  tearDown(() => container.dispose());

  Future<JournalLockState> readState() async {
    return await container.read(journalLockProvider.future);
  }

  group('JournalLockNotifier.build', () {
    test('reports hasPin = false when no PIN is stored', () async {
      final state = await readState();
      expect(state.hasPin, isFalse);
      expect(state.sessionUnlocked, isFalse);
      expect(state.isLocked, isFalse);
    });

    test('reports hasPin = true when a PIN is stored', () async {
      await settings.setJournalPin('1234');
      final state = await readState();
      expect(state.hasPin, isTrue);
      expect(state.sessionUnlocked, isFalse);
      expect(state.isLocked, isTrue);
    });
  });

  group('tryUnlock', () {
    test('returns false and stays locked on a wrong PIN', () async {
      await settings.setJournalPin('1234');
      await readState();

      final ok = await container
          .read(journalLockProvider.notifier)
          .tryUnlock('9999');
      expect(ok, isFalse);

      final state = container.read(journalLockProvider).value!;
      expect(state.isLocked, isTrue);
    });

    test('returns true and unlocks the session on the right PIN', () async {
      await settings.setJournalPin('1234');
      await readState();

      final ok = await container
          .read(journalLockProvider.notifier)
          .tryUnlock('1234');
      expect(ok, isTrue);

      final state = container.read(journalLockProvider).value!;
      expect(state.hasPin, isTrue);
      expect(state.sessionUnlocked, isTrue);
      expect(state.isLocked, isFalse);
    });

    test('returns false when no PIN is configured', () async {
      await readState();
      final ok = await container
          .read(journalLockProvider.notifier)
          .tryUnlock('1234');
      expect(ok, isFalse);
      final state = container.read(journalLockProvider).value!;
      expect(state.sessionUnlocked, isFalse);
    });
  });

  group('lock', () {
    test('resets sessionUnlocked back to false', () async {
      await settings.setJournalPin('1234');
      await readState();
      await container.read(journalLockProvider.notifier).tryUnlock('1234');
      expect(
        container.read(journalLockProvider).value!.sessionUnlocked,
        isTrue,
      );

      container.read(journalLockProvider.notifier).lock();

      final state = container.read(journalLockProvider).value!;
      expect(state.sessionUnlocked, isFalse);
      expect(state.isLocked, isTrue);
    });

    test('is a no-op when already locked', () async {
      await settings.setJournalPin('1234');
      await readState();
      container.read(journalLockProvider.notifier).lock();
      expect(
        container.read(journalLockProvider).value!.sessionUnlocked,
        isFalse,
      );
    });
  });

  group('setPin', () {
    test('persists a new PIN and relocks the session', () async {
      await readState();
      await container.read(journalLockProvider.notifier).setPin('5555');

      expect(await settings.hasJournalPin(), isTrue);
      expect(await settings.verifyJournalPin('5555'), isTrue);

      final state = container.read(journalLockProvider).value!;
      expect(state.hasPin, isTrue);
      expect(state.sessionUnlocked, isFalse);
      expect(state.isLocked, isTrue);
    });

    test('clearing with null removes the stored PIN and unlocks', () async {
      await settings.setJournalPin('1234');
      await readState();
      await container.read(journalLockProvider.notifier).setPin(null);

      expect(await settings.hasJournalPin(), isFalse);
      final state = container.read(journalLockProvider).value!;
      expect(state.hasPin, isFalse);
      expect(state.isLocked, isFalse);
    });

    test('changing the PIN re-locks even if previously unlocked', () async {
      await settings.setJournalPin('1234');
      await readState();
      await container.read(journalLockProvider.notifier).tryUnlock('1234');

      await container.read(journalLockProvider.notifier).setPin('5678');

      final state = container.read(journalLockProvider).value!;
      expect(state.hasPin, isTrue);
      expect(state.sessionUnlocked, isFalse);
    });
  });

  group('JournalLockState', () {
    test('isLocked is true only when hasPin and not unlocked', () {
      expect(
        const JournalLockState(hasPin: false, sessionUnlocked: false).isLocked,
        isFalse,
      );
      expect(
        const JournalLockState(hasPin: false, sessionUnlocked: true).isLocked,
        isFalse,
      );
      expect(
        const JournalLockState(hasPin: true, sessionUnlocked: true).isLocked,
        isFalse,
      );
      expect(
        const JournalLockState(hasPin: true, sessionUnlocked: false).isLocked,
        isTrue,
      );
    });

    test('equality covers both fields', () {
      expect(
        const JournalLockState(hasPin: true, sessionUnlocked: false),
        equals(const JournalLockState(hasPin: true, sessionUnlocked: false)),
      );
      expect(
        const JournalLockState(hasPin: true, sessionUnlocked: false),
        isNot(const JournalLockState(hasPin: true, sessionUnlocked: true)),
      );
    });
  });
}
