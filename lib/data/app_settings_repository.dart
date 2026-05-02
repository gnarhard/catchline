import 'package:hive_ce/hive.dart';

const _kPhraseStyles = 'phrase_styles';
const _kAnthropicCostUsd = 'anthropic_cost_usd';

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

  /// Cumulative USD spent on Anthropic API calls. Returns 0 if nothing has
  /// been recorded yet or the stored value is malformed.
  double get anthropicCostUsd {
    final raw = _box.get(_kAnthropicCostUsd);
    if (raw is num) return raw.toDouble();
    return 0.0;
  }

  /// Adds [delta] to the running anthropic cost. No-op for non-positive deltas
  /// so callers don't need to guard against zero-token responses.
  Future<void> addAnthropicCostUsd(double delta) async {
    if (delta <= 0) return;
    await _box.put(_kAnthropicCostUsd, anthropicCostUsd + delta);
  }

  Future<void> resetAnthropicCostUsd() async {
    await _box.put(_kAnthropicCostUsd, 0.0);
  }

  Stream<BoxEvent> watch() => _box.watch();
}
