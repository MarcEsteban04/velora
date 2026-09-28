import 'transaction.dart';

class Category {
  const Category({
    required this.id,
    required this.kind,
    required this.name,
    required this.icon,
    required this.color,
    this.sortOrder = 0,
    this.hidden = false,
  });

  final String id;

  /// Expense or income; categories don't apply to transfers.
  final TransactionKind kind;
  final String name;

  /// Keys into the app's icon and color sets (see `CategoryStyle`).
  final String icon;
  final String color;
  final int sortOrder;

  /// Hidden categories leave the pickers but keep their history.
  final bool hidden;

  factory Category.fromRow(Map<String, dynamic> row) => Category(
    id: row['id'] as String,
    kind: row['kind'] == 'income'
        ? TransactionKind.income
        : TransactionKind.expense,
    name: row['name'] as String,
    icon: row['icon'] as String,
    color: row['color'] as String,
    sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
    // Tolerates a database that hasn't had the migration yet.
    hidden: row['archived_at'] != null,
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

  /// A new category goes to the end of the list.
  Map<String, Object> toRow({int sortOrder = 100}) => {
    'kind': kind.name,
    'name': name.trim(),
    'icon': icon,
    'color': color,
    'sort_order': sortOrder,
  };

  /// The editable fields, for updating an existing category.
  Map<String, Object> toUpdate() => {
    'name': name.trim(),
    'icon': icon,
    'color': color,
  };
}
