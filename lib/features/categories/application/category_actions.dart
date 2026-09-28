import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transactions/application/transaction_providers.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/domain/transaction.dart';

/// Creates, edits, hides, reorders and deletes categories, then refreshes
/// every screen that lists them.
class CategoryActions {
  CategoryActions(this._container);

  factory CategoryActions.of(BuildContext context) =>
      CategoryActions(ProviderScope.containerOf(context, listen: false));

  final ProviderContainer _container;

  CategoryRepository get _repo => _container.read(categoryRepositoryProvider);

  void _refresh() => _container.invalidate(categoriesProvider);

  Future<Category> create(CategoryDraft draft) async {
    final c = await _repo.create(draft);
    _refresh();
    return c;
  }

  Future<Category> update(String id, CategoryDraft draft) async {
    final c = await _repo.update(id, draft);
    _refresh();
    return c;
  }

  Future<void> setHidden(String id, bool hidden) async {
    await _repo.setHidden(id, hidden);
    _refresh();
  }

  Future<void> reorder(List<String> ids) async {
    await _repo.reorder(ids);
    _refresh();
  }

  Future<int> usage(String id) => _repo.usage(id);

  Future<void> delete(String id) async {
    await _repo.delete(id);
    _refresh();
  }
}

/// Whether [name] is already used by another category of the same kind.
/// Names are compared the way the database does: trimmed, ignoring case.
bool isCategoryNameTaken(
  String name,
  Iterable<Category> categories, {
  required Category? except,
  required TransactionKind kind,
}) {
  final n = name.trim().toLowerCase();
  return categories.any(
    (c) => c.kind == kind && c.id != except?.id && c.name.toLowerCase() == n,
  );
}
