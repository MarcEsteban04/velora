import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/velora_mascot.dart';
import '../../application/wallet_insight_providers.dart';

/// Velora's take on the wallet, with a shimmering placeholder while it
/// thinks.
class InsightCard extends StatelessWidget {
  const InsightCard({super.key, required this.insight, required this.hidden});

  /// Null while loading.
  final WalletInsight? insight;

  /// With balances hidden, the insight (which quotes amounts) is hidden too.
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final i = insight;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: SizedBox.square(
                  dimension: 26,
                  child: Transform.scale(
                    scale: 1.6,
                    alignment: const Alignment(0, -0.75),
                    child: Image.asset(
                      MascotPose.wave.asset,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'INSIGHT',
                style: text.labelMedium?.copyWith(
                  fontSize: 11,
                  letterSpacing: 1.4,
                  color: AppColors.leafBright,
                ),
              ),
              const Spacer(),
              if (i != null && i.fromAi)
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: AppColors.ember,
                  semanticLabel: 'Written by AI',
                ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: i == null
                ? const _Shimmer(key: ValueKey('loading'))
                : Text(
                    hidden
                        ? 'Balances are hidden. Tap the eye to see '
                              "Velora's take."
                        : i.text,
                    key: ValueKey(i.text + hidden.toString()),
                    style: text.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Shimmer extends StatefulWidget {
  const _Shimmer({super.key});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Velora is thinking',
      child: FadeTransition(
        opacity: Tween(begin: 0.35, end: 0.8).animate(_controller),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final w in [1.0, 0.92, 0.6])
              FractionallySizedBox(
                widthFactor: w,
                child: Container(
                  height: 11,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.hairline(0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Seven bars, one per day, sized by net worth at the end of that day.
/// Today is highlighted.
class DailyBalanceCard extends StatelessWidget {
  const DailyBalanceCard({
    super.key,
    required this.days,
    required this.currency,
    required this.hidden,
  });

  /// Null while loading.
  final List<(DateTime, int)>? days;
  final Currency currency;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final d = days;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DAILY BALANCE',
            style: text.labelMedium?.copyWith(fontSize: 11, letterSpacing: 1.4),
          ),
          if (d != null) ...[
            const SizedBox(height: 4),
            _WeekChange(
              changeMinor: d.last.$2 - d.first.$2,
              currency: currency,
              hidden: hidden,
            ),
          ],
          const SizedBox(height: 10),
          // The card stretches to match the insight beside it; the bars
          // stay a fixed height and sit at the bottom.
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: 76,
                child: d == null
                    ? const SizedBox.shrink()
                    : _Bars(days: d, currency: currency, hidden: hidden),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The change over the week shown, colored by direction.
class _WeekChange extends StatelessWidget {
  const _WeekChange({
    required this.changeMinor,
    required this.currency,
    required this.hidden,
  });

  final int changeMinor;
  final Currency currency;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final up = changeMinor >= 0;
    final color = changeMinor == 0
        ? AppColors.textMuted
        : up
        ? AppColors.leafBright
        : AppColors.ember;
    final amount = hidden
        ? '${currency.symbol} ••••'
        : Money.format(changeMinor.abs(), currency);

    return Row(
      children: [
        Icon(
          changeMinor == 0
              ? Icons.trending_flat_rounded
              : up
              ? Icons.trending_up_rounded
              : Icons.trending_down_rounded,
          size: 15,
          color: color,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${changeMinor == 0 ? '' : (up ? '+' : '−')}$amount',
              semanticsLabel: hidden
                  ? 'Change this week hidden'
                  : '${up ? 'Up' : 'Down'} $amount this week',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontSize: 14, color: color),
            ),
          ),
        ),
      ],
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({
    required this.days,
    required this.currency,
    required this.hidden,
  });

  final List<(DateTime, int)> days;
  final Currency currency;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final values = [for (final (_, v) in days) v];
    final hi = values.reduce((a, b) => a > b ? a : b);
    final lo = values.reduce((a, b) => a < b ? a : b);
    // Scale between a floor and the top so small changes still show.
    double heightOf(int v) =>
        hi == lo ? 0.6 : 0.25 + 0.75 * (v - lo) / (hi - lo);

    return Semantics(
      label: hidden
          ? 'Daily balance hidden'
          : 'Daily balance, last 7 days: '
                '${[for (final (day, v) in days) '${DateFormat('EEE').format(day)} ${Money.format(v, currency)}'].join(', ')}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, (day, v)) in days.indexed)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: hidden ? 0.5 : heightOf(v)),
                        duration: Duration(milliseconds: 500 + i * 60),
                        curve: Curves.easeOutCubic,
                        builder: (context, f, _) => FractionallySizedBox(
                          heightFactor: f,
                          child: Container(
                            width: 9,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: i == days.length - 1
                                  ? AppColors.leafBright
                                  : AppColors.leaf.withValues(alpha: 0.38),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat('E').format(day).substring(0, 1),
                    style: text.labelMedium?.copyWith(
                      fontSize: 11,
                      color: i == days.length - 1
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
