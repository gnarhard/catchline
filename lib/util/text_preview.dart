String textPreview(String body, {int maxChars = 120}) {
  final flat = body.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (flat.length <= maxChars) return flat;
  return '${flat.substring(0, maxChars).trimRight()}…';
}
