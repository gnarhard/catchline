import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_service.dart';
import '../data/app_settings_repository.dart';
import '../data/audio_repository.dart';
import '../data/boxes.dart';
import '../data/items_repository.dart';
import '../data/models/item_kind.dart';
import '../data/models/tag_palette.dart';
import '../data/secure_settings.dart';
import '../data/tags_repository.dart';

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

final syncMetaBoxProvider = Provider(
  (ref) => ref.watch(boxesProvider).syncMeta,
);

final appSettingsRepoProvider = Provider<AppSettingsRepository>((ref) {
  final boxes = ref.watch(boxesProvider);
  return AppSettingsRepository(boxes.appSettings);
});

final secureSettingsProvider = Provider<SecureSettings>((ref) {
  return SecureSettings();
});

final aiServiceProvider = Provider<AiService>((ref) {
  final repo = ref.watch(appSettingsRepoProvider);
  final svc = AiService(
    onUsage: (usage) => repo.addAnthropicCostUsd(usage.usdCost),
  );
  ref.onDispose(svc.dispose);
  return svc;
});

/// Streams the cumulative Anthropic spend so the Settings UI updates as
/// requests complete. First value is the current stored cost; subsequent
/// values fire on any app-settings box change (cheap — the box is small).
final anthropicCostUsdProvider = StreamProvider<double>((ref) async* {
  final repo = ref.watch(appSettingsRepoProvider);
  yield repo.anthropicCostUsd;
  await for (final _ in repo.watch()) {
    yield repo.anthropicCostUsd;
  }
});

final tagsRepoProvider = Provider<TagsRepository>((ref) {
  final boxes = ref.watch(boxesProvider);
  return TagsRepository(boxes.appSettings);
});

/// Streams the user's current tag palette. Emits the current value on
/// subscribe and again on every tag-list mutation, so pickers/filters/badges
/// reflect edits without manual invalidation.
final tagsProvider = StreamProvider<List<TagDescriptor>>((ref) async* {
  final repo = ref.watch(tagsRepoProvider);
  yield repo.all;
  await for (final _ in repo.watch()) {
    yield repo.all;
  }
});

/// Tags assigned to a specific item kind. Derived from [tagsProvider] so
/// it shares the same stream subscription.
final tagsForKindProvider =
    Provider.family<List<TagDescriptor>, ItemKind>((ref, kind) {
      final all = ref.watch(tagsProvider).value ?? const <TagDescriptor>[];
      return all.where((t) => t.kinds.contains(kind)).toList();
    });
