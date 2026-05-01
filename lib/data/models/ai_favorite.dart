import 'package:hive_ce/hive.dart';

part 'ai_favorite.g.dart';

@HiveType(typeId: 3)
class AiFavorite extends HiveObject {
  @HiveField(0)
  String style;

  @HiveField(1)
  String text;

  @HiveField(2)
  int createdAtMs;

  AiFavorite({
    required this.style,
    required this.text,
    required this.createdAtMs,
  });
}
