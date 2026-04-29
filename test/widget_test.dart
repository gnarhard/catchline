import 'dart:io';

import 'package:catchline/app.dart';
import 'package:catchline/data/boxes.dart';
import 'package:catchline/data/models/item.dart';
import 'package:catchline/hive_registrar.g.dart';
import 'package:catchline/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory tempDir;
  late Boxes boxes;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('catchline_test_');
    Hive.init(tempDir.path);
    Hive.registerAdapters();
    final items = await Hive.openBox<Item>(kItemsBoxName);
    boxes = Boxes(items: items);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  testWidgets('home shell renders all four navigation destinations', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [boxesProvider.overrideWithValue(boxes)],
        child: const CatchlineApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Journal'), findsAtLeastNWidgets(1));
    expect(find.text('Poems'), findsAtLeastNWidgets(1));
    expect(find.text('Lyrics'), findsAtLeastNWidgets(1));
    expect(find.text('Phrases'), findsAtLeastNWidgets(1));
  });
}
