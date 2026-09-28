enum AccountType { cash, bank, eWallet, savings }

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.currencyCode,
    required this.openingBalanceMinor,
    required this.createdAt,
    this.includeInNetWorth = true,
  });

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

  /// The current balance. Until transactions exist, it's the opening balance.
  int get balanceMinor => openingBalanceMinor;

  factory Account.fromRow(Map<String, dynamic> row) => Account(
    id: row['id'] as String,
    name: row['name'] as String,
    type:
        AccountType.values.asNameMap()[row['type'] as String] ??
        AccountType.cash,
    currencyCode: row['currency_code'] as String,
    openingBalanceMinor: (row['opening_balance_minor'] as num).toInt(),
    createdAt: DateTime.parse(row['created_at'] as String),
    // Reads tolerate a database that hasn't had the migration yet.
    includeInNetWorth: row['include_in_net_worth'] as bool? ?? true,
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
  });

  final String name;
  final AccountType type;
  final String currencyCode;
  final int openingBalanceMinor;
  final bool includeInNetWorth;

  Map<String, Object> toRow() => {
    'name': name.trim(),
    'type': type.name,
    'currency_code': currencyCode,
    'opening_balance_minor': openingBalanceMinor,
    'include_in_net_worth': includeInNetWorth,
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
