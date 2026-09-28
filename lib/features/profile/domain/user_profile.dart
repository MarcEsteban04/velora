/// How Velora phrases feedback about the user's spending.
enum CoachTone { gentle, balanced, direct }

/// Who the user is and how they like Velora to behave. The row is created
/// when onboarding finishes, so its existence means onboarding is complete.
class UserProfile {
  const UserProfile({
    required this.name,
    required this.currencyCode,
    required this.coachTone,
    required this.onboardedAt,
  });

  final String name;
  final String currencyCode;
  final CoachTone coachTone;
  final DateTime onboardedAt;

  factory UserProfile.fromRow(Map<String, dynamic> row) => UserProfile(
    name: row['display_name'] as String,
    currencyCode: row['currency_code'] as String,
    coachTone:
        CoachTone.values.asNameMap()[row['coach_tone'] as String] ??
        CoachTone.balanced,
    onboardedAt: DateTime.parse(row['onboarded_at'] as String),
  );
}
