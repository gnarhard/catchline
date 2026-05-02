import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';

import 'models/item_kind.dart';
import 'models/tag_palette.dart';

/// Storage key in the app_settings Hive box. v1 in case the schema needs to
/// evolve later — older versions can be left untouched and migrated lazily.
const _kTags = 'tags_v1';

/// Persistence and CRUD for the user-editable tag palette.
///
/// Tags live as a list of plain maps inside the existing app_settings
/// `Box<dynamic>` to avoid introducing a new Hive adapter (the box already
/// handles primitive lists/maps cleanly). On first read, when no list has
/// been stored, the seed [kDefaultTagDefs] is returned so the UI shows the
/// design's stock palette. The seed is only persisted once the user makes
/// a change, so a fresh install does not waste a write.
class TagsRepository {
  TagsRepository(this._box);

  final Box<dynamic> _box;

  /// Full ordered tag list. Returns the seeded defaults when nothing has
  /// been stored yet — never returns an empty list because of a missing key.
  List<TagDescriptor> get all {
    final raw = _box.get(_kTags);
    if (raw is! List) return List<TagDescriptor>.from(kDefaultTagDefs);
    final out = <TagDescriptor>[];
    for (final entry in raw) {
      final tag = _fromJson(entry);
      if (tag != null) out.add(tag);
    }
    return out.isEmpty ? List<TagDescriptor>.from(kDefaultTagDefs) : out;
  }

  /// Tags assigned to [kind], preserving the global order.
  List<TagDescriptor> forKind(ItemKind kind) =>
      all.where((t) => t.kinds.contains(kind)).toList();

  /// Look up a tag by id across the full list. Returns null for unknown ids
  /// (formerly-custom tags can outlive their definitions).
  TagDescriptor? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Insert or replace a tag by id. Trims the label and rejects empty ids.
  /// The tag is appended when its id is new and replaced in place otherwise,
  /// so existing ordering is preserved across edits.
  Future<void> upsert(TagDescriptor def) async {
    final id = def.id.trim();
    final label = def.label.trim();
    if (id.isEmpty || label.isEmpty) {
      throw ArgumentError('Tag id and label must be non-empty');
    }
    final cleaned = def.copyWith(id: id, label: label);
    final list = [...all];
    final i = list.indexWhere((t) => t.id == id);
    if (i >= 0) {
      list[i] = cleaned;
    } else {
      list.add(cleaned);
    }
    await _persist(list);
  }

  /// Removes [kind] from the tag's kind set. When the tag has no kinds left,
  /// it is fully deleted — a kind-less tag is otherwise invisible everywhere.
  Future<void> removeFromKind(String id, ItemKind kind) async {
    final list = [...all];
    final i = list.indexWhere((t) => t.id == id);
    if (i < 0) return;
    final remaining = {...list[i].kinds}..remove(kind);
    if (remaining.isEmpty) {
      list.removeAt(i);
    } else {
      list[i] = list[i].copyWith(kinds: remaining);
    }
    await _persist(list);
  }

  /// Hard-delete a tag regardless of its kind set. Existing items still
  /// reference the id — they fall back to a neutral chip in the UI.
  Future<void> delete(String id) async {
    final list = [...all]..removeWhere((t) => t.id == id);
    await _persist(list);
  }

  /// Restore the seed defaults, discarding all user edits.
  Future<void> resetToDefaults() => _persist(kDefaultTagDefs);

  /// Fires whenever the tag list mutates. Scoped to the tags key so unrelated
  /// settings writes don't cause spurious tag rebuilds.
  Stream<BoxEvent> watch() => _box.watch(key: _kTags);

  Future<void> _persist(List<TagDescriptor> list) async {
    await _box.put(_kTags, list.map(_toJson).toList());
  }
}

Map<String, dynamic> _toJson(TagDescriptor t) => {
  'id': t.id,
  'label': t.label,
  'color': t.color.toARGB32(),
  'kinds': t.kinds.map((k) => k.name).toList(),
};

TagDescriptor? _fromJson(dynamic raw) {
  if (raw is! Map) return null;
  final id = raw['id'];
  final label = raw['label'];
  final color = raw['color'];
  final kinds = raw['kinds'];
  if (id is! String || id.isEmpty) return null;
  if (label is! String || label.isEmpty) return null;
  if (color is! int) return null;
  if (kinds is! List) return null;
  final parsedKinds = <ItemKind>{};
  for (final k in kinds) {
    if (k is! String) continue;
    for (final v in ItemKind.values) {
      if (v.name == k) {
        parsedKinds.add(v);
        break;
      }
    }
  }
  return TagDescriptor(
    id: id,
    label: label,
    color: Color(color),
    kinds: parsedKinds,
  );
}
