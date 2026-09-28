import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_preferences.dart';

/// "Hide balances": masks every amount on screen, for checking the app in
/// public. It starts from the "Hide balances on open" setting, and the eye
/// button toggles it for the session.
final balancesHiddenProvider = NotifierProvider<BalancePrivacy, bool>(
  BalancePrivacy.new,
);

class BalancePrivacy extends Notifier<bool> {
  @override
  bool build() => ref.read(appPreferencesProvider).hideBalancesOnOpen;

  void toggle() => state = !state;
}
