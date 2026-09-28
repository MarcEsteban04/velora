import 'package:flutter/material.dart';

import '../domain/account.dart';

/// How each account type looks and reads in the UI.
extension AccountTypeStyle on AccountType {
  String get label => switch (this) {
    AccountType.cash => 'Cash',
    AccountType.bank => 'Bank',
    AccountType.eWallet => 'E-wallet',
    AccountType.savings => 'Savings',
  };

  String get defaultName => switch (this) {
    AccountType.cash => 'Cash',
    AccountType.bank => 'Bank account',
    AccountType.eWallet => 'E-wallet',
    AccountType.savings => 'Savings',
  };

  IconData get icon => switch (this) {
    AccountType.cash => Icons.payments_rounded,
    AccountType.bank => Icons.account_balance_rounded,
    AccountType.eWallet => Icons.phone_iphone_rounded,
    AccountType.savings => Icons.savings_rounded,
  };

  List<Color> get gradient => switch (this) {
    AccountType.cash => const [Color(0xFF6CBF78), Color(0xFF2F6B3C)],
    AccountType.bank => const [Color(0xFF6E8BFF), Color(0xFF2E3A8C)],
    AccountType.eWallet => const [Color(0xFF3CC6C0), Color(0xFF1D6670)],
    AccountType.savings => const [Color(0xFFF0A15E), Color(0xFFB0472A)],
  };
}
