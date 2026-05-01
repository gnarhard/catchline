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

  test('setPhraseStyles with all-empty input still falls back to defaults', () async {
    await repo.setPhraseStyles(['', '   ']);
    // Stored list is empty -> getter falls back to defaults.
    expect(repo.phraseStyles, kDefaultPhraseStyles);
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
