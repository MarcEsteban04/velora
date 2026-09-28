enum AccountType { cash, bank, eWallet, savings }

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.currencyCode,
    required this.openingBalanceMinor,
    required this.createdAt,
  });

  final String id;
  final String name;
  final AccountType type;
  final String currencyCode;

  /// The balance the user started with, in minor units (see `Money`).
  final int openingBalanceMinor;
  final DateTime createdAt;

  factory Account.fromRow(Map<String, dynamic> row) => Account(
    id: row['id'] as String,
    name: row['name'] as String,
    type:
        AccountType.values.asNameMap()[row['type'] as String] ??
        AccountType.cash,
    currencyCode: row['currency_code'] as String,
    openingBalanceMinor: (row['opening_balance_minor'] as num).toInt(),
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}
