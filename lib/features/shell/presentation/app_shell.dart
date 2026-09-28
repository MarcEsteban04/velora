import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/dusk_backdrop.dart';
import '../../../core/widgets/velora_mascot.dart';
import '../../home/presentation/home_screen.dart';
import 'widgets/coming_soon_tab.dart';
import 'widgets/floating_nav_bar.dart';
import 'widgets/quick_actions.dart';

/// The signed-in app: four tabs under a floating nav bar, plus the quick
/// actions opened from the "+" button.
///
/// Tabs are kept alive (switching doesn't reset scroll or state) and
/// cross-fade. The nav bar hides while you scroll down and returns when you
/// scroll up. Android back returns to Home before leaving the app.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;

  /// Fades the incoming tab in. Outgoing tabs go offstage right away. They
  /// must never rely on their own fade-out, because their tickers are paused
  /// and the fade would freeze halfway.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: 1,
  );

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  bool _navVisible = true;
  bool _actionsOpen = false;

  static const _destinations = [
    NavDestination(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    NavDestination(
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet_rounded,
      label: 'Wallet',
    ),
    NavDestination(
      icon: Icons.event_note_outlined,
      activeIcon: Icons.event_note_rounded,
      label: 'Plan',
    ),
    NavDestination(
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
      label: 'History',
    ),
  ];

  void _select(int index) {
    if (index != _index && !MediaQuery.disableAnimationsOf(context)) {
      _fade.forward(from: 0);
    }
    _setIndex(index);
  }

  void _setIndex(int index) => setState(() {
    _index = index;
    _navVisible = true;
    _actionsOpen = false;
  });

  void _toggleActions() => setState(() => _actionsOpen = !_actionsOpen);

  void _onAction(QuickAction action) {
    setState(() => _actionsOpen = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            "${action.label} is coming next. It's the next thing we're building!",
          ),
        ),
      );
  }

  bool _onScroll(UserScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    final show = switch (n.direction) {
      ScrollDirection.reverse => false,
      ScrollDirection.forward => true,
      ScrollDirection.idle => _navVisible,
    };
    if (show != _navVisible) setState(() => _navVisible = show);
    return false;
  }

  Widget _tab(int i) => switch (i) {
    0 => HomeScreen(onQuickAction: _onAction),
    1 => const ComingSoonTab(
      title: 'Wallet',
      subtitle: 'All your accounts and balances in one place.',
      pose: MascotPose.wallet,
      previews: [
        (
          Icons.add_card_rounded,
          'Add cash, bank, e-wallet and savings accounts',
        ),
        (Icons.swap_horiz_rounded, 'Move money between accounts'),
        (Icons.show_chart_rounded, 'See how your balance changes over time'),
      ],
    ),
    2 => const ComingSoonTab(
      title: 'Plan',
      subtitle: 'Budgets and goals that keep you on track.',
      pose: MascotPose.thumbsUp,
      previews: [
        (
          Icons.pie_chart_rounded,
          'Category budgets with a heads-up before you overspend',
        ),
        (Icons.flag_rounded, 'Savings goals with progress you can feel'),
        (
          Icons.event_repeat_rounded,
          'Bills and planned payments, never missed',
        ),
      ],
    ),
    _ => const ComingSoonTab(
      title: 'History',
      subtitle: 'Every peso, searchable and tidy.',
      pose: MascotPose.coin,
      previews: [
        (Icons.search_rounded, 'Search and filter every transaction'),
        (Icons.calendar_month_rounded, 'Daily summaries at a glance'),
        (Icons.ios_share_rounded, 'Export to a spreadsheet anytime'),
      ],
    ),
  };

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0 && !_actionsOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_actionsOpen) {
          setState(() => _actionsOpen = false);
        } else {
          _select(0);
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        ),
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              const Positioned.fill(child: DuskBackdrop(showMoon: false)),
              Positioned.fill(
                child: ColoredBox(
                  color: AppColors.night.withValues(alpha: 0.62),
                ),
              ),
              NotificationListener<UserScrollNotification>(
                onNotification: _onScroll,
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _fade,
                    curve: Curves.easeOut,
                  ),
                  // Hidden tabs stay alive (scroll position and state are
                  // kept) but are offstage: not painted, not tappable, and
                  // hidden from screen readers.
                  child: Stack(
                    children: [
                      for (var i = 0; i < _destinations.length; i++)
                        Positioned.fill(
                          child: Offstage(
                            offstage: i != _index,
                            child: TickerMode(
                              enabled: i == _index,
                              child: _tab(i),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: QuickActionsOverlay(
                  open: _actionsOpen,
                  onClose: () => setState(() => _actionsOpen = false),
                  onAction: _onAction,
                  bottomInset: FloatingNavBar.reservedHeight(context) - 4,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: FloatingNavBar(
                  destinations: _destinations,
                  currentIndex: _index,
                  onSelect: _select,
                  onAdd: _toggleActions,
                  addOpen: _actionsOpen,
                  visible: _navVisible,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
