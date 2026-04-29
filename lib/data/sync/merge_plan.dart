import '../models/item.dart';
import 'json_codec.dart';

/// What the sync engine should do for a given item id.
enum MergeAction {
  /// Local is the winner — upload it (and any new clip bytes), set the
  /// manifest entry to local's state.
  push,

  /// Remote is the winner — download `items/<id>.json`, prefetch any missing
  /// clip bytes, upsert into Hive. The manifest entry stays as the remote
  /// entry.
  pull,

  /// Both sides agree on `updatedAtMs`. Nothing changes; keep the existing
  /// manifest entry.
  noop,
}

class MergeDecision {
  const MergeDecision({
    required this.itemId,
    required this.action,
    required this.newEntry,
  });

  final String itemId;
  final MergeAction action;
  final ManifestEntry newEntry;

  @override
  bool operator ==(Object other) =>
      other is MergeDecision &&
      other.itemId == itemId &&
      other.action == action &&
      other.newEntry.updatedAtMs == newEntry.updatedAtMs &&
      other.newEntry.deletedAtMs == newEntry.deletedAtMs;

  @override
  int get hashCode =>
      Object.hash(itemId, action, newEntry.updatedAtMs, newEntry.deletedAtMs);

  @override
  String toString() => 'MergeDecision($itemId, $action, ${newEntry.toJson()})';
}

/// Decides per-item what to do given a remote manifest and the current local
/// state. Pure — no I/O. The sync engine consumes this list to drive the
/// upload/download loop.
///
/// Rules:
/// - id only on remote → PULL.
/// - id only locally → PUSH.
/// - newer `updatedAtMs` wins. Tie → if exactly one side is a tombstone, the
///   tombstone wins (deletion is sticky); otherwise NOOP, keep remote.
List<MergeDecision> planMerge({
  required Map<String, ManifestEntry> remoteEntries,
  required Map<String, Item> localItems,
}) {
  final ids = <String>{...remoteEntries.keys, ...localItems.keys};
  final out = <MergeDecision>[];

  for (final id in ids) {
    final remote = remoteEntries[id];
    final local = localItems[id];

    if (remote == null) {
      out.add(
        MergeDecision(
          itemId: id,
          action: MergeAction.push,
          newEntry: ManifestEntry.fromItem(local!),
        ),
      );
      continue;
    }
    if (local == null) {
      out.add(
        MergeDecision(itemId: id, action: MergeAction.pull, newEntry: remote),
      );
      continue;
    }
    if (local.updatedAtMs > remote.updatedAtMs) {
      out.add(
        MergeDecision(
          itemId: id,
          action: MergeAction.push,
          newEntry: ManifestEntry.fromItem(local),
        ),
      );
    } else if (remote.updatedAtMs > local.updatedAtMs) {
      out.add(
        MergeDecision(itemId: id, action: MergeAction.pull, newEntry: remote),
      );
    } else {
      // Equal updatedAtMs.
      final localTomb = local.deletedAtMs != null;
      final remoteTomb = remote.deletedAtMs != null;
      if (localTomb && !remoteTomb) {
        out.add(
          MergeDecision(
            itemId: id,
            action: MergeAction.push,
            newEntry: ManifestEntry.fromItem(local),
          ),
        );
      } else if (remoteTomb && !localTomb) {
        out.add(
          MergeDecision(itemId: id, action: MergeAction.pull, newEntry: remote),
        );
      } else {
        out.add(
          MergeDecision(itemId: id, action: MergeAction.noop, newEntry: remote),
        );
      }
    }
  }

  return out;
}
