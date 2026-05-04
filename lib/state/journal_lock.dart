import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Snapshot of the journal lock state.
///
/// - [hasPin] true once a PIN has been configured by the user.
/// - [sessionUnlocked] true while the user has typed the correct PIN since
///   the app was last brought to the foreground. Resets on backgrounding.
class JournalLockState {
  const JournalLockState({required this.hasPin, required this.sessionUnlocked});

  final bool hasPin;
  final bool sessionUnlocked;

  /// True iff the journal should currently be hidden behind the PIN gate.
  bool get isLocked => hasPin && !sessionUnlocked;

  JournalLockState copyWith({bool? hasPin, bool? sessionUnlocked}) =>
      JournalLockState(
        hasPin: hasPin ?? this.hasPin,
        sessionUnlocked: sessionUnlocked ?? this.sessionUnlocked,
      );

  @override
  bool operator ==(Object other) =>
      other is JournalLockState &&
      other.hasPin == hasPin &&
      other.sessionUnlocked == sessionUnlocked;

  @override
  int get hashCode => Object.hash(hasPin, sessionUnlocked);
}

/// Holds the journal PIN status (configured?) plus the current session's
/// unlock flag. The unlock flag lives only in memory; backgrounding the app
/// re-locks the journal via [lock].
class JournalLockNotifier extends AsyncNotifier<JournalLockState> {
  @override
  Future<JournalLockState> build() async {
    final hasPin = await ref.read(secureSettingsProvider).hasJournalPin();
    return JournalLockState(hasPin: hasPin, sessionUnlocked: false);
  }

  /// Persist a new PIN (or clear it when [pin] is null/empty). Sets
  /// [JournalLockState.hasPin] accordingly. Always relocks the session so
  /// the user is challenged on the next access.
  Future<void> setPin(String? pin) async {
    await ref.read(secureSettingsProvider).setJournalPin(pin);
    final has = pin != null && pin.isNotEmpty;
    state = AsyncData(JournalLockState(hasPin: has, sessionUnlocked: false));
  }

  /// Verify [pin] against storage and, on success, mark the session unlocked.
  /// Returns true on success, false if the PIN is wrong or no PIN is set.
  Future<bool> tryUnlock(String pin) async {
    final ok = await ref.read(secureSettingsProvider).verifyJournalPin(pin);
    if (!ok) return false;
    state = const AsyncData(
      JournalLockState(hasPin: true, sessionUnlocked: true),
    );
    return true;
  }

  /// Drop the in-memory unlock flag so the next access requires the PIN.
  /// Called from the app lifecycle listener on pause/detach.
  void lock() {
    final cur = state.value;
    if (cur == null) return;
    if (!cur.sessionUnlocked) return;
    state = AsyncData(cur.copyWith(sessionUnlocked: false));
  }
}

final journalLockProvider =
    AsyncNotifierProvider<JournalLockNotifier, JournalLockState>(
      JournalLockNotifier.new,
    );

/// Convenience: true while we should hide journal content.
/// Defaults to **unlocked** while the initial PIN check is in flight so the
/// UI doesn't flash a lock state for the no-PIN case.
final journalLockedProvider = Provider<bool>((ref) {
  final state = ref.watch(journalLockProvider);
  return state.value?.isLocked ?? false;
});
