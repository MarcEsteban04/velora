import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velora/app/velora_app.dart';
import 'package:velora/features/accounts/domain/account.dart';
import 'package:velora/features/ask/domain/chat_message.dart';
import 'package:velora/features/profile/domain/user_profile.dart';
import 'package:velora/features/transactions/domain/transaction.dart';

import '../../support/fakes.dart';

void main() {
  late FakeBackend db;
  late FakePins pins;
  late FakeAsk ask;
  late SharedPreferences prefs;

  setUp(() async {
    db = FakeBackend();
    pins = FakePins()..pin = '2580';
    ask = FakeAsk();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await db.complete(
      displayName: 'Marc',
      currencyCode: 'PHP',
      coachTone: CoachTone.balanced,
      accountName: 'Cash',
      accountType: AccountType.cash,
      openingBalanceMinor: 1200000,
    );
  });

  Future<void> frames(WidgetTester tester, [int n = 12]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> openAsk(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(db, pins, prefs, ask: ask),
        child: const VeloraApp(),
      ),
    );
    await frames(tester, 16);
    for (final d in '2580'.split('')) {
      await tester.tap(find.text(d).last);
      await tester.pump(const Duration(milliseconds: 60));
    }
    await frames(tester, 30);
    await tester.tap(find.bySemanticsLabel(RegExp('Add: open quick actions')));
    await frames(tester);
    await tester.tap(find.text('Ask Velora'));
    await tester.pump();
    await frames(tester, 16);
  }

  Future<void> say(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Send'));
    await tester.pump();
    await frames(tester, 16);
  }

  testWidgets('log by chatting, then undo', (tester) async {
    final semantics = tester.ensureSemantics();
    await openAsk(tester);
    expect(find.textContaining('I’m Velora'), findsOneWidget);
    expect(find.textContaining('never your notes'), findsOneWidget);

    await say(tester, 'Spent 250 on lunch from Cash');
    expect(find.text('Log it'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);
    // Nothing is saved until confirmed.
    expect(db.transactions, isEmpty);

    await tester.tap(find.text('Log it'));
    await tester.pump();
    await frames(tester);
    expect(db.transactions, hasLength(1));
    final t = db.transactions.single;
    expect(t.kind, TransactionKind.expense);
    expect(t.amountMinor, 25000);
    expect(t.categoryId, 'food');
    expect(t.note, 'Lunch');
    expect(find.text('Logged'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    await frames(tester);
    expect(db.transactions, isEmpty);
    expect(find.textContaining('Undone'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('offline, the phone answers from the numbers', (tester) async {
    final semantics = tester.ensureSemantics();
    await openAsk(tester);

    // The AI is tried first; when it's unreachable, the phone answers.
    await say(tester, 'What’s my net worth?');
    expect(ask.requests, hasLength(1));
    expect(find.textContaining('Your net worth is ₱12,000.00'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a real conversation, remembered turn to turn', (tester) async {
    final semantics = tester.ensureSemantics();
    await openAsk(tester);

    ask.reply = const AiReply(text: 'Hi Marc! How’s your day going?');
    await say(tester, 'hi velora!');
    expect(find.text('Hi Marc! How’s your day going?'), findsOneWidget);
    expect(find.text('Log it'), findsNothing);

    ask.reply = const AiReply(text: 'Mostly food this week.');
    await say(tester, 'why so much?');
    expect(find.text('Mostly food this week.'), findsOneWidget);
    // The follow-up carries the chat so far.
    final history = ask.histories.last;
    expect(history.map((m) => m.$2), [
      'hi velora!',
      'Hi Marc! How’s your day going?',
      'why so much?',
    ]);
    expect(ask.requests.last['net_worth'], '12000.00');
    semantics.dispose();
  });

  testWidgets('a question with an amount is talked about, not logged', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openAsk(tester);
    ask.reply = const AiReply(text: 'That’s a solid start for a fund.');
    await say(tester, 'I earn 30000 a month, is that enough?');
    expect(find.text('That’s a solid start for a fund.'), findsOneWidget);
    expect(find.text('Log it'), findsNothing);
    semantics.dispose();
  });

  testWidgets('the AI can still offer to log something', (tester) async {
    final semantics = tester.ensureSemantics();
    await openAsk(tester);
    ask.reply = const AiReply(
      text: 'Here’s what I’ll log for the concert.',
      action: AiAction(kind: 'expense', amount: 1500, category: 'Fun'),
    );
    await say(
      tester,
      'I bought concert tickets for my sister and me, can you add it',
    );
    expect(ask.requests.single['net_worth'], '12000.00');
    expect(find.text('Here’s what I’ll log for the concert.'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
    expect(find.text('Log it'), findsOneWidget);
    semantics.dispose();
  });
}
