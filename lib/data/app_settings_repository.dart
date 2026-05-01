import 'package:hive_ce/hive.dart';

const _kPhraseStyles = 'phrase_styles';

const List<String> kDefaultPhraseStyles = [
  'Hozier',
  'Bob Dylan',
  'Matthew McConaughey',
  'Plato',
  'Maya Angelou',
  'Shakespeare',
  'Hemingway',
  'Hunter S. Thompson',
  'Rumi',
  'Cormac McCarthy',
];

class AppSettingsRepository {
  AppSettingsRepository(this._box);

  final Box<dynamic> _box;

  List<String> get phraseStyles {
    final raw = _box.get(_kPhraseStyles);
    if (raw is List) {
      final list = raw.whereType<String>().toList();
      if (list.isNotEmpty) return list;
    }
    return List<String>.from(kDefaultPhraseStyles);
  }

  Future<void> setPhraseStyles(List<String> styles) async {
    final cleaned = styles
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    await _box.put(_kPhraseStyles, cleaned);
  }

  Stream<BoxEvent> watch() => _box.watch();
}
