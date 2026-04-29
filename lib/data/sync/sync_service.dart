import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

import '../audio_repository.dart';
import '../items_repository.dart';
import '../models/audio_clip_meta.dart';
import '../models/item.dart';
import 'drive_client.dart';
import 'google_auth.dart';
import 'json_codec.dart';
import 'merge_plan.dart';

enum SyncStatusKind { idle, syncing, error, signedOut }

class SyncStatus {
  const SyncStatus(this.kind, {this.message, this.lastSyncedAtMs});
  final SyncStatusKind kind;
  final String? message;
  final int? lastSyncedAtMs;

  static const SyncStatus signedOut = SyncStatus(SyncStatusKind.signedOut);
  static const SyncStatus idle = SyncStatus(SyncStatusKind.idle);
  static const SyncStatus syncing = SyncStatus(SyncStatusKind.syncing);
}

const String _kManifestName = 'manifest.json';
const int _kMaxAttempts = 3;

String _itemFileName(String id) => 'items/$id.json';
String _audioFileName(AudioClipMeta clip) => 'audio/${clip.id}.${clip.fileExt}';

class SyncService {
  SyncService({
    required ItemsRepository items,
    required AudioRepository audio,
    required Box<dynamic> syncMeta,
    required GoogleAuth auth,
  }) : _items = items,
       _audio = audio,
       _syncMeta = syncMeta,
       _auth = auth;

  final ItemsRepository _items;
  final AudioRepository _audio;
  final Box<dynamic> _syncMeta;
  final GoogleAuth _auth;

  final StreamController<SyncStatus> _status =
      StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _status.stream;

  SyncStatus _last = SyncStatus.signedOut;
  SyncStatus get currentStatus => _last;

  Completer<void>? _inFlight;

  /// Prefix used to scope `sync_meta` keys to a specific Google account.
  String _key(String email, String suffix) => '$email:$suffix';

  /// Fire-and-forget entry point. Coalesces concurrent calls onto a single
  /// run. Never throws — failures surface via [statusStream].
  Future<void> syncNow() {
    final existing = _inFlight;
    if (existing != null) return existing.future;
    final completer = Completer<void>();
    _inFlight = completer;
    _run().whenComplete(() {
      _inFlight = null;
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  Future<void> _run() async {
    final account = _auth.currentAccount;
    if (account == null) {
      _emit(SyncStatus.signedOut);
      return;
    }
    _emit(SyncStatus.syncing);

    try {
      final client = await _auth.getAuthedClient();
      try {
        final drive = DriveClient(client);
        await _runWithRetry(drive, account.email);
        final now = DateTime.now().toUtc().millisecondsSinceEpoch;
        await _syncMeta.put(_key(account.email, 'lastSyncedAtMs'), now);
        _emit(SyncStatus(SyncStatusKind.idle, lastSyncedAtMs: now));
      } finally {
        client.close();
      }
    } catch (e, st) {
      debugPrint('SyncService error: $e\n$st');
      _emit(SyncStatus(SyncStatusKind.error, message: '$e'));
    }
  }

  Future<void> _runWithRetry(DriveClient drive, String email) async {
    DriveEtagMismatch? lastMismatch;
    for (var attempt = 0; attempt < _kMaxAttempts; attempt++) {
      try {
        await _runOnce(drive, email);
        return;
      } on DriveEtagMismatch catch (e) {
        lastMismatch = e;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    throw lastMismatch ?? StateError('exhausted retries');
  }

  Future<void> _runOnce(DriveClient drive, String email) async {
    final remoteFiles = await drive.listAll();
    final remoteByName = <String, DriveFile>{
      for (final f in remoteFiles) f.name: f,
    };

    final manifestFile = remoteByName[_kManifestName];
    Manifest manifest;
    String? manifestEtag;

    if (manifestFile != null) {
      try {
        final raw = await drive.downloadJson(manifestFile.id);
        manifest = Manifest.fromJson(raw);
        manifestEtag = manifestFile.headRevisionId;
      } catch (_) {
        manifest = await _rebuildManifest(drive, remoteByName);
      }
    } else {
      manifest = await _rebuildManifest(drive, remoteByName);
    }

    final localItems = _items.rawValues().toList();
    final localById = <String, Item>{for (final i in localItems) i.id: i};

    final decisions = planMerge(
      remoteEntries: manifest.items,
      localItems: localById,
    );

    final newEntries = <String, ManifestEntry>{};
    for (final d in decisions) {
      switch (d.action) {
        case MergeAction.push:
          await _pushItem(drive, localById[d.itemId]!, remoteByName);
        case MergeAction.pull:
          await _pullItem(drive, d.itemId, remoteByName);
        case MergeAction.noop:
          break;
      }
      newEntries[d.itemId] = d.newEntry;
    }

    final newManifest = Manifest(
      schemaVersion: kSyncSchemaVersion,
      items: newEntries,
    );
    if (manifestFile != null) {
      final updated = await drive.updateJson(
        fileId: manifestFile.id,
        content: newManifest.toJson(),
        ifMatch: manifestEtag,
      );
      await _syncMeta.put(
        _key(email, 'lastManifestEtag'),
        updated.headRevisionId,
      );
    } else {
      final created = await drive.createJson(
        name: _kManifestName,
        content: newManifest.toJson(),
      );
      await _syncMeta.put(
        _key(email, 'lastManifestEtag'),
        created.headRevisionId,
      );
    }
  }

  Future<Manifest> _rebuildManifest(
    DriveClient drive,
    Map<String, DriveFile> remoteByName,
  ) async {
    final entries = <String, ManifestEntry>{};
    for (final entry in remoteByName.entries) {
      final name = entry.key;
      if (!name.startsWith('items/') || !name.endsWith('.json')) continue;
      try {
        final json = await drive.downloadJson(entry.value.id);
        final item = itemFromJson(json);
        entries[item.id] = ManifestEntry.fromItem(item);
      } catch (_) {
        // Skip malformed item files; the next sync from a clean writer fixes
        // them.
      }
    }
    return Manifest(schemaVersion: kSyncSchemaVersion, items: entries);
  }

  Future<void> _pushItem(
    DriveClient drive,
    Item item,
    Map<String, DriveFile> remoteByName,
  ) async {
    // Upload any clip bytes that aren't already on Drive.
    for (final clip in item.audioClips) {
      final name = _audioFileName(clip);
      if (remoteByName.containsKey(name)) continue;
      if (!await _audio.hasBytes(clip)) {
        // Local item references audio we don't have bytes for. Skip the
        // upload — the manifest still propagates, and a later device may have
        // the bytes.
        continue;
      }
      final bytes = await _audio.readBytes(clip);
      if (bytes == null) continue;
      final created = await drive.createBinary(
        name: name,
        mimeType: clip.mimeType,
        bytes: bytes,
      );
      remoteByName[name] = created;
    }

    final fileName = _itemFileName(item.id);
    final existing = remoteByName[fileName];
    if (existing != null) {
      final updated = await drive.updateJson(
        fileId: existing.id,
        content: itemToJson(item),
      );
      remoteByName[fileName] = updated;
    } else {
      final created = await drive.createJson(
        name: fileName,
        content: itemToJson(item),
      );
      remoteByName[fileName] = created;
    }
  }

  Future<void> _pullItem(
    DriveClient drive,
    String id,
    Map<String, DriveFile> remoteByName,
  ) async {
    final fileName = _itemFileName(id);
    final remoteFile = remoteByName[fileName];
    if (remoteFile == null) {
      // Manifest references an item with no JSON file. Treat as orphan and
      // skip — local state remains untouched.
      return;
    }
    final json = await drive.downloadJson(remoteFile.id);
    final remoteItem = itemFromJson(json);

    // Pre-fetch any clip bytes we don't already have, BEFORE writing the item
    // to Hive — keeps the UI from rendering an item whose audio 404s.
    if (remoteItem.deletedAtMs == null) {
      for (final clip in remoteItem.audioClips) {
        if (await _audio.hasBytes(clip)) continue;
        final audioFile = remoteByName[_audioFileName(clip)];
        if (audioFile == null) continue;
        try {
          final bytes = await drive.downloadBytes(audioFile.id);
          await _audio.writeBytes(clip, bytes);
        } catch (e) {
          debugPrint('Audio download failed for ${clip.id}: $e');
          // Don't abort the whole sync; the clip will retry next time.
        }
      }
    } else {
      // Tombstone: drop any local audio for clips that were on this item.
      final priorLocal = _items.rawGet(id);
      if (priorLocal != null) {
        for (final clip in priorLocal.audioClips) {
          await _audio.delete(clip);
        }
      }
    }

    await _items.put(remoteItem);
  }

  void _emit(SyncStatus status) {
    _last = status;
    _status.add(status);
  }

  /// Wipes sync metadata for [email]. Call on sign-out so signing back in
  /// with a different account starts fresh.
  Future<void> clearAccountMeta(String email) async {
    final keysToRemove = _syncMeta.keys
        .whereType<String>()
        .where((k) => k.startsWith('$email:'))
        .toList();
    await _syncMeta.deleteAll(keysToRemove);
  }

  Future<void> dispose() async {
    await _status.close();
  }
}
