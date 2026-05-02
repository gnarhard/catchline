import 'package:flutter/material.dart';

import 'item_kind.dart';

/// One mood/category tag the user can attach to an item.
///
/// Tags are referenced by their stable [id] (lowercase, no spaces) on Item
/// records. Label, color, and the set of [kinds] the tag is offered for are
/// user-editable via Settings — see `TagsRepository` for storage.
@immutable
class TagDescriptor {
  const TagDescriptor({
    required this.id,
    required this.label,
    required this.color,
    required this.kinds,
  });

  final String id;
  final String label;
  final Color color;

  /// The item kinds for which this tag appears in pickers/filters.
  /// A tag with an empty kind set is effectively retired.
  final Set<ItemKind> kinds;

  TagDescriptor copyWith({
    String? id,
    String? label,
    Color? color,
    Set<ItemKind>? kinds,
  }) => TagDescriptor(
    id: id ?? this.id,
    label: label ?? this.label,
    color: color ?? this.color,
    kinds: kinds ?? this.kinds,
  );

  @override
  bool operator ==(Object other) =>
      other is TagDescriptor &&
      other.id == id &&
      other.label == label &&
      other.color.toARGB32() == color.toARGB32() &&
      _setEquals(other.kinds, kinds);

  @override
  int get hashCode => Object.hash(id, label, color.toARGB32(), kinds.length);
}

bool _setEquals<T>(Set<T> a, Set<T> b) {
  if (a.length != b.length) return false;
  for (final v in a) {
    if (!b.contains(v)) return false;
  }
  return true;
}

/// Default tag palette used to seed [TagsRepository] on first run and as a
/// reset target. Each tag carries the set of kinds it should appear in,
/// matching the original design's per-kind curation:
///
/// - phrase:   all
/// - poem:     lyric, observation, romantic, serious, hopeful, dark
/// - lyric:    serious, funny, dark, romantic, prayer
/// - journal:  hopeful, serious, observation, dark
///
/// Colors lifted from `catchline-design.html`.
const List<TagDescriptor> kDefaultTagDefs = [
  TagDescriptor(
    id: 'serious',
    label: 'serious',
    color: Color(0xFFC47A82),
    kinds: {ItemKind.phrase, ItemKind.poem, ItemKind.lyric, ItemKind.journal},
  ),
  TagDescriptor(
    id: 'funny',
    label: 'funny',
    color: Color(0xFFF0C47A),
    kinds: {ItemKind.phrase, ItemKind.lyric},
  ),
  TagDescriptor(
    id: 'dark',
    label: 'dark',
    color: Color(0xFF7A4A82),
    kinds: {ItemKind.phrase, ItemKind.poem, ItemKind.lyric, ItemKind.journal},
  ),
  TagDescriptor(
    id: 'romantic',
    label: 'romantic',
    color: Color(0xFFF7A0B0),
    kinds: {ItemKind.phrase, ItemKind.poem, ItemKind.lyric},
  ),
  TagDescriptor(
    id: 'hopeful',
    label: 'hopeful',
    color: Color(0xFFA0C4A8),
    kinds: {ItemKind.phrase, ItemKind.poem, ItemKind.journal},
  ),
  TagDescriptor(
    id: 'lyric',
    label: 'lyric',
    color: Color(0xFF9AB8D4),
    kinds: {ItemKind.phrase, ItemKind.poem},
  ),
  TagDescriptor(
    id: 'rant',
    label: 'rant',
    color: Color(0xFFD47A5A),
    kinds: {ItemKind.phrase},
  ),
  TagDescriptor(
    id: 'prayer',
    label: 'prayer',
    color: Color(0xFFE8D4A0),
    kinds: {ItemKind.phrase, ItemKind.lyric},
  ),
  TagDescriptor(
    id: 'observation',
    label: 'observation',
    color: Color(0xFFA890B0),
    kinds: {ItemKind.phrase, ItemKind.poem, ItemKind.journal},
  ),
];

/// Preset color swatches offered in the tag editor. The defaults are first
/// so a user picking a default-tag-style color gets the canonical shade.
const List<Color> kTagColorPresets = [
  Color(0xFFC47A82),
  Color(0xFFF0C47A),
  Color(0xFF7A4A82),
  Color(0xFFF7A0B0),
  Color(0xFFA0C4A8),
  Color(0xFF9AB8D4),
  Color(0xFFD47A5A),
  Color(0xFFE8D4A0),
  Color(0xFFA890B0),
  Color(0xFF8FB8A8),
  Color(0xFFD4A0E8),
  Color(0xFFE8A0A0),
];
