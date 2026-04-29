import 'dart:js_interop';
import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:web/web.dart' as web;

import '../util/id.dart';
import 'audio_repository.dart';
import 'models/audio_clip_meta.dart';

class _WebAudioRepository implements AudioRepository {
  _WebAudioRepository(this._bytesBox);

  final Box<Uint8List> _bytesBox;
  final Map<String, String> _blobUrlCache = <String, String>{};

  @override
  Future<({String clipId, String recordingTarget})> beginRecording({
    required String fileExt,
  }) async {
    final clipId = newId();
    return (clipId: clipId, recordingTarget: '');
  }

  @override
  Future<({AudioClipMeta meta, String playableUri})> finalizeRecording({
    required String clipId,
    required String sourcePath,
    required String mimeType,
    required String fileExt,
    required int durationMs,
  }) async {
    final response = await web.window.fetch(sourcePath.toJS).toDart;
    final buffer = await response.arrayBuffer().toDart;
    final bytes = buffer.toDart.asUint8List();

    await _bytesBox.put(clipId, bytes);

    web.URL.revokeObjectURL(sourcePath);

    final meta = AudioClipMeta(
      id: clipId,
      durationMs: durationMs,
      createdAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      mimeType: mimeType,
      fileExt: fileExt,
    );
    return (meta: meta, playableUri: _materialize(clipId, bytes, mimeType));
  }

  String _materialize(String clipId, Uint8List bytes, String mimeType) {
    final cached = _blobUrlCache[clipId];
    if (cached != null) return cached;
    final blob = web.Blob(
      <JSUint8Array>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    _blobUrlCache[clipId] = url;
    return url;
  }

  @override
  Future<String> playableUri(AudioClipMeta meta) async {
    final cached = _blobUrlCache[meta.id];
    if (cached != null) return cached;
    final bytes = _bytesBox.get(meta.id);
    if (bytes == null) {
      throw StateError('Audio bytes not found for clip ${meta.id}');
    }
    return _materialize(meta.id, bytes, meta.mimeType);
  }

  @override
  Future<void> delete(AudioClipMeta meta) async {
    await _bytesBox.delete(meta.id);
    final cached = _blobUrlCache.remove(meta.id);
    if (cached != null) {
      web.URL.revokeObjectURL(cached);
    }
  }
}

AudioRepository createAudioRepository({Box<Uint8List>? audioBytesBox}) {
  if (audioBytesBox == null) {
    throw StateError(
      'audioBytesBox is required for the web AudioRepository implementation',
    );
  }
  return _WebAudioRepository(audioBytesBox);
}
