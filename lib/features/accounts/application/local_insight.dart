import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/wallet_insight.dart';

/// An insight worked out on the phone, used when the AI isn't reachable
/// (offline, not deployed, or every provider out of credits). It speaks in
/// the user's coaching tone and only states what the numbers show.
String localInsight(WalletSnapshot s, CoachTone tone) {
  final currency = Currencies.byCode(s.currencyCode);
  String money(int minor) => Money.format(minor, currency);

  final week = s.weekChangeMinor == 0
      ? ''
      : s.weekChangeMinor > 0
      ? ' Up ${money(s.weekChangeMinor)} this week.'
      : ' Down ${money(-s.weekChangeMinor)} this week.';

  if (s.netWorthMinor <= 0) {
    return switch (tone) {
      CoachTone.gentle =>
        'Your accounts are resting at zero. Every little bit you add counts.',
      CoachTone.balanced =>
        'Your balance is at zero. Log some income to start a cushion.',
      CoachTone.direct => 'Net worth is zero. Build a buffer.',
    };
  }

  final runway = s.runwayMonths;
  if (runway == null) {
    final where =
        '${money(s.netWorthMinor)} across ${s.accountCount} '
        '${s.accountCount == 1 ? 'account' : 'accounts'}.';
    // Too early for a pace: say so instead of guessing from a day or two.
    if (s.trackedDays < WalletSnapshot.minDaysForRunway) {
      final left = WalletSnapshot.minDaysForRunway - s.trackedDays;
      final days = '${s.trackedDays} ${s.trackedDays == 1 ? 'day' : 'days'}';
      return switch (tone) {
        CoachTone.gentle =>
          '$where You’re $days in. Keep logging and in $left more '
              '${left == 1 ? 'day' : 'days'} I’ll show how long it lasts.',
        CoachTone.balanced =>
          '$where $days tracked so far. After a week, I’ll tell you how '
              'long it would last.',
        CoachTone.direct => '$where $days of data. A week unlocks your runway.',
      };
    }
    return '$where Log a few expenses and I’ll tell you how long it would '
        'last.$week';
  }

  final r = runway >= 10
      ? runway.round().toString()
      : runway.toStringAsFixed(1);
  final months = '$r ${r == '1.0' || r == '1' ? 'month' : 'months'}';

  final line = switch ((tone, runway)) {
    (CoachTone.gentle, >= 6) =>
      'About $months of spending tucked away. A lovely, calm cushion.',
    (CoachTone.balanced, >= 6) =>
      'About $months of spending saved. That’s a strong cushion.',
    (CoachTone.direct, >= 6) => '$months of runway. Solid.',
    (CoachTone.gentle, >= 3) =>
      'Around $months of cushion. You’re building something steady.',
    (CoachTone.balanced, >= 3) =>
      'Around $months of cushion. Solid, keep building.',
    (CoachTone.direct, >= 3) => '$months of runway. Keep it growing.',
    (CoachTone.gentle, >= 1) =>
      'Roughly $months of runway. A little more buffer would feel nice.',
    (CoachTone.balanced, >= 1) =>
      'Roughly $months of runway. A bit more buffer would help.',
    (CoachTone.direct, >= 1) => 'Only $months of runway. Build more buffer.',
    (CoachTone.gentle, _) =>
      'Less than a month of cushion at this pace. Maybe a slower week?',
    (CoachTone.balanced, _) =>
      'Less than a month of runway at this pace. Worth slowing down.',
    (CoachTone.direct, _) => 'Under a month of runway. Cut spending now.',
  };
  return '$line$week';
}
