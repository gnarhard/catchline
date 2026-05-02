import '../../data/models/item.dart';
import '../../data/models/item_kind.dart';
import '../../util/journal_date.dart';

/// Append [addition] to [current], inserting a single newline between them
/// only when [current] has content and doesn't already end in one. An empty
/// existing body simply returns the addition.
///
/// Used by the editor's AI affordances ("Append to poem", "Append next line")
/// to splice generated content into the body field without doubling up
/// blank lines.
String appendBody(String current, String addition) {
  if (current.isEmpty) return addition;
  if (current.endsWith('\n')) return '$current$addition';
  return '$current\n$addition';
}

/// Filter an item list by a free-text query and a tag-id set.
///
/// Both filters are AND-combined. An empty query/tag set is a pass-through.
///
/// Lives outside the list-screen widget so it can be unit-tested without a
/// `WidgetTester` — the screen wraps it for free.
List<Item> filterItems(
  List<Item> items, {
  String query = '',
  Set<String> tagFilter = const {},
}) {
  final q = query.trim().toLowerCase();
  Iterable<Item> out = items;
  if (tagFilter.isNotEmpty) {
    out = out.where((item) => item.tag != null && tagFilter.contains(item.tag));
  }
  if (q.isNotEmpty) {
    out = out.where((item) {
      if (item.title.toLowerCase().contains(q)) return true;
      if (item.textBody.toLowerCase().contains(q)) return true;
      if (item.kind == ItemKind.journal &&
          formatJournalTitle(item.createdAtMs).toLowerCase().contains(q)) {
        return true;
      }
      return false;
    });
  }
  return out.toList();
}
