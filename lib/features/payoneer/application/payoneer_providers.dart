import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_preferences.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/presentation/institutions.dart';
import '../../transactions/application/transaction_providers.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/domain/transaction.dart';
import '../data/invoice_repository.dart';
import '../domain/invoice.dart';

/// The user's Payoneer accounts, oldest first. Usually one.
final payoneerAccountsProvider = Provider<List<Account>>((ref) {
  final accounts = ref.watch(accountsProvider).value ?? const [];
  return [
    for (final a in accounts)
      if (Institutions.forAccount(a)?.isPayoneer ?? false) a,
  ];
});

final invoicesProvider = FutureProvider<List<Invoice>>(
  (ref) => ref.watch(invoiceRepositoryProvider).fetchAll(),
);

/// Payoneer converts at the market rate less a margin (up to 2%, it says).
/// Velora starts from that and learns the real one from each withdrawal.
final payoneerSpreadProvider = NotifierProvider<PayoneerSpread, double>(
  PayoneerSpread.new,
);

class PayoneerSpread extends Notifier<double> {
  static const _key = 'payoneer.spread';
  static const published = 0.02;

  @override
  double build() =>
      ref.watch(sharedPreferencesProvider).getDouble(_key) ?? published;

  /// Remembers the margin a real withdrawal got: [effective] against the
  /// [market] rate that day. Out-of-range values (typos) are ignored.
  Future<void> learn({
    required double effective,
    required double market,
  }) async {
    if (market <= 0) return;
    final spread = 1 - effective / market;
    if (spread < -0.01 || spread > 0.06) return;
    state = spread.clamp(0, 0.06);
    await ref.read(sharedPreferencesProvider).setDouble(_key, state);
  }
}

/// The income category salary goes into: "Salary", else "Freelance", else
/// the first income category.
Category? salaryCategory(List<Category> categories) {
  final income = categories
      .where((c) => c.kind == TransactionKind.income && !c.hidden)
      .toList();
  for (final name in ['salary', 'freelance']) {
    for (final c in income) {
      if (c.name.toLowerCase() == name) return c;
    }
  }
  return income.firstOrNull;
}

/// Changes invoices, then refreshes what shows them (and the money, when a
/// payment is logged or undone).
class InvoiceActions {
  InvoiceActions(this._container);

  factory InvoiceActions.of(BuildContext context) =>
      InvoiceActions(ProviderScope.containerOf(context, listen: false));

  final ProviderContainer _container;

  InvoiceRepository get _repo => _container.read(invoiceRepositoryProvider);

  void _refresh() => _container.invalidate(invoicesProvider);

  Future<Invoice> create(InvoiceDraft draft) async {
    final i = await _repo.create(draft);
    _refresh();
    return i;
  }

  Future<Invoice> update(String id, InvoiceDraft draft) async {
    final i = await _repo.update(id, draft);
    _refresh();
    return i;
  }

  Future<void> setStatus(String id, InvoiceStatus status) async {
    await _repo.setStatus(id, status);
    _refresh();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    _refresh();
  }

  /// Logs the payment as income and marks the invoice paid. Returns the
  /// income's id, for Undo.
  Future<String> markPaid(
    Invoice invoice, {
    required int amountMinor,
    required DateTime paidAt,
    String? categoryId,
  }) async {
    final id = await _repo.markPaid(
      invoice,
      amountMinor: amountMinor,
      paidAt: paidAt,
      categoryId: categoryId,
      note: 'Invoice ${invoice.title}',
    );
    _refresh();
    TransactionActions(_container).changedElsewhere();
    return id;
  }

  /// Deletes the logged income; the database puts the invoice back to sent.
  Future<void> undoPaid(String transactionId) async {
    await TransactionActions(_container).delete(transactionId);
    _refresh();
  }
}
