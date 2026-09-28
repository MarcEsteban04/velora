import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/dusk_backdrop.dart';
import '../../accounts/presentation/wallet_screen.dart';
import '../../history/presentation/history_screen.dart';
import '../../home/presentation/home_screen.dart';
import '../../plan/presentation/plan_screen.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/transaction_entry_screen.dart';
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
    final kind = switch (action) {
      QuickAction.expense => TransactionKind.expense,
      QuickAction.income => TransactionKind.income,
      QuickAction.transfer => TransactionKind.transfer,
      QuickAction.scan || QuickAction.ask => null,
    };
    if (kind != null) {
      Navigator.of(context).push(TransactionEntryScreen.route(kind: kind));
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${action.label} is coming soon!')),
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
    0 => HomeScreen(onQuickAction: _onAction, onOpenHistory: () => _select(3)),
    1 => const WalletScreen(),
    2 => const PlanScreen(),
    _ => const HistoryScreen(),
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
        value: AppTheme.overlayStyle.copyWith(
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
