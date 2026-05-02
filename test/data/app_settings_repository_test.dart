import 'dart:io';

import 'package:catchline/data/app_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> box;
  late AppSettingsRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('catchline_app_settings_');
    Hive.init(tempDir.path);
    box = await Hive.openBox<dynamic>('app_settings_test');
    repo = AppSettingsRepository(box);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('falls back to defaults when nothing is stored', () {
    expect(repo.phraseStyles, kDefaultPhraseStyles);
  });

  test('falls back to defaults when stored value is wrong type', () async {
    await box.put('phrase_styles', 'not a list');
    expect(repo.phraseStyles, kDefaultPhraseStyles);
  });

  test('falls back to defaults when stored list is empty', () async {
    await box.put('phrase_styles', <String>[]);
    expect(repo.phraseStyles, kDefaultPhraseStyles);
  });

  test('returns only string entries from a mixed list', () async {
    await box.put('phrase_styles', <dynamic>['Hozier', 42, 'Rumi', null]);
    expect(repo.phraseStyles, ['Hozier', 'Rumi']);
  });

  test('setPhraseStyles persists the cleaned list', () async {
    await repo.setPhraseStyles(['Hozier', 'Plato']);
    expect(repo.phraseStyles, ['Hozier', 'Plato']);
  });

  test('setPhraseStyles trims whitespace and drops empty entries', () async {
    await repo.setPhraseStyles(['  Hozier ', '', '   ', 'Plato']);
    expect(repo.phraseStyles, ['Hozier', 'Plato']);
  });

  test(
    'setPhraseStyles with all-empty input still falls back to defaults',
    () async {
      await repo.setPhraseStyles(['', '   ']);
      // Stored list is empty -> getter falls back to defaults.
      expect(repo.phraseStyles, kDefaultPhraseStyles);
    },
  );

  group('anthropic cost', () {
    test('defaults to 0 when nothing is stored', () {
      expect(repo.anthropicCostUsd, 0.0);
    });

    test('falls back to 0 for malformed stored value', () async {
      await box.put('anthropic_cost_usd', 'not a number');
      expect(repo.anthropicCostUsd, 0.0);
    });

    test('coerces an int to a double', () async {
      await box.put('anthropic_cost_usd', 1);
      expect(repo.anthropicCostUsd, 1.0);
    });

    test('addAnthropicCostUsd accumulates positive deltas', () async {
      await repo.addAnthropicCostUsd(0.0125);
      await repo.addAnthropicCostUsd(0.0050);
      expect(repo.anthropicCostUsd, closeTo(0.0175, 1e-9));
    });

    test('addAnthropicCostUsd ignores zero / negative deltas', () async {
      await repo.addAnthropicCostUsd(0.10);
      await repo.addAnthropicCostUsd(0);
      await repo.addAnthropicCostUsd(-0.05);
      expect(repo.anthropicCostUsd, closeTo(0.10, 1e-9));
    });

    test('resetAnthropicCostUsd zeroes the stored value', () async {
      await repo.addAnthropicCostUsd(1.23);
      await repo.resetAnthropicCostUsd();
      expect(repo.anthropicCostUsd, 0.0);
    });
  });

  test('watch() emits when the styles change', () async {
    final events = <BoxEvent>[];
    final sub = repo.watch().listen(events.add);
    await repo.setPhraseStyles(['Hozier']);
    // Let the watch stream deliver.
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(events, isNotEmpty);
    expect(events.first.key, 'phrase_styles');
  });
}
