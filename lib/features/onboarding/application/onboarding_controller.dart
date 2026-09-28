import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/currency.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/domain/account.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/user_profile.dart';
import '../data/onboarding_repository.dart';

/// Everything collected during onboarding. Nothing is saved until
/// [OnboardingController.complete], so backing out leaves no partial data.
class OnboardingDraft {
  const OnboardingDraft({
    required this.currency,
    this.name = '',
    this.accountType = AccountType.cash,
    this.accountName = 'Cash',
    this.openingBalanceMinor = 0,
    this.coachTone = CoachTone.balanced,
  });

  final String name;
  final Currency currency;
  final AccountType accountType;
  final String accountName;
  final int openingBalanceMinor;
  final CoachTone coachTone;

  String get firstName => name.trim();

  OnboardingDraft copyWith({
    String? name,
    Currency? currency,
    AccountType? accountType,
    String? accountName,
    int? openingBalanceMinor,
    CoachTone? coachTone,
  }) => OnboardingDraft(
    name: name ?? this.name,
    currency: currency ?? this.currency,
    accountType: accountType ?? this.accountType,
    accountName: accountName ?? this.accountName,
    openingBalanceMinor: openingBalanceMinor ?? this.openingBalanceMinor,
    coachTone: coachTone ?? this.coachTone,
  );
}

/// The currency for the device's region. It's a provider so tests can pin it.
final deviceCurrencyProvider = Provider<Currency>(
  (ref) => Currencies.fromDeviceLocale(),
);

final onboardingControllerProvider =
    NotifierProvider.autoDispose<OnboardingController, OnboardingDraft>(
      OnboardingController.new,
    );

class OnboardingController extends Notifier<OnboardingDraft> {
  @override
  OnboardingDraft build() =>
      OnboardingDraft(currency: ref.watch(deviceCurrencyProvider));

  void setName(String value) => state = state.copyWith(name: value);

  void setCurrency(Currency value) => state = state.copyWith(currency: value);

  void setAccountType(AccountType type, {String? name}) =>
      state = state.copyWith(accountType: type, accountName: name);

  void setAccountName(String value) =>
      state = state.copyWith(accountName: value);

  void setOpeningBalance(int minor) =>
      state = state.copyWith(openingBalanceMinor: minor);

  void setCoachTone(CoachTone value) =>
      state = state.copyWith(coachTone: value);

  /// Saves the profile and first account together on the server, then
  /// refreshes what the rest of the app reads.
  Future<void> complete() async {
    final draft = state;
    await ref
        .read(onboardingRepositoryProvider)
        .complete(
          displayName: draft.firstName,
          currencyCode: draft.currency.code,
          coachTone: draft.coachTone,
          accountName: draft.accountName.trim(),
          accountType: draft.accountType,
          openingBalanceMinor: draft.openingBalanceMinor,
        );
    ref
      ..invalidate(profileProvider)
      ..invalidate(accountsProvider);
  }
}
