/// How long an insight may be: one short sentence that fits a card.
const insightMaxChars = 120;

/// Cleans an AI insight and keeps it short: no markdown or quotes, and if
/// it runs long, just its first sentence, or failing that a cut at a word
/// boundary. Returns null when nothing is left.
String? tightenInsight(String raw, {int max = insightMaxChars}) {
  var t = raw
      .replaceAll(RegExp(r'[*_#`"]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (t.isEmpty) return null;
  if (t.length <= max) return t;

  // The first sentence usually says the most useful thing.
  final first = RegExp(r'^.+?[.!?](?=\s|$)').firstMatch(t)?.group(0);
  if (first != null && first.length <= max && first.length >= 20) {
    return first;
  }
  t = t.substring(0, max);
  final cut = t.lastIndexOf(' ');
  if (cut > max * 0.6) t = t.substring(0, cut);
  return '${t.replaceAll(RegExp(r'[,;:\s]+$'), '')}…';
}
