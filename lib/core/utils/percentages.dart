/// Whole-number percentages that always add up to exactly 100, using the
/// largest-remainder method. Plain rounding can give 98 + 2 + 1 = 101.
List<int> percentagesSummingTo100(List<int> values) {
  final total = values.fold<int>(0, (s, v) => s + v);
  if (total <= 0) return [for (final _ in values) 0];
  final exact = [for (final v in values) v * 100 / total];
  final floors = [for (final e in exact) e.floor()];
  var remaining = 100 - floors.fold<int>(0, (s, v) => s + v);
  final order = List.generate(values.length, (i) => i)
    ..sort((a, b) => (exact[b] - floors[b]).compareTo(exact[a] - floors[a]));
  for (final i in order) {
    if (remaining == 0) break;
    floors[i]++;
    remaining--;
  }
  return floors;
}
