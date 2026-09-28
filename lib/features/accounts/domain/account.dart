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

  final int id;
  final String name;
  final AccountType type;
  final String currencyCode;

  /// The balance the user started with, in minor units (see `Money`).
  final int openingBalanceMinor;
  final DateTime createdAt;
}
