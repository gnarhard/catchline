import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/audio_repository.dart';
import '../data/boxes.dart';
import '../data/items_repository.dart';

/// Holds the open Hive boxes. Must be overridden at app bootstrap with the
/// result of [openBoxes] — the default factory throws so a missing override
/// fails loudly instead of returning a half-initialized state.
final boxesProvider = Provider<Boxes>(
  (ref) => throw UnimplementedError(
    'boxesProvider must be overridden at app bootstrap with openBoxes()',
  ),
);

final itemsRepoProvider = Provider<ItemsRepository>((ref) {
  final boxes = ref.watch(boxesProvider);
  return ItemsRepository(boxes.items);
});

final audioRepoProvider = Provider<AudioRepository>((ref) {
  final boxes = ref.watch(boxesProvider);
  return createAudioRepository(audioBytesBox: boxes.audioBytes);
});
