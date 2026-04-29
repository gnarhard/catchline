import 'dart:io';
import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../util/id.dart';
import 'audio_repository.dart';
import 'models/audio_clip_meta.dart';

class _IoAudioRepository implements AudioRepository {
  Directory? _audioDir;

  Future<Directory> _ensureAudioDir() async {
    final cached = _audioDir;
    if (cached != null) return cached;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/audio');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _audioDir = dir;
    return dir;
  }

  String _pathFor(Directory dir, String clipId, String fileExt) =>
      '${dir.path}/$clipId.$fileExt';

  @override
  Future<({String clipId, String recordingTarget})> beginRecording({
    required String fileExt,
  }) async {
    final dir = await _ensureAudioDir();
    final clipId = newId();
    return (clipId: clipId, recordingTarget: _pathFor(dir, clipId, fileExt));
  }

  @override
  Future<({AudioClipMeta meta, String playableUri})> finalizeRecording({
    required String clipId,
    required String sourcePath,
    required String mimeType,
    required String fileExt,
    required int durationMs,
  }) async {
    final meta = AudioClipMeta(
      id: clipId,
      durationMs: durationMs,
      createdAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      mimeType: mimeType,
      fileExt: fileExt,
    );
    return (meta: meta, playableUri: Uri.file(sourcePath).toString());
  }

  @override
  Future<String> playableUri(AudioClipMeta meta) async {
    final dir = await _ensureAudioDir();
    return Uri.file(_pathFor(dir, meta.id, meta.fileExt)).toString();
  }

  @override
  Future<void> delete(AudioClipMeta meta) async {
    final dir = await _ensureAudioDir();
    final f = File(_pathFor(dir, meta.id, meta.fileExt));
    if (await f.exists()) {
      await f.delete();
    }
  }

  @override
  Future<bool> hasBytes(AudioClipMeta meta) async {
    final dir = await _ensureAudioDir();
    return File(_pathFor(dir, meta.id, meta.fileExt)).exists();
  }

  @override
  Future<Uint8List?> readBytes(AudioClipMeta meta) async {
    final dir = await _ensureAudioDir();
    final f = File(_pathFor(dir, meta.id, meta.fileExt));
    if (!await f.exists()) return null;
    return f.readAsBytes();
  }

  @override
  Future<void> writeBytes(AudioClipMeta meta, Uint8List bytes) async {
    final dir = await _ensureAudioDir();
    await File(_pathFor(dir, meta.id, meta.fileExt)).writeAsBytes(bytes);
  }
}

AudioRepository createAudioRepository({Box<Uint8List>? audioBytesBox}) =>
    _IoAudioRepository();
