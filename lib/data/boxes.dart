import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../hive_registrar.g.dart';
import 'models/item.dart';

class Boxes {
  Boxes({required this.items, this.audioBytes});

  final Box<Item> items;

  /// Web only. Stores raw audio bytes keyed by [AudioClipMeta.id]. On native,
  /// audio is written to files in the app documents directory instead, so this
  /// is null.
  final Box<Uint8List>? audioBytes;
}

const String kItemsBoxName = 'items';
const String kAudioBytesBoxName = 'audioBytes';

Future<Boxes> openBoxes() async {
  await Hive.initFlutter();
  Hive.registerAdapters();

  final items = await Hive.openBox<Item>(kItemsBoxName);
  final audioBytes = kIsWeb
      ? await Hive.openBox<Uint8List>(kAudioBytesBoxName)
      : null;

  return Boxes(items: items, audioBytes: audioBytes);
}
