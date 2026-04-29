import '../models/audio_clip_meta.dart';
import '../models/item.dart';
import '../models/item_kind.dart';

/// Wire format version. Bump when the JSON schema changes incompatibly so
/// older clients can refuse to merge a manifest written by a newer client.
const int kSyncSchemaVersion = 1;

Map<String, dynamic> audioClipToJson(AudioClipMeta clip) => {
  'id': clip.id,
  'durationMs': clip.durationMs,
  'createdAtMs': clip.createdAtMs,
  'mimeType': clip.mimeType,
  'fileExt': clip.fileExt,
  if (clip.label != null) 'label': clip.label,
};

AudioClipMeta audioClipFromJson(Map<String, dynamic> json) => AudioClipMeta(
  id: json['id'] as String,
  durationMs: (json['durationMs'] as num).toInt(),
  createdAtMs: (json['createdAtMs'] as num).toInt(),
  mimeType: json['mimeType'] as String,
  fileExt: json['fileExt'] as String,
  label: json['label'] as String?,
);

Map<String, dynamic> itemToJson(Item item) => {
  'id': item.id,
  'kind': item.kind.name,
  'title': item.title,
  'textBody': item.textBody,
  'audioClips': item.audioClips.map(audioClipToJson).toList(),
  'createdAtMs': item.createdAtMs,
  'updatedAtMs': item.updatedAtMs,
  if (item.deletedAtMs != null) 'deletedAtMs': item.deletedAtMs,
};

Item itemFromJson(Map<String, dynamic> json) => Item(
  id: json['id'] as String,
  kind: ItemKind.values.byName(json['kind'] as String),
  title: json['title'] as String,
  textBody: json['textBody'] as String,
  audioClips: ((json['audioClips'] as List?) ?? const [])
      .cast<Map<String, dynamic>>()
      .map(audioClipFromJson)
      .toList(),
  createdAtMs: (json['createdAtMs'] as num).toInt(),
  updatedAtMs: (json['updatedAtMs'] as num).toInt(),
  deletedAtMs: (json['deletedAtMs'] as num?)?.toInt(),
);

/// Manifest entry: the minimum we need to decide whether we already have the
/// latest copy of an item without downloading the full Item JSON.
class ManifestEntry {
  const ManifestEntry({required this.updatedAtMs, this.deletedAtMs});

  final int updatedAtMs;
  final int? deletedAtMs;

  Map<String, dynamic> toJson() => {
    'updatedAtMs': updatedAtMs,
    if (deletedAtMs != null) 'deletedAtMs': deletedAtMs,
  };

  static ManifestEntry fromJson(Map<String, dynamic> json) => ManifestEntry(
    updatedAtMs: (json['updatedAtMs'] as num).toInt(),
    deletedAtMs: (json['deletedAtMs'] as num?)?.toInt(),
  );

  static ManifestEntry fromItem(Item item) => ManifestEntry(
    updatedAtMs: item.updatedAtMs,
    deletedAtMs: item.deletedAtMs,
  );
}

class Manifest {
  const Manifest({required this.schemaVersion, required this.items});

  final int schemaVersion;
  final Map<String, ManifestEntry> items;

  static const Manifest empty = Manifest(
    schemaVersion: kSyncSchemaVersion,
    items: <String, ManifestEntry>{},
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'items': {for (final e in items.entries) e.key: e.value.toJson()},
  };

  static Manifest fromJson(Map<String, dynamic> json) {
    final raw = (json['items'] as Map?) ?? const {};
    final entries = <String, ManifestEntry>{};
    raw.forEach((key, value) {
      entries[key as String] = ManifestEntry.fromJson(
        (value as Map).cast<String, dynamic>(),
      );
    });
    return Manifest(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
      items: entries,
    );
  }
}
