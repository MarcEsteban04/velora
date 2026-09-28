import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:velora/core/money/currency.dart';
import 'package:velora/core/theme/app_theme.dart';
import 'package:velora/features/accounts/data/account_repository.dart';
import 'package:velora/features/accounts/domain/account.dart';
import 'package:velora/features/home/presentation/home_screen.dart';
import 'package:velora/features/onboarding/application/onboarding_controller.dart';
import 'package:velora/features/onboarding/data/onboarding_repository.dart';
import 'package:velora/features/onboarding/presentation/onboarding_flow.dart';
import 'package:velora/features/profile/data/profile_repository.dart';
import 'package:velora/features/profile/domain/user_profile.dart';

/// Stands in for Supabase: one in-memory "backend" behind all three
/// repositories, so the flow is tested end to end without the network.
class _FakeBackend
    implements OnboardingRepository, ProfileRepository, AccountRepository {
  UserProfile? profile;
  final accounts = <Account>[];
  int completeCalls = 0;

  @override
  Future<void> complete({
    required String displayName,
    required String currencyCode,
    required CoachTone coachTone,
    required String accountName,
    required AccountType accountType,
    required int openingBalanceMinor,
  }) async {
    completeCalls++;
    profile = UserProfile(
      name: displayName,
      currencyCode: currencyCode,
      coachTone: coachTone,
      onboardedAt: DateTime(2026),
    );
    accounts.add(
      Account(
        id: 'acc-1',
        name: accountName,
        type: accountType,
        currencyCode: currencyCode,
        openingBalanceMinor: openingBalanceMinor,
        createdAt: DateTime(2026),
      ),
    );
  }

  @override
  Future<UserProfile?> fetch() async => profile;

  @override
  Future<List<Account>> fetchAll() async => List.of(accounts);
}

void main() {
  late _FakeBackend backend;

  setUp(() => backend = _FakeBackend());

  Future<ProviderContainer> pumpFlow(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingRepositoryProvider.overrideWithValue(backend),
          profileRepositoryProvider.overrideWithValue(backend),
          accountRepositoryProvider.overrideWithValue(backend),
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

    expect(backend.completeCalls, 1);
    final account = backend.accounts.single;
    expect(account.name, 'E-wallet');
    expect(account.type, AccountType.eWallet);
    expect(account.currencyCode, 'PHP');
    expect(account.openingBalanceMinor, 1200000);

    final profile = await container.read(profileProvider.future);
    expect(profile?.name, 'Marc');
    expect(profile?.coachTone, CoachTone.direct);

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
