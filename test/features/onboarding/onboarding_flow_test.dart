import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velora/core/money/currency.dart';
import 'package:velora/core/storage/preferences.dart';
import 'package:velora/core/theme/app_theme.dart';
import 'package:velora/features/accounts/data/account_repository.dart';
import 'package:velora/features/accounts/domain/account.dart';
import 'package:velora/features/home/presentation/home_screen.dart';
import 'package:velora/features/onboarding/application/onboarding_controller.dart';
import 'package:velora/features/onboarding/presentation/onboarding_flow.dart';
import 'package:velora/features/profile/data/profile_repository.dart';
import 'package:velora/features/profile/domain/user_profile.dart';

class _InMemoryAccounts implements AccountRepository {
  final created = <Account>[];

  @override
  Stream<List<Account>> watchAll() => Stream.value(List.of(created));

  @override
  Future<Account> create({
    required String name,
    required AccountType type,
    required String currencyCode,
    required int openingBalanceMinor,
  }) async {
    final account = Account(
      id: created.length + 1,
      name: name,
      type: type,
      currencyCode: currencyCode,
      openingBalanceMinor: openingBalanceMinor,
      createdAt: DateTime(2026),
    );
    created.add(account);
    return account;
  }
}

void main() {
  late _InMemoryAccounts accounts;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    accounts = _InMemoryAccounts();
  });

  Future<ProviderContainer> pumpFlow(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          accountRepositoryProvider.overrideWithValue(accounts),
          deviceCurrencyProvider.overrideWithValue(Currencies.byCode('PHP')),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const OnboardingFlow()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    return ProviderScope.containerOf(
      tester.element(find.byType(OnboardingFlow)),
    );
  }

  Future<void> tapNext(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('Continue is disabled until a name is entered', (tester) async {
    await pumpFlow(tester);
    expect(find.text('Hi! What should I call you?'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text("Let's get to know each other"), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Marc');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Nice to meet you, Marc!'), findsOneWidget);
  });

  testWidgets('full flow saves the account and profile, then opens Home', (
    tester,
  ) async {
    final container = await pumpFlow(tester);

    await tester.enterText(find.byType(TextField), 'Marc');
    await tester.pump();
    await tapNext(tester, 'Continue'); // Name
    expect(find.text('Money, made calm'), findsOneWidget);

    await tapNext(tester, 'Continue'); // Promise
    expect(find.text('Choose your main currency'), findsOneWidget);

    await tapNext(tester, 'Continue'); // Currency (PHP detected)
    expect(find.text('Set up your first account'), findsOneWidget);

    await tester.ensureVisible(find.text('E-wallet'));
    await tester.pump();
    await tester.tap(find.text('E-wallet'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField).last, '12000');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('12,000'), findsOneWidget);

    await tapNext(tester, 'Create account');
    expect(find.text('Congrats on your first account, Marc!'), findsOneWidget);

    await tapNext(tester, 'Continue'); // Celebration
    await tapNext(tester, 'Continue'); // Features
    expect(find.text('How should Velora cheer you on?'), findsOneWidget);

    await tester.ensureVisible(find.text('Straight-talk'));
    await tester.pump();
    await tester.tap(find.text('Straight-talk'));
    await tester.pump(const Duration(milliseconds: 400));
    await tapNext(tester, 'Continue'); // Coach
    expect(find.text("You're all set, Marc!"), findsOneWidget);
    expect(find.textContaining('₱12,000.00'), findsOneWidget);

    await tapNext(tester, 'Start tracking');
    await tester.pump(const Duration(seconds: 1));

    expect(accounts.created, hasLength(1));
    final account = accounts.created.single;
    expect(account.name, 'E-wallet');
    expect(account.type, AccountType.eWallet);
    expect(account.currencyCode, 'PHP');
    expect(account.openingBalanceMinor, 1200000);

    final profile = container.read(profileProvider);
    expect(profile?.name, 'Marc');
    expect(profile?.coachTone, CoachTone.direct);
    expect(prefs.getString('profile.v1'), isNotNull);

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
