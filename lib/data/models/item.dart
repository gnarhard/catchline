import 'package:hive_ce/hive.dart';

import 'ai_favorite.dart';
import 'audio_clip_meta.dart';
import 'item_kind.dart';

part 'item.g.dart';

@HiveType(typeId: 2)
class Item extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  ItemKind kind;

  @HiveField(2)
  String title;

  @HiveField(3)
  String textBody;

  @HiveField(4)
  List<AudioClipMeta> audioClips;

  @HiveField(5)
  int createdAtMs;

  @HiveField(6)
  int updatedAtMs;

  @HiveField(7)
  int? deletedAtMs;

  @HiveField(8)
  String? aiSynopsis;

  @HiveField(9)
  Map<String, String>? aiRephrasings;

  @HiveField(10)
  List<AiFavorite>? aiFavorites;

  Item({
    required this.id,
    required this.kind,
    required this.title,
    required this.textBody,
    required this.audioClips,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.deletedAtMs,
    this.aiSynopsis,
    this.aiRephrasings,
    this.aiFavorites,
  });
}
