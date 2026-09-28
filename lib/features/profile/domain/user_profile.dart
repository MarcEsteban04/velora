/// How Velora phrases feedback about the user's spending.
enum CoachTone { gentle, balanced, direct }

/// Who the user is and how they like Velora to behave. Saved once onboarding
/// finishes, and its presence means onboarding is complete.
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

  Map<String, Object> toJson() => {
    'name': name,
    'currencyCode': currencyCode,
    'coachTone': coachTone.name,
    'onboardedAt': onboardedAt.toIso8601String(),
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] as String,
    currencyCode: json['currencyCode'] as String,
    coachTone:
        CoachTone.values.asNameMap()[json['coachTone']] ?? CoachTone.balanced,
    onboardedAt: DateTime.parse(json['onboardedAt'] as String),
  );
}
