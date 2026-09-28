import 'transaction.dart';

class Category {
  const Category({
    required this.id,
    required this.kind,
    required this.name,
    required this.icon,
    required this.color,
    this.sortOrder = 0,
  });

  final String id;

  /// Expense or income; categories don't apply to transfers.
  final TransactionKind kind;
  final String name;

  /// Keys into the app's icon and color sets (see `CategoryStyle`).
  final String icon;
  final String color;
  final int sortOrder;

  factory Category.fromRow(Map<String, dynamic> row) => Category(
    id: row['id'] as String,
    kind: row['kind'] == 'income'
        ? TransactionKind.income
        : TransactionKind.expense,
    name: row['name'] as String,
    icon: row['icon'] as String,
    color: row['color'] as String,
    sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
  );
}

class CategoryDraft {
  const CategoryDraft({
    required this.kind,
    required this.name,
    required this.icon,
    required this.color,
  });

  final TransactionKind kind;
  final String name;
  final String icon;
  final String color;

  Map<String, Object> toRow() => {
    'kind': kind.name,
    'name': name.trim(),
    'icon': icon,
    'color': color,
    'sort_order': 100,
  };
}
