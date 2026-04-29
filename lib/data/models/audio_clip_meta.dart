import 'package:hive_ce/hive.dart';

part 'audio_clip_meta.g.dart';

@HiveType(typeId: 1)
class AudioClipMeta extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  int durationMs;

  @HiveField(2)
  int createdAtMs;

  @HiveField(3)
  String mimeType;

  @HiveField(4)
  String fileExt;

  @HiveField(5)
  String? label;

  AudioClipMeta({
    required this.id,
    required this.durationMs,
    required this.createdAtMs,
    required this.mimeType,
    required this.fileExt,
    this.label,
  });
}
