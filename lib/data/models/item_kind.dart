import 'package:hive_ce/hive.dart';

part 'item_kind.g.dart';

@HiveType(typeId: 0)
enum ItemKind {
  @HiveField(0)
  journal,
  @HiveField(1)
  poem,
  @HiveField(2)
  lyric,
  @HiveField(3)
  phrase;

  String get label => switch (this) {
    ItemKind.journal => 'Journal',
    ItemKind.poem => 'Poems',
    ItemKind.lyric => 'Lyrics',
    ItemKind.phrase => 'Phrases',
  };

  String get singular => switch (this) {
    ItemKind.journal => 'journal entry',
    ItemKind.poem => 'poem',
    ItemKind.lyric => 'lyric',
    ItemKind.phrase => 'phrase',
  };
}
