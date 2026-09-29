import 'package:flutter/material.dart';

import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../domain/account.dart';

/// How each account type looks and reads in the UI.
extension AccountTypeStyle on AccountType {
  String get label => switch (this) {
    AccountType.cash => 'Cash',
    AccountType.bank => 'Bank',
    AccountType.eWallet => 'E-wallet',
    AccountType.savings => 'Savings',
    AccountType.credit => 'Credit',
  };

  String get defaultName => switch (this) {
    AccountType.cash => 'Cash',
    AccountType.bank => 'Bank account',
    AccountType.eWallet => 'E-wallet',
    AccountType.savings => 'Savings',
    AccountType.credit => 'Credit line',
  };

  IconData get icon => switch (this) {
    AccountType.cash => Icons.payments_rounded,
    AccountType.bank => Icons.account_balance_rounded,
    AccountType.eWallet => Icons.phone_iphone_rounded,
    AccountType.savings => Icons.savings_rounded,
    AccountType.credit => Icons.credit_card_rounded,
  };

  List<Color> get gradient => switch (this) {
    AccountType.cash => const [Color(0xFF6CBF78), Color(0xFF2F6B3C)],
    AccountType.bank => const [Color(0xFF6E8BFF), Color(0xFF2E3A8C)],
    AccountType.eWallet => const [Color(0xFF3CC6C0), Color(0xFF1D6670)],
    AccountType.savings => const [Color(0xFFF0A15E), Color(0xFFB0472A)],
    AccountType.credit => const [Color(0xFFB77CE0), Color(0xFF5A2E8A)],
  };
}

/// How a balance reads. A credit account shows what's owed instead of a
/// negative number: "₱5,471.44 owed", "Nothing owed", or "₱20.00 extra"
/// when more was paid than owed.
String balanceText(AccountType type, int minor, Currency currency) {
  if (type != AccountType.credit) return Money.format(minor, currency);
  if (minor < 0) return '${Money.format(-minor, currency)} owed';
  if (minor == 0) return 'Nothing owed';
  return '${Money.format(minor, currency)} extra';
}

/// What the big number on a card is: "BALANCE", or for credit "OWED"
/// (or "PAID EXTRA" when it's above zero).
String cardCaption(AccountType type, int minor) => switch (type) {
  AccountType.credit when minor > 0 => 'PAID EXTRA',
  AccountType.credit => 'OWED',
  _ => 'BALANCE',
};

/// The big number on a card: the balance, or for credit the amount alone
/// (the caption says whether it's owed).
String cardAmount(AccountType type, int minor, Currency currency) =>
    Money.format(type == AccountType.credit ? minor.abs() : minor, currency);
