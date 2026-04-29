import 'dart:typed_data';

import 'package:hive_ce/hive.dart';

import 'audio_repository_io.dart'
    if (dart.library.js_interop) 'audio_repository_web.dart' as platform;
import 'models/audio_clip_meta.dart';

/// Persists audio clip bytes/files and resolves playable URIs.
///
/// On native platforms, clips are stored as files inside the app documents
/// directory. On web, clips are stored as `Uint8List` values in a Hive box
/// (backed by IndexedDB) and a fresh blob URL is materialized on demand.
abstract class AudioRepository {
  /// Allocates a new clip id and a recording target.
  ///
  /// On native, [recordingTarget] is an absolute file path the recorder should
  /// write to. On web, it is an empty string (the `record` package ignores it
  /// on that platform).
  Future<({String clipId, String recordingTarget})> beginRecording({
    required String fileExt,
  });

  /// Persists a finished recording and returns its metadata + a playable URI.
  ///
  /// On native, [sourcePath] is the file path the recorder wrote to. On web,
  /// [sourcePath] is the blob URL returned by `record.stop()`; the bytes will
  /// be fetched and persisted before this returns.
  Future<({AudioClipMeta meta, String playableUri})> finalizeRecording({
    required String clipId,
    required String sourcePath,
    required String mimeType,
    required String fileExt,
    required int durationMs,
  });

  Future<String> playableUri(AudioClipMeta meta);

  Future<void> delete(AudioClipMeta meta);
}

AudioRepository createAudioRepository({Box<Uint8List>? audioBytesBox}) =>
    platform.createAudioRepository(audioBytesBox: audioBytesBox);
