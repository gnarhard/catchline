import 'package:catchline/data/models/ai_favorite.dart';
import 'package:catchline/data/models/audio_clip_meta.dart';
import 'package:catchline/data/models/item.dart';
import 'package:catchline/data/models/item_kind.dart';
import 'package:catchline/data/sync/json_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AudioClipMeta JSON', () {
    test('round-trips with optional label set', () {
      final clip = AudioClipMeta(
        id: 'c1',
        durationMs: 4500,
        createdAtMs: 1700000000000,
        mimeType: 'audio/aac',
        fileExt: 'm4a',
        label: 'Take 2',
      );
      final restored = audioClipFromJson(audioClipToJson(clip));
      expect(restored.id, clip.id);
      expect(restored.durationMs, clip.durationMs);
      expect(restored.createdAtMs, clip.createdAtMs);
      expect(restored.mimeType, clip.mimeType);
      expect(restored.fileExt, clip.fileExt);
      expect(restored.label, 'Take 2');
    });

    test('round-trips with no label', () {
      final clip = AudioClipMeta(
        id: 'c2',
        durationMs: 1000,
        createdAtMs: 1700000000000,
        mimeType: 'audio/webm',
        fileExt: 'webm',
      );
      final json = audioClipToJson(clip);
      expect(json.containsKey('label'), isFalse);
      final restored = audioClipFromJson(json);
      expect(restored.label, isNull);
    });
  });

  group('Item JSON', () {
    test('round-trips a full item', () {
      final item = Item(
        id: 'i1',
        kind: ItemKind.poem,
        title: 'A title',
        textBody: 'Body text',
        audioClips: [
          AudioClipMeta(
            id: 'c1',
            durationMs: 1000,
            createdAtMs: 1,
            mimeType: 'audio/aac',
            fileExt: 'm4a',
          ),
        ],
        createdAtMs: 100,
        updatedAtMs: 200,
      );
      final restored = itemFromJson(itemToJson(item));
      expect(restored.id, 'i1');
      expect(restored.kind, ItemKind.poem);
      expect(restored.title, 'A title');
      expect(restored.textBody, 'Body text');
      expect(restored.audioClips.length, 1);
      expect(restored.audioClips.single.id, 'c1');
      expect(restored.createdAtMs, 100);
      expect(restored.updatedAtMs, 200);
      expect(restored.deletedAtMs, isNull);
    });

    test('round-trips a tombstone', () {
      final item = Item(
        id: 'i1',
        kind: ItemKind.journal,
        title: '',
        textBody: '',
        audioClips: const [],
        createdAtMs: 100,
        updatedAtMs: 300,
        deletedAtMs: 400,
      );
      final restored = itemFromJson(itemToJson(item));
      expect(restored.deletedAtMs, 400);
    });

    test('omits deletedAtMs from JSON when null', () {
      final item = Item(
        id: 'i1',
        kind: ItemKind.lyric,
        title: 't',
        textBody: 'b',
        audioClips: const [],
        createdAtMs: 1,
        updatedAtMs: 1,
      );
      final json = itemToJson(item);
      expect(json.containsKey('deletedAtMs'), isFalse);
    });

    test('decodes ItemKind by name', () {
      for (final kind in ItemKind.values) {
        final item = Item(
          id: 'i',
          kind: kind,
          title: 't',
          textBody: 'b',
          audioClips: const [],
          createdAtMs: 1,
          updatedAtMs: 1,
        );
        expect(itemFromJson(itemToJson(item)).kind, kind);
      }
    });
  });

  group('AiFavorite JSON', () {
    test('round-trips style/text/createdAtMs', () {
      final fav = AiFavorite(
        style: 'Hozier',
        text: 'in green hush',
        createdAtMs: 1234567890,
      );
      final restored = aiFavoriteFromJson(aiFavoriteToJson(fav));
      expect(restored.style, 'Hozier');
      expect(restored.text, 'in green hush');
      expect(restored.createdAtMs, 1234567890);
    });
  });

  group('Item JSON with AI fields', () {
    test('round-trips aiSynopsis and aiRephrasings', () {
      final item = Item(
        id: 'i1',
        kind: ItemKind.journal,
        title: 't',
        textBody: 'b',
        audioClips: const [],
        createdAtMs: 1,
        updatedAtMs: 1,
        aiSynopsis: 'A reflective entry.',
        aiRephrasings: const {'Hozier': 'a green hush', 'Plato': 'the form'},
      );
      final restored = itemFromJson(itemToJson(item));
      expect(restored.aiSynopsis, 'A reflective entry.');
      expect(restored.aiRephrasings, {'Hozier': 'a green hush', 'Plato': 'the form'});
    });

    test('round-trips aiFavorites', () {
      final item = Item(
        id: 'i1',
        kind: ItemKind.phrase,
        title: 't',
        textBody: 'b',
        audioClips: const [],
        createdAtMs: 1,
        updatedAtMs: 1,
        aiFavorites: [
          AiFavorite(style: 'Hozier', text: 'green hush', createdAtMs: 10),
          AiFavorite(style: 'Plato', text: 'the form', createdAtMs: 20),
        ],
      );
      final restored = itemFromJson(itemToJson(item));
      expect(restored.aiFavorites, isNotNull);
      expect(restored.aiFavorites!.length, 2);
      expect(restored.aiFavorites!.first.style, 'Hozier');
      expect(restored.aiFavorites!.last.text, 'the form');
    });

    test('omits aiSynopsis/aiRephrasings/aiFavorites from JSON when null/empty',
        () {
      final item = Item(
        id: 'i1',
        kind: ItemKind.poem,
        title: 't',
        textBody: 'b',
        audioClips: const [],
        createdAtMs: 1,
        updatedAtMs: 1,
        aiFavorites: const [],
      );
      final json = itemToJson(item);
      expect(json.containsKey('aiSynopsis'), isFalse);
      expect(json.containsKey('aiRephrasings'), isFalse);
      expect(json.containsKey('aiFavorites'), isFalse);
    });

    test('decodes JSON missing optional fields without error', () {
      final item = itemFromJson({
        'id': 'i1',
        'kind': 'lyric',
        'title': '',
        'textBody': '',
        'createdAtMs': 1,
        'updatedAtMs': 1,
      });
      expect(item.audioClips, isEmpty);
      expect(item.deletedAtMs, isNull);
      expect(item.aiSynopsis, isNull);
      expect(item.aiRephrasings, isNull);
      expect(item.aiFavorites, isNull);
    });
  });

  group('Manifest JSON', () {
    test('round-trips with mixed entries', () {
      final manifest = Manifest(
        schemaVersion: kSyncSchemaVersion,
        items: {
          'a': const ManifestEntry(updatedAtMs: 100),
          'b': const ManifestEntry(updatedAtMs: 200, deletedAtMs: 250),
        },
      );
      final restored = Manifest.fromJson(manifest.toJson());
      expect(restored.schemaVersion, kSyncSchemaVersion);
      expect(restored.items.length, 2);
      expect(restored.items['a']!.updatedAtMs, 100);
      expect(restored.items['a']!.deletedAtMs, isNull);
      expect(restored.items['b']!.deletedAtMs, 250);
    });

    test('decodes an empty items map', () {
      final restored = Manifest.fromJson({
        'schemaVersion': 1,
        'items': <String, dynamic>{},
      });
      expect(restored.items, isEmpty);
    });
  });
}
