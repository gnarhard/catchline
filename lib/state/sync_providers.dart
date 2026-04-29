import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../data/sync/google_auth.dart';
import '../data/sync/sync_service.dart';
import 'providers.dart';

/// Stable wrapper around [GoogleAuth] singleton so widgets can `ref.watch` it.
final googleAuthProvider = Provider<GoogleAuth>((ref) => GoogleAuth.instance);

/// Emits the current Google account (or null when signed out). Seeds with the
/// auth singleton's current value so widgets don't flash a "signed out" state
/// while waiting for the first stream event.
final googleAccountProvider = StreamProvider<GoogleSignInAccount?>((
  ref,
) async* {
  final auth = ref.watch(googleAuthProvider);
  yield auth.currentAccount;
  yield* auth.accountStream;
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    items: ref.watch(itemsRepoProvider),
    audio: ref.watch(audioRepoProvider),
    syncMeta: ref.watch(syncMetaBoxProvider),
    auth: ref.watch(googleAuthProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Emits sync engine status updates. Seeds with the service's current value
/// so the UI reflects the latest state on first build.
final syncStatusProvider = StreamProvider<SyncStatus>((ref) async* {
  final service = ref.watch(syncServiceProvider);
  yield service.currentStatus;
  yield* service.statusStream;
});
