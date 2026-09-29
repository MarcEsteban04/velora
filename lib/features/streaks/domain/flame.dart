import 'streak.dart';

/// The flame's colour as a streak grows: every badge heats it up a step,
/// from a first orange spark to a rainbow after a whole year.
enum FlameTier {
  spark(1, 'Spark', 'A spark'),
  amber(3, 'Amber', 'Your flame glows amber now.'),
  redHot(7, 'Red-hot', 'Your flame burns red-hot.'),
  magenta(14, 'Magenta', 'Your flame turned magenta.'),
  violet(30, 'Violet', 'Your flame turned violet.'),
  blue(50, 'Blue', 'Your flame burns blue now. That’s hot.'),
  whiteHot(100, 'White-hot', 'Your flame is white-hot.'),
  golden(200, 'Golden', 'Your flame turned gold.'),
  legendary(365, 'Legendary', 'A rainbow flame. A whole year of streak!');

  const FlameTier(this.from, this.label, this.phrase);

  /// The streak length (days) this colour starts at.
  final int from;
  final String label;

  /// Said when the flame reaches this colour.
  final String phrase;

  /// The colour for a streak of [days]; a spark below the first badge.
  static FlameTier of(int days) =>
      values.lastWhere((t) => days >= t.from, orElse: () => spark);

  /// The colour after this one, or null at the top.
  FlameTier? get next => index + 1 < values.length ? values[index + 1] : null;

  /// The one before, or null for the first spark.
  FlameTier? get previous => index > 0 ? values[index - 1] : null;
}

/// The badge a streak of [current] days should celebrate, given the badges
/// already celebrated up to [seen] days; null when there's nothing new.
/// When [seen] is null (never recorded) nothing is due: the badges earned
/// before celebrations existed aren't replayed all at once.
int? milestoneDue(int current, int? seen) {
  if (seen == null) return null;
  final reached = streakMilestones.lastWhere(
    (m) => m <= current,
    orElse: () => 0,
  );
  return reached > seen ? reached : null;
}
