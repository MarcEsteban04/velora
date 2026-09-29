import 'dart:math' as math;

import '../../../core/time/app_clock.dart';

enum AccountType {
  cash,
  bank,
  eWallet,
  savings,

  /// A card or pay-later plan (BillEase). Its balance is what's owed, as a
  /// negative number: spending on it takes it down, paying the bill (a
  /// transfer in) brings it back up to zero.
  credit,
}

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.currencyCode,
    required this.openingBalanceMinor,
    required this.createdAt,
    this.includeInNetWorth = true,
    this.institutionId,
    this.creditLimitMinor,
    int? balanceMinor,
  }) : balanceMinor = balanceMinor ?? openingBalanceMinor;

  final String id;
  final String name;
  final AccountType type;
  final String currencyCode;

  /// The balance the user started with, in minor units (see `Money`).
  final int openingBalanceMinor;
  final DateTime createdAt;

  /// False for money that isn't really the user's (for example a shared
  /// household wallet). Such accounts are listed but not counted.
  final bool includeInNetWorth;

  /// The bank or e-wallet it belongs to (a key in `Institutions`), if one
  /// was chosen.
  final String? institutionId;

  /// The live balance: opening balance plus all transactions. The database
  /// computes it (the `account_balances` view).
  final int balanceMinor;

  /// A credit account's limit, if known.
  final int? creditLimitMinor;

  bool get isCredit => type == AccountType.credit;

  /// What's owed on a credit account (zero for the others).
  int get owedMinor => isCredit && balanceMinor < 0 ? -balanceMinor : 0;

  /// How much more can go on a credit account, when it has a limit.
  int? get availableCreditMinor => switch (creditLimitMinor) {
    final limit? when isCredit => math.max(0, limit - owedMinor),
    _ => null,
  };

  Account withBalance(int minor) => Account(
    id: id,
    name: name,
    type: type,
    currencyCode: currencyCode,
    openingBalanceMinor: openingBalanceMinor,
    createdAt: createdAt,
    includeInNetWorth: includeInNetWorth,
    institutionId: institutionId,
    creditLimitMinor: creditLimitMinor,
    balanceMinor: minor,
  );

  factory Account.fromRow(Map<String, dynamic> row) => Account(
    id: row['id'] as String,
    name: row['name'] as String,
    type:
        AccountType.values.asNameMap()[row['type'] as String] ??
        AccountType.cash,
    currencyCode: row['currency_code'] as String,
    openingBalanceMinor: (row['opening_balance_minor'] as num).toInt(),
    createdAt: AppClock.wall(DateTime.parse(row['created_at'] as String)),
    // Reads tolerate a database that hasn't had the migration yet.
    includeInNetWorth: row['include_in_net_worth'] as bool? ?? true,
    institutionId: row['institution'] as String?,
    creditLimitMinor: (row['credit_limit_minor'] as num?)?.toInt(),
  );
}

/// What the user fills in to create or edit an account.
class AccountDraft {
  const AccountDraft({
    required this.name,
    required this.type,
    required this.currencyCode,
    required this.openingBalanceMinor,
    this.includeInNetWorth = true,
    this.institutionId,
    this.creditLimitMinor,
  });

  final String name;
  final AccountType type;
  final String currencyCode;
  final int openingBalanceMinor;
  final bool includeInNetWorth;
  final String? institutionId;

  /// Only kept for a credit account.
  final int? creditLimitMinor;

  Map<String, Object?> toRow() => {
    'name': name.trim(),
    'type': type.name,
    'currency_code': currencyCode,
    'opening_balance_minor': openingBalanceMinor,
    'include_in_net_worth': includeInNetWorth,
    'institution': ?institutionId,
    // Only sent for credit (other types ignore it), so saving the rest
    // works before the credit migration.
    if (type == AccountType.credit) 'credit_limit_minor': creditLimitMinor,
  };
}

/// Net worth in the main currency, broken down by account type. Accounts in
/// other currencies are totalled separately rather than converted with a
/// made-up exchange rate.
class NetWorth {
  NetWorth._(this.totalMinor, this.byType, this.otherCurrencies);

  factory NetWorth.of(Iterable<Account> accounts, String mainCurrency) {
    final byType = <AccountType, int>{};
    final others = <String, int>{};
    var total = 0;
    for (final a in accounts.where((a) => a.includeInNetWorth)) {
      if (a.currencyCode == mainCurrency) {
        total += a.balanceMinor;
        byType.update(
          a.type,
          (v) => v + a.balanceMinor,
          ifAbsent: () => a.balanceMinor,
        );
      } else {
        others.update(
          a.currencyCode,
          (v) => v + a.balanceMinor,
          ifAbsent: () => a.balanceMinor,
        );
      }
    }
    return NetWorth._(total, byType, others);
  }

  final int totalMinor;
  final Map<AccountType, int> byType;

  /// Currency code to total, for included accounts not in the main currency.
  final Map<String, int> otherCurrencies;
}
