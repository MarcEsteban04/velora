import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:velora/core/theme/app_theme.dart';
import 'package:velora/features/welcome/presentation/welcome_screen.dart';
import 'package:velora/features/welcome/presentation/widgets/mascot_hero.dart';

Widget _wrap(VoidCallback onGetStarted) => MaterialApp(
  theme: AppTheme.dark,
  home: WelcomeScreen(onGetStarted: onGetStarted),
);

void main() {
  testWidgets('shows the brand, the tagline and the privacy promise', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(() {}));
    await tester.pump(const Duration(seconds: 2));

    expect(find.bySemanticsLabel('Velora'), findsOneWidget);
    expect(find.textContaining('cozy companion'), findsOneWidget);
    expect(find.textContaining('No account needed'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('Get started celebrates, then calls onGetStarted once', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(() => taps++));
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('Get started'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(MascotHero.celebrationLine), findsOneWidget);

    // A second tap during the celebration is ignored.
    await tester.tap(find.text('Get started'), warnIfMissed: false);
    expect(taps, 0);

    await tester.pump(const Duration(seconds: 1));
    expect(taps, 1);
  });

  testWidgets('tapping the mascot cycles its speech bubble', (tester) async {
    await tester.pumpWidget(_wrap(() {}));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(MascotHero.lines[0]), findsOneWidget);

    await tester.tap(find.byType(MascotHero));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(MascotHero.lines[1]), findsOneWidget);
  });

  testWidgets('fits a small phone without overflowing', (tester) async {
    tester.view.physicalSize = const Size(320, 568) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(() {}));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
