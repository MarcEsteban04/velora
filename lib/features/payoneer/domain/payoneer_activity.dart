import 'dart:math' as math;

import '../../../core/money/currency.dart';
import '../../transactions/domain/transaction.dart';

/// Money leaving the account for another one, possibly in another currency.
class Withdrawal {
  const Withdrawal(this.transaction, {required this.from, required this.to});

  final Transaction transaction;
  final Currency from;
  final Currency to;

  int get sentMinor => transaction.amountMinor;
  int get receivedMinor => transaction.toAmountMinor ?? transaction.amountMinor;
  String get toAccountId => transaction.toAccountId!;
  DateTime get at => transaction.occurredAt;

  /// What 1 unit of [from] became, for example ₱61.20 per $1.
  double get rate =>
      (receivedMinor / math.pow(10, to.decimalDigits)) /
      (sentMinor / math.pow(10, from.decimalDigits));
}

/// One account's money in and out, summed for a period.
class PayoneerActivity {
  PayoneerActivity._({
    required this.received,
    required this.withdrawals,
    required this.receivedMinor,
    required this.withdrawnMinor,
    required this.withdrawnToMinor,
  });

  /// [transactions] touch the account (see `fetchForAccount`); only those
  /// on or after [since] count towards the totals. [currencyOf] maps
  /// account ids to their currency.
  factory PayoneerActivity.of(
    String accountId,
    Iterable<Transaction> transactions, {
    required Currency Function(String accountId) currencyOf,
    required DateTime since,
  }) {
    final from = currencyOf(accountId);
    final received = <Transaction>[];
    final withdrawals = <Withdrawal>[];
    var receivedMinor = 0, withdrawnMinor = 0;
    final withdrawnTo = <String, int>{};
    for (final t in transactions) {
      final counts = !t.occurredAt.isBefore(since);
      if (t.kind == TransactionKind.income && t.accountId == accountId) {
        received.add(t);
        if (counts) receivedMinor += t.amountMinor;
      } else if (t.kind == TransactionKind.transfer &&
          t.accountId == accountId &&
          t.toAccountId != null) {
        final w = Withdrawal(t, from: from, to: currencyOf(t.toAccountId!));
        withdrawals.add(w);
        if (counts) {
          withdrawnMinor += w.sentMinor;
          withdrawnTo.update(
            w.to.code,
            (v) => v + w.receivedMinor,
            ifAbsent: () => w.receivedMinor,
          );
        }
      }
    }
    return PayoneerActivity._(
      received: received,
      withdrawals: withdrawals,
      receivedMinor: receivedMinor,
      withdrawnMinor: withdrawnMinor,
      withdrawnToMinor: withdrawnTo,
    );
  }

  /// Every payment in and withdrawal out, newest first.
  final List<Transaction> received;
  final List<Withdrawal> withdrawals;

  /// Totals since the period started, in the account's currency...
  final int receivedMinor;
  final int withdrawnMinor;

  /// ...and what the withdrawals became, per destination currency.
  final Map<String, int> withdrawnToMinor;

  /// The average rate withdrawals into [to] got this period, or null.
  double? averageRate(Currency from, Currency to) {
    final got = withdrawnToMinor[to.code];
    if (got == null || withdrawnMinor == 0 || withdrawnToMinor.length != 1) {
      return null;
    }
    return (got / math.pow(10, to.decimalDigits)) /
        (withdrawnMinor / math.pow(10, from.decimalDigits));
  }
}
