import 'package:flutter_test/flutter_test.dart';
import 'package:velora/features/accounts/domain/account.dart';
import 'package:velora/features/ask/domain/transaction_parser.dart';
import 'package:velora/features/receipts/application/receipt_to_transaction.dart';
import 'package:velora/features/receipts/data/receipt_reader.dart';
import 'package:velora/features/receipts/domain/receipt.dart';
import 'package:velora/features/transactions/domain/category.dart';
import 'package:velora/features/transactions/domain/transaction.dart';

final _now = DateTime(2026, 9, 30, 15, 10);

void main() {
  test('the AI reply is read, checked and trimmed', () {
    final s = SmartReceiptReader.parseAi(
      '{"is_receipt": true, "merchant": "Mercury Drug", "total": "1,245.50", '
      '"date": "2026-09-28", "category": "Health", "items": ['
      '{"name": "Biogesic", "amount": 45}, {"name": "Vitamin C", "amount": 320.5}]}',
      _now,
    )!;
    expect(s.totalMinor, 124550);
    expect(s.merchant, 'Mercury Drug');
    expect(s.date, DateTime(2026, 9, 28));
    expect(s.category, 'Health');
    expect(s.items.map((i) => i.amountMinor), [4500, 32050]);
    expect(s.source, ReceiptSource.ai);
  });

  test('not a receipt, no total, or a date from the future', () {
    expect(SmartReceiptReader.parseAi('{"is_receipt": false}', _now), isNull);
    expect(
      SmartReceiptReader.parseAi('{"is_receipt": true, "total": null}', _now),
      isNull,
    );
    expect(SmartReceiptReader.parseAi('garbage', _now), isNull);
    final future = SmartReceiptReader.parseAi(
      '{"is_receipt": true, "total": 10, "date": "2027-01-01"}',
      _now,
    )!;
    expect(future.date, isNull);
  });

  group('receipt to transaction', () {
    final accounts = [
      Account(
        id: 'cash',
        name: 'Cash',
        type: AccountType.cash,
        currencyCode: 'PHP',
        openingBalanceMinor: 0,
        createdAt: DateTime(2026),
      ),
    ];
    const categories = [
      Category(
        id: 'food',
        kind: TransactionKind.expense,
        name: 'Food',
        icon: 'food',
        color: 'ember',
      ),
      Category(
        id: 'health',
        kind: TransactionKind.expense,
        name: 'Health',
        icon: 'health',
        color: 'coral',
      ),
      Category(
        id: 'other',
        kind: TransactionKind.expense,
        name: 'Other',
        icon: 'other',
        color: 'slate',
      ),
      Category(
        id: 'refund',
        kind: TransactionKind.income,
        name: 'Refund',
        icon: 'refund',
        color: 'teal',
      ),
      Category(
        id: 'interest',
        kind: TransactionKind.income,
        name: 'Interest',
        icon: 'interest',
        color: 'amber',
      ),
      Category(
        id: 'other-in',
        kind: TransactionKind.income,
        name: 'Other',
        icon: 'other',
        color: 'slate',
      ),
    ];
    ParsedTransaction map(ReceiptScan s) => receiptToTransaction(
      s,
      accounts: accounts,
      categories: categories,
      now: _now,
      accountId: 'cash',
    );

    test('uses the AI category, the store as note and the receipt day', () {
      final t = map(
        ReceiptScan(
          totalMinor: 124550,
          source: ReceiptSource.ai,
          merchant: 'Mercury Drug',
          date: DateTime(2026, 9, 28),
          category: 'Health',
        ),
      );
      expect(t.kind, TransactionKind.expense);
      expect(t.amountMinor, 124550);
      expect(t.categoryId, 'health');
      expect(t.note, 'Mercury Drug');
      expect(t.occurredAt, DateTime(2026, 9, 28, 15, 10));
    });

    test('offline, the store name picks the category', () {
      final t = map(
        const ReceiptScan(
          totalMinor: 25400,
          source: ReceiptSource.device,
          merchant: 'Jollibee',
        ),
      );
      expect(t.categoryId, 'food');
      expect(t.occurredAt, _now);
    });

    test('cashback is income, filed under Refund', () {
      final t = map(
        const ReceiptScan(
          totalMinor: 2500,
          source: ReceiptSource.device,
          kind: TransactionKind.income,
          merchant: 'GCash cashback',
        ),
      );
      expect(t.kind, TransactionKind.income);
      expect(t.categoryId, 'refund');
    });

    test('income uses the AI income category, never an expense one', () {
      final t = map(
        const ReceiptScan(
          totalMinor: 1234,
          source: ReceiptSource.ai,
          kind: TransactionKind.income,
          merchant: 'BPI',
          category: 'Interest',
        ),
      );
      expect(t.categoryId, 'interest');
      final unknown = map(
        const ReceiptScan(
          totalMinor: 1234,
          source: ReceiptSource.ai,
          kind: TransactionKind.income,
          merchant: 'Zqx',
          category: 'Food',
        ),
      );
      expect(unknown.categoryId, 'other-in');
    });

    test('an unknown store goes to Other', () {
      final t = map(
        const ReceiptScan(
          totalMinor: 999,
          source: ReceiptSource.device,
          merchant: 'Zqx Trading',
        ),
      );
      expect(t.categoryId, 'other');
    });
  });

  group('money in', () {
    test('the AI says which way the money went', () {
      final s = SmartReceiptReader.parseAi(
        '{"is_receipt": true, "direction": "in", "merchant": "BPI interest",'
        ' "total": 12.34, "category": "Interest", "items": []}',
        _now,
      )!;
      expect(s.kind, TransactionKind.income);
      expect(s.totalMinor, 1234);
      // No direction means a receipt: money out.
      expect(
        SmartReceiptReader.parseAi(
          '{"is_receipt": true, "total": 5}',
          _now,
        )!.kind,
        TransactionKind.expense,
      );
    });

    test('flipping a scan keeps the amount and drops the other kind\'s '
        'category', () {
      const out = ReceiptScan(
        totalMinor: 5000,
        source: ReceiptSource.ai,
        category: 'Food',
      );
      final flipped = out.withKind(TransactionKind.income);
      expect(flipped.isIncome, isTrue);
      expect(flipped.totalMinor, 5000);
      expect(flipped.category, isNull);
    });

    test('the prompt offers both kinds of category', () {
      final prompt = SmartReceiptReader.prompt((
        expense: ['Food'],
        income: ['Interest', 'Refund'],
      ), _now);
      expect(prompt, contains('"direction": "out" | "in"'));
      expect(prompt, contains('Interest, Refund'));
    });
  });
}
