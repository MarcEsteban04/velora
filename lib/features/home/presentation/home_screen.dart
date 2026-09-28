import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/dusk_backdrop.dart';
import '../../../core/widgets/reveal.dart';
import '../../../core/widgets/speech_bubble.dart';
import '../../../core/widgets/velora_mascot.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/presentation/widgets/account_card.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/coach_tone_style.dart';

/// Home: a greeting, the net worth across accounts, and the accounts
/// themselves. This is the foundation that transactions and budgets build on.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static String _greeting(DateTime now) => switch (now.hour) {
    < 12 => 'Good morning',
    < 18 => 'Good afternoon',
    _ => 'Good evening',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final text = Theme.of(context).textTheme;
    final currency = Currencies.byCode(profile?.currencyCode ?? 'USD');
    final total = accounts
        .where((a) => a.currencyCode == currency.code)
        .fold<int>(0, (sum, a) => sum + a.openingBalanceMinor);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.night,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: DuskBackdrop()),
            Positioned.fill(
              child: ColoredBox(color: AppColors.night.withValues(alpha: 0.6)),
            ),
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                children: [
                  FadeSlideIn(
                    child: Text(
                      '${_greeting(DateTime.now())},',
                      style: text.bodyLarge,
                    ),
                  ),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 80),
                    child: Text(
                      '${profile?.name ?? 'friend'}!',
                      style: text.displaySmall,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 160),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const VeloraMascot(pose: MascotPose.wave, size: 110),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 40),
                            child: SpeechBubble(
                              speaker: 'Velora',
                              message: profile == null
                                  ? 'Welcome!'
                                  : profile.coachTone.onTrackExample(
                                      profile.name,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 240),
                    child: Text(
                      'NET WORTH',
                      style: text.labelMedium?.copyWith(letterSpacing: 1.6),
                    ),
                  ),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 280),
                    child: Text(
                      Money.format(total, currency),
                      style: text.displaySmall?.copyWith(fontSize: 38),
                    ),
                  ),
                  const SizedBox(height: 24),
                  for (final (i, a) in accounts.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: FadeSlideIn(
                        delay: Duration(milliseconds: 340 + i * 80),
                        child: AccountCard(
                          name: a.name,
                          type: a.type,
                          currency: Currencies.byCode(a.currencyCode),
                          balanceMinor: a.openingBalanceMinor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
