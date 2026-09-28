import 'package:flutter_test/flutter_test.dart';
import 'package:velora/features/accounts/domain/account.dart';
import 'package:velora/features/ask/domain/transaction_parser.dart';
import 'package:velora/features/transactions/domain/category.dart';
import 'package:velora/features/transactions/domain/transaction.dart';

final _now = DateTime(2026, 9, 30, 15, 20); // Wednesday afternoon.

Account _acc(String id, String name, {String? institution}) => Account(
  id: id,
  name: name,
  type: AccountType.cash,
  currencyCode: 'PHP',
  openingBalanceMinor: 0,
  createdAt: DateTime(2026),
  institutionId: institution,
);

Category _cat(String id, TransactionKind kind, String name, String icon) =>
    Category(id: id, kind: kind, name: name, icon: icon, color: 'ember');

final _parser = TransactionParser(
  accounts: [
    _acc('cash', 'Cash'),
    _acc('gcash', 'GCash', institution: 'gcash'),
    _acc('bpi', 'BPI Savings', institution: 'bpi'),
  ],
  categories: [
    _cat('food', TransactionKind.expense, 'Food', 'food'),
    _cat('transport', TransactionKind.expense, 'Transport', 'transport'),
    _cat('bills', TransactionKind.expense, 'Bills', 'bills'),
    _cat('other', TransactionKind.expense, 'Other', 'other'),
    _cat('salary', TransactionKind.income, 'Salary', 'salary'),
    _cat('other-in', TransactionKind.income, 'Other', 'other'),
  ],
  now: _now,
  defaultAccountId: 'cash',
);

void main() {
  test('spent 250 on lunch from cash', () {
    final t = _parser.parse('Spent 250 on lunch from Cash')!;
    expect(t.kind, TransactionKind.expense);
    expect(t.amountMinor, 25000);
    expect(t.accountId, 'cash');
    expect(t.accountGuessed, isFalse);
    expect(t.categoryId, 'food');
    expect(t.note, 'Lunch');
    expect(t.occurredAt, DateTime(2026, 9, 30, 15, 20));
  });

  test('Taglish, shorthand amounts and days', () {
    final grab = _parser.parse('grab 180 kahapon gamit gcash')!;
    expect(grab.categoryId, 'transport');
    expect(grab.accountId, 'gcash');
    expect(grab.amountMinor, 18000);
    expect(grab.occurredAt.day, 29);

    final meralco = _parser.parse('paid meralco ₱2,450.50 via bpi')!;
    expect(meralco.categoryId, 'bills');
    expect(meralco.amountMinor, 245050);
    expect(meralco.accountId, 'bpi');

    final monday = _parser.parse('jollibee 1.2k monday')!;
    expect(monday.amountMinor, 120000);
    expect(monday.occurredAt.day, 28);
    expect(monday.accountGuessed, isTrue);
  });

  test('income and transfers', () {
    final salary = _parser.parse('got 25k salary sa bpi')!;
    expect(salary.kind, TransactionKind.income);
    expect(salary.amountMinor, 2500000);
    expect(salary.categoryId, 'salary');
    expect(salary.accountId, 'bpi');

    final move = _parser.parse('moved 1000 from bpi to gcash')!;
    expect(move.kind, TransactionKind.transfer);
    expect(move.accountId, 'bpi');
    expect(move.toAccountId, 'gcash');
    expect(move.categoryId, isNull);
  });

  test('unknown things land in Other with a note', () {
    final t = _parser.parse('spent 300 on haircut')!;
    expect(t.categoryId, 'other');
    expect(t.note, 'Haircut');
  });

  test('questions and plain numbers are not transactions', () {
    expect(_parser.parse('how much did I spend on food?'), isNull);
    expect(_parser.parse('magkano pera ko'), isNull);
    expect(_parser.parse('what is 250'), isNull);
    expect(_parser.parse('250'), isNull);
    expect(_parser.parse('hello velora'), isNull);
  });
}
