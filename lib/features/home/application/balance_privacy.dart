import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Hide balances": masks every amount on screen, for checking the app in
/// public. It lasts for the session; persisting it arrives with Settings.
final balancesHiddenProvider = NotifierProvider<BalancePrivacy, bool>(
  BalancePrivacy.new,
);

class BalancePrivacy extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}
