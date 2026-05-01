import 'package:catchline/data/models/item.dart';
import 'package:catchline/data/models/item_kind.dart';
import 'package:catchline/data/sync/json_codec.dart';
import 'package:catchline/data/sync/merge_plan.dart';
import 'package:flutter_test/flutter_test.dart';

Item _item({String id = 'i', int updatedAtMs = 100, int? deletedAtMs}) => Item(
  id: id,
  kind: ItemKind.journal,
  title: '',
  textBody: '',
  audioClips: const [],
  createdAtMs: updatedAtMs,
  updatedAtMs: updatedAtMs,
  deletedAtMs: deletedAtMs,
);

ManifestEntry _entry({required int updatedAtMs, int? deletedAtMs}) =>
    ManifestEntry(updatedAtMs: updatedAtMs, deletedAtMs: deletedAtMs);

void main() {
  group('planMerge', () {
    test('local-only ids -> push', () {
      final decisions = planMerge(
        remoteEntries: const {},
        localItems: {'a': _item(id: 'a', updatedAtMs: 10)},
      );
      expect(decisions.length, 1);
      expect(decisions.single.itemId, 'a');
      expect(decisions.single.action, MergeAction.push);
      expect(decisions.single.newEntry.updatedAtMs, 10);
    });

    test('remote-only ids -> pull', () {
      final decisions = planMerge(
        remoteEntries: {'b': _entry(updatedAtMs: 20)},
        localItems: const {},
      );
      expect(decisions.length, 1);
      expect(decisions.single.itemId, 'b');
      expect(decisions.single.action, MergeAction.pull);
      expect(decisions.single.newEntry.updatedAtMs, 20);
    });

    test('newer local wins -> push', () {
      final decisions = planMerge(
        remoteEntries: {'a': _entry(updatedAtMs: 10)},
        localItems: {'a': _item(updatedAtMs: 20)},
      );
      expect(decisions.single.action, MergeAction.push);
      expect(decisions.single.newEntry.updatedAtMs, 20);
    });

    test('newer remote wins -> pull', () {
      final decisions = planMerge(
        remoteEntries: {'a': _entry(updatedAtMs: 30)},
        localItems: {'a': _item(updatedAtMs: 20)},
      );
      expect(decisions.single.action, MergeAction.pull);
      expect(decisions.single.newEntry.updatedAtMs, 30);
    });

    test('equal timestamps with no tombstones -> noop', () {
      final decisions = planMerge(
        remoteEntries: {'a': _entry(updatedAtMs: 50)},
        localItems: {'a': _item(updatedAtMs: 50)},
      );
      expect(decisions.single.action, MergeAction.noop);
    });

    test(
      'equal timestamps but local is tombstone -> push (deletion sticky)',
      () {
        final decisions = planMerge(
          remoteEntries: {'a': _entry(updatedAtMs: 50)},
          localItems: {'a': _item(updatedAtMs: 50, deletedAtMs: 50)},
        );
        expect(decisions.single.action, MergeAction.push);
        expect(decisions.single.newEntry.deletedAtMs, 50);
      },
    );

    test('equal timestamps but remote is tombstone -> pull', () {
      final decisions = planMerge(
        remoteEntries: {'a': _entry(updatedAtMs: 50, deletedAtMs: 50)},
        localItems: {'a': _item(updatedAtMs: 50)},
      );
      expect(decisions.single.action, MergeAction.pull);
      expect(decisions.single.newEntry.deletedAtMs, 50);
    });

    test('remote tombstone newer than local -> pull (delete propagates)', () {
      final decisions = planMerge(
        remoteEntries: {'a': _entry(updatedAtMs: 100, deletedAtMs: 100)},
        localItems: {'a': _item(updatedAtMs: 50)},
      );
      expect(decisions.single.action, MergeAction.pull);
      expect(decisions.single.newEntry.deletedAtMs, 100);
    });

    test('both sides tombstoned at the same timestamp -> noop', () {
      final decisions = planMerge(
        remoteEntries: {'a': _entry(updatedAtMs: 50, deletedAtMs: 50)},
        localItems: {'a': _item(updatedAtMs: 50, deletedAtMs: 50)},
      );
      expect(decisions.single.action, MergeAction.noop);
    });

    test('local tombstone newer than remote -> push', () {
      final decisions = planMerge(
        remoteEntries: {'a': _entry(updatedAtMs: 50)},
        localItems: {'a': _item(updatedAtMs: 100, deletedAtMs: 100)},
      );
      expect(decisions.single.action, MergeAction.push);
      expect(decisions.single.newEntry.deletedAtMs, 100);
    });

    test('remote-only id that is already a tombstone -> pull', () {
      final decisions = planMerge(
        remoteEntries: {'a': _entry(updatedAtMs: 100, deletedAtMs: 100)},
        localItems: const {},
      );
      expect(decisions.single.action, MergeAction.pull);
      expect(decisions.single.newEntry.deletedAtMs, 100);
    });

    test('empty inputs produce no decisions', () {
      expect(planMerge(remoteEntries: const {}, localItems: const {}),
          isEmpty);
    });

    test('mixed batch: pull, push, noop', () {
      final decisions = planMerge(
        remoteEntries: {
          'a': _entry(updatedAtMs: 100), // newer remote -> pull
          'b': _entry(updatedAtMs: 50), // older remote -> push
          'c': _entry(updatedAtMs: 75), // equal -> noop
          'd': _entry(updatedAtMs: 10), // remote-only -> pull
        },
        localItems: {
          'a': _item(updatedAtMs: 50),
          'b': _item(updatedAtMs: 80),
          'c': _item(updatedAtMs: 75),
          'e': _item(updatedAtMs: 5), // local-only -> push
        },
      );
      final byId = {for (final d in decisions) d.itemId: d};
      expect(byId['a']!.action, MergeAction.pull);
      expect(byId['b']!.action, MergeAction.push);
      expect(byId['c']!.action, MergeAction.noop);
      expect(byId['d']!.action, MergeAction.pull);
      expect(byId['e']!.action, MergeAction.push);
    });
  });
}
