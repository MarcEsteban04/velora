import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:velora/app/velora_app.dart';
import 'package:velora/core/money/currency.dart';
import 'package:velora/core/theme/app_theme.dart';
import 'package:velora/features/accounts/data/account_repository.dart';
import 'package:velora/features/accounts/domain/account.dart';
import 'package:velora/features/app_lock/data/pin_repository.dart';
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

/// Keeps the PIN in memory. The real repository hashes on an isolate, which
/// can't run inside a widget test's fake clock.
class _FakePins implements PinRepository {
  String? pin;

  @override
  Future<bool> hasPin() async => pin != null;

  @override
  Future<void> setPin(String value) async => pin = value;

  @override
  Future<PinCheck> verify(String value) async =>
      value == pin ? const PinAccepted() : const PinRejected(4);

  @override
  Future<DateTime?> lockedUntil() async => null;

  @override
  Future<void> clear() async => pin = null;
}

void main() {
  late _FakeBackend backend;
  late _FakePins pins;

  setUp(() {
    backend = _FakeBackend();
    pins = _FakePins();
  });

  List<Override> overrides() => [
    onboardingRepositoryProvider.overrideWithValue(backend),
    profileRepositoryProvider.overrideWithValue(backend),
    accountRepositoryProvider.overrideWithValue(backend),
    pinRepositoryProvider.overrideWithValue(pins),
    deviceCurrencyProvider.overrideWithValue(Currencies.byCode('PHP')),
  ];

  /// A typical phone (411x914 logical pixels), so full-height screens such
  /// as the PIN pad fit the way they do on a device.
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
  }

  Future<void> typePin(WidgetTester tester, String pin) async {
    for (final d in pin.split('')) {
      await tester.tap(find.text(d));
      await tester.pump(const Duration(milliseconds: 60));
    }
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<ProviderContainer> pumpFlow(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
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

  testWidgets('from Welcome to Home: saves everything and sets a PIN', (
    tester,
  ) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(overrides: overrides(), child: const VeloraApp()),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Get started'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingFlow)),
    );

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
    expect(find.text('Protect your space'), findsOneWidget);

    await typePin(tester, '1234');
    expect(find.textContaining('easy to guess'), findsOneWidget);

    await typePin(tester, '2580');
    expect(find.text('Confirm your PIN'), findsOneWidget);
    await typePin(tester, '2581');
    expect(find.textContaining("didn't match"), findsOneWidget);

    await typePin(tester, '2580');
    await typePin(tester, '2580');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text("You're all set, Marc!"), findsOneWidget);
    expect(pins.pin, isNull, reason: 'saved only when onboarding completes');
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

    expect(pins.pin, '2580');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Enter your PIN'), findsNothing);
  });

  testWidgets('returning users must enter their PIN to see Home', (
    tester,
  ) async {
    await backend.complete(
      displayName: 'Marc',
      currencyCode: 'PHP',
      coachTone: CoachTone.balanced,
      accountName: 'Cash',
      accountType: AccountType.cash,
      openingBalanceMinor: 500000,
    );
    pins.pin = '2580';

    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(overrides: overrides(), child: const VeloraApp()),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Enter your PIN'), findsOneWidget);
    expect(find.text('Welcome back, Marc!'), findsOneWidget);

    await typePin(tester, '1111');
    expect(find.textContaining('Wrong PIN'), findsOneWidget);

    await typePin(tester, '2580');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Enter your PIN'), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('onboarded users without a PIN are asked to create one', (
    tester,
  ) async {
    await backend.complete(
      displayName: 'Marc',
      currencyCode: 'PHP',
      coachTone: CoachTone.balanced,
      accountName: 'Cash',
      accountType: AccountType.cash,
      openingBalanceMinor: 0,
    );

    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(overrides: overrides(), child: const VeloraApp()),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Protect your space'), findsOneWidget);

    await typePin(tester, '2580');
    await typePin(tester, '2580');
    await tester.pump(const Duration(seconds: 1));
    expect(pins.pin, '2580');
    expect(find.text('Protect your space'), findsNothing);
  });

  testWidgets('shell: tabs switch, + opens quick actions, back goes Home', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await backend.complete(
      displayName: 'Marc',
      currencyCode: 'PHP',
      coachTone: CoachTone.balanced,
      accountName: 'Cash',
      accountType: AccountType.cash,
      openingBalanceMinor: 1200000,
    );
    pins.pin = '2580';
    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(overrides: overrides(), child: const VeloraApp()),
    );
    await tester.pump(const Duration(seconds: 1));
    await typePin(tester, '2580');
    await tester.pump(const Duration(seconds: 2));

    // Dashboard content.
    expect(find.text('NET WORTH'), findsOneWidget);
    expect(find.text('Your accounts'), findsOneWidget);
    expect(find.text('₱12,000.00'), findsWidgets);

    // Hide balances masks every amount.
    await tester.tap(find.byIcon(Icons.visibility_rounded));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('₱12,000.00'), findsNothing);

    // Switch tabs.
    await tester.tap(find.bySemanticsLabel(RegExp('Plan tab')));
    await tester.pump(const Duration(milliseconds: 500));
    // Only the active tab is on screen. This guards against tabs stacking
    // on top of each other.
    expect(
      find.text('Budgets and goals that keep you on track.'),
      findsOneWidget,
    );
    expect(find.text('NET WORTH'), findsNothing);
    expect(find.text('Every peso, searchable and tidy.'), findsNothing);

    // Android back returns to Home instead of leaving the app.
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('NET WORTH'), findsOneWidget);
    expect(
      find.text('Budgets and goals that keep you on track.'),
      findsNothing,
    );

    // + opens quick actions; picking one closes the panel with a note.
    await tester.tap(find.bySemanticsLabel(RegExp('Add: open quick actions')));
    // Let the spring-in animation settle before tapping a tile.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.text('What would you like to log?'), findsOneWidget);
    await tester.tap(find.text('Money coming in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('What would you like to log?'), findsNothing);
    expect(find.textContaining('Income is coming next'), findsOneWidget);
    semantics.dispose();
  });
}
