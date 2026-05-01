import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../hive_registrar.g.dart';
import 'models/item.dart';

class Boxes {
  Boxes({
    required this.items,
    required this.syncMeta,
    required this.appSettings,
    this.audioBytes,
  });

  final Box<Item> items;

  /// Web only. Stores raw audio bytes keyed by [AudioClipMeta.id]. On native,
  /// audio is written to files in the app documents directory instead, so this
  /// is null.
  final Box<Uint8List>? audioBytes;

  /// Small key/value store for Drive sync state (manifest etag, last-synced
  /// timestamps). Keys are scoped by Google account email so signing into a
  /// different account does not leak state from another.
  final Box<dynamic> syncMeta;

  /// User-tunable app settings: Anthropic API key, configured phrase
  /// rephrase styles, etc.
  final Box<dynamic> appSettings;
}

const String kItemsBoxName = 'items';
const String kAudioBytesBoxName = 'audioBytes';
const String kSyncMetaBoxName = 'sync_meta';
const String kAppSettingsBoxName = 'app_settings';

Future<Boxes> openBoxes() async {
  await Hive.initFlutter();
  Hive.registerAdapters();

  final items = await Hive.openBox<Item>(kItemsBoxName);
  final syncMeta = await Hive.openBox<dynamic>(kSyncMetaBoxName);
  final appSettings = await Hive.openBox<dynamic>(kAppSettingsBoxName);
  final audioBytes = kIsWeb
      ? await Hive.openBox<Uint8List>(kAudioBytesBoxName)
      : null;

  return Boxes(
    items: items,
    syncMeta: syncMeta,
    appSettings: appSettings,
    audioBytes: audioBytes,
  );
}
