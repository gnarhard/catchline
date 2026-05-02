import 'package:flutter/material.dart';

import 'item_kind.dart';

/// One mood/category tag the user can attach to an item.
///
/// Tags are referenced by their stable [id] (lowercase, no spaces) on Item
/// records; the label and color are presentation-only and live in code.
class TagDescriptor {
  const TagDescriptor({
    required this.id,
    required this.label,
    required this.color,
  });

  final String id;
  final String label;
  final Color color;
}

/// Default tag palette used everywhere a user can pick a tag.
///
/// Colors lifted from the design canvas (see catchline-design.html) so
/// in-app chips match the mockups.
const List<TagDescriptor> kDefaultTags = [
  TagDescriptor(id: 'serious', label: 'serious', color: Color(0xFFC47A82)),
  TagDescriptor(id: 'funny', label: 'funny', color: Color(0xFFF0C47A)),
  TagDescriptor(id: 'dark', label: 'dark', color: Color(0xFF7A4A82)),
  TagDescriptor(id: 'romantic', label: 'romantic', color: Color(0xFFF7A0B0)),
  TagDescriptor(id: 'hopeful', label: 'hopeful', color: Color(0xFFA0C4A8)),
  TagDescriptor(id: 'lyric', label: 'lyric', color: Color(0xFF9AB8D4)),
  TagDescriptor(id: 'rant', label: 'rant', color: Color(0xFFD47A5A)),
  TagDescriptor(id: 'prayer', label: 'prayer', color: Color(0xFFE8D4A0)),
  TagDescriptor(
    id: 'observation',
    label: 'observation',
    color: Color(0xFFA890B0),
  ),
];

/// Subset of [kDefaultTags] available for a given item kind.
///
/// Per the design intent: each entry type has its own tag set, so a tag
/// like "lyric" is only meaningful on a phrase or poem, not a journal entry.
List<TagDescriptor> defaultTagsFor(ItemKind kind) {
  switch (kind) {
    case ItemKind.phrase:
      return kDefaultTags;
    case ItemKind.poem:
      return kDefaultTags
          .where(
            (t) => const {
              'lyric',
              'observation',
              'romantic',
              'serious',
              'hopeful',
              'dark',
            }.contains(t.id),
          )
          .toList();
    case ItemKind.lyric:
      return kDefaultTags
          .where(
            (t) => const {
              'serious',
              'funny',
              'dark',
              'romantic',
              'prayer',
            }.contains(t.id),
          )
          .toList();
    case ItemKind.journal:
      return kDefaultTags
          .where(
            (t) => const {
              'hopeful',
              'serious',
              'observation',
              'dark',
            }.contains(t.id),
          )
          .toList();
  }
}

/// Lookup a tag by its id. Returns null when the id is unknown (e.g. a
/// formerly-custom tag that no longer exists). Callers should render the
/// raw id with a neutral color in that case.
TagDescriptor? tagById(String? id) {
  if (id == null || id.isEmpty) return null;
  for (final t in kDefaultTags) {
    if (t.id == id) return t;
  }
  return null;
}
