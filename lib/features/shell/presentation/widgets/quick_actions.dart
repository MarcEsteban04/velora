import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';

enum QuickAction {
  expense('Expense', 'Money going out', Icons.north_east_rounded),
  income('Income', 'Money coming in', Icons.south_west_rounded),
  transfer('Transfer', 'Between accounts', Icons.swap_horiz_rounded),
  scan('Scan receipt', 'Snap it, done', Icons.document_scanner_rounded),
  ask('Ask Velora', 'Log by chatting', Icons.chat_bubble_rounded);

  const QuickAction(this.label, this.hint, this.icon);

  final String label;
  final String hint;
  final IconData icon;

  /// A getter rather than a field, so it follows the current scene.
  Color get color => switch (this) {
    QuickAction.expense => AppColors.rust,
    QuickAction.income => AppColors.leafBright,
    QuickAction.transfer => AppColors.sky,
    QuickAction.scan => AppColors.lilac,
    QuickAction.ask => AppColors.ember,
  };
}

/// A blurred scrim with a panel of actions rising from the "+" button. The
/// two actions people use most (Expense and Income) get big tiles, and the
/// rest sit in rows underneath. Everything springs in with a stagger.
class QuickActionsOverlay extends StatefulWidget {
  const QuickActionsOverlay({
    super.key,
    required this.open,
    required this.onClose,
    required this.onAction,
    required this.bottomInset,
  });

  final bool open;
  final VoidCallback onClose;
  final ValueChanged<QuickAction> onAction;

  /// Keeps the panel above the nav bar.
  final double bottomInset;

  @override
  State<QuickActionsOverlay> createState() => _QuickActionsOverlayState();
}

class _QuickActionsOverlayState extends State<QuickActionsOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 220),
  );

  @override
  void didUpdateWidget(QuickActionsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != oldWidget.open) {
      widget.open ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Animation<double> _stagger(int i) => CurvedAnimation(
    parent: _controller,
    curve: Interval(0.08 * i, 0.6 + 0.08 * i, curve: Curves.easeOutBack),
    reverseCurve: Curves.easeIn,
  );

  Widget _springIn(int i, Widget child) {
    final a = _stagger(i);
    return AnimatedBuilder(
      animation: a,
      child: child,
      builder: (context, child) => Opacity(
        opacity: a.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - a.value) * 40),
          child: Transform.scale(scale: 0.9 + 0.1 * a.value, child: child),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_controller.isDismissed) return const SizedBox.shrink();
        final t = Curves.easeOut.transform(_controller.value);
        return Stack(
          children: [
            // Scrim: blurs and dims the dashboard, and tapping it closes.
            Positioned.fill(
              child: GestureDetector(
                onTap: widget.onClose,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10 * t, sigmaY: 10 * t),
                  child: ColoredBox(
                    color: AppColors.night.withValues(alpha: 0.55 * t),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: widget.bottomInset,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _springIn(
            0,
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 12),
              child: Text(
                'What would you like to log?',
                style: text.titleMedium,
              ),
            ),
          ),
          Row(
            children: [
              for (final (i, a) in [
                QuickAction.expense,
                QuickAction.income,
              ].indexed) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: _springIn(
                    i + 1,
                    _BigTile(action: a, onTap: () => widget.onAction(a)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _springIn(
            3,
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              radius: 24,
              child: Column(
                children: [
                  for (final (i, a) in [
                    QuickAction.transfer,
                    QuickAction.scan,
                    QuickAction.ask,
                  ].indexed) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 68,
                        color: AppColors.hairline(0.06),
                      ),
                    _RowTile(action: a, onTap: () => widget.onAction(a)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BigTile extends StatelessWidget {
  const _BigTile({required this.action, required this.onTap});

  final QuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: '${action.label}: ${action.hint}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  action.color.withValues(alpha: 0.32),
                  AppColors.surface.withValues(alpha: 0.9),
                ],
              ),
              border: Border.all(color: action.color.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: action.color.withValues(alpha: 0.2),
                  ),
                  child: Icon(action.icon, color: action.color),
                ),
                const SizedBox(height: 22),
                Text(action.label, style: text.titleMedium),
                Text(action.hint, style: text.labelMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.action, required this.onTap});

  final QuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    // Its own Material, so the ripple paints above the frosted card.
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: action.color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(action.icon, color: action.color, size: 22),
        ),
        title: Text(
          action.label,
          style: text.titleMedium?.copyWith(fontSize: 15),
        ),
        subtitle: Text(action.hint, style: text.labelMedium),
        trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
      ),
    );
  }
}
