import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/currency.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/domain/account.dart';
import '../../app_lock/application/app_lock_controller.dart';
import '../../app_lock/data/pin_repository.dart';
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
    this.pin,
  });

  final String name;
  final Currency currency;
  final AccountType accountType;
  final String accountName;
  final int openingBalanceMinor;
  final CoachTone coachTone;

  /// Held in memory only until [OnboardingController.complete] saves its
  /// hash to the keystore. It's never sent to the server.
  final String? pin;

  String get firstName => name.trim();

  OnboardingDraft copyWith({
    String? name,
    Currency? currency,
    AccountType? accountType,
    String? accountName,
    int? openingBalanceMinor,
    CoachTone? coachTone,
    String? pin,
  }) => OnboardingDraft(
    name: name ?? this.name,
    currency: currency ?? this.currency,
    accountType: accountType ?? this.accountType,
    accountName: accountName ?? this.accountName,
    openingBalanceMinor: openingBalanceMinor ?? this.openingBalanceMinor,
    coachTone: coachTone ?? this.coachTone,
    pin: pin ?? this.pin,
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

  void setPin(String value) => state = state.copyWith(pin: value);

  /// Saves the profile and first account together on the server, then the
  /// PIN on the device, then refreshes what the rest of the app reads. The
  /// PIN is saved before the profile refresh so the "set a PIN" screen never
  /// flashes up for a user who just chose one.
  Future<void> complete() async {
    final draft = state;
    final pin = draft.pin;
    if (pin == null) throw StateError('PIN missing from onboarding draft');
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
    await ref.read(pinRepositoryProvider).setPin(pin);
    ref.read(appLockProvider.notifier).pinCreated();
    ref.invalidate(accountsProvider);
    // Wait for the fresh profile, so the app gate shows Home the moment
    // onboarding closes rather than a flash of Welcome.
    final _ = await ref.refresh(profileProvider.future);
  }
}
