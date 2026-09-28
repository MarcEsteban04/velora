import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:velora/core/widgets/island_toast.dart';

void main() {
  late Toaster toast;

  Future<void> host(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => IslandToastHost(child: child!),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            toast = Toast.of(context);
            return const SizedBox.expand();
          },
        ),
      ),
    ),
  );

  testWidgets('shows at the top and tucks itself away', (tester) async {
    await host(tester);
    toast.show('Expense saved');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Expense saved'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Expense saved')).dy, lessThan(80));

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Expense saved'), findsNothing);
  });

  testWidgets('Undo runs the action and closes the island', (tester) async {
    await host(tester);
    var undone = false;
    toast.show(
      'Expense saved',
      action: ToastAction('Undo', () => undone = true),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(undone, isTrue);
    expect(find.text('Expense saved'), findsNothing);
  });

  testWidgets('swipe up to dismiss; a new message replaces the old', (
    tester,
  ) async {
    await host(tester);
    toast.show('First');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    toast.show('Second', tone: ToastTone.error);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);

    await tester.drag(find.text('Second'), const Offset(0, -60));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Second'), findsNothing);
  });
}
